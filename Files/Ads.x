#import "Headers.h"

static const void *kFilteredSectionKey = &kFilteredSectionKey;

// Marks a section as processed (skipped on later passes); always returns NO (keep).
static BOOL ymKeepSection(GPBMessage *sectionRenderer) {
    objc_setAssociatedObject(sectionRenderer, kFilteredSectionKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return NO;
}

// YouTube-X (https://github.com/PoomSmart/YouTube-X)
static BOOL isProductList(YTICommand *command) {
    if ([command respondsToSelector:@selector(yt_showEngagementPanelEndpoint)]) {
        YTIShowEngagementPanelEndpoint *endpoint = [command yt_showEngagementPanelEndpoint];
        return [endpoint.identifier.tag isEqualToString:@"PAproduct_list"];
    }
    return NO;
}

// One compiled regex matching any of the literals: a single scan instead of many containsString: passes.
static NSRegularExpression *ymLiteralRegex(NSArray<NSString *> *literals) {
    NSMutableArray<NSString *> *escaped = [NSMutableArray arrayWithCapacity:literals.count];
    for (NSString *literal in literals) [escaped addObject:[NSRegularExpression escapedPatternForString:literal]];
    return [NSRegularExpression regularExpressionWithPattern:[escaped componentsJoinedByString:@"|"] options:0 error:nil];
}

static NSString *ymFirstRegexMatch(NSString *string, NSRegularExpression *regex) {
    if (!string.length) return nil;
    NSRange range = [regex rangeOfFirstMatchInString:string options:0 range:NSMakeRange(0, string.length)];
    return range.location == NSNotFound ? nil : [string substringWithRange:range];
}

static NSString *getPostString(NSString *description) {
    static NSRegularExpression *regex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = ymLiteralRegex(@[
            @"poll_post_root.eml",
            @"options_post_root.eml",
            @"images_post_root_slim.eml",
            @"images_post_responsive_root.eml",
            @"options_post_responsive_root.eml",
            @"post_base_wrapper_slim.eml",
            @"text_post_root_slim.eml",
            @"text_post_responsive_root.eml",
            @"videos_post_root.eml"
        ]);
    });
    return ymFirstRegexMatch(description, regex);
}

static NSString *getAdString(NSString *description) {
    static NSRegularExpression *regex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        regex = ymLiteralRegex(@[
            @"brand_promo",
            @"brand_video_shelf",
            @"brand_video_singleton",
            @"carousel_footered_layout",
            @"carousel_headered_layout",
            @"eml.expandable_metadata",
            @"feed_ad_metadata",
            @"full_width_portrait_image_layout",
            @"full_width_square_image_layout",
            @"grid_ads_image_layout",
            @"landscape_image_wide_button_layout",
            @"post_shelf",
            @"product_carousel",
            @"product_engagement_panel",
            @"product_item",
            @"shopping_carousel",
            @"shopping_item_card_list",
            @"statement_banner",
            @"square_image_layout",
            @"text_image_button_layout",
            @"text_search_ad",
            @"video_display_full_layout",
            @"video_display_full_buttoned_layout"
        ]);
    });
    return ymFirstRegexMatch(description, regex);
}

static BOOL isAdRenderer(YTIElementRenderer *elementRenderer) {
    if (!elementRenderer) return NO;
    if (elementRenderer.compatibilityOptions.hasAdLoggingData) return YES;
    return getAdString([elementRenderer description]) != nil;
}

NSMutableArray <YTIItemSectionRenderer *> *filteredArray(NSArray <YTIItemSectionRenderer *> *array) {
    const BOOL hideShorts = IS_ENABLED(HideShortsShelf);
    const BOOL keepShortsSub = IS_ENABLED(KeepShortsSubscript);
    const BOOL hideFeedPost = IS_ENABLED(HideFeedPost);
    const BOOL hidePlayables = IS_ENABLED(HidePlayables);
    const BOOL hideHoriShelf = IS_ENABLED(HideHoriShelf);
    const BOOL hideCommuGuide = IS_ENABLED(HideCommuGuide);
    const BOOL hideGenMusic = IS_ENABLED(HideGenMusicShelf);
    const BOOL hideSurveys = IS_ENABLED(HideSurveys);
    const BOOL hideComments = IS_ENABLED(HideCommentsSection);

    NSMutableArray <YTIItemSectionRenderer *> *newArray = [array mutableCopy];
    NSIndexSet *removeIndexes = [newArray indexesOfObjectsPassingTest:^BOOL(YTIItemSectionRenderer *sectionRenderer, NSUInteger idx, BOOL *stop) {
        if (objc_getAssociatedObject(sectionRenderer, kFilteredSectionKey)) return NO;
        else if ([sectionRenderer isKindOfClass:%c(YTIShelfRenderer)]) {
            NSString *description = [sectionRenderer description];
            if ([description containsString:@"community-tab-chip-posts-section"]) return ymKeepSection(sectionRenderer);
            if (hideShorts) {
                if (keepShortsSub && [description containsString:@"subscriptions-shorts-shelf-item"]) return ymKeepSection(sectionRenderer);
                if ([description containsString:@"shorts_video_cell.eml"]) return YES;
                if ([description containsString:@"shelf_header.eml"] && [description containsString:@"youtube_shorts_24_cairo"]) return YES;
            }
            if (hideFeedPost && getPostString(description) != nil) return YES;

            // Strip ad cells from shelf carousels.
            NSMutableArray <YTIHorizontalListSupportedRenderers *> *itemsArray = ((YTIShelfRenderer *)sectionRenderer).content.horizontalListRenderer.itemsArray;
            if (itemsArray.count > 0) {
                [itemsArray removeObjectsAtIndexes:[itemsArray indexesOfObjectsPassingTest:^BOOL(YTIHorizontalListSupportedRenderers *horizontalListSupportedRenderers, NSUInteger idx2, BOOL *stop2) {
                    return isAdRenderer(horizontalListSupportedRenderers.elementRenderer);
                }]];
            }
            return ymKeepSection(sectionRenderer);
        } else if ([sectionRenderer isKindOfClass:%c(YTIItemSectionRenderer)]) {
            NSString *description = [sectionRenderer description];
            if ([description containsString:@"community-tab-chip-posts-section"]) return ymKeepSection(sectionRenderer);

            // Drop "SPunlimited" promo rows along with the divider in front of each.
            if ([description containsString:@"UNLIMITED"] && [description containsString:@"SPunlimited"]) {
                NSMutableArray <YTIItemSectionSupportedRenderers *> *contentsArray = sectionRenderer.contentsArray;
                NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];
                __block NSUInteger lastCellDividerIndex = NSNotFound;
                [contentsArray enumerateObjectsUsingBlock:^(YTIItemSectionSupportedRenderers *item, NSUInteger idx2, BOOL *stop2) {
                    NSString *desc = [item description];
                    if ([desc containsString:@"cell_divider.eml"]) lastCellDividerIndex = idx2;
                    else if ([desc containsString:@"UNLIMITED"] && [desc containsString:@"SPunlimited"]) {
                        [indexesToRemove addIndex:idx2];
                        if (lastCellDividerIndex != NSNotFound) {
                            [indexesToRemove addIndex:lastCellDividerIndex];
                            lastCellDividerIndex = NSNotFound;
                        }
                    }
                }];
                [contentsArray removeObjectsAtIndexes:indexesToRemove];
                return ymKeepSection(sectionRenderer);
            }

            if (hideShorts) {
                const BOOL isShortsShelf = [description containsString:@"shorts_shelf.eml"];
                const BOOL isHistory = [description containsString:@"history-shorts-shelf-item"];
                const BOOL isSubsShorts = [description containsString:@"subscriptions-shorts-shelf-item"];
                if ([description containsString:@"video_lockup_overlay"]) return YES;
                if (isShortsShelf && !isHistory && !(keepShortsSub && isSubsShorts)) return YES;
            }

            if ((hidePlayables || hideHoriShelf) && [description containsString:@"horizontal_shelf.eml"]) {
                if (hidePlayables && [description containsString:@"FEmini_app_destination"]) return YES;
                if (hideHoriShelf && ![description containsString:@"UCYfdidRxbB8Qhf0Nx7ioOYw"] && ![description containsString:@"FElibrary"] && ![description containsString:@"mini_game_card.eml"] && ![description containsString:@"FEplaylist_aggregation"]) return YES;
            }

            if (hideCommuGuide && ([description containsString:@"community_guidelines.eml"] || [description containsString:@"channel_guidelines_entry_banner.eml"])) return YES;
            if (hideFeedPost && getPostString(description) != nil) return YES;
            if (hideGenMusic && [description containsString:@"feed_nudge.eml"]) return YES;
            if (hideSurveys && [description containsString:@"in_feed_survey.eml"]) return YES;
            if (hideComments && [description containsString:@"comment-item-section"] && [description containsString:@"comments-entry-point"]) return YES;

            // Strip ad elements; drop the whole section if only the ad remains on top.
            NSMutableArray <YTIItemSectionSupportedRenderers *> *contentsArray = sectionRenderer.contentsArray;
            if (contentsArray.count > 1) {
                [contentsArray removeObjectsAtIndexes:[contentsArray indexesOfObjectsPassingTest:^BOOL(YTIItemSectionSupportedRenderers *sectionSupportedRenderers, NSUInteger idx2, BOOL *stop2) {
                    return isAdRenderer(sectionSupportedRenderers.elementRenderer);
                }]];
            }
            if (isAdRenderer([contentsArray firstObject].elementRenderer)) return YES;
            return ymKeepSection(sectionRenderer);
        }

        return ymKeepSection(sectionRenderer);
    }];
    [newArray removeObjectsAtIndexes:removeIndexes];
    return newArray;
}

// Filter new ads
%hook YTIElementRenderer
- (NSData *)elementData {
    if (self.compatibilityOptions.hasAdLoggingData) return nil;
    return %orig;
}
%end

%hook YTPlayerResponse
%new(@@:)
- (NSMutableArray *)playerAdsArray { return [NSMutableArray array]; }
%new(@@:)
- (NSMutableArray *)adSlotsArray { return [NSMutableArray array]; }
%end

%hook YTIClientMdxGlobalConfig
%new(B@:)
- (BOOL)enableSkippableAd { return YES; }
%end

%hook YTAdShieldUtils
+ (id)spamSignalsDictionary { return @{}; }
+ (id)spamSignalsDictionaryWithoutIDFA { return @{}; }
%end

%hook YTDataUtils
+ (id)spamSignalsDictionary { return @{ @"ms": @"" }; }
+ (id)spamSignalsDictionaryWithoutIDFA { return @{}; }
%end

%hook YTAdsInnerTubeContextDecorator
- (void)decorateContext:(id)context { %orig(nil); }
%end

%hook YTAccountScopedAdsInnerTubeContextDecorator
- (void)decorateContext:(id)context { %orig(nil); }
%end

%hook YTLocalPlaybackController
- (id)createAdsPlaybackCoordinator { return nil; }
%end

%hook MDXSession
- (void)adPlaying:(id)ad {}
%end

%hook MDXSessionImpl
- (void)adPlaying:(id)ad {}
%end

static BOOL isAdsReelContentModel(YTReelContentModel *model) {
    if ([model isKindOfClass:%c(YTReelNonVideoContentModel)])
        return [[[(YTReelNonVideoContentModel *)model renderer].customData description] containsString:@"YTIReelNonVideoAdsCustomData_reelNonVideoAdsCustomData"];
    return ((YTReelModel *)model).isAdVideo || ((YTReelModel *)model).isStackedCardsPromoVideo;
}

// 9 is Playables ads, 10 posts
%hook YTReelDataSource
- (YTReelContentModel *)makeContentModelForEntry:(id)entry {
    YTReelContentModel *model = %orig;
    if (isAdsReelContentModel(model)) return nil;
    else if (((YTReelModel *)model).videoType == 10 && IS_ENABLED(RemoveShortsPosts)) return nil;
    else if ((((YTReelModel *)model).isLiveVideo || ((YTReelModel *)model).isLivePreviewVideo) && IS_ENABLED(RemoveShortsLive)) return nil;
    return model;
}
// Moved from YTReelInfinitePlaybackDataSource (19.x only).
- (void)setReels:(NSMutableOrderedSet <YTReelContentModel *> *)reels {
    [reels removeObjectsAtIndexes:[reels indexesOfObjectsPassingTest:^BOOL(YTReelContentModel *obj, NSUInteger idx, BOOL *stop) {
        if (isAdsReelContentModel(obj)) return YES;
        else if (((YTReelModel *)obj).videoType == 10 && IS_ENABLED(RemoveShortsPosts)) return YES;
        else if ((((YTReelModel *)obj).isLiveVideo || ((YTReelModel *)obj).isLivePreviewVideo) && IS_ENABLED(RemoveShortsLive)) return YES;
        return NO;
    }]];
    %orig;
}
%end

%hook YTReelContentModel
+ (YTReelContentModel *)makeContentModelForEntry:(id)entry {
    YTReelContentModel *model = %orig;
    if (isAdsReelContentModel(model)) return nil;
    else if (((YTReelModel *)model).videoType == 10 && IS_ENABLED(RemoveShortsPosts)) return nil;
    else if ((((YTReelModel *)model).isLiveVideo || ((YTReelModel *)model).isLivePreviewVideo) && IS_ENABLED(RemoveShortsLive)) return nil;
    return model;
}
%end

%hook YTReelInfinitePlaybackDataSource
- (YTReelContentModel *)makeContentModelForEntry:(id)entry {
    YTReelContentModel *model = %orig;
    if (isAdsReelContentModel(model)) return nil;
    else if (((YTReelModel *)model).videoType == 10 && IS_ENABLED(RemoveShortsPosts)) return nil;
    else if ((((YTReelModel *)model).isLiveVideo || ((YTReelModel *)model).isLivePreviewVideo) && IS_ENABLED(RemoveShortsLive)) return nil;
    return model;
}
- (void)setReels:(NSMutableOrderedSet <YTReelContentModel *> *)reels {
    [reels removeObjectsAtIndexes:[reels indexesOfObjectsPassingTest:^BOOL(YTReelContentModel *obj, NSUInteger idx, BOOL *stop) {
        if (isAdsReelContentModel(obj)) return YES;
        else if (((YTReelModel *)obj).videoType == 10 && IS_ENABLED(RemoveShortsPosts)) return YES;
        else if ((((YTReelModel *)obj).isLiveVideo || ((YTReelModel *)obj).isLivePreviewVideo) && IS_ENABLED(RemoveShortsLive)) return YES;
        return NO;
    }]];
    %orig;
}
%end

%hook YTWatchNextResponseViewController
- (void)loadWithModel:(YTIWatchNextResponse *)model {
    YTICommand *onUiReady = model.onUiReady;
    if ([onUiReady respondsToSelector:@selector(yt_commandExecutorCommand)]) {
        YTICommandExecutorCommand *commandExecutorCommand = [onUiReady yt_commandExecutorCommand];
        NSMutableArray <YTICommand *> *commandsArray = commandExecutorCommand.commandsArray;
        [commandsArray removeObjectsAtIndexes:[commandsArray indexesOfObjectsPassingTest:^BOOL(YTICommand *command, NSUInteger idx, BOOL *stop) {
            return isProductList(command);
        }]];
    }
    if (isProductList(onUiReady)) model.onUiReady = nil;
    %orig;
}
%end

%hook YTMainAppVideoPlayerOverlayViewController
- (void)playerOverlayProvider:(YTPlayerOverlayProvider *)provider didInsertPlayerOverlay:(YTPlayerOverlay *)overlay {
    NSString *iden = [overlay overlayIdentifier];
    if ([iden isEqualToString:@"player_overlay_product_in_video"] || [iden isEqualToString:@"player_overlay_timely_shelf"]) return;
    else if ([iden isEqualToString:@"player_overlay_paid_content"] && IS_ENABLED(HidePaidPromoOverlay)) return;
    %orig;
}
%end

%hook YTIPlayerCueRangeSet
- (NSMutableArray *)playerCueRangesArray {
    if (self.cueRangeSetIdentifier == 16) return [NSMutableArray array];
    return %orig;
}
%end

%hook YTWatchFloatingMiniplayerBadgeView
- (void)didMoveToWindow {
    %orig;
    if (IS_ENABLED(HidePaidPromoOverlay)) {
        UIView *badge = [self valueForKey:@"_overlayBadge"];
        if (badge) [badge removeFromSuperview];
    }
}
%end

void YouModFilterAdsDisplayView(_ASDisplayView *view, NSString *iden) {
    if ([iden isEqualToString:@"eml.expandable_metadata.vpp"]) {
        _ASDisplayView *spview = (_ASDisplayView *)view.superview;
        ASDisplayNode *node = spview.keepalive_node;
        [node removeYogaChild:node.yogaChildren.firstObject];
        [view removeFromSuperview];
    } else if (IS_ENABLED(HideCommentsPreview) && [iden isEqualToString:@"id.ui.comments_entry_point_teaser"]) {
        view.hidden = YES;
    } else if ([view.accessibilityLabel containsString:@"Premium"] && [view._viewControllerForAncestor isKindOfClass:%c(YTPageHeaderViewController)]) {
        _ASDisplayView *spview = (_ASDisplayView *)view.superview;
        ASDisplayNode *node = spview.keepalive_node;
        if (node.yogaChildren.count == 1) node = node.yogaChildren[0];
        [node removeYogaChild:node.yogaChildren.lastObject];
        [view removeFromSuperview];
    }
}

void YouModRemoveDrawerAds(YTELMViewController *self) {
    UIView *coll = nil;
    for (UIView *view in self.view.subviews) {
        if ([view isKindOfClass:%c(ASCollectionView)]) {
            coll = view;
            break;
        }
    }
    if (coll == nil) return;
    _ASCollectionViewCell *premiumCell = nil;
    for (_ASCollectionViewCell *vc in coll.subviews) {
        if ([vc isKindOfClass:%c(_ASCollectionViewCell)]) {
            UIView *svtemp = vc.subviews[0];
            while (svtemp != nil && svtemp.subviews.count == 1) {
                svtemp = svtemp.subviews[0];
            }
            if ([svtemp.accessibilityLabel containsString:@"Premium"]) {
                premiumCell = vc;
                break;
            }
        }
    }
    if (premiumCell == nil) return;
    ASDisplayNode *node = premiumCell.node;
    for (ASDisplayNode *child in node.yogaChildren) [node removeYogaChild:child];
    [premiumCell removeFromSuperview];
}

// NoYTPremium - @PoomSmart https://github.com/PoomSmart/NoYTPremium
// Alert
%hook YTCommerceEventGroupHandler
- (void)addEventHandlers {}
%end

// Full-screen
%hook YTInterstitialPromoEventGroupHandler
- (void)addEventHandlers {}
%end

%hook YTPromosheetEventGroupHandler
- (void)addEventHandlers {}
%end

%hook YTPromoThrottleController
- (BOOL)canShowThrottledPromo { return NO; }
- (BOOL)canShowThrottledPromoWithFrequencyCap:(id)arg1 { return NO; }
- (BOOL)canShowThrottledPromoWithFrequencyCaps:(id)arg1 { return NO; }
%end

%hook YTPromoThrottleControllerImpl
- (BOOL)canShowThrottledPromo { return NO; }
- (BOOL)canShowThrottledPromoWithFrequencyCap:(id)arg1 { return NO; }
- (BOOL)canShowThrottledPromoWithFrequencyCaps:(id)arg1 { return NO; }
%end

%hook YTIShowFullscreenInterstitialCommand
- (BOOL)shouldThrottleInterstitial {
    if (self.hasModalClientThrottlingRules) self.modalClientThrottlingRules.oncePerTimeWindow = YES;
    return %orig;
}
%end

// Settings
%hook YTSettingsSectionItemManager
- (void)updatePremiumEarlyAccessSectionWithEntry:(id)arg {}
- (void)updateUnlimitedSectionWithEntry:(id)arg {}
%end

%hook YTSettingsSectionController
- (NSArray <YTSettingsSectionItem *> *)items {
    NSArray <YTSettingsSectionItem *> *orig = %orig;
    if (orig && orig.count > 0) {
        for (YTSettingsSectionItem *item in orig) {
            if ([item.categoryId integerValue] == 31) {
                [orig removeObject:item];
                break;
            }
        }
    }
    return orig;
}
%end

// Survey
%hook YTSurveyController
- (void)showSurveyWithRenderer:(id)arg1 surveyParentResponder:(id)arg2 {}
%end

/*
%hook YTEngagementPanelViewControllerImpl
- (void)viewWillAppear:(BOOL)animated {
    NSString *desc = [[self valueForKey:@"_model"] description];
    if ([desc containsString:@"mealbar_promo.eml"]) {
        [self dismissViewControllerAnimated:NO completion:nil];
        return;
    }
    %orig;
    [[self.view valueForKey:@"_headerView"] performSelector:@selector(didTapCloseButton:) withObject:nil];
}
%end
*/

%ctor {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        RemoveAds: @YES
    }];
    if (!IS_ENABLED(RemoveAds)) return;
    %init;
}
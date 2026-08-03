#import "Headers.h"

// YouTube-X (https://github.com/PoomSmart/YouTube-X)
static BOOL isProductList(YTICommand *command) {
    if ([command respondsToSelector:@selector(yt_showEngagementPanelEndpoint)]) {
        YTIShowEngagementPanelEndpoint *endpoint = [command yt_showEngagementPanelEndpoint];
        return [endpoint.identifier.tag isEqualToString:@"PAproduct_list"];
    }
    return NO;
}

static NSString *getPostString(NSString *description) {
    static NSArray *postStrings = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        postStrings = @[
            @"poll_post_root.eml",
            @"options_post_root.eml",
            @"images_post_root_slim.eml",
            @"images_post_responsive_root.eml",
            @"options_post_responsive_root.eml",
            @"post_base_wrapper_slim.eml",
            @"text_post_root_slim.eml",
            @"text_post_responsive_root.eml",
            @"videos_post_root.eml"
        ];
    });
    for (NSString *str in postStrings) {
        if ([description containsString:str]) return str;
    }
    return nil;
}

static NSString *getAdString(NSString *description) {
    static NSArray *adStrings = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        adStrings = @[
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
        ];
    });
    for (NSString *str in adStrings) {
        if ([description containsString:str]) return str;
    }
    return nil;
}

static BOOL isAdRenderer(YTIElementRenderer *elementRenderer, int kind) {
    if ([elementRenderer respondsToSelector:@selector(hasCompatibilityOptions)] && elementRenderer.hasCompatibilityOptions && elementRenderer.compatibilityOptions.hasAdLoggingData) {
        return YES;
    }
    NSString *description = [elementRenderer description];
    NSString *adString = getAdString(description);
    if (adString) return YES;
    return NO;
}

static NSMutableArray <YTIItemSectionRenderer *> *filteredArray(NSArray <YTIItemSectionRenderer *> *array) {
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
        if ([sectionRenderer isKindOfClass:%c(YTIShelfRenderer)]) {
            NSString *description = [sectionRenderer description];
            if ([description containsString:@"community-tab-chip-posts-section"]) return NO;
            if (hideShorts) {
                if (keepShortsSub && [description containsString:@"subscriptions-shorts-shelf-item"]) return NO;
                else if ([description containsString:@"shorts_video_cell.eml"]) return YES;
                else if ([description containsString:@"shelf_header.eml"] && [description containsString:@"youtube_shorts_24_cairo"]) return YES;
            }
            if (hideFeedPost && getPostString(description) != nil) return YES;
            YTIShelfSupportedRenderers *content = ((YTIShelfRenderer *)sectionRenderer).content;
            YTIHorizontalListRenderer *horizontalListRenderer = content.horizontalListRenderer;
            NSMutableArray <YTIHorizontalListSupportedRenderers *> *itemsArray = horizontalListRenderer.itemsArray;
            NSIndexSet *removeItemsArrayIndexes = [itemsArray indexesOfObjectsPassingTest:^BOOL(YTIHorizontalListSupportedRenderers *horizontalListSupportedRenderers, NSUInteger idx2, BOOL *stop2) {
                YTIElementRenderer *elementRenderer = horizontalListSupportedRenderers.elementRenderer;
                return isAdRenderer(elementRenderer, 4);
            }];
            [itemsArray removeObjectsAtIndexes:removeItemsArrayIndexes];
        } else if ([sectionRenderer isKindOfClass:%c(YTIItemSectionRenderer)]) {
            NSString *description = [sectionRenderer description];
            if ([description containsString:@"community-tab-chip-posts-section"]) return NO;
            if ([description containsString:@"UNLIMITED"] && [description containsString:@"SPunlimited"]) {
                NSMutableArray <YTIItemSectionSupportedRenderers *> *contentsArray = sectionRenderer.contentsArray;
                NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];
                __block NSUInteger lastCellDividerIndex = NSNotFound;
                
                [contentsArray enumerateObjectsUsingBlock:^(YTIItemSectionSupportedRenderers *item, NSUInteger idx, BOOL *stop) {
                    NSString *desc = [item description];
                    if ([desc containsString:@"cell_divider.eml"]) lastCellDividerIndex = idx;
                    else if ([desc containsString:@"UNLIMITED"] && [desc containsString:@"SPunlimited"]) {
                        [indexesToRemove addIndex:idx];
                        if (lastCellDividerIndex != NSNotFound) {
                            [indexesToRemove addIndex:lastCellDividerIndex];
                            lastCellDividerIndex = NSNotFound;
                        }
                    }
                }];
                [contentsArray removeObjectsAtIndexes:indexesToRemove];
                return NO;
            }
            
            const BOOL isShortsShelf = [description containsString:@"shorts_shelf.eml"];
            const BOOL isHistory = [description containsString:@"history-shorts-shelf-item"];
            const BOOL isShortsOverlay = [description containsString:@"video_lockup_overlay"];
            if (hideShorts && keepShortsSub) {
                if (isShortsShelf && ![description containsString:@"subscriptions-shorts-shelf-item"] && !isHistory) return YES;
                else if (isShortsOverlay) return YES;
            } else if (hideShorts) {
                if (isShortsShelf && !isHistory) return YES;
                else if (isShortsOverlay) return YES;
            }
            
            if ([description containsString:@"horizontal_shelf.eml"]) {
                if (hidePlayables && [description containsString:@"FEmini_app_destination"]) return YES;
                if (hideHoriShelf && ![description containsString:@"UCYfdidRxbB8Qhf0Nx7ioOYw"] && ![description containsString:@"FElibrary"] && ![description containsString:@"mini_game_card.eml"] && ![description containsString:@"FEplaylist_aggregation"]) {
                    return YES;
                }
            }

            if (hideCommuGuide && ([description containsString:@"community_guidelines.eml"] || [description containsString:@"channel_guidelines_entry_banner.eml"])) {
                return YES;
            }
            
            if (hideFeedPost && getPostString(description) != nil) return YES;
            if (hideGenMusic && [description containsString:@"feed_nudge.eml"]) return YES;
            if (hideSurveys && [description containsString:@"in_feed_survey.eml"]) return YES;
            if (hideComments && [description containsString:@"comment-item-section"] && [description containsString:@"comments-entry-point"]) {
                return YES;
            }
            
            NSMutableArray <YTIItemSectionSupportedRenderers *> *contentsArray = sectionRenderer.contentsArray;
            if (contentsArray.count > 1) {
                NSIndexSet *removeContentsArrayIndexes = [contentsArray indexesOfObjectsPassingTest:^BOOL(YTIItemSectionSupportedRenderers *sectionSupportedRenderers, NSUInteger idx2, BOOL *stop2) {
                    YTIElementRenderer *elementRenderer = sectionSupportedRenderers.elementRenderer;
                    return isAdRenderer(elementRenderer, 3);
                }];
                [contentsArray removeObjectsAtIndexes:removeContentsArrayIndexes];
            }
            YTIItemSectionSupportedRenderers *firstObject = [contentsArray firstObject];
            YTIElementRenderer *elementRenderer = firstObject.elementRenderer;
            if (isAdRenderer(elementRenderer, 2)) return YES;
        }
        return NO;
    }];
    [newArray removeObjectsAtIndexes:removeIndexes];
    return newArray;
}

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
- (void)decorateContext:(id)context { 
    id temp = nil;
    %orig(temp);
}
%end

%hook YTAccountScopedAdsInnerTubeContextDecorator
- (void)decorateContext:(id)context { 
    id temp = nil;
    %orig(temp);
}
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

// Live video type = 4 and Live preview = 7, 9 is Playables ads, 10 posts
%hook YTReelDataSource
- (YTReelModel *)makeContentModelForEntry:(id)entry {
    YTReelModel *model = %orig;
    if ([model respondsToSelector:@selector(videoType)] && model.videoType == 3)
        return nil;
    if ([model isKindOfClass:%c(YTReelNonVideoContentModel)])
        return nil;
    if ([model respondsToSelector:@selector(videoType)] && model.videoType == 10 && IS_ENABLED(RemoveShortsPosts))
        return nil;
    if ([model respondsToSelector:@selector(videoType)] && (model.videoType == 4 || model.videoType == 7) && IS_ENABLED(RemoveShortsLive))
        return nil;
    return model;
}
%end

%hook YTReelContentModel
+ (YTReelModel *)makeContentModelForEntry:(id)entry {
    YTReelModel *model = %orig;
    if ([model respondsToSelector:@selector(videoType)] && model.videoType == 3)
        return nil;
    if ([model isKindOfClass:%c(YTReelNonVideoContentModel)])
        return nil;
    if ([model respondsToSelector:@selector(videoType)] && model.videoType == 10 && IS_ENABLED(RemoveShortsPosts))
        return nil;
    if ([model respondsToSelector:@selector(videoType)] && (model.videoType == 4 || model.videoType == 7) && IS_ENABLED(RemoveShortsLive))
        return nil;
    return model;
}
%end

%hook YTReelInfinitePlaybackDataSource
- (YTReelModel *)makeContentModelForEntry:(id)entry {
    YTReelModel *model = %orig;
    if ([model respondsToSelector:@selector(videoType)] && model.videoType == 3)
        return nil;
    if ([model isKindOfClass:%c(YTReelNonVideoContentModel)])
        return nil;
    if ([model respondsToSelector:@selector(videoType)] && model.videoType == 10 && IS_ENABLED(RemoveShortsPosts))
        return nil;
    if ([model respondsToSelector:@selector(videoType)] && (model.videoType == 4 || model.videoType == 7) && IS_ENABLED(RemoveShortsLive))
        return nil;
    return model;
}
- (void)setReels:(NSMutableOrderedSet <YTReelModel *> *)reels {
    [reels removeObjectsAtIndexes:[reels indexesOfObjectsPassingTest:^BOOL(YTReelModel *obj, NSUInteger idx, BOOL *stop) {
        if ([obj respondsToSelector:@selector(videoType)] && obj.videoType == 3) return YES;
        if ([obj isKindOfClass:%c(YTReelNonVideoContentModel)]) return YES;
        if ([obj respondsToSelector:@selector(videoType)] && obj.videoType == 10 && IS_ENABLED(RemoveShortsPosts)) return YES;
        if ([obj respondsToSelector:@selector(videoType)] && (obj.videoType == 4 || obj.videoType == 7) && IS_ENABLED(RemoveShortsLive)) return YES;
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
    if (isProductList(onUiReady))
        model.onUiReady = nil;
    %orig;
}
%end

%hook YTMainAppVideoPlayerOverlayViewController
- (void)playerOverlayProvider:(YTPlayerOverlayProvider *)provider didInsertPlayerOverlay:(YTPlayerOverlay *)overlay {
    if ([[overlay overlayIdentifier] isEqualToString:@"player_overlay_product_in_video"]) return;
    if ([[overlay overlayIdentifier] isEqualToString:@"player_overlay_paid_content"] && IS_ENABLED(HidePaidPromoOverlay)) return;
    %orig;
}
%end

%hook YTWatchFloatingMiniplayerBadgeView
- (void)layoutSubviews {
    %orig;
    if (IS_ENABLED(HidePaidPromoOverlay)) {
        UIView *badge = [self valueForKey:@"_overlayBadge"];
        if (badge && badge.superview) {
            [badge removeFromSuperview];
        }
    }
}
%end

%hook YTInnerTubeCollectionViewController
- (void)displaySectionsWithReloadingSectionControllerByRenderer:(id)renderer {
    NSMutableArray *sectionRenderers = [self valueForKey:@"_sectionRenderers"];
    [self setValue:filteredArray(sectionRenderers) forKey:@"_sectionRenderers"];
    %orig;
}
- (void)addSectionsFromArray:(NSArray <YTIItemSectionRenderer *> *)array {
    %orig(filteredArray(array));
}
%end

%hook _ASDisplayView
- (void)didMoveToWindow {
    %orig;
    if ([self.accessibilityIdentifier isEqualToString:@"eml.expandable_metadata.vpp"]) [self removeFromSuperview];
    if (IS_ENABLED(HideCommentsPreview) && [self.accessibilityIdentifier isEqualToString:@"id.ui.comments_entry_point_teaser"]) [self removeFromSuperview];
    if ([self.accessibilityLabel containsString:@"Premium"]) {
        UIResponder *responder = self.nextResponder;
        while (responder != nil) {
            if ([responder isKindOfClass:%c(YTPageHeaderViewController)]) {
                YTPageHeaderViewController *pageh = (YTPageHeaderViewController *)responder;
                YTIPageHeaderRenderer *pagerender = [pageh valueForKey:@"_renderer"];
                NSString *desc = [pagerender description];
                if ([desc containsString:@"Premium"] && [desc containsString:@"SPunlimited"]) {
                    [self removeFromSuperview];
                }
                break;
            }
            responder = responder.nextResponder;
        }
    }
}
%end

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
    if (self.hasModalClientThrottlingRules)
        self.modalClientThrottlingRules.oncePerTimeWindow = YES;
    return %orig;
}
%end

// "Try new features" in settings
%hook YTSettingsSectionItemManager
// - (void)updatePremiumEarlyAccessSectionWithEntry:(id)arg1 {} Will think about this again
- (void)updateUnlimitedSectionWithEntry:(id)arg {}
%end

// Survey
%hook YTSurveyController
- (void)showSurveyWithRenderer:(id)arg1 surveyParentResponder:(id)arg2 {}
%end

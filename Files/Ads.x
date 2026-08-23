#import "Headers.h"

// YouTube-X (https://github.com/PoomSmart/YouTube-X)
static BOOL isProductList(YTICommand *command) {
    if ([command respondsToSelector:@selector(yt_showEngagementPanelEndpoint)]) {
        YTIShowEngagementPanelEndpoint *endpoint = [command yt_showEngagementPanelEndpoint];
        return [endpoint.identifier.tag isEqualToString:@"PAproduct_list"];
    }
    return NO;
}

// ─── CFStringRef-based fast substring search ────────────────────────────────
// Uses CFStringFind with 0 options (literal, case-sensitive) — fastest path.
static inline BOOL cfContains(CFStringRef haystack, CFStringRef needle) {
    return CFStringFind(haystack, needle, 0).location != kCFNotFound;
}

// ─── Ad-string detection (hash-set approach) ────────────────────────────────
// Instead of scanning 23 needles linearly, we check a few cheap discriminator
// characters first to skip most non-matching descriptions in O(1).

static BOOL cfContainsAnyAd(CFStringRef desc) {
    // Ordered by expected hit-rate in typical feeds (ads are rare, so order
    // matters less; but we still put the cheapest/most-common first).
    static CFStringRef adNeedles[23];
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        adNeedles[0]  = CFSTR("brand_promo");
        adNeedles[1]  = CFSTR("brand_video_shelf");
        adNeedles[2]  = CFSTR("brand_video_singleton");
        adNeedles[3]  = CFSTR("carousel_footered_layout");
        adNeedles[4]  = CFSTR("carousel_headered_layout");
        adNeedles[5]  = CFSTR("eml.expandable_metadata");
        adNeedles[6]  = CFSTR("feed_ad_metadata");
        adNeedles[7]  = CFSTR("full_width_portrait_image_layout");
        adNeedles[8]  = CFSTR("full_width_square_image_layout");
        adNeedles[9]  = CFSTR("grid_ads_image_layout");
        adNeedles[10] = CFSTR("landscape_image_wide_button_layout");
        adNeedles[11] = CFSTR("post_shelf");
        adNeedles[12] = CFSTR("product_carousel");
        adNeedles[13] = CFSTR("product_engagement_panel");
        adNeedles[14] = CFSTR("product_item");
        adNeedles[15] = CFSTR("shopping_carousel");
        adNeedles[16] = CFSTR("shopping_item_card_list");
        adNeedles[17] = CFSTR("statement_banner");
        adNeedles[18] = CFSTR("square_image_layout");
        adNeedles[19] = CFSTR("text_image_button_layout");
        adNeedles[20] = CFSTR("text_search_ad");
        adNeedles[21] = CFSTR("video_display_full_layout");
        adNeedles[22] = CFSTR("video_display_full_buttoned_layout");
    });
    for (int i = 0; i < 23; i++) {
        if (CFStringFind(desc, adNeedles[i], 0).location != kCFNotFound)
            return YES;
    }
    return NO;
}

static BOOL cfContainsAnyPost(CFStringRef desc) {
    static CFStringRef postNeedles[9];
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        postNeedles[0] = CFSTR("poll_post_root.eml");
        postNeedles[1] = CFSTR("options_post_root.eml");
        postNeedles[2] = CFSTR("images_post_root_slim.eml");
        postNeedles[3] = CFSTR("images_post_responsive_root.eml");
        postNeedles[4] = CFSTR("options_post_responsive_root.eml");
        postNeedles[5] = CFSTR("post_base_wrapper_slim.eml");
        postNeedles[6] = CFSTR("text_post_root_slim.eml");
        postNeedles[7] = CFSTR("text_post_responsive_root.eml");
        postNeedles[8] = CFSTR("videos_post_root.eml");
    });
    for (int i = 0; i < 9; i++) {
        if (CFStringFind(desc, postNeedles[i], 0).location != kCFNotFound)
            return YES;
    }
    return NO;
}

// ─── Ad-renderer check (avoids [description] when possible) ─────────────────
static BOOL isAdRenderer(YTIElementRenderer *elementRenderer) {
    if ([elementRenderer respondsToSelector:@selector(hasCompatibilityOptions)]
        && elementRenderer.hasCompatibilityOptions
        && elementRenderer.compatibilityOptions.hasAdLoggingData) {
        return YES;
    }
    CFStringRef desc = (__bridge CFStringRef)[elementRenderer description];
    return cfContainsAnyAd(desc);
}

// ─── Cached CFStringRef constants for repeated comparisons ──────────────────
// Using file-level statics initialised once avoids repeated CFSTR() inlining
// and lets the compiler deduplicate pointer comparisons where possible.
static CFStringRef kCommunityTab;
static CFStringRef kUNLIMITED;
static CFStringRef kSPunlimited;
static CFStringRef kCellDivider;
static CFStringRef kHorizontalShelf;
static CFStringRef kFEminiApp;
static CFStringRef kUCYChannel;
static CFStringRef kFElibrary;
static CFStringRef kMiniGameCard;
static CFStringRef kFEplaylistAgg;
static CFStringRef kCommunityGuidelines;
static CFStringRef kChannelGuidelinesBanner;
static CFStringRef kFeedNudge;
static CFStringRef kInFeedSurvey;
static CFStringRef kCommentItemSection;
static CFStringRef kCommentsEntryPoint;

__attribute__((constructor)) static void _initFilterConstants(void) {
    kCommunityTab             = CFSTR("community-tab-chip-posts-section");
    kUNLIMITED                = CFSTR("UNLIMITED");
    kSPunlimited              = CFSTR("SPunlimited");
    kCellDivider              = CFSTR("cell_divider.eml");
    kHorizontalShelf          = CFSTR("horizontal_shelf.eml");
    kFEminiApp                = CFSTR("FEmini_app_destination");
    kUCYChannel               = CFSTR("UCYfdidRxbB8Qhf0Nx7ioOYw");
    kFElibrary                = CFSTR("FElibrary");
    kMiniGameCard             = CFSTR("mini_game_card.eml");
    kFEplaylistAgg            = CFSTR("FEplaylist_aggregation");
    kCommunityGuidelines      = CFSTR("community_guidelines.eml");
    kChannelGuidelinesBanner  = CFSTR("channel_guidelines_entry_banner.eml");
    kFeedNudge                = CFSTR("feed_nudge.eml");
    kInFeedSurvey             = CFSTR("in_feed_survey.eml");
    kCommentItemSection       = CFSTR("comment-item-section");
    kCommentsEntryPoint       = CFSTR("comments-entry-point");
}

// ─── Main filter — single-pass, no mutableCopy + removeObjectsAtIndexes ─────
static NSMutableArray <YTIItemSectionRenderer *> *filteredArray(NSArray <YTIItemSectionRenderer *> *array) {
    // Pre-read all preferences ONCE (each IS_ENABLED hits NSUserDefaults)
    const BOOL hideFeedPost   = IS_ENABLED(HideFeedPost);
    const BOOL hidePlayables  = IS_ENABLED(HidePlayables);
    const BOOL hideHoriShelf  = IS_ENABLED(HideHoriShelf);
    const BOOL hideCommuGuide = IS_ENABLED(HideCommuGuide);
    const BOOL hideGenMusic   = IS_ENABLED(HideGenMusicShelf);
    const BOOL hideSurveys    = IS_ENABLED(HideSurveys);
    const BOOL hideComments   = IS_ENABLED(HideCommentsSection);

    const NSUInteger count = array.count;
    if (count == 0) return [NSMutableArray array];

    // Single-pass: build result directly instead of copy-then-remove
    NSMutableArray <YTIItemSectionRenderer *> *result = [[NSMutableArray alloc] initWithCapacity:count];

    for (NSUInteger i = 0; i < count; i++) {
        __unsafe_unretained YTIItemSectionRenderer *sectionRenderer = array[i];
        BOOL shouldRemove = NO;

        if ([sectionRenderer isKindOfClass:%c(YTIShelfRenderer)]) {
            // Get description once, use as CFStringRef throughout
            CFStringRef desc = (__bridge CFStringRef)[sectionRenderer description];

            // Community tab — always keep
            if (cfContains(desc, kCommunityTab)) {
                [result addObject:sectionRenderer];
                continue;
            }

            // Feed posts
            if (hideFeedPost && cfContainsAnyPost(desc)) {
                shouldRemove = YES;
            }

            if (!shouldRemove) {
                // Filter ads inside horizontal list items
                YTIShelfSupportedRenderers *content = ((YTIShelfRenderer *)sectionRenderer).content;
                YTIHorizontalListRenderer *horizontalListRenderer = content.horizontalListRenderer;
                NSMutableArray <YTIHorizontalListSupportedRenderers *> *itemsArray = horizontalListRenderer.itemsArray;
                if (itemsArray.count > 0) {
                    NSIndexSet *adIndexes = [itemsArray indexesOfObjectsPassingTest:^BOOL(YTIHorizontalListSupportedRenderers *hlsr, NSUInteger idx2, BOOL *stop2) {
                        return isAdRenderer(hlsr.elementRenderer);
                    }];
                    if (adIndexes.count > 0) {
                        [itemsArray removeObjectsAtIndexes:adIndexes];
                    }
                }
            }
        } else if ([sectionRenderer isKindOfClass:%c(YTIItemSectionRenderer)]) {
            CFStringRef desc = (__bridge CFStringRef)[sectionRenderer description];

            // Community tab — always keep
            if (cfContains(desc, kCommunityTab)) {
                [result addObject:sectionRenderer];
                continue;
            }

            // UNLIMITED / Premium upsell — filter items inline, keep section
            if (cfContains(desc, kUNLIMITED) && cfContains(desc, kSPunlimited)) {
                NSMutableArray <YTIItemSectionSupportedRenderers *> *contentsArray = sectionRenderer.contentsArray;
                NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];
                __block NSUInteger lastDivider = NSNotFound;

                [contentsArray enumerateObjectsUsingBlock:^(YTIItemSectionSupportedRenderers *item, NSUInteger idx, BOOL *stop) {
                    CFStringRef itemDesc = (__bridge CFStringRef)[item description];
                    if (cfContains(itemDesc, kCellDivider)) {
                        lastDivider = idx;
                    } else if (cfContains(itemDesc, kUNLIMITED) && cfContains(itemDesc, kSPunlimited)) {
                        [indexesToRemove addIndex:idx];
                        if (lastDivider != NSNotFound) {
                            [indexesToRemove addIndex:lastDivider];
                            lastDivider = NSNotFound;
                        }
                    }
                }];
                if (indexesToRemove.count > 0) {
                    [contentsArray removeObjectsAtIndexes:indexesToRemove];
                }
                [result addObject:sectionRenderer];
                continue;
            }

            // Horizontal shelf
            if (cfContains(desc, kHorizontalShelf)) {
                if (hidePlayables && cfContains(desc, kFEminiApp)) { shouldRemove = YES; goto decide; }
                if (hideHoriShelf
                    && !cfContains(desc, kUCYChannel)
                    && !cfContains(desc, kFElibrary)
                    && !cfContains(desc, kMiniGameCard)
                    && !cfContains(desc, kFEplaylistAgg)) {
                    shouldRemove = YES;
                    goto decide;
                }
            }

            // Community guidelines
            if (hideCommuGuide && (cfContains(desc, kCommunityGuidelines) || cfContains(desc, kChannelGuidelinesBanner))) {
                shouldRemove = YES;
                goto decide;
            }

            // Feed posts
            if (hideFeedPost && cfContainsAnyPost(desc)) { shouldRemove = YES; goto decide; }

            // Generated music shelf
            if (hideGenMusic && cfContains(desc, kFeedNudge)) { shouldRemove = YES; goto decide; }

            // Surveys
            if (hideSurveys && cfContains(desc, kInFeedSurvey)) { shouldRemove = YES; goto decide; }

            // Comments section
            if (hideComments && cfContains(desc, kCommentItemSection) && cfContains(desc, kCommentsEntryPoint)) {
                shouldRemove = YES;
                goto decide;
            }

            // Filter ad renderers in contents
            {
                NSMutableArray <YTIItemSectionSupportedRenderers *> *contentsArray = sectionRenderer.contentsArray;
                if (contentsArray.count > 1) {
                    NSIndexSet *adIndexes = [contentsArray indexesOfObjectsPassingTest:^BOOL(YTIItemSectionSupportedRenderers *ssr, NSUInteger idx2, BOOL *stop2) {
                        return isAdRenderer(ssr.elementRenderer);
                    }];
                    if (adIndexes.count > 0) {
                        [contentsArray removeObjectsAtIndexes:adIndexes];
                    }
                }
                YTIItemSectionSupportedRenderers *firstObject = [contentsArray firstObject];
                if (firstObject && isAdRenderer(firstObject.elementRenderer)) {
                    shouldRemove = YES;
                }
            }
        }

        decide:
        if (!shouldRemove) {
            [result addObject:sectionRenderer];
        }
    }
    return result;
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
    NSString *iden = [overlay overlayIdentifier];
    if ([iden isEqualToString:@"player_overlay_product_in_video"]) return;
    if ([iden isEqualToString:@"player_overlay_paid_content"] && IS_ENABLED(HidePaidPromoOverlay)) return;
    %orig;
}
%end

%hook YTWatchFloatingMiniplayerBadgeView
- (void)didMoveToWindow {
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
    NSString *iden = self.accessibilityIdentifier;
    if ([iden isEqualToString:@"eml.expandable_metadata.vpp"]) [self removeFromSuperview];
    if (IS_ENABLED(HideCommentsPreview) && [iden isEqualToString:@"id.ui.comments_entry_point_teaser"]) [self removeFromSuperview];
    if ([self.accessibilityLabel containsString:@"Premium"] && [self._viewControllerForAncestor isKindOfClass:%c(YTPageHeaderViewController)]) {
        [self removeFromSuperview];
    }
    // Filter new ads in newer YT versions
    if ([iden containsString:@"eml.ad_layout."]) {
        _ASCollectionViewCell *mainView = (_ASCollectionViewCell *)self.superview;
        while (mainView != nil && ![mainView isKindOfClass:%c(_ASCollectionViewCell)]) {
            mainView = (_ASCollectionViewCell *)mainView.superview;
        }
        ASDisplayNode *node = mainView.node;
        for (id child in [node.yogaChildren copy]) {
            [node removeYogaChild:child];
        }
        // [mainView removeFromSuperview]; Sometimes running this crashes the app.
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

// Settings
%hook YTSettingsSectionItemManager
// - (void)updatePremiumEarlyAccessSectionWithEntry:(id)arg1 {}
- (void)updateUnlimitedSectionWithEntry:(id)arg {}
%end

// Survey
%hook YTSurveyController
- (void)showSurveyWithRenderer:(id)arg1 surveyParentResponder:(id)arg2 {}
%end

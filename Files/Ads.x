#import "Headers.h"

// YouTube-X (https://github.com/PoomSmart/YouTube-X)
static BOOL isProductList(YTICommand *command) {
    if ([command respondsToSelector:@selector(yt_showEngagementPanelEndpoint)]) {
        YTIShowEngagementPanelEndpoint *endpoint = [command yt_showEngagementPanelEndpoint];
        return [endpoint.identifier.tag isEqualToString:@"PAproduct_list"];
    }
    return NO;
}

NSString *getAdString(NSString *description) {
    for (NSString *str in @[
        @"brand_promo",
        @"brand_video_shelf",
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
    ])
        if ([description containsString:str]) return str;
    return nil;
}

static BOOL isAdRenderer(YTIElementRenderer *elementRenderer, int kind) {
    if ([elementRenderer respondsToSelector:@selector(hasCompatibilityOptions)] && elementRenderer.hasCompatibilityOptions && elementRenderer.compatibilityOptions.hasAdLoggingData) {
        return YES;
    }
    NSString *description = [elementRenderer description];
    NSString *adString = getAdString(description);
    if (adString) {
        return YES;
    }
    return NO;
}

static NSMutableArray <YTIItemSectionRenderer *> *filteredArray(NSArray <YTIItemSectionRenderer *> *array) {
    NSMutableArray <YTIItemSectionRenderer *> *newArray = [array mutableCopy];
    NSIndexSet *removeIndexes = [newArray indexesOfObjectsPassingTest:^BOOL(YTIItemSectionRenderer *sectionRenderer, NSUInteger idx, BOOL *stop) {
        // Filter shelf renderer items (ads and shorts)
        if ([sectionRenderer isKindOfClass:%c(YTIShelfRenderer)]) {
            NSString *description = [sectionRenderer description];
            // Filter shorts
            if (IS_ENABLED(HideShortsShelf)) {
                if (IS_ENABLED(KeepShortsSubscript)) {
                    if ([description containsString:@"shorts_video_cell.eml"] && ![description containsString:@"subscriptions-shorts-shelf-item"]) return YES;
                } else {
                    if ([description containsString:@"shorts_video_cell.eml"]) return YES;
                }
                if ([description containsString:@"shelf_header.eml"] && [description containsString:@"youtube_shorts_24_cairo"]) return YES;
            }
            // Filter feed posts
            if (IS_ENABLED(HideFeedPost) && ([description containsString:@"poll_post_root.eml"] || [description containsString:@"options_post_root.eml"] || [description containsString:@"images_post_root_slim.eml"] || [description containsString:@"options_post_responsive_root.eml"] || [description containsString:@"text_post_root_slim.eml"])) {
                return YES;
            }
            YTIShelfSupportedRenderers *content = ((YTIShelfRenderer *)sectionRenderer).content;
            YTIHorizontalListRenderer *horizontalListRenderer = content.horizontalListRenderer;
            NSMutableArray <YTIHorizontalListSupportedRenderers *> *itemsArray = horizontalListRenderer.itemsArray;
            NSIndexSet *removeItemsArrayIndexes = [itemsArray indexesOfObjectsPassingTest:^BOOL(YTIHorizontalListSupportedRenderers *horizontalListSupportedRenderers, NSUInteger idx2, BOOL *stop2) {
                YTIElementRenderer *elementRenderer = horizontalListSupportedRenderers.elementRenderer;
                return isAdRenderer(elementRenderer, 4);
            }];
            [itemsArray removeObjectsAtIndexes:removeItemsArrayIndexes];
        }
        
        // Filter item section renderers
        if (![sectionRenderer isKindOfClass:%c(YTIItemSectionRenderer)]) return NO;
            
        NSString *description = [sectionRenderer description];
        
        // Filter shorts shelf
        BOOL isShortsShelf = [description containsString:@"shorts_shelf.eml"];
        BOOL isHistory = [description containsString:@"history-shorts-shelf-item"];
        if (IS_ENABLED(HideShortsShelf) && IS_ENABLED(KeepShortsSubscript)) {
            if (isShortsShelf && ![description containsString:@"subscriptions-shorts-shelf-item"] && !isHistory) {
                return YES;
            }
        } else if (IS_ENABLED(HideShortsShelf)) {
            if (isShortsShelf && !isHistory) {
                return YES;
            }
        }
        
        // Filter horizontal shelf
        if (IS_ENABLED(HideHoriShelf) && [description containsString:@"horizontal_shelf.eml"] && 
            ![description containsString:@"UCYfdidRxbB8Qhf0Nx7ioOYw"] && 
            ![description containsString:@"FElibrary"] && 
            ![description containsString:@"mini_game_card.eml"] &&
            ![description containsString:@"FEplaylist_aggregation"]) {
            return YES;
        }
        
        // Filter feed posts
        if (IS_ENABLED(HideFeedPost) && ([description containsString:@"poll_post_root.eml"] || [description containsString:@"options_post_root.eml"] || [description containsString:@"images_post_root_slim.eml"] || [description containsString:@"options_post_responsive_root.eml"] || [description containsString:@"text_post_root_slim.eml"])) {
            return YES;
        }

        if (IS_ENABLED(HideGenMusicShelf) && [description containsString:@"feed_nudge.eml"]) {
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
        if (isAdRenderer(elementRenderer, 2)) {
            return YES;
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

%hook YTSectionListViewController
- (void)loadWithModel:(YTISectionListRenderer *)model {
    YTISectionListRenderer *renderer = model;
    NSString *description = [model description];
    // pcs is mostly ads path
    if ([description containsString:@"https://www.youtube.com/pcs/"]) renderer = nil;
    %orig(renderer);
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

// Live video type = 4 and Live preview = 7
%hook YTReelDataSource
- (YTReelModel *)makeContentModelForEntry:(id)entry {
    YTReelModel *model = %orig;
    YTReelPlayerResponder *responder = [model valueForKey:@"_reelPlayerResponder"];
    if ([model respondsToSelector:@selector(videoType)] && model.videoType == 3)
        return nil;
    if ([responder.parentResponder isKindOfClass:%c(YTShortsAdsPlayerViewController)])
        return nil;
    if ([model respondsToSelector:@selector(videoType)] && (model.videoType == 4 || model.videoType == 7) && IS_ENABLED(RemoveShortsLive))
        return nil;
    return model;
}
%end

%hook YTReelInfinitePlaybackDataSource
- (YTReelModel *)makeContentModelForEntry:(id)entry {
    YTReelModel *model = %orig;
    YTReelPlayerResponder *responder = [model valueForKey:@"_reelPlayerResponder"];
    if ([model respondsToSelector:@selector(videoType)] && model.videoType == 3)
        return nil;
    if ([responder.parentResponder isKindOfClass:%c(YTShortsAdsPlayerViewController)])
        return nil;
    if ([model respondsToSelector:@selector(videoType)] && (model.videoType == 4 || model.videoType == 7) && IS_ENABLED(RemoveShortsLive))
        return nil;
    return model;
}
- (void)setReels:(NSMutableOrderedSet <YTReelModel *> *)reels {
    [reels removeObjectsAtIndexes:[reels indexesOfObjectsPassingTest:^BOOL(YTReelModel *obj, NSUInteger idx, BOOL *stop) {
        YTReelPlayerResponder *responder = [obj valueForKey:@"_reelPlayerResponder"];
        if ([obj respondsToSelector:@selector(videoType)] && obj.videoType == 3) return YES;
        if ([responder.parentResponder isKindOfClass:%c(YTShortsAdsPlayerViewController)]) return YES;
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
- (void)updatePremiumEarlyAccessSectionWithEntry:(id)arg1 {}
%end

// Survey
%hook YTSurveyController
- (void)showSurveyWithRenderer:(id)arg1 surveyParentResponder:(id)arg2 {}
%end

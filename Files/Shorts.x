#import "Headers.h"
#import <objc/message.h>

UIViewController *YouModAppViewController() {
    return UIApplication.sharedApplication.delegate.window.rootViewController;
}

// Enables shorts quality - works best with YTClassicVideoQuality
%hook YTHotConfig
- (BOOL)enableOmitAdvancedMenuInShortsVideoQualityPicker { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
- (BOOL)enableShortsVideoQualityPicker { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
- (BOOL)iosEnableImmersiveLivePlayerVideoQuality { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
- (BOOL)iosEnableShortsPlayerVideoQuality { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
- (BOOL)iosEnableShortsPlayerVideoQualityRestartVideo { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
- (BOOL)iosEnableSimplerTitleInShortsVideoQualityPicker { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
- (BOOL)enablePlayerBarForVerticalVideoWhenControlsHiddenInFullscreen { return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; }
%end

// Always show Shorts seekbar
%hook YTShortsPlayerViewController
- (BOOL)shouldAlwaysEnablePlayerBar { return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; }
- (BOOL)shouldEnablePlayerBarOnlyOnPause { return IS_ENABLED(ShowShortsSeekbar) ? NO : %orig; }
%end

%hook YTReelPlayerViewControllerSub
- (BOOL)shouldAlwaysEnablePlayerBar { return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; }
- (BOOL)shouldEnablePlayerBarOnlyOnPause { return IS_ENABLED(ShowShortsSeekbar) ? NO : %orig; }
%end

%hook YTColdConfig
- (BOOL)iosEnableVideoPlayerScrubber { return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; }
- (BOOL)mobileShortsTabInlinedExpandWatchOnDismiss { return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; }
%end

static BOOL isShortsOnlyOn = YES;
static BOOL isFullscreenEnabled = NO;

static void YouModRemoveShortsOverlayButton(_ASDisplayView *dpView) {
    NSDictionary *buttonsList = @{
        @"id.reel_like_button": @(IS_ENABLED(RemoveShortsLikeButton)),
        @"id.reel_like_toggled_button": @(IS_ENABLED(RemoveShortsLikeButton)),
        @"id.reel_comment_button": @(IS_ENABLED(RemoveShortsCommentButton)),
        @"id.reel_share_button": @(IS_ENABLED(RemoveShortsShareButton)),
        @"id.reel_remix_button" : @(IS_ENABLED(RemoveShortsRemixButton)),
        @"id.reel_pivot_button": @(IS_ENABLED(RemoveShortsSoundMetadataButton)),
        @"reel_save_button.eml" : @(IS_ENABLED(RemoveShortsSaveButton)),
        @"id.reel_ask_button" : @(IS_ENABLED(RemoveShortsAskButton))
    };
    ASDisplayNode *node = dpView.keepalive_node;
    for (NSString *button in buttonsList) {
        if ([buttonsList[button] boolValue]) {
            for (ASDisplayNode *child in node.yogaChildren.copy) {
                if ([child.description containsString:button]) [node removeYogaChild:child];
                else if (IS_ENABLED(RemoveShortsSaveButton)) {
                    NSString *desc = nil;
                    @try {
                        desc = [[[[child nodeController] performSelector:@selector(owningComponent)] performSelector:@selector(owningComponent)] description];
                    } @catch (id ex) {
                        continue;
                    }
                    if (desc != nil && [desc containsString:button]) [node removeYogaChild:child];
                }
            }
        }
    }   
}

// Block Shorts player: close any Short as soon as it opens (from links, history, notifications, search).
static void YouModCloseShortsController(UIViewController *controller) {
    if (!IS_ENABLED(BlockShortsPlayer) || !controller) return;
    YTPlayerViewController *player = [controller respondsToSelector:@selector(player)] ? [controller performSelector:@selector(player)] : nil;
    if ([player respondsToSelector:@selector(pause)]) [player performSelector:@selector(pause)];
    dispatch_async(dispatch_get_main_queue(), ^{
        UINavigationController *nav = controller.navigationController;
        if (nav && nav.viewControllers.count > 1) [nav popViewControllerAnimated:YES];
        else if (controller.presentingViewController) [controller dismissViewControllerAnimated:YES completion:nil];
        else {
            UIViewController *root = YouModAppViewController();
            if ([root respondsToSelector:@selector(pivotBarViewController)]) {
                id pivot = [root performSelector:@selector(pivotBarViewController)];
                if ([pivot respondsToSelector:@selector(selectItemWithPivotIdentifier:)]) [pivot performSelector:@selector(selectItemWithPivotIdentifier:) withObject:@"FEwhat_to_watch"];
            }
        }
        Class hudClass = %c(YTHUDMessage), managerClass = %c(GOOHUDManagerInternal);
        if ([hudClass respondsToSelector:@selector(messageWithText:)] && [managerClass respondsToSelector:@selector(sharedInstance)])
            [[managerClass sharedInstance] showMessageMainThread:[hudClass messageWithText:LOC(@"SHORTS_BLOCKED")]];
    });
}

%hook YTReelPlayerViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    YouModCloseShortsController(self);
}
- (BOOL)shouldAlwaysEnablePlayerBar { return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; }
- (BOOL)shouldEnablePlayerBarOnlyOnPause { return IS_ENABLED(ShowShortsSeekbar) ? NO : %orig; }
- (void)loadPlayerBar {
    %orig;
    if ((isShortsOnlyOn && IS_ENABLED(ShortsOnly)) || (isFullscreenEnabled && IS_ENABLED(FullScreenShorts))) [YouModAppViewController() performSelector:@selector(hidePivotBar)];
    YTPlayerViewController *main = self.player;
    if (INTFORVAL(CaptionTrack) != 0) [main performSelector:@selector(YouModAutoCaptions) withObject:nil afterDelay:0.5];
    if (INTFORVAL(ShortsAutoSpeedIndex) != 0) [main performSelector:@selector(YouModSetAutoSpeed) withObject:nil afterDelay:0.5];
}
- (void)maybeLoopPlayback {
    NSInteger action = INTFORVAL(ShortsActionIndex);
    if (action == 1) [self reelContentViewRequestsAdvanceToNextVideo:nil];
    else if (action == 2) [self reelContentViewRequestsPlayPauseToggle:nil];
    else %orig;
}
%end

// YT 21.4x: Shorts are hosted by YTReelContainerViewController + YTShortsContentPresenter, not YTReelPlayerViewController
%hook YTReelContainerViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    YouModCloseShortsController(self);
}
- (void)handleLoopBehavior {
    NSInteger action = INTFORVAL(ShortsActionIndex);
    if (action == 1) [[self valueForKey:@"_delegate"] playbackSequentialItemControllerDidRequestNextReel:self isAutoAdvance:YES];
    else if (action == 2) return;
    else %orig;
}
- (void)setupPlayerForPiP { if (!IS_ENABLED(DisablesShortsPiP)) %orig; }
- (void)loadPlayerBarAndShowIfNeeded {
    %orig;
    if ((isShortsOnlyOn && IS_ENABLED(ShortsOnly)) || (isFullscreenEnabled && IS_ENABLED(FullScreenShorts))) [YouModAppViewController() performSelector:@selector(hidePivotBar)];
    YTPlayerViewController *main = self.player;
    if (INTFORVAL(CaptionTrack) != 0) [main performSelector:@selector(YouModAutoCaptions) withObject:nil afterDelay:0.5];
    if (INTFORVAL(ShortsAutoSpeedIndex) != 0) [main performSelector:@selector(YouModSetAutoSpeed) withObject:nil afterDelay:0.5];
}
%end

%hook YTReelPlayerBarIntegrationController
- (void)updatePlayerBarVisibility:(BOOL)visible { %orig(IS_ENABLED(ShowShortsSeekbar) ? YES : visible); }
%end

%hook YTReelTopBarView
- (void)didMoveToWindow {
    %orig;
    if (IS_ENABLED(HideShortsTopbar)) self.hidden = YES;
}
%end

%hook YTPausedStateCarouselView
- (void)didMoveToWindow {
    %orig;
    if (IS_ENABLED(HideShortsSubbar)) self.hidden = YES;
}
%end

%hook YTReelAccessoryView
- (void)setAccessoryViewElementRenderer:(YTIElementRenderer *)renderer hdrUIBoostRatio:(float)ratio {
    if (IS_ENABLED(HideShortsSubbar) && renderer && [renderer.description containsString:@"shorts_paused_state.eml"]) return;
    %orig;
}
%end

void YouModRemoveShortsPausedButtons(_ASDisplayView *self, NSString *iden) {
    if (!IS_ENABLED(RemoveShortsPausedSubButton) && !IS_ENABLED(RemoveShortsPausedLiveButton) && !IS_ENABLED(RemoveShortsPausedLensButton) && !IS_ENABLED(RemoveShortsPausedTrendsButton)) return;
    if (![iden containsString:@"id.ui.shorts_paused_state."] && ![iden hasSuffix:@"_button"]) return;
    ASScrollView *view = (ASScrollView *)self.superview;
    if (![view isKindOfClass:%c(ASScrollView)]) return;
    NSDictionary *buttonsList = @{
        @"id.ui.shorts_paused_state.subscriptions_button": @(IS_ENABLED(RemoveShortsPausedSubButton)),
        @"id.ui.shorts_paused_state.live_button": @(IS_ENABLED(RemoveShortsPausedLiveButton)),
        @"id.ui.shorts_paused_state.lens_button": @(IS_ENABLED(RemoveShortsPausedLensButton)),
        @"id.ui.shorts_paused_state.trends_button" : @(IS_ENABLED(RemoveShortsPausedTrendsButton))
    };
    for (NSString *button in buttonsList) {
        if ([buttonsList[button] boolValue] && [iden isEqualToString:button]) {
            ASDisplayNode *node = view.scrollNode;
            for (ASDisplayNode *child in node.yogaChildren) {
                if ([child.description containsString:button]) {
                    [node removeYogaChild:child];
                    break;
                }
            }
        }
    }
}

void YouModFilterShortsDisplayView(_ASDisplayView *view, NSString *iden) {
    UIViewController *con = view._viewControllerForAncestor;
    BOOL isShorts = [con isKindOfClass:%c(YTShortsPlayerViewController)] || [con isKindOfClass:%c(YTShortsContentPresenter)];
    if (([iden isEqualToString:@"id.sponsor_button"] || [iden isEqualToString:@"eml.reel_sponsor_button"]) && IS_ENABLED(HideSponsorButton)) {
        if (![con isKindOfClass:%c(YTWatchNextResultsViewController)] && !isShorts) return;
        ASDisplayNode *supNode = ((_ASDisplayView *)view.superview).keepalive_node;
        for (ASDisplayNode *child in supNode.yogaChildren) {
            if ([child.description containsString:@"sponsor_button"]) {
                [supNode removeYogaChild:child];
                break;
            }
        }
    }
    else if (!isShorts) return;
    else if (([iden isEqualToString:@"product_sticker.main_target"] || [iden isEqualToString:@"product_sticker.secondary_target"]) && IS_ENABLED(HideShortsProducts)) view.hidden = YES;
    else if ([iden isEqualToString:@"id.elements.components.suggested_action"] && IS_ENABLED(HideShortsRecbar)) view.hidden = YES;
    else if ([iden isEqualToString:@"eml.shorts-disclosures"] && IS_ENABLED(RemoveShortsDisclosure)) {
        _ASDisplayView *dpView = (_ASDisplayView *)((_ASDisplayView *)view.superview).superview;
        ASDisplayNode *node = dpView.keepalive_node;
        _ASDisplayView *maindpView = (_ASDisplayView *)dpView.superview;
        ASDisplayNode *mainNode = maindpView.keepalive_node;
        [mainNode removeYogaChild:node];
    } else if (([iden isEqualToString:@"eml.animated_subscribe_button"] || [iden isEqualToString:@"eml.compact_subscribe_button"]) && IS_ENABLED(RemoveShortsSubButton)) {
        view.hidden = YES;
    } else if ([iden isEqualToString:@"eml.shorts-video-title-new"] && IS_ENABLED(RemoveShortsVideoTitle)) {
        _ASDisplayView *title = view;
        for (int i=0; i<3; i++) title = (_ASDisplayView *)title.superview;
        ASDisplayNode *node = title.keepalive_node;
        title = (_ASDisplayView *)title.superview;
        [title.keepalive_node removeYogaChild:node];
    } else if ([iden isEqualToString:@"eml.reel_channel_bar.channel_name"] && IS_ENABLED(RemoveShortsChannelName)) {
        _ASDisplayView *bruh = view;
        for (int i=0; i<=1; i++) bruh = (_ASDisplayView *)bruh.superview;
        ASDisplayNode *node = bruh.keepalive_node;
        [node removeYogaChild:node.yogaChildren.lastObject];
    } else if ([iden isEqualToString:@"decorated-avatar-id"] && IS_ENABLED(RemoveShortsChannelProfile)) {
        ASDisplayNode *node = ((_ASDisplayView *)view.superview).keepalive_node;
        [node removeYogaChild:node.yogaChildren.firstObject];
    } else {
        ASDisplayNode *no = view.keepalive_node;
        NSString *desc = nil;
        @try {
            desc = [[[no nodeController] performSelector:@selector(owningComponent)] description];
        } @catch (...) {}
        if (desc != nil && [desc containsString:@"participation_bar.eml"] && IS_ENABLED(RemoveShortsCommentBar)) {
            ASDisplayNode *supNode = ((_ASDisplayView *)view.superview).keepalive_node;
            [supNode removeYogaChild:no];
        } else {
            desc = nil;
            @try {
                desc = [[[[no nodeController] performSelector:@selector(children)] performSelector:@selector(firstObject)] description];
            } @catch (...) {
                return;
            }
            if (desc != nil && [desc containsString:@"reel_carousel.eml"] && IS_ENABLED(RemoveShortsRelatedButtons)) {
                ASDisplayNode *supNode = ((_ASDisplayView *)view.superview).keepalive_node;
                [supNode removeYogaChild:no];
            }
        }
    }
}

// bro, it's becoming lowkey tiktok
%hook YTReelWatchRootView
- (void)setBottomActionBarView:(UIView *)view {
    if (IS_ENABLED(RemoveShortsCommentBar)) return;
    %orig;
}
%end

%hook YTAppDelegate
- (void)sceneDidBecomeActive:(UIScene *)scene {
    %orig;
    if ((isFullscreenEnabled && IS_ENABLED(FullScreenShorts)) || (isShortsOnlyOn && IS_ENABLED(ShortsOnly))) [YouModAppViewController() performSelector:@selector(hidePivotBar)];
}
%end

// Filtering Shorts overlay buttons
%hook YTReelWatchPlaybackOverlayView
- (void)layoutActionBar {
    %orig;
    if (!IS_ENABLED(RemoveShortsLikeButton) && !IS_ENABLED(RemoveShortsCommentButton) && !IS_ENABLED(RemoveShortsShareButton) && !IS_ENABLED(RemoveShortsRemixButton) && !IS_ENABLED(RemoveShortsSoundMetadataButton) && !IS_ENABLED(RemoveShortsSaveButton)) return;
    _ASDisplayView *view = nil;
    @try {
        view = [self valueForKey:@"_playerOverlayView"];
    } @catch (id ex) {}
    if (view != nil) {
        _ASDisplayView *check = view;
        while (view.subviews.count == 1) view = view.subviews[0];
        if (view.subviews.count > 1 && view != check && [view isKindOfClass:%c(_ASDisplayView)]) YouModRemoveShortsOverlayButton(view.subviews[1]);
    } else {
        view = [self valueForKey:@"_actionBarComponentView"];
        if (view == nil) return;
        _ASDisplayView *check = view;
        while (view.subviews.count == 1) view = view.subviews[0];
        if (view != check && view.subviews.count > 1 && [view isKindOfClass:%c(_ASDisplayView)]) YouModRemoveShortsOverlayButton(view);
    }
}
- (void)setLensButtonElementRenderer:(YTIElementRenderer *)renderer { if (!IS_ENABLED(RemoveShortsCenterLensButton)) %orig; }
%end

// new hook for newer YT
%hook YTShortsContentPresenterView
- (void)layoutSubviews {
    %orig;
    if (!IS_ENABLED(RemoveShortsLikeButton) && !IS_ENABLED(RemoveShortsCommentButton) && !IS_ENABLED(RemoveShortsShareButton) && !IS_ENABLED(RemoveShortsRemixButton) && !IS_ENABLED(RemoveShortsSoundMetadataButton) && !IS_ENABLED(RemoveShortsSaveButton)) return;
    _ASDisplayView *view = [self valueForKey:@"_overlayView"];
    _ASDisplayView *check = view;
    while (view.subviews.count == 1) view = view.subviews[0];
    if (view.subviews.count > 1 && view != check && [view isKindOfClass:%c(_ASDisplayView)]) YouModRemoveShortsOverlayButton(view.subviews[1]);
}
- (void)setLensButtonElementRenderer:(YTIElementRenderer *)renderer { if (!IS_ENABLED(RemoveShortsCenterLensButton)) %orig; }
%end

%hook YTPlayerView
- (void)didPinch:(UIPinchGestureRecognizer *)gesture {
    %orig;
    BOOL isNotOk = isShortsOnlyOn && IS_ENABLED(ShortsOnly);
    if (IS_ENABLED(FullScreenShorts) && !isNotOk) {
        UIViewController *vc = self._viewControllerForAncestor.parentViewController;
        if ([vc isKindOfClass:%c(YTShortsPlayerViewController)]
            || [vc isKindOfClass:%c(YTReelContainerViewController)]) {
            UIView *mainView = vc.view;
            @try {
                mainView = [mainView valueForKey:@"_overlayView"];
            } @catch (id ex) {
                mainView = [mainView valueForKey:@"_playbackOverlay"];
            }
            UIViewController *appVC = YouModAppViewController();
            if (gesture.scale > 1) {
                isFullscreenEnabled = YES;
                [appVC performSelector:@selector(hidePivotBar)];
                [UIView animateWithDuration:0.3 animations:^{ mainView.alpha = 0; }];
            } else {
                isFullscreenEnabled = NO;
                [appVC performSelector:@selector(showPivotBar)];
                [UIView animateWithDuration:0.3 animations:^{ mainView.alpha = 1; }];
            }
        }
    }
}
%end

%hook YTReelFreeZoomOverlayView
- (void)didMoveToWindow {
    %orig;
    if (IS_ENABLED(FullScreenShorts)) [self removeFromSuperview];
}
%end

%hook YTReelContentView
%property (nonatomic, retain) UILongPressGestureRecognizer *YouModExitShortsOnlyGesture;
- (void)setUpGestureRecognizers {
    %orig;
    self.playbackOverlay.alpha = !isFullscreenEnabled;
    if (IS_ENABLED(ShortsOnly) && isShortsOnlyOn && !self.YouModExitShortsOnlyGesture) {
        self.YouModExitShortsOnlyGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(YouModTurnOffShortsOnly:)];
        self.YouModExitShortsOnlyGesture.numberOfTouchesRequired = 2;
        self.YouModExitShortsOnlyGesture.minimumPressDuration = 0.5;
        [self addGestureRecognizer:self.YouModExitShortsOnlyGesture];
    }
}
%new
- (void)YouModTurnOffShortsOnly:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    isShortsOnlyOn = NO;
    [self removeGestureRecognizer:self.YouModExitShortsOnlyGesture];
    self.YouModExitShortsOnlyGesture = nil;
    UIView *parent = sbGetNotificationParent();
    [YouModPillView showSuccessInView:parent message:LOC(@"SHORTS_ONLY_DISABLED") duration:3.0];
    [YouModAppViewController() performSelector:@selector(showPivotBar)];
    [UIView animateWithDuration:0.3 animations:^{ self.playbackOverlay.alpha = 1; }];
}
%end

%hook YTReelContainerView
%property (nonatomic, retain) UILongPressGestureRecognizer *YouModExitShortsOnlyGesture;
- (void)setOverlayView:(UIView *)overlayView {
    %orig;
    if (overlayView) overlayView.alpha = !isFullscreenEnabled;
    if (IS_ENABLED(ShortsOnly) && isShortsOnlyOn && !self.YouModExitShortsOnlyGesture) {
        self.YouModExitShortsOnlyGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(YouModTurnOffShortsOnly:)];
        self.YouModExitShortsOnlyGesture.numberOfTouchesRequired = 2;
        self.YouModExitShortsOnlyGesture.minimumPressDuration = 0.5;
        [self addGestureRecognizer:self.YouModExitShortsOnlyGesture];
    }
}
%new
- (void)YouModTurnOffShortsOnly:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    isShortsOnlyOn = NO;
    [self removeGestureRecognizer:self.YouModExitShortsOnlyGesture];
    self.YouModExitShortsOnlyGesture = nil;
    UIView *parent = sbGetNotificationParent();
    [YouModPillView showSuccessInView:parent message:LOC(@"SHORTS_ONLY_DISABLED") duration:3.0];
    [YouModAppViewController() performSelector:@selector(showPivotBar)];
    [UIView animateWithDuration:0.3 animations:^{ self.overlayView.alpha = 1; }];
}
%end

// Block Shorts player: Shorts links (youtube.com/shorts/ID) open as normal videos (youtube.com/watch?v=ID).
static NSURL *YouModShortsLinkAsVideo(NSURL *url) {
    if (!IS_ENABLED(BlockShortsPlayer) || ![url.host.lowercaseString hasSuffix:@"youtube.com"]) return url;
    NSArray <NSString *> *parts = url.pathComponents;
    if (parts.count < 3 || ![parts[1] isEqualToString:@"shorts"]) return url;
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    NSMutableArray <NSURLQueryItem *> *query = [NSMutableArray arrayWithObject:[NSURLQueryItem queryItemWithName:@"v" value:parts[2]]];
    if (components.queryItems) [query addObjectsFromArray:components.queryItems];
    components.path = @"/watch";
    components.queryItems = query;
    return components.URL ?: url;
}

%hook YTAppDelegate
- (void)handleURL:(NSURL *)url sourceApplication:(NSString *)app annotation:(id)annotation {
    %orig(YouModShortsLinkAsVideo(url), app, annotation);
}
%end

%hook YTURLHandlerImpl
- (void)openURL:(NSURL *)url fromView:(id)view parentResponder:(id)parent originalResponder:(id)original referringApp:(id)app trackingParams:(id)params isOriginExternal:(BOOL)external linkOpenerOptions:(id)options {
    %orig(YouModShortsLinkAsVideo(url), view, parent, original, app, params, external, options);
}
%end

// Hide Shorts shelf: drop the Shorts tab from channel pages (its browse params start with field 2 = "shorts"), unless it is the open tab.
static BOOL YouModIsShortsChannelTab(id tab) {
    id tabRenderer = [tab respondsToSelector:@selector(tabRenderer)] ? [tab performSelector:@selector(tabRenderer)] : nil;
    if (!tabRenderer || ([tabRenderer respondsToSelector:@selector(selected)] && ((BOOL (*)(id, SEL))objc_msgSend)(tabRenderer, @selector(selected)))) return NO;
    GPBMessage *endpoint = [tabRenderer respondsToSelector:@selector(endpoint)] ? [tabRenderer performSelector:@selector(endpoint)] : nil;
    if (![endpoint respondsToSelector:@selector(messageForFieldNumber:messageClass:)]) return NO;
    id browseEndpoint = [endpoint messageForFieldNumber:48687626 messageClass:%c(YTIBrowseEndpoint)]; // YTIBrowseEndpointRoot_browseEndpoint
    NSString *params = [browseEndpoint respondsToSelector:@selector(params)] ? [[browseEndpoint performSelector:@selector(params)] stringByRemovingPercentEncoding] : nil;
    if (params.length == 0) return NO;
    params = [[params stringByReplacingOccurrencesOfString:@"-" withString:@"+"] stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    while (params.length % 4) params = [params stringByAppendingString:@"="];
    NSData *data = [[NSData alloc] initWithBase64EncodedString:params options:0];
    static const char prefix[] = "\x12\x06shorts";
    return data.length >= sizeof(prefix) - 1 && memcmp(data.bytes, prefix, sizeof(prefix) - 1) == 0;
}

%hook YTISingleColumnBrowseResultsRenderer
- (NSMutableArray *)tabsArray {
    NSMutableArray *tabs = %orig;
    if (IS_ENABLED(HideShortsShelf) && tabs.count > 1) {
        NSIndexSet *shorts = [tabs indexesOfObjectsPassingTest:^BOOL(id tab, NSUInteger idx, BOOL *stop) { return YouModIsShortsChannelTab(tab); }];
        if (shorts.count) [tabs removeObjectsAtIndexes:shorts];
    }
    return tabs;
}
%end

// Remove the "Shorts" filter chip (History, Subscriptions, search) from its ELM chip collection, so the chip row reflows.
void YouModRemoveShortsChip(_ASDisplayView *view, NSString *iden) {
    if (![iden isEqualToString:@"id.elements.components.chip.primary_tap_container"] || ![view.accessibilityLabel isEqualToString:@"Shorts"]) return;
    if (!IS_ENABLED(HideShortsShelf) && !IS_ENABLED(HideShortsHistory)) return;
    UIView *cell = view;
    while (cell && ![((_ASDisplayView *)cell).keepalive_node isKindOfClass:%c(ELMCellNode)]) cell = cell.superview;
    UIView *collection = cell;
    while (collection && ![collection isKindOfClass:%c(ASCollectionView)]) collection = collection.superview;
    if (!cell || ![collection respondsToSelector:@selector(collectionNode)]) return;
    ASDisplayNode *cellNode = ((_ASDisplayView *)cell).keepalive_node;
    ELMNodeController *chip = (ELMNodeController *)[cellNode controller];
    id bar = [chip respondsToSelector:@selector(parent)] ? chip.parent : nil;
    id collectionNode = [collection performSelector:@selector(collectionNode)];
    // Subscriptions keeps a stale cell after ELM's own removal, so drop it from the collection's section there instead.
    BOOL isSubs = [collection.superview.superview.superview.accessibilityIdentifier isEqualToString:@"eml.subscriptions_chip_bar"];
    if (isSubs && IS_ENABLED(KeepShortsSubscript)) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!isSubs) {
            if ([bar respondsToSelector:@selector(remove:)]) [bar performSelector:@selector(remove:) withObject:chip];
            return;
        }
        id section = nil;
        @try { section = [collectionNode valueForKey:@"_singleSectionController"]; } @catch (id ex) { return; }
        if (![[section valueForKey:@"_cellNodes"] containsObject:cellNode]) return;
        [section performSelector:@selector(removeNode:) withObject:cellNode];
        [collectionNode performSelector:@selector(reloadData)];
    });
}

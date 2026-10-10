#import "Headers.h"

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

static void YouModMakeAShortsAction(YTReelPlayerViewController *self, YTSingleVideoController *video, YTSingleVideoTime *time) {
    if (INTFORVAL(ShortsActionIndex) == 0) return;
    if (floor(time.time) >= floor(video.totalMediaTime)) {
        if (INTFORVAL(ShortsActionIndex) == 1) [self reelContentViewRequestsAdvanceToNextVideo:nil];
        else if (INTFORVAL(ShortsActionIndex) == 2) [self reelContentViewRequestsPlayPauseToggle:nil];
    }
}

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
        @"reel_save_button.eml" : @(IS_ENABLED(RemoveShortsSaveButton))
    };
    ASDisplayNode *node = dpView.keepalive_node;
    for (NSString *button in buttonsList) {
        if ([buttonsList[button] boolValue]) {
            for (_ASDisplayView *sub in dpView.subviews) {
                if ([sub.accessibilityIdentifier isEqualToString:button]) {
                    [sub removeFromSuperview];
                } else if (sub.accessibilityIdentifier == nil && sub.accessibilityLabel != nil && IS_ENABLED(RemoveShortsSaveButton)) {
                    NSString *desc = nil;
                    @try {
                        desc = [[[sub.keepalive_node.nodeController performSelector:@selector(owningComponent)] performSelector:@selector(owningComponent)] description];
                    } @catch (id ex) {
                        continue;
                    }
                    if (desc != nil && [desc containsString:button]) [sub removeFromSuperview];
                }
            }
            for (ASDisplayNode *child in [node.yogaChildren copy]) {
                if ([[child description] containsString:button]) {
                    [node removeYogaChild:child];
                } else if (IS_ENABLED(RemoveShortsSaveButton)) {
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

%hook YTReelPlayerViewController
- (BOOL)shouldAlwaysEnablePlayerBar { return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; }
- (BOOL)shouldEnablePlayerBarOnlyOnPause { return IS_ENABLED(ShowShortsSeekbar) ? NO : %orig; }
- (void)singleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    YouModMakeAShortsAction(self, video, time);
}
- (void)loadPlayerBar {
    %orig;
    if ((isShortsOnlyOn && IS_ENABLED(ShortsOnly)) || (isFullscreenEnabled && IS_ENABLED(FullScreenShorts))) [[self valueForKey:@"_pivotBarProvider"] performSelector:@selector(hidePivotBar)];
    YTPlayerViewController *main = self.player;
    if (INTFORVAL(CaptionTrack) != 0) [main performSelector:@selector(YouModAutoCaptions) withObject:nil afterDelay:0.5];
    if (INTFORVAL(ShortsAutoSpeedIndex) != 0) [main performSelector:@selector(YouModSetAutoSpeed) withObject:nil afterDelay:0.5];
}
%end

%hook YTReelTopBarView
- (void)didMoveToWindow {
    %orig;
    if (IS_ENABLED(HideShortsTopbar)) {
        [self removeFromSuperview];
    } else if (IS_ENABLED(HideShortsSubbar)) { 
        UIView *subbar = [self valueForKey:@"_pausedStateCarouselView"];
        if (subbar) [subbar removeFromSuperview];
    }
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
            for (id child in node.yogaChildren) {
                if ([[child description] containsString:button]) {
                    [node removeYogaChild:child];
                    [self removeFromSuperview];
                    break;
                }
            }
        }
    }
}

void YouModFilterShortsDisplayView(_ASDisplayView *view, NSString *iden) {
    if (([iden isEqualToString:@"product_sticker.main_target"] || [iden isEqualToString:@"product_sticker.secondary_target"]) && IS_ENABLED(HideShortsProducts)) {
        view.hidden = YES;
    } else if ([iden isEqualToString:@"id.elements.components.suggested_action"] && IS_ENABLED(HideShortsRecbar)) {
        view.hidden = YES;
    } else if ([iden isEqualToString:@"eml.shorts-disclosures"] && IS_ENABLED(RemoveShortsDisclosure)) {
        _ASDisplayView *dpView = (_ASDisplayView *)((_ASDisplayView *)view.superview).superview;
        ASDisplayNode *node = dpView.keepalive_node;
        _ASDisplayView *maindpView = (_ASDisplayView *)dpView.superview;
        ASDisplayNode *mainNode = maindpView.keepalive_node;
        [mainNode removeYogaChild:node];
        [dpView removeFromSuperview];
    } else if (([iden isEqualToString:@"id.sponsor_button"] || [iden isEqualToString:@"eml.reel_sponsor_button"]) && IS_ENABLED(HideSponsorButton)) {
        if (![view._viewControllerForAncestor isKindOfClass:%c(YTWatchNextResultsViewController)] && ![view._viewControllerForAncestor isKindOfClass:%c(YTShortsPlayerViewController)]) return;
        ASDisplayNode *supNode = ((_ASDisplayView *)view.superview).keepalive_node;
        for (ASDisplayNode *child in supNode.yogaChildren) {
            if ([child.description containsString:@"sponsor_button"]) {
                [supNode removeYogaChild:child];
                break;
            }
        }
        [view removeFromSuperview];
    } else if (([iden isEqualToString:@"eml.animated_subscribe_button"] || [iden isEqualToString:@"eml.compact_subscribe_button"]) && IS_ENABLED(RemoveShortsSubButton) && [view._viewControllerForAncestor isKindOfClass:%c(YTShortsPlayerViewController)]) {
        view.hidden = YES;
    } else if ([view._viewControllerForAncestor isKindOfClass:%c(YTShortsPlayerViewController)]) {
        ASDisplayNode *no = view.keepalive_node;
        NSString *desc = nil;
        @try {
            desc = [[[no nodeController] performSelector:@selector(owningComponent)] description];
        } @catch (...) {}
        if (desc != nil && [desc containsString:@"participation_bar.eml"] && IS_ENABLED(RemoveShortsCommentBar)) {
            ASDisplayNode *supNode = ((_ASDisplayView *)view.superview).keepalive_node;
            [supNode removeYogaChild:no];
            [view removeFromSuperview];
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
                [view removeFromSuperview];
            }
        }
    }
}

%hook YTAppDelegate
- (void)sceneDidBecomeActive:(UIScene *)scene {
    %orig;
    if ((isFullscreenEnabled && IS_ENABLED(FullScreenShorts)) || (isShortsOnlyOn && IS_ENABLED(ShortsOnly))) {
        [[self valueForKey:@"_appViewController"] performSelector:@selector(hidePivotBar)];
    }
}
%end

%hook YTPlayerView
- (void)didPinch:(UIPinchGestureRecognizer *)gesture {
    %orig;
    UIViewController *shortspvc = self._viewControllerForAncestor.parentViewController;
    if (!IS_ENABLED(FullScreenShorts) || (isShortsOnlyOn && IS_ENABLED(ShortsOnly))
        || ![shortspvc isKindOfClass:%c(YTShortsPlayerViewController)]) return;
    UIViewController *appVC = [shortspvc valueForKey:@"_pivotBarProvider"];
    BOOL isTabBarHidden = [appVC performSelector:@selector(isPivotBarHidden)];
    if (gesture.scale > 1.0) {
        if (!isTabBarHidden) {
            [appVC performSelector:@selector(hidePivotBar)];
            [UIView animateWithDuration:0.3 animations:^{ self.alpha = 0; }];
            isFullscreenEnabled = YES;
        }
    } else if (gesture.scale < 1.0) {
        if (isTabBarHidden) {
            [appVC performSelector:@selector(showPivotBar)];
            [UIView animateWithDuration:0.3 animations:^{ self.alpha = 1; }];
            isFullscreenEnabled = NO;
        }
    }
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
        if (view.subviews.count > 1 && view != check) YouModRemoveShortsOverlayButton(view.subviews[1]);
    } else {
        view = [self valueForKey:@"_actionBarComponentView"];
        _ASDisplayView *check = view;
        while (view.subviews.count == 1) view = view.subviews[0];
        if (view != check) YouModRemoveShortsOverlayButton(view);
    }
}
%end

%hook YTReelContentView
%property (nonatomic, retain) UILongPressGestureRecognizer *YouModExitShortsOnlyGesture;
- (void)setUpGestureRecognizers {
    %orig;
    if (!IS_ENABLED(ShortsOnly)) return;
    self.playbackOverlay.alpha = !isFullscreenEnabled;
    if (isShortsOnlyOn) {
        self.YouModExitShortsOnlyGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(YouModTurnOffShortsOnly:)];
        self.YouModExitShortsOnlyGesture.numberOfTouchesRequired = 2;
        self.YouModExitShortsOnlyGesture.minimumPressDuration = 0.5;
        self.YouModExitShortsOnlyGesture.delegate = (id<UIGestureRecognizerDelegate>)self;
        [self addGestureRecognizer:self.YouModExitShortsOnlyGesture];
    }
}
%new
- (void)YouModTurnOffShortsOnly:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    isShortsOnlyOn = NO;
    UIView *parent = sbGetNotificationParent();
    [SBSkipNotificationView showSuccessInView:parent message:LOC(@"SHORTS_ONLY_DISABLED") duration:3.0];
    [[[[self valueForKey:@"_parentResponder"] valueForKey:@"_delegate"] valueForKey:@"_pivotBarProvider"] performSelector:@selector(showPivotBar)];
    [UIView animateWithDuration:0.3 animations:^{ self.playbackOverlay.alpha = 1; }];
}
%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == self.YouModExitShortsOnlyGesture && [otherGestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
        return YES;
    }
    return NO;
}
%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == self.YouModExitShortsOnlyGesture) return NO;
    return YES;
}
%end
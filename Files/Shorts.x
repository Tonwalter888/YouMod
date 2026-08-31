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
- (BOOL)mobileShortsTablnlinedExpandWatchOnDismiss { return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; }
%end

static void YouModMakeAShortsAction(YTReelPlayerViewController *self, YTSingleVideoController *video, YTSingleVideoTime *time) {
    if (INTFORVAL(ShortsActionIndex) == 0) return;

    if (floor(time.time) >= floor(video.totalMediaTime)) {
        if (INTFORVAL(ShortsActionIndex) == 1) {
            [self reelContentViewRequestsAdvanceToNextVideo:nil];
        } else if (INTFORVAL(ShortsActionIndex) == 2) {
            [self reelContentViewRequestsPlayPauseToggle:nil];
        }
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
        @"id.reel_pivot_button": @(IS_ENABLED(RemoveShortsSoundMetadataButton))
    };
    ASDisplayNode *node = dpView.keepalive_node;
    for (NSString *button in buttonsList) {
        if ([buttonsList[button] boolValue]) {
            for (UIView *sub in dpView.subviews) {
                if ([sub.accessibilityIdentifier isEqualToString:button]) {
                    [sub removeFromSuperview];
                }
            }
            for (id child in [node.yogaChildren copy]) {
                if ([[child description] containsString:button]) {
                    [node removeYogaChild:child];
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
    if (INTFORVAL(AutoSpeedIndex) != 0) [main performSelector:@selector(YouModSetAutoSpeed) withObject:nil afterDelay:0.5];
    if (INTFORVAL(AudioTrack) != 0) [self performSelector:@selector(YouModAutoAudioTrack:) withObject:main afterDelay:0.5];
}
%new
- (void)YouModAutoAudioTrack:(YTPlayerViewController *)pv {
    NSInteger selectedIndex = INTFORVAL(AudioTrackLangIndex);
    NSArray *langCodes = getAllSystemLanguageValues();
    NSString *userTargetLang = langCodes[selectedIndex];
    id switchcon = self.audioTrackController;
    NSArray *availableTracks = [switchcon valueForKey:@"_availableAudioTracks"];
    if (!availableTracks || availableTracks.count == 0) return;
    YTIAudioTrack *matchedTrack = nil;

    if (INTFORVAL(AudioTrack) == 1) {
        // Loop for all tracks
        for (YTIAudioTrack *track in availableTracks) {
            if ([track.id_p hasSuffix:@".4"]) {
                matchedTrack = track;
                break;
            }
        }
    } else if (INTFORVAL(AudioTrack) == 2) {
        // Loop for all tracks
        for (YTIAudioTrack *track in availableTracks) {
            if ([track.id_p hasPrefix:userTargetLang]) {
                matchedTrack = track;
                break;
            }
        }

        // Check if it's dubbed
        if (matchedTrack && [matchedTrack isAutoDubbed] && IS_ENABLED(NoDubbedAudioTrack)) matchedTrack = nil;

        if (!matchedTrack && IS_ENABLED(NoDubbedAudioTrack)) {
            for (YTIAudioTrack *track in availableTracks) {
                if ([track.id_p hasSuffix:@".4"]) {
                    matchedTrack = track;
                    break;
                }
            }
        }
    }

    // If found, change to it
    if (matchedTrack) {
        [pv setAudioTrack:matchedTrack source:0];
    }
}
%end

%hook YTReelTopBarView
- (void)didMoveToWindow {
    %orig;
    if (IS_ENABLED(HideShortsTopbar)) {
        if (self.superview) {
            [self removeFromSuperview];
        }
    } else if (IS_ENABLED(HideShortsSubbar)) {
        UIView *subbar = [self valueForKey:@"_pausedStateCarouselView"];
        if (subbar && subbar.superview) {
            [subbar removeFromSuperview];
        }
    }
}
%end

extern void YouModConfigureDownloadButton(_ASDisplayView *view);

%hook YTReelPausedStateCarouselView 
- (void)didMoveToWindow {
    %orig;
    if (!IS_ENABLED(RemoveShortsPausedSubButton) && !IS_ENABLED(RemoveShortsPausedLiveButton) && !IS_ENABLED(RemoveShortsPausedLensButton) && !IS_ENABLED(RemoveShortsPausedTrendsButton)) return;
    ASScrollView *view = (ASScrollView *)self;
    while (view.subviews.count == 1 && ![view isKindOfClass:%c(ASScrollView)]) {
        view = view.subviews[0];
    }
    if (![view isKindOfClass:%c(ASScrollView)] || view == self) return; 
    ASDisplayNode *node = view.scrollNode;
    NSDictionary *buttonsList = @{
        @"id.ui.shorts_paused_state.subscriptions_button": @(IS_ENABLED(RemoveShortsPausedSubButton)),
        @"id.ui.shorts_paused_state.live_button": @(IS_ENABLED(RemoveShortsPausedLiveButton)),
        @"id.ui.shorts_paused_state.lens_button": @(IS_ENABLED(RemoveShortsPausedLensButton)),
        @"id.ui.shorts_paused_state.trends_button" : @(IS_ENABLED(RemoveShortsPausedTrendsButton))
    };
    for (NSString *button in buttonsList) {
        if ([buttonsList[button] boolValue]) {
            for (UIView *sub in view.subviews) {
                if ([sub.accessibilityIdentifier isEqualToString:button]) {
                    [sub removeFromSuperview];
                }
            }
            for (id child in node.yogaChildren) {
                if ([[child description] containsString:button]) {
                    [node removeYogaChild:child];
                }
            }
        }
    }
}
%end

static void YouModFilterShortsDisclosure(_ASDisplayView *self, NSString *iden) {
    if (![self.accessibilityIdentifier isEqualToString:@"eml.shorts-disclosures"] || !IS_ENABLED(RemoveShortsDisclosure)) return;
    _ASDisplayView *dpView = (_ASDisplayView *)self.superview;
    ASDisplayNode *node = dpView.keepalive_node;
    _ASDisplayView *maindpView = (_ASDisplayView *)dpView.superview;
    ASDisplayNode *mainNode = maindpView.keepalive_node;
    [mainNode removeYogaChild:node];
    [maindpView removeFromSuperview];
}

// _ASDisplayView filters
%hook _ASDisplayView
- (void)didMoveToWindow {
    %orig;
    YouModConfigureDownloadButton(self);
    NSString *iden = self.accessibilityIdentifier;
    if (!iden || iden.length == 0) return;
    NSDictionary *elements = @{
        @"product_sticker.main_target": @(IS_ENABLED(HideShortsProducts)),
        @"product_sticker.secondary_target": @(IS_ENABLED(HideShortsProducts)),
        @"id.elements.components.suggested_action": @(IS_ENABLED(HideShortsRecbar))
    };
    if ([elements[iden] boolValue]) {
        [self removeFromSuperview];
        return;
    }
    if ([iden isEqualToString:@"eml.reel_sponsor_button"] && IS_ENABLED(RemoveChannelSponsorAll)) {
        [self.superview removeFromSuperview];
        return;
    }
    YouModFilterShortsDisclosure(self, iden);
}
%end

%hook YTAppDelegate
- (void)appDidBecomeActive {
    %orig;
    if ((isFullscreenEnabled && IS_ENABLED(FullScreenShorts)) || (isShortsOnlyOn && IS_ENABLED(ShortsOnly))) {
        [[self valueForKey:@"_appViewController"] performSelector:@selector(hidePivotBar)];
    }
}
%end

%hook YTReelWatchPlaybackOverlayView
%property (nonatomic, retain) UIPinchGestureRecognizer *YouModFullscreenGesture;
- (void)didMoveToWindow {
    %orig;
    if (!IS_ENABLED(FullScreenShorts)) return;
    if (!self.YouModFullscreenGesture) {
        self.YouModFullscreenGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(YouModFullscrrenGestureHandler:)];
        self.YouModFullscreenGesture.delegate = (id<UIGestureRecognizerDelegate>)self;
        [self.superview addGestureRecognizer:self.YouModFullscreenGesture];
    }
}
%new
- (void)YouModFullscrrenGestureHandler:(UIPinchGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan || (isShortsOnlyOn && IS_ENABLED(ShortsOnly))) return;
    UIViewController *appVC = [self valueForKey:@"_pivotBarProvider"];
    BOOL isTabBarHidden = [appVC performSelector:@selector(isPivotBarHidden)];
    if (gesture.scale > 1.0) {
        if (!isTabBarHidden) {
            [appVC performSelector:@selector(hidePivotBar)];
            [UIView animateWithDuration:0.3 animations:^{
                self.alpha = 0;
            }];
            isFullscreenEnabled = YES;
        }
    } else if (gesture.scale < 1.0) {
        if (isTabBarHidden) {
            [appVC performSelector:@selector(showPivotBar)];
            [UIView animateWithDuration:0.3 animations:^{
                self.alpha = 1;
            }];
            isFullscreenEnabled = NO;
        }
    }
}
%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == self.YouModFullscreenGesture) {
        return YES;
    }
    return NO;
}
// Filtering Shorts overlay buttons
- (void)layoutActionBar {
    %orig;
    if (!IS_ENABLED(RemoveShortsLikeButton) && !IS_ENABLED(RemoveShortsLikeButton) && !IS_ENABLED(RemoveShortsCommentButton) && !IS_ENABLED(RemoveShortsShareButton) && !IS_ENABLED(RemoveShortsRemixButton) && !IS_ENABLED(RemoveShortsSoundMetadataButton)) return;
    YTReelElementAsyncComponentView *view = nil;
    @try {
        view = [self valueForKey:@"_playerOverlayView"];
    } @catch (id ex) {}
    if (view != nil) {
        UIView *check = view;
        while (view.subviews.count == 1) {
            view = view.subviews[0];
        }
        if (view.subviews.count > 1 && view != check) {
            _ASDisplayView *dpView = (_ASDisplayView *)view.subviews[1];
            YouModRemoveShortsOverlayButton(dpView);
        }
    } else {
        view = [self valueForKey:@"_actionBarComponentView"];
        UIView *check = view;
        while (view.subviews.count == 1) {
            view = view.subviews[0];
        }
        if (view == check) return;
        _ASDisplayView *dpView = (_ASDisplayView *)view;
        YouModRemoveShortsOverlayButton(dpView);
    }
}
%end

%hook YTReelContentView
%property (nonatomic, retain) UILongPressGestureRecognizer *YouModExitShortsOnlyGesture;
- (void)setPlaybackView:(id)arg1 {
    %orig;
    self.playbackOverlay.alpha = !isFullscreenEnabled;
    if (!IS_ENABLED(ShortsOnly)) return;
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
    [UIView animateWithDuration:0.3 animations:^{
        self.playbackOverlay.alpha = 1;
    }];
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
    if (gestureRecognizer == self.YouModExitShortsOnlyGesture) {
        return NO;
    }
    return YES;
}
%end

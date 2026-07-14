#import "Headers.h"

// Enables shorts quality - works best with YTClassicVideoQuality
%hook YTHotConfig
- (BOOL)enableOmitAdvancedMenuInShortsVideoQualityPicker { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
- (BOOL)enableShortsVideoQualityPicker { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
- (BOOL)iosEnableImmersiveLivePlayerVideoQuality { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
- (BOOL)iosEnableShortsPlayerVideoQuality { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
- (BOOL)iosEnableShortsPlayerVideoQualityRestartVideo { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
- (BOOL)iosEnableSimplerTitleInShortsVideoQualityPicker { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
%end

// Always show Shorts seekbar
%hook YTShortsPlayerViewController
- (BOOL)shouldAlwaysEnablePlayerBar { return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; }
- (BOOL)shouldEnablePlayerBarOnlyOnPause { return IS_ENABLED(ShowShortsSeekbar) ? NO : %orig; }
%end

%hook YTReelPlayerViewController
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

%hook YTHotConfig
- (BOOL)enablePlayerBarForVerticalVideoWhenControlsHiddenInFullscreen { return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; }
%end

static void YouModMakeAShortsAction(YTReelPlayerViewController *self, YTSingleVideoController *video, YTSingleVideoTime *time) {
    if (INTFORVAL(ShortsActionIndex) == 0) return;

    if (floor(time.time) == floor(video.totalMediaTime)) {
        if (INTFORVAL(ShortsActionIndex) == 1) {
            [self reelContentViewRequestsAdvanceToNextVideo:nil];
        } else if (INTFORVAL(ShortsActionIndex) == 2) {
            [self reelContentViewRequestsPlayPauseToggle:nil];
        }
    }
}

%hook YTReelPlayerViewController
- (void)singleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    YouModMakeAShortsAction(self, video, time);
}
- (void)loadPlayerBar {
    %orig;
    YTPlayerViewController *main = self.player;
    // if (IS_ENABLED(MuteButton)) [main YouModAutoMute];
    if (INTFORVAL(CaptionTrack) != 0) [main performSelector:@selector(YouModAutoCaptions) withObject:nil afterDelay:0.5];
    if (INTFORVAL(AutoSpeedIndex) != 0) [main performSelector:@selector(YouModSetAutoSpeed) withObject:nil afterDelay:0.5];
    if (INTFORVAL(AudioTrack) != 0) [main performSelector:@selector(YouModAutoAudioTrack) withObject:nil afterDelay:0.5];
}
%end

extern void YouModConfigureDownloadButton(_ASDisplayView *view);

// _ASDisplayView filters
%hook _ASDisplayView
- (void)didMoveToWindow {
    %orig;
    YouModConfigureDownloadButton(self);
    NSDictionary *elements = @{
        @"product_sticker.main_target": @(IS_ENABLED(HideShortsProducts)),
        @"product_sticker.secondary_target": @(IS_ENABLED(HideShortsProducts)),
        @"id.elements.components.suggested_action": @(IS_ENABLED(HideShortsRecbar))
    };
    if ([elements[self.accessibilityIdentifier] boolValue]) [self removeFromSuperview]; 
}
%end

%hook YTReelWatchPlaybackOverlayView
%property (nonatomic, retain) UIPinchGestureRecognizer *YouModFullscreenGesture;
- (void)layoutPlayerOverlayView {
    %orig;
    if (!IS_ENABLED(FullScreenShorts)) return;
    if (!self.YouModFullscreenGesture) {
        self.YouModFullscreenGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(YouModFullscrrenGestureHandler:)];
        [self addGestureRecognizer:self.YouModFullscreenGesture];
    }
}
%new
- (void)YouModFullscrrenGestureHandler:(UIPinchGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    if ([self valueForKey:@"_pivotBarProvider"] isKindOfClass:%c(YTAppViewControllerImpl)) {
        YTAppViewControllerImpl *appcon = [self valueForKey:@"_pivotBarProvider"];
        if ([appcon isPivotBarHidden]) {
            [appcon showPivotBar];
        } else {
            [appcon hidePivotBar];
        }
    } else {
        YTAppViewController *appcon = [self valueForKey:@"_pivotBarProvider"];
        if ([appcon isPivotBarHidden]) {
            [appcon showPivotBar];
        } else {
            [appcon hidePivotBar];
        }
    }
}
%end
#import "Headers.h"

static BOOL isWiFiConnected() {
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)&zeroAddress);
    if (!reachability) return NO;
    
    SCNetworkReachabilityFlags flags;
    BOOL retrievedFlags = SCNetworkReachabilityGetFlags(reachability, &flags);
    CFRelease(reachability);
    
    if (!retrievedFlags) return NO;
    
    BOOL isReachable = (flags & kSCNetworkReachabilityFlagsReachable) != 0;
    BOOL needsConnection = (flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0;
    BOOL canConnect = isReachable && !needsConnection;
    
    if (!canConnect) return NO;
    
    BOOL isCellular = (flags & kSCNetworkReachabilityFlagsIsWWAN) != 0;
    return !isCellular;
}

extern void YouModDownloadSetCurrentPlayer(YTPlayerViewController *player);
extern YTPlayerViewController *YouModDownloadGetCurrentPlayer(void);

#pragma mark - Rewind / Fast-forward on iOS media controls

// The user-chosen skip amount for each direction, in seconds. Zero means the
// preference was never set, in which case the seek falls back to 10 seconds.
static CGFloat YouModRewindSecondsValue(void) {
    CGFloat s = FLOAT_FOR_KEY(RewindSeconds);
    return s > 0 ? s : 10.0;
}

static CGFloat YouModForwardSecondsValue(void) {
    CGFloat s = FLOAT_FOR_KEY(ForwardSeconds);
    return s > 0 ? s : 10.0;
}

// Seeks the active player by delta seconds, clamped to [0, duration]. Returns NO
// when no active player is available (e.g. a media key is pressed after playback
// ended), so the caller can report the command as having nothing to act on.
//
// The seek runs on the main queue because MPRemoteCommand handlers may be invoked
// off the main thread (notably from Bluetooth and CarPlay), while seekToTime: and
// the player's time accessors are main-thread-only.
static BOOL YouModSeekByInterval(CGFloat delta) {
    YTPlayerViewController *player = YouModDownloadGetCurrentPlayer();
    if (!player || ![player respondsToSelector:@selector(seekToTime:)]) return NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat cur = [player currentVideoMediaTime];
        CGFloat dur = [player currentVideoTotalMediaTime];
        CGFloat target = cur + delta;
        if (target < 0) target = 0;
        if (dur > 0 && target > dur) target = dur;
        [player seekToTime:target];
    });
    return YES;
}

// Retained handler tokens for the two skip commands. A non-nil token marks a
// command whose handler is already installed, so it is installed only once.
static id gYouModRewindTarget = nil;
static id gYouModForwardTarget = nil;

// Points the system now-playing skip controls (lock screen, Bluetooth, Control
// Center, CarPlay) at our per-direction seek. When enabled, the OS previous/next
// commands are turned off and skip-backward/forward take over with the user's
// intervals; when disabled, previous/next are restored. Only these system
// controls are configurable — the on-screen player rewind/fast-forward buttons
// are rendered by YouTube with an amount it owns, so they are left alone.
//
// The handlers are installed once and thereafter only their enabled state and
// preferred intervals are updated. Because the handlers read the seconds at press
// time, a changed preference always seeks by the new amount immediately; the
// interval shown on the OS controls reflects the value captured the last time this
// ran (video change or launch).
static void YouModConfigureRemoteSkipCommands(void) {
    MPRemoteCommandCenter *cc = [MPRemoteCommandCenter sharedCommandCenter];
    BOOL back = IS_ENABLED(SkipBackwardEnabled);
    BOOL fwd = IS_ENABLED(SkipForwardEnabled);

    // Each direction is independent: the previous/next track command is remapped
    // to a skip only on the side the user enabled, so a mixed state (e.g. rewind
    // on, fast-forward off) shows a skip-back control alongside the stock next
    // track button.
    cc.skipBackwardCommand.enabled = back;
    cc.skipBackwardCommand.preferredIntervals = @[@(YouModRewindSecondsValue())];
    cc.skipForwardCommand.enabled = fwd;
    cc.skipForwardCommand.preferredIntervals = @[@(YouModForwardSecondsValue())];
    cc.previousTrackCommand.enabled = !back;
    cc.nextTrackCommand.enabled = !fwd;

    if (!gYouModRewindTarget) {
        gYouModRewindTarget = [cc.skipBackwardCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
            return YouModSeekByInterval(-YouModRewindSecondsValue()) ? MPRemoteCommandHandlerStatusSuccess : MPRemoteCommandHandlerStatusNoSuchContent;
        }];
    }
    if (!gYouModForwardTarget) {
        gYouModForwardTarget = [cc.skipForwardCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
            return YouModSeekByInterval(YouModForwardSecondsValue()) ? MPRemoteCommandHandlerStatusSuccess : MPRemoteCommandHandlerStatusNoSuchContent;
        }];
    }
}

static void YouModAddEndTime(YTPlayerViewController *self, YTSingleVideoController *video, YTSingleVideoTime *time) {
    if (!IS_ENABLED(ShowExtraTimeRemaining) && !IS_ENABLED(SBShowDuration)) return;

    YTMainAppVideoPlayerOverlayViewController *con = [self activeVideoPlayerOverlay];
    if (![con isKindOfClass:%c(YTMainAppVideoPlayerOverlayViewController)]) return;
    CGFloat rate = [con currentPlaybackRate] != 0 ? [con currentPlaybackRate] : 1.0;
    NSTimeInterval remainingSeconds = (lround(video.totalMediaTime) - lround(time.time)) / rate;

    NSString *remainingTimeText;
    NSString *SBTimeRemaining = nil;
    NSTimeInterval SBTotalTimeRemaining = 0.0;
    
    if (IS_ENABLED(SBShowDuration)) {
        if (self.sbSegments && self.sbSegments.count > 0 && IS_ENABLED(SBButtonKey)) {
            for (SBSegment *segment in self.sbSegments) {
                SBSegmentAction action = [segment configuredAction];
                if (action == SBSegmentActionDisable) continue;

                CGFloat timeValue = segment.endTime - segment.startTime;
                SBTotalTimeRemaining = SBTotalTimeRemaining + timeValue;
            }
            if (SBTotalTimeRemaining != 0.0) { 
                NSTimeInterval SBRemaining = video.totalMediaTime - SBTotalTimeRemaining;
                int hours = (int)(SBRemaining / 3600);
                int minutes = (int)(((int)SBRemaining % 3600) / 60);
                int seconds = (int)((int)SBRemaining % 60);
                if (hours > 0) {
                    SBTimeRemaining = [NSString stringWithFormat:@"%d:%02d:%02d", hours, minutes, seconds];
                } else {
                    SBTimeRemaining = [NSString stringWithFormat:@"%d:%02d", minutes, seconds];
                }
            }
        }
    }
    
    if (IS_ENABLED(ShowExtraTimeRemaining)) {
        NSDate *estimatedEndTime = [NSDate dateWithTimeIntervalSinceNow:remainingSeconds];
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
        [dateFormatter setDateFormat:IS_ENABLED(Uses24HoursTime) ? @"HH:mm" : @"h:mm a"];
        remainingTimeText = [dateFormatter stringFromDate:estimatedEndTime];
    }
    
    NSString *safeRemainingTimeText = remainingTimeText ?: @"";
    NSString *safeSBTimeRemaining = SBTimeRemaining ?: @"";

    YTPlayerView *playerView = (YTPlayerView *)self.playerView;
    if (![playerView.overlayView isKindOfClass:%c(YTMainAppVideoPlayerOverlayView)]) return;

    YTMainAppVideoPlayerOverlayView *overlay = (YTMainAppVideoPlayerOverlayView*)playerView.overlayView;
    YTLabel *durationLabel = overlay.playerBar.durationLabel;
    
    NSString *labelText = durationLabel.text ?: @"";

    NSString *baseText = labelText;
    NSRange extraTimeRange = [baseText rangeOfString:@" • "];
    if (extraTimeRange.location != NSNotFound) {
        baseText = [baseText substringToIndex:extraTimeRange.location];
    }
    NSRange sbRange = [baseText rangeOfString:@" ("];
    if (sbRange.location != NSNotFound) {
        baseText = [baseText substringToIndex:sbRange.location];
    }

    NSMutableString *newLabelText = [NSMutableString stringWithString:baseText];
    if (IS_ENABLED(SBShowDuration) && safeSBTimeRemaining.length > 0) {
        [newLabelText appendFormat:@" (%@)", safeSBTimeRemaining];
    }
    if (IS_ENABLED(ShowExtraTimeRemaining) && safeRemainingTimeText.length > 0) {
        [newLabelText appendFormat:@" • %@", safeRemainingTimeText];
    }

    if (![labelText isEqualToString:newLabelText]) {
        durationLabel.text = newLabelText;
        overlay.playerBar.endTimeString = newLabelText;
        [durationLabel sizeToFit];
    }
}

%hook YTInlinePlayerBarContainerView
%property (nonatomic, strong) NSString *endTimeString;
- (void)layoutSubviews {
    %orig;
    if (!IS_ENABLED(TapToSeek)) return;
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:%c(YTInlineScrubGestureView)]) {
            BOOL hasCustomTap = NO;
            for (UIGestureRecognizer *gesture in subview.gestureRecognizers) {
                if ([gesture isKindOfClass:[UITapGestureRecognizer class]] && 
                    [gesture.name isEqualToString:@"YouModTapToSeek"]) {
                    hasCustomTap = YES;
                    break;
                }
            }
            if (!hasCustomTap) {
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleYouModScrubTap:)];
                tap.name = @"YouModTapToSeek";
                [subview addGestureRecognizer:tap];
            }
            break;
        }
    }
}
%new
- (void)handleYouModScrubTap:(UITapGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateEnded) {
        UIView *progressBar = nil;

        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:%c(YTModularPlayerBarView)]) {
                progressBar = subview;
                break;
            }
        }
        if (!progressBar) return;
        
        CGPoint touchPoint = [gesture locationInView:progressBar];
        CGFloat barWidth = progressBar.bounds.size.width;
        
        if (barWidth > 0) {
            CGFloat relativeX = touchPoint.x;
            CGFloat percentage = relativeX / barWidth;
            CGFloat snapThreshold = 8.0;
            
            if (relativeX <= snapThreshold) {
                percentage = 0.0;
            } else if (relativeX >= barWidth - snapThreshold) {
                percentage = 1.0;
            } else {
                if (percentage < 0.0) percentage = 0.0;
                if (percentage > 1.0) percentage = 1.0;
            }
            
            UIResponder *responder = self.nextResponder;
            while (responder && ![responder isKindOfClass:%c(YTMainAppVideoPlayerOverlayViewController)]) {
                responder = responder.nextResponder;
            }
  
            if (responder) {
                YTMainAppVideoPlayerOverlayViewController *controller = (YTMainAppVideoPlayerOverlayViewController *)responder;
                YTPlayerViewController *controller2 = controller.parentViewController;
                CGFloat totalDuration = [controller2 currentVideoTotalMediaTime];
                CGFloat targetTime = totalDuration * percentage;    
                [controller2 seekToTime:targetTime];
            }
        }
    }
}
// Disable toggle time remaining - @bhackel
- (void)setShouldDisplayTimeRemaining:(BOOL)arg1 {
    BOOL temp;
    if (IS_ENABLED(DisablesShowRemaining)) {
        temp = NO;
    } else if (IS_ENABLED(AlwaysShowRemaining)) {
        temp = YES;
    } else {
        temp = arg1;
    }
    %orig(temp);
}
// Always show seekbar
- (void)setPlayerBarAlpha:(CGFloat)alpha { 
    CGFloat temp = IS_ENABLED(AlwaysShowSeekbar) ? 1.0 : alpha;
    %orig(temp);
}
// Disables snap to chapter
- (void)inlinePlayerBarView:(id)arg1 didScrubToChapteredTime:(CGFloat)arg2 shouldSnap:(BOOL)arg3 { 
    BOOL temp = IS_ENABLED(DontSnapToChapter) ? NO : arg3;
    %orig(arg1, arg2, temp);
}
- (void)setPeekableViewVisible:(BOOL)visible {
    %orig;
    if (!IS_ENABLED(ShowExtraTimeRemaining) && !IS_ENABLED(SBShowDuration)) return;

    YTLabel *dLabel = self.durationLabel;
    if (dLabel && self.endTimeString) {
        if (![dLabel.text isEqualToString:self.endTimeString]) {
            dLabel.text = self.endTimeString;
            [dLabel sizeToFit];
        }
    }
}
%end

%hook YTMainAppControlsOverlayView
// Hide autoplay Switch
- (void)setAutoplaySwitchButtonRenderer:(id)arg1 { if (!IS_ENABLED(HideAutoPlayToggle)) %orig; }
// Hide captions Button
- (void)setClosedCaptionsOrSubtitlesButtonAvailable:(BOOL)arg1 { if (!IS_ENABLED(HideCaptionsButton)) %orig; }
// Hide video title in full screen
- (BOOL)titleViewHidden { return IS_ENABLED(HideFullvidTitle) ? YES : %orig; }
// Pause On Overlay
- (void)setOverlayVisible:(BOOL)visible {
    %orig;
    if (!IS_ENABLED(PauseOnOverlay)) return;
    YTMainAppVideoPlayerOverlayViewController *mainOverlayController = (YTMainAppVideoPlayerOverlayViewController *)self.eventsDelegate;
    YTPlayerViewController *playerViewController = mainOverlayController.parentViewController;
    visible ? [playerViewController pause] : [playerViewController play];
}
%end

%hook YTAutonavEndscreenController
- (void)showEndscreen { if (!IS_ENABLED(HideSuggestedVideo)) %orig; }
- (void)showEndscreenControlsInPlayerBar:(BOOL)arg {
    BOOL temp = IS_ENABLED(HideSuggestedVideo) ? NO : arg;
    %orig(temp);
}
%end

// YTAnotherMiniplayer (https://github.com/PoomSmart/YTAnotherMiniplayer)
%hook YTWatchMiniplayerConstants
+ (NSInteger)miniplayerVariant { return IS_ENABLED(UseAnotherMiniplayer) ? 2 : %orig; }
%end

%hook YTSettings
- (BOOL)isAutoplayEnabled { return IS_ENABLED(HideAutoPlayToggle) ? NO : %orig; }
%end

%hook YTSettingsImpl
- (BOOL)isAutoplayEnabled { return IS_ENABLED(HideAutoPlayToggle) ? NO : %orig; }
%end

%hook YTColdConfig
- (BOOL)isLandscapeEngagementPanelEnabled { return IS_ENABLED(DisablesEngagementPanel) ? NO : %orig; }
- (BOOL)removeNextPaddleForAllVideos { return IS_ENABLED(HideNextAndPrevButtons) ? YES : %orig; }
- (BOOL)removePreviousPaddleForAllVideos { return IS_ENABLED(HideNextAndPrevButtons) ? YES : %orig; }
// Replace previous/next buttons with back and forward
- (BOOL)replaceNextPaddleWithFastForwardButtonForSingletonVods { return IS_ENABLED(ReplacePrevNextButtons) ? YES : %orig; }
- (BOOL)replacePreviousPaddleWithRewindButtonForSingletonVods { return IS_ENABLED(ReplacePrevNextButtons) ? YES : %orig; }
%end

// No Endscreen Cards
%hook YTCreatorEndscreenView
- (void)setHidden:(BOOL)arg1 { 
    BOOL temp = IS_ENABLED(HideEndScreenCards) ? YES : arg1;
    %orig(temp);
}
- (void)setHoverCardHidden:(BOOL)arg { 
    BOOL temp = IS_ENABLED(HideEndScreenCards) ? YES : arg;
    %orig(temp);
}
- (void)setHoverCardRenderer:(id)arg { if (!IS_ENABLED(HideEndScreenCards)) %orig; }
%end

%hook YTMainAppVideoPlayerOverlayViewController
// Disable Double Tap To Seek
- (BOOL)allowDoubleTapToSeekGestureRecognizer { return IS_ENABLED(DisablesDoubleTap) ? NO : %orig; }
// Disable long hold
- (BOOL)allowLongPressGestureRecognizerInView:(id)arg { 
    if (IS_ENABLED(DisablesLongHold) || INTFORVAL(HoldToSpeedIndex) != 0) return NO;
    return %orig;
}
// Copy timestamp on pause
- (void)didPressPause:(id)arg {
    %orig;
    if (!IS_ENABLED(CopyWithTimestampOnPause)) return;
    CGFloat mediaTimeIn = self.mediaTime;
    NSString *vidID = self.videoID;
    if (vidID.length) {
        UIPasteboard.generalPasteboard.string = [NSString stringWithFormat:@"https://www.youtube.com/watch?v=%@&t=%lds", vidID, (long)mediaTimeIn];
    }
}
- (BOOL)isZoomEnabled { 
    if (IS_ENABLED(DisablesFreeZoom)) {
        YTMainAppVideoPlayerOverlayView *mainov = [self videoPlayerOverlayView];
        YTVideoFreeZoomOverlayView *vidfreeov = [mainov videoFreeZoomOverlayView];
        vidfreeov.hidden = YES; // See if this is enough to hide the indicator
        return NO;
    }
    return %orig; 
}
- (void)setPaidContentWithPlayerData:(id)data { if (!IS_ENABLED(HidePaidPromoOverlay)) %orig; }
%end

// YTNoPaidPromo (https://github.com/PoomSmart/YTNoPaidPromo)
%hook YTInlineMutedPlaybackPlayerOverlayViewController
- (void)setPaidContentWithPlayerData:(id)data { if (!IS_ENABLED(HidePaidPromoOverlay)) %orig; }
%end

// Remove Watermarks
%hook YTAnnotationsViewController
- (void)loadFeaturedChannelWatermark { if (!IS_ENABLED(HideWaterMark)) %orig; }
- (void)setWatermarkImage:(id)arg1 height:(NSUInteger)arg2 { if (!IS_ENABLED(HideWaterMark)) %orig; }
%end

// Exit Fullscreen on Finish
%hook YTWatchFlowController
- (BOOL)shouldExitFullScreenOnFinish { return IS_ENABLED(AutoExitFullScreen) ? YES : %orig; }
%end

// Always use remaining time in the video player - @bhackel
%hook YTPlayerBarController
// When a new video is played, enable time remaining flag
- (void)setActiveSingleVideo:(id)arg1 {
    %orig;
    if (IS_ENABLED(AlwaysShowRemaining) && !IS_ENABLED(DisablesShowRemaining)) {
        // Get the player bar view
        YTInlinePlayerBarContainerView *playerBar = self.playerBar;
        if (playerBar) {
            // Enable the time remaining flag
            playerBar.shouldDisplayTimeRemaining = YES;
        }
    }
    YTSingleVideoController *sgvid = [self valueForKey:@"_currentSingleVideo"];
    YTPlayerView *playerview = [sgvid valueForKey:@"_playerView"];
    YTPlayerViewController *playerviewController = [playerview valueForKey:@"_playerViewDelegate"];
    YouModDownloadSetCurrentPlayer(playerviewController);
    YouModConfigureRemoteSkipCommands();
    if (INTFORVAL(AutoDRCAudioIndex) != 0) [playerviewController YouModAutoDRCAudio];
    if (INTFORVAL(AudioTrack) != 0) [playerviewController performSelector:@selector(YouModAutoAudioTrack) withObject:nil afterDelay:0.1];
    if (IS_ENABLED(MuteButton)) [playerviewController YouModAutoMute];
    if (IS_ENABLED(AutoFullScreen)) [playerviewController performSelector:@selector(YouModAutoFullscreen) withObject:nil afterDelay:0.4];
    if (INTFORVAL(CaptionTrack) != 0) [playerviewController YouModAutoCaptions];
    if (INTFORVAL(AutoSpeedIndex) != 0) [playerviewController YouModSetAutoSpeed];
}
%end

// Disable Fullscreen Actions
%hook YTFullscreenActionsView
- (CGSize)sizeThatFits:(CGSize)size { return IS_ENABLED(HideFullAction) ? CGSizeMake(1, 35) : %orig; }
%end

// Disable Ambiant mode (Hide the lights)
%hook YTWatchView
- (void)setCinematicContainerView:(id)arg { if (!IS_ENABLED(RemoveAmbiant)) %orig; }
%end

// Disable Autoplay 
%hook YTPlaybackConfig
- (void)setStartPlayback:(BOOL)arg1 { 
    BOOL temp = IS_ENABLED(StopAutoplayVideo) ? NO : arg1;
    %orig(temp); 
}
%end

// Skip Content Warning (https://github.com/qnblackcat/uYouPlus/blob/main/uYouPlus.xm#L452-L454)
%hook YTPlayabilityResolutionUserActionUIController
- (void)showConfirmAlert { IS_ENABLED(HideContentWarning) ? [self confirmAlertDidPressConfirm] : %orig; }
%end

%hook YTPlayabilityResolutionUserActionUIControllerImpl
- (void)showConfirmAlert { IS_ENABLED(HideContentWarning) ? [self confirmAlertDidPressConfirm] : %orig; }
%end

// Portrait Fullscreen
%hook YTWatchViewController
- (NSUInteger)allowedFullScreenOrientations { return IS_ENABLED(PortFull) ? UIInterfaceOrientationMaskAllButUpsideDown : %orig; }
%end

%group ForceMiniPlayer
%hook YTIMiniplayerRenderer
%new
- (BOOL)hasMinimizedEndpoint { return NO; }
%new
- (BOOL)hasPlaybackMode { return NO; }
%end
%end

// Extra speed - adapted from YouSpeed
%group Speed

#define itemCount 13

%hook YTMenuController

- (NSMutableArray <YTActionSheetAction *> *)actionsForRenderers:(NSMutableArray <YTIMenuItemSupportedRenderers *> *)renderers fromView:(UIView *)fromView entry:(id)entry shouldLogItems:(BOOL)shouldLogItems firstResponder:(id)firstResponder {
    NSUInteger index = [renderers indexOfObjectPassingTest:^BOOL(YTIMenuItemSupportedRenderers *renderer, NSUInteger idx, BOOL *stop) {
        YTIMenuItemSupportedRenderersElementRendererCompatibilityOptionsExtension *extension = (YTIMenuItemSupportedRenderersElementRendererCompatibilityOptionsExtension *)[renderer.elementRenderer.compatibilityOptions messageForFieldNumber:396644439];
        BOOL isVideoSpeed = [extension.menuItemIdentifier isEqualToString:@"menu_item_playback_speed"];
        if (isVideoSpeed) *stop = YES;
        return isVideoSpeed;
    }];
    NSMutableArray <YTActionSheetAction *> *actions = %orig;
    if (index != NSNotFound) {
        YTActionSheetAction *action = actions[index];
        action.handler = ^{
            [firstResponder didPressVarispeed:fromView];
        };
        UIView *elementView = [action.button valueForKey:@"_elementView"];
        elementView.userInteractionEnabled = NO;
    }
    return actions;
}

%end

%hook YTVarispeedSwitchController

- (id)init {
    self = %orig;
    float speeds[] = {0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 5.0, 7.5, 10.0};
    id options[itemCount];
    Class YTVarispeedSwitchControllerOptionClass = %c(YTVarispeedSwitchControllerOption);
    for (int i = 0; i < itemCount; ++i) {
        NSString *title = [NSString stringWithFormat:@"%.2fx", speeds[i]];
        options[i] = [[YTVarispeedSwitchControllerOptionClass alloc] initWithTitle:title rate:speeds[i]];
    }
    [self setValue:[NSArray arrayWithObjects:options count:itemCount] forKey:@"_options"];
    return self;
}

%end

%hook YTIPlayerHotConfig

%new(f@:)
- (float)maximumPlaybackRate {
    return 10.0;
}

%end

%hook YTIGranularVariableSpeedConfig

%new(d@:)
- (int)maximumPlaybackRate {
    return 10.0 * 100;
}

%end
%end

static NSArray *YouModHoldSpeedValues(void) {
    return @[@0.0, @0.25, @0.5, @0.75, @1.0, @1.25, @1.5, @1.75, @2.0, @3.0, @4.0, @5.0];
}

static CGFloat YouModSpeedForHoldIndex(NSInteger index) {
    NSArray *values = YouModHoldSpeedValues();
    return [values[index] floatValue];
}

%hook YTMainAppVideoPlayerOverlayView
- (void)setLongPressGestureRecognizer:(id)arg {
    if (INTFORVAL(HoldToSpeedIndex) != 0) return;
    %orig;
}
// Remove Dark Background in Overlay
- (void)setBackgroundVisible:(BOOL)arg1 isGradientBackground:(BOOL)arg2 {
    BOOL temp = IS_ENABLED(RemoveDarkOverlay) ? NO : arg1;
    %orig(temp, arg2);
}
// Hide Watermarks
- (BOOL)isWatermarkEnabled { return IS_ENABLED(HideWaterMark) ? NO : %orig; }
- (void)setWatermarkEnabled:(BOOL)arg { 
    BOOL temp = IS_ENABLED(HideWaterMark) ? NO : arg;
    %orig(temp);
}
- (void)layoutSubviews {
    %orig;
    if (IS_ENABLED(HideCastButtonPlayer)) self.playbackRouteButton.hidden = YES;
}
- (BOOL)isFullscreenActionsVisible { return IS_ENABLED(HideFullAction) ? NO : %orig; }
%end

%hook YTSingleVideoController

- (void)playerItem:(id)arg1 hasSelectableVideoFormats:(id)arg2 {
    %orig;
    if (!arg2) return;
    [self YouModAutoQuality];
}

%new
- (void)YouModAutoQuality {
    NSArray *videoFormats = self.selectableVideoFormats;
    // Return early if there aren't any video formats available
    // eg. Voice comments and others
    if (!videoFormats || videoFormats.count == 0) return;
    NSInteger kQualityIndex = isWiFiConnected() ? INTFORVAL(WifiQualityIndex) : INTFORVAL(CellQualityIndex);
    if ([NSProcessInfo processInfo].lowPowerModeEnabled) kQualityIndex = INTFORVAL(LowPowerQualityIndex);
    if (kQualityIndex == 0) return;

    NSString *bestQualityLabel;
    int highestResolution = 0;
    for (MLFormat *format in videoFormats) {
        int reso = format.singleDimensionResolution;
        if (reso > highestResolution) {
            highestResolution = reso;
            bestQualityLabel = format.qualityLabel;
        }
    }

    NSArray *qualityLabels = @[@"Default", bestQualityLabel, @"2160p", @"1440p", @"1080p", @"720p", @"480p", @"360p", @"240p", @"144p"];
    NSString *qualityLabel = qualityLabels[kQualityIndex];

    if (![qualityLabel isEqualToString:bestQualityLabel]) {
        BOOL exactMatch = NO;
        NSString *closestQualityLabel = qualityLabel;

        for (MLFormat *format in videoFormats) {
            if ([format.qualityLabel isEqualToString:qualityLabel]) {
                exactMatch = YES;
                break;
            }
        }

        if (!exactMatch) {
            NSInteger bestQualityDifference = NSIntegerMax;

            for (MLFormat *format in videoFormats) {
                NSArray *formatСomponents = [format.qualityLabel componentsSeparatedByString:@"p"];
                NSArray *targetComponents = [qualityLabel componentsSeparatedByString:@"p"];
                if (formatСomponents.count == 2) {
                    NSInteger formatQuality = [formatСomponents.firstObject integerValue];
                    NSInteger targetQuality = [targetComponents.firstObject integerValue];
                    NSInteger difference = labs(formatQuality - targetQuality);
                    if (difference < bestQualityDifference) {
                        bestQualityDifference = difference;
                        closestQualityLabel = format.qualityLabel;
                    }
                }
            }

            qualityLabel = closestQualityLabel;
        }
    }

    MLQuickMenuVideoQualitySettingFormatConstraint *fc = [%c(MLQuickMenuVideoQualitySettingFormatConstraint) alloc];
    if ([fc respondsToSelector:@selector(initWithVideoQualitySetting:formatSelectionReason:qualityLabel:resolutionCap:)]) {
        [self setVideoFormatConstraint:[fc initWithVideoQualitySetting:3 formatSelectionReason:2 qualityLabel:qualityLabel resolutionCap:0]];
    } else {
        [self setVideoFormatConstraint:[fc initWithVideoQualitySetting:3 formatSelectionReason:2 qualityLabel:qualityLabel]];
    }
}
%end

// YTClassicVideoQuality (https://github.com/PoomSmart/YTClassicVideoQuality)
%group OldVideoQuality
%hook YTIMediaQualitySettingsHotConfig
%new(B@:)
- (BOOL)enableQuickMenuVideoQualitySettings { return NO; }
%end

%hook YTVideoQualitySwitchOriginalController
%property (retain, nonatomic) YTVideoQualitySwitchRedesignedController *redesignedController;
- (void)setUserSelectableFormats:(NSArray <MLFormat *> *)formats {
    if (self.redesignedController == nil)
        self.redesignedController = [[%c(YTVideoQualitySwitchRedesignedController) alloc] initWithServiceRegistryScope:nil parentResponder:nil];
    [self.redesignedController setValue:[self valueForKey:@"_video"] forKey:@"_video"];
    NSArray <MLFormat *> *newFormats = [self.redesignedController respondsToSelector:@selector(addRestrictedFormats:)] ? [self.redesignedController addRestrictedFormats:formats] : formats;
    %orig(newFormats);
}
- (void)dealloc {
    self.redesignedController = nil;
    %orig;
}
%end

%hook YTMenuController
- (NSMutableArray <YTActionSheetAction *> *)actionsForRenderers:(NSMutableArray <YTIMenuItemSupportedRenderers *> *)renderers fromView:(UIView *)fromView entry:(id)entry shouldLogItems:(BOOL)shouldLogItems firstResponder:(id)firstResponder {
    NSUInteger index = [renderers indexOfObjectPassingTest:^BOOL(YTIMenuItemSupportedRenderers *renderer, NSUInteger idx, BOOL *stop) {
        YTIMenuItemSupportedRenderersElementRendererCompatibilityOptionsExtension *extension = (YTIMenuItemSupportedRenderersElementRendererCompatibilityOptionsExtension *)[renderer.elementRenderer.compatibilityOptions messageForFieldNumber:396644439];
        BOOL isVideoQuality = [extension.menuItemIdentifier isEqualToString:@"menu_item_video_quality"];
        if (isVideoQuality) *stop = YES;
        return isVideoQuality;
    }];
    NSMutableArray <YTActionSheetAction *> *actions = %orig;
    if (index != NSNotFound) {
        YTActionSheetAction *action = actions[index];
        action.handler = ^{
            [firstResponder didPressVideoQuality:fromView];
        };
        UIView *elementView = [action.button valueForKey:@"_elementView"];
        elementView.userInteractionEnabled = NO;
    }
    return actions;
}
%end
%end

// Gestures - @bhackel (YTLitePlus)
%hook YTWatchLayerViewController
// invoked when the player view controller is either created or destroyed
- (void)watchController:(YTWatchController *)watchController didSetPlayerViewController:(YTPlayerViewController *)playerViewController {
    if (playerViewController) {
        YTPlayerView *pv = playerViewController.playerView;
        if (!playerViewController.YouModPanGesture && (IS_ENABLED(GestureControls) || IS_ENABLED(SeekOnOverlay))) {
            playerViewController.YouModPanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:playerViewController action:@selector(YouModHandlePanGesture:)];
            playerViewController.YouModPanGesture.delegate = playerViewController;
            [pv addGestureRecognizer:playerViewController.YouModPanGesture];
        }
        if (!playerViewController.YouModTapGesture && IS_ENABLED(PauseTwoFingers)) {
            playerViewController.YouModTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:playerViewController action:@selector(YouModHandleTapGesture:)];
            playerViewController.YouModTapGesture.numberOfTouchesRequired = 2;
            playerViewController.YouModTapGesture.delegate = playerViewController;
            [pv addGestureRecognizer:playerViewController.YouModTapGesture];
        }
        if (!playerViewController.YouModHoldGesture && INTFORVAL(HoldToSpeedIndex) != 0) {
            playerViewController.YouModHoldGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:playerViewController action:@selector(YouModHoldToSpeed:)];
            playerViewController.YouModHoldGesture.minimumPressDuration = 0.4;
            playerViewController.YouModHoldGesture.cancelsTouchesInView = YES;
            playerViewController.YouModHoldGesture.delegate = playerViewController;
            [pv addGestureRecognizer:playerViewController.YouModHoldGesture];   
        }
    }
    %orig;
}
%end

static YTMainAppVideoPlayerOverlayView *getMainVideoOverlay(YTPlayerViewController *pvc) {
    YTMainAppVideoPlayerOverlayViewController *ovcon = [pvc activeVideoPlayerOverlay];
    return [ovcon videoPlayerOverlayView];
}

static BOOL isRelatedVideosPanelEnabled(YTPlayerViewController *pvc) {
    YTMainAppVideoPlayerOverlayView *ov = getMainVideoOverlay(pvc);
    YTFullscreenEngagementOverlayView *fullov = [ov valueForKey:@"_fullscreenEngagementOverlayView"];
    if (fullov) {
        YTRelatedVideosView *relatedview = [fullov valueForKey:@"_relatedVideosView"];
        YTRelatedVideosViewController *relatedcon = [relatedview valueForKey:@"_delegate"];
        return [relatedcon isExpanded];
    }    
    return NO;
}

static CGFloat remainingOverlayWidth(YTPlayerViewController *pvc, CGFloat fullWidth) {
    YTMainAppVideoPlayerOverlayView *ov = getMainVideoOverlay(pvc);
    YTEngagementPanelContainerView *engagecontainer = [ov valueForKey:@"_engagementPanelContainerView"];
    if (engagecontainer) {
        if (engagecontainer.engagementPanelState == 3) {
            UIView *mainpanel = nil;
            for (UIView *sub in engagecontainer.subviews) {
                if ([sub isKindOfClass:%c(UILayoutContainerView)]) {
                    mainpanel = sub;
                    break;
                }
            }
            if (mainpanel) {
                CGFloat panelWidth = mainpanel.bounds.size.width;
                if (panelWidth > 0 && panelWidth < fullWidth) {
                    CGFloat remainingWidth = fullWidth - panelWidth;
                    return remainingWidth;
                }
            }
        }
    }
    return fullWidth;
}

%hook YTPlayerViewController
%property (nonatomic, retain) UIPanGestureRecognizer *YouModPanGesture;
%property (nonatomic, retain) UITapGestureRecognizer *YouModTapGesture;
%property (nonatomic, retain) UILabel *YouModGestureHUD;
%property (nonatomic, strong) UIView *YouModSpeedToastView;
%property (nonatomic, strong) UILabel *YouModSpeedToastLabel;
%property (nonatomic, retain) UILongPressGestureRecognizer *YouModHoldGesture;
%new
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.YouModPanGesture) {
        if (self.YouModHoldGesture && (self.YouModHoldGesture.state == UIGestureRecognizerStateBegan || self.YouModHoldGesture.state == UIGestureRecognizerStateChanged)) {
            return NO;
        }

        if (isRelatedVideosPanelEnabled(self)) return NO;          

        UIPanGestureRecognizer *panGesture = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint startLocation = [panGesture locationInView:self.view];
        CGPoint velocity = [panGesture velocityInView:self.view];
        CGFloat activeWidth = remainingOverlayWidth(self, self.view.bounds.size.width);
        
        if (startLocation.x > activeWidth) return NO;

        BOOL isHorizontal = fabs(velocity.x) > fabs(velocity.y);

        if (isHorizontal) {
            YTMainAppVideoPlayerOverlayView *ov = getMainVideoOverlay(self);
            YTVideoFreeZoomOverlayView *vidfreeov = ov.videoFreeZoomOverlayView;
            YTVideoFreeZoomOverlayController *vidfreecon = [vidfreeov valueForKey:@"_delegate"];
            return IS_ENABLED(SeekOnOverlay) && vidfreecon.state != 4;
        } else {
            if (!IS_ENABLED(GestureControls)) return NO;

            float areaPercent = 0.15;
            int areaSetting = INTFORVAL(GestureActivationArea);
            if (areaSetting == 0) areaPercent = 0.10;
            else if (areaSetting == 2) areaPercent = 0.20;
            else if (areaSetting == 3) areaPercent = 0.25;
            else if (areaSetting == 4) areaPercent = 0.30;
            else if (areaSetting == 5) areaPercent = 0.35;
            else if (areaSetting == 6) areaPercent = 0.40;
            else if (areaSetting == 7) areaPercent = 0.45;
            else if (areaSetting == 8) areaPercent = 0.50;

            int leftAction = [[NSUserDefaults standardUserDefaults] objectForKey:LeftSideGesture] ? INTFORVAL(LeftSideGesture) : 1;
            int rightAction = [[NSUserDefaults standardUserDefaults] objectForKey:RightSideGesture] ? INTFORVAL(RightSideGesture) : 2;

            if (startLocation.x > activeWidth * areaPercent && startLocation.x < activeWidth * (1.0 - areaPercent)) return NO;
            if (startLocation.x <= activeWidth * areaPercent && leftAction == 0) return NO;
            if (startLocation.x >= activeWidth * (1.0 - areaPercent) && rightAction == 0) return NO;

            return YES;
        }
    }
    if (gestureRecognizer == self.YouModHoldGesture) {
        if (self.YouModPanGesture && (self.YouModPanGesture.state == UIGestureRecognizerStateBegan || self.YouModPanGesture.state == UIGestureRecognizerStateChanged)) {
            return NO;
        }
        if (isRelatedVideosPanelEnabled(self)) return NO;
        CGPoint touchLocation = [gestureRecognizer locationInView:self.view];
        CGFloat activeWidth = remainingOverlayWidth(self, self.view.bounds.size.width);
        if (touchLocation.x > activeWidth) return NO;
    }
    return YES;
}

%new
- (void)YouModHandlePanGesture:(UIPanGestureRecognizer *)panGestureRecognizer {
    // 0 = None, 1 = Vertical (Bright/Vol/Speed), 2 = Horizontal (Scrub)
    static int currentPanMode = 0; 
    
    static float initialVolume;
    static float initialBrightness;
    static float initialSpeed;
    static int controlType = 0;
    static CGFloat deadzoneStartingTranslation;
    static CGFloat sensitivityFactor = 1.0;

    static MPVolumeView *volumeView;
    static UISlider *volumeViewSlider;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        volumeView = [[MPVolumeView alloc] initWithFrame:CGRectZero];
        for (UIView *view in volumeView.subviews) {
            if ([view isKindOfClass:[UISlider class]]) {
                volumeViewSlider = (UISlider *)view;
                break;
            }
        }
    });

    YTMainAppVideoPlayerOverlayViewController *ovcon = [self activeVideoPlayerOverlay];

    if (IS_ENABLED(GestureHUD)) {
        if (!self.YouModGestureHUD) {
            self.YouModGestureHUD = [[UILabel alloc] initWithFrame:CGRectZero];
            self.YouModGestureHUD.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
            self.YouModGestureHUD.textColor = [UIColor colorWithWhite:1.0 alpha:0.75];
            self.YouModGestureHUD.tintColor = [UIColor colorWithWhite:1.0 alpha:0.75];
            self.YouModGestureHUD.textAlignment = NSTextAlignmentCenter;
            self.YouModGestureHUD.layer.masksToBounds = YES;
            self.YouModGestureHUD.alpha = 0.0;
            [self.view addSubview:self.YouModGestureHUD];
        }
    }

    if (panGestureRecognizer.state == UIGestureRecognizerStateBegan) {
        CGPoint velocity = [panGestureRecognizer velocityInView:self.view];
        BOOL isHorizontal = fabs(velocity.x) > fabs(velocity.y);

        if (isHorizontal && IS_ENABLED(SeekOnOverlay)) {
            currentPanMode = 2;
        } else if (!isHorizontal && IS_ENABLED(GestureControls)) {
            currentPanMode = 1;
        }

        if (currentPanMode == 2) {
            YTMainAppVideoPlayerOverlayView *ovview = [ovcon videoPlayerOverlayView];
            YTInlinePlayerBarContainerView *wth = ovview.playerBar;
            YTPlayerBarController *playerbarcon = [wth valueForKey:@"_delegate"];
            [playerbarcon didScrub:panGestureRecognizer];
        } else if (currentPanMode == 1) {
            CGPoint startLocation = [panGestureRecognizer locationInView:self.view];
            CGFloat activeWidth = remainingOverlayWidth(self, self.view.bounds.size.width);

            float areaPercent = 0.15;
            int areaSetting = INTFORVAL(GestureActivationArea);
            if (areaSetting == 0) areaPercent = 0.10;
            else if (areaSetting == 2) areaPercent = 0.20;
            else if (areaSetting == 3) areaPercent = 0.25;
            else if (areaSetting == 4) areaPercent = 0.30;
            else if (areaSetting == 5) areaPercent = 0.35;
            else if (areaSetting == 6) areaPercent = 0.40;
            else if (areaSetting == 7) areaPercent = 0.45;
            else if (areaSetting == 8) areaPercent = 0.50;

            int leftAction = [[NSUserDefaults standardUserDefaults] objectForKey:LeftSideGesture] ? INTFORVAL(LeftSideGesture) : 1;
            int rightAction = [[NSUserDefaults standardUserDefaults] objectForKey:RightSideGesture] ? INTFORVAL(RightSideGesture) : 2;

            if (startLocation.x <= activeWidth * areaPercent) {
                controlType = leftAction; 
            } else if (startLocation.x >= activeWidth * (1.0 - areaPercent)) {
                controlType = rightAction;
            } else {
                controlType = 0;
            }
            
            deadzoneStartingTranslation = [panGestureRecognizer translationInView:self.view].y;
            
            if (controlType == 1) initialBrightness = [UIScreen mainScreen].brightness;
            else if (controlType == 2) initialVolume = [[AVAudioSession sharedInstance] outputVolume];
            else if (controlType == 3) initialSpeed = [ovcon currentPlaybackRate];

            if (IS_ENABLED(GestureHUD) && controlType != 0) {
                int sizeSetting = [[NSUserDefaults standardUserDefaults] objectForKey:GestureHUDSize] ? (int)[[NSUserDefaults standardUserDefaults] integerForKey:GestureHUDSize] : 1;
                CGFloat fontSize = 14.0 + (sizeSetting * 2.0);
                CGFloat hudWidth = 74.0 + (sizeSetting * 10.0);
                CGFloat hudHeight = 30.0 + (sizeSetting * 4.0);
                
                self.YouModGestureHUD.frame = CGRectMake(0, 0, hudWidth, hudHeight);
                self.YouModGestureHUD.layer.cornerRadius = hudHeight / 2.0;
                self.YouModGestureHUD.font = [UIFont boldSystemFontOfSize:fontSize];

                int posSetting = [[NSUserDefaults standardUserDefaults] objectForKey:GestureHUDPosition] ? (int)[[NSUserDefaults standardUserDefaults] integerForKey:GestureHUDPosition] : 0;
                CGFloat viewHeight = self.view.bounds.size.height;
                CGFloat centerY = viewHeight / 6.0;
                if (posSetting == 1) centerY = viewHeight / 2.0;
                else if (posSetting == 2) centerY = viewHeight * 5.0 / 6.0;

                [self.view bringSubviewToFront:self.YouModGestureHUD];
                self.YouModGestureHUD.center = CGPointMake(activeWidth / 2, centerY);
            }
        }
    }

    if (panGestureRecognizer.state == UIGestureRecognizerStateChanged) {
        if (currentPanMode == 2) {
            YTMainAppVideoPlayerOverlayView *ovview = [ovcon videoPlayerOverlayView];
            YTInlinePlayerBarContainerView *wth = ovview.playerBar;
            YTPlayerBarController *playerbarcon = [wth valueForKey:@"_delegate"];
            [playerbarcon didScrub:panGestureRecognizer];
        } else if (currentPanMode == 1 && controlType != 0) {
            CGPoint translation = [panGestureRecognizer translationInView:self.view];
            CGFloat adjustedTranslation = translation.y - deadzoneStartingTranslation;
            float delta = (-adjustedTranslation / self.view.bounds.size.height) * sensitivityFactor;
            
            NSString *symbolName = nil;
            NSString *percentString = nil;

            if (controlType == 1) {
                float newBrightness = fmaxf(fminf(initialBrightness + delta, 1.0), 0.0);
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[UIScreen mainScreen] setBrightness:newBrightness];
                });
                
                if (newBrightness <= 0.5f) {
                    symbolName = @"sun.min.fill";
                } else {
                    symbolName = @"sun.max.fill";
                }
                
                percentString = [NSString stringWithFormat:@" %d%%", (int)(newBrightness * 100)];
            } else if (controlType == 2) {
                float newVolume = fmaxf(fminf(initialVolume + delta, 1.0), 0.0);
                dispatch_async(dispatch_get_main_queue(), ^{
                    volumeViewSlider.value = newVolume;
                });
                
                if (newVolume == 0.0f) {
                    symbolName = @"speaker.slash.fill";
                } else if (newVolume <= 0.25f) {
                    symbolName = @"speaker.fill";
                } else if (newVolume <= 0.50f) {
                    symbolName = @"speaker.wave.1.fill";
                } else if (newVolume <= 0.75f) {
                    symbolName = @"speaker.wave.2.fill";
                } else {
                    symbolName = @"speaker.wave.3.fill";
                }
                
                percentString = [NSString stringWithFormat:@" %d%%", (int)(newVolume * 100)];
            } else if (controlType == 3) {
                float speedSensitivity = 8.0; 
                float speedDelta = (-adjustedTranslation / self.view.bounds.size.height) * speedSensitivity;
                float rawSpeed = initialSpeed + speedDelta;
                float clampedSpeed = fmaxf(fminf(rawSpeed, 10.0), 0.25);
                float steppedSpeed = roundf(clampedSpeed * 4.0) / 4.0;

                static float lastUpdatedSpeed = 0;
                if (steppedSpeed != lastUpdatedSpeed) {
                    [self setPlaybackRate:steppedSpeed];
                    lastUpdatedSpeed = steppedSpeed;
                }
                
                if (steppedSpeed < 1.0f) {
                    symbolName = @"tortoise.fill";
                } else if (steppedSpeed == 1.0f) {
                    symbolName = @"speedometer";
                } else if (steppedSpeed <= 5.0f) {
                    symbolName = @"hare.fill";
                } else {
                    symbolName = @"bolt.fill";
                }
                
                percentString = [NSString stringWithFormat:@" %.2fx", steppedSpeed];
            }

            if (IS_ENABLED(GestureHUD) && symbolName) {
                NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
                UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:self.YouModGestureHUD.font.pointSize - 1];
                UIImage *icon = [UIImage systemImageNamed:symbolName withConfiguration:config];
                attachment.image = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                CGFloat iconY = (self.YouModGestureHUD.font.capHeight - attachment.image.size.height) / 2.0;
                attachment.bounds = CGRectMake(0, iconY, attachment.image.size.width, attachment.image.size.height);
                NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
                NSAttributedString *textString = [[NSAttributedString alloc] initWithString:percentString attributes:@{NSFontAttributeName: self.YouModGestureHUD.font, NSForegroundColorAttributeName: self.YouModGestureHUD.textColor}];
                [attributedString appendAttributedString:textString];
                self.YouModGestureHUD.attributedText = attributedString;
                self.YouModGestureHUD.alpha = 1.0;
            }
        }
    } 
    
    if (panGestureRecognizer.state == UIGestureRecognizerStateEnded || panGestureRecognizer.state == UIGestureRecognizerStateCancelled || panGestureRecognizer.state == UIGestureRecognizerStateFailed) {
        if (currentPanMode == 2) {
            YTMainAppVideoPlayerOverlayView *ovview = [ovcon videoPlayerOverlayView];
            YTInlinePlayerBarContainerView *wth = ovview.playerBar;
            YTPlayerBarController *playerbarcon = [wth valueForKey:@"_delegate"];
            [playerbarcon didScrub:panGestureRecognizer];
        } else if (currentPanMode == 1) {
            if (IS_ENABLED(GestureHUD)) {
                [UIView animateWithDuration:0.3 delay:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
                    self.YouModGestureHUD.alpha = 0.0;
                } completion:nil];
            }
        }
        currentPanMode = 0;
        controlType = 0;
    }
}

%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == self.YouModPanGesture && [otherGestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        return YES;
    }
    if (gestureRecognizer == self.YouModHoldGesture && ![otherGestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        return YES;
    }
    return NO;
}

%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == self.YouModPanGesture) {
        return NO; 
    }
    if (gestureRecognizer == self.YouModHoldGesture || otherGestureRecognizer == self.YouModHoldGesture) {
        if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]] || [otherGestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
            return NO;
        }
        return YES;
    }
    return YES;
}

// Pause using Two fingers
%new
- (void)YouModHandleTapGesture:(UITapGestureRecognizer *)tapGestureRecognizer {
    if (isRelatedVideosPanelEnabled(self)) return;  

    CGPoint startLocation = [tapGestureRecognizer locationInView:self.view];
    CGFloat remainingWidth = remainingOverlayWidth(self, self.view.bounds.size.width);
    if (startLocation.x > remainingWidth) return;

    if (tapGestureRecognizer.state == UIGestureRecognizerStateEnded) {
        if (self.playerState == 3) {
            [self pause];
        } else if (self.playerState == 4) {
            [self play];
        }
    }
}

%new
- (void)YouModAutoFullscreen {
    YTWatchController *watchController = [self valueForKey:@"_UIDelegate"];
    [watchController showFullScreen];
}

%new
- (void)YouModSetAutoSpeed {
    if (self.YouModHoldGesture && (self.YouModHoldGesture.state == UIGestureRecognizerStateBegan || self.YouModHoldGesture.state == UIGestureRecognizerStateChanged)) {
        return;
    }
    if (IS_ENABLED(GlobalSpeedLocked)) {
        NSInteger speedIndex = INTFORVAL(HoldToSpeedIndex);
        CGFloat speed = YouModSpeedForHoldIndex(speedIndex);
        [self setPlaybackRate:speed];
        return;
    }
    if (INTFORVAL(AutoSpeedIndex) == 0) return;
    NSArray *speedLabels = @[@0.01, @0.25, @0.5, @0.75, @1.0, @1.25, @1.5, @1.75, @2.0, @3.0, @4.0, @5.0];
    [self setPlaybackRate:[speedLabels[INTFORVAL(AutoSpeedIndex)] floatValue]];
}

- (void)singleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    YouModAddEndTime(self, video, time);
}

- (void)potentiallyMutatedSingleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    YouModAddEndTime(self, video, time);
}

%new
- (void)YouModAutoMute {
    YTSingleVideoController *sgvid = self.activeVideo;
    BOOL muted = [sgvid isMuted];
    [sgvid setMuted:[self isInlinePlaybackActive] ? muted : IS_ENABLED(KeepMutedKey)];
}

%new
- (void)YouModAutoAudioTrack {
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
        [self setAudioTrack:matchedTrack source:0];
    }
}

%new
- (void)YouModAutoCaptions {
    YTSingleVideoController *sgvid = self.activeVideo;
    NSArray *allTracks = sgvid.availableCaptionTracks;
    if (!allTracks || allTracks.count == 0) return;
    NSInteger selectedIndex = INTFORVAL(CaptionTrackLangIndex);
    NSArray *langCodes = getAllSystemLanguageValues();
    NSString *userTargetLang = langCodes[selectedIndex];
    MLInnerTubeCaptionTrack *currentTrack = sgvid.activeCaptionTrack;
    MLInnerTubeCaptionTrack *matchedTrack;

    if (INTFORVAL(CaptionTrack) == 1) {
        if (currentTrack != nil) {
            [self YouModCaptionsHelper:nil];
        }
        return;
    }

    for (MLInnerTubeCaptionTrack *track in allTracks) {
        if ([track.languageCode isEqualToString:userTargetLang]) {
            matchedTrack = track;
            break;
        }
    }
    if (matchedTrack && ([matchedTrack.VSSID hasPrefix:@"a."] || [matchedTrack.VSSID hasPrefix:@"ta."]) && IS_ENABLED(DisablesCaptionTrack)) {
        matchedTrack = nil;
        [self YouModCaptionsHelper:nil];
        return;
    } else if (!matchedTrack && IS_ENABLED(DisablesCaptionTrack)) {
        [self YouModCaptionsHelper:nil];
        return;
    }
    if (matchedTrack && matchedTrack != currentTrack) {
        [self YouModCaptionsHelper:matchedTrack];
    }
}

%new
- (void)YouModCaptionsHelper:(MLInnerTubeCaptionTrack *)track {
    if ([self respondsToSelector:@selector(setActiveCaptionTrack:source:)]) {
        [self setActiveCaptionTrack:track source:0];
    } else {
        [self setActiveCaptionTrack:track];
    }
}
%new
- (void)YouModHideSpeedToast {
    [UIView animateWithDuration:0.2 animations:^{
        self.YouModSpeedToastView.alpha = 0.0;
    }];
}
%new
- (void)YouModShowSpeedToast:(CGFloat)speed isLocked:(BOOL)isLocked {
    UIColor *themeTextColor = [UIColor labelColor];
    UIColor *toastBgColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) ? 
            [UIColor colorWithWhite:0.1 alpha:0.95] : [UIColor colorWithWhite:0.95 alpha:0.95];
    }];

    if (!self.YouModSpeedToastView) {
        self.YouModSpeedToastView = [[UIView alloc] init];
        self.YouModSpeedToastView.clipsToBounds = YES;
        self.YouModSpeedToastView.alpha = 0.0;

        self.YouModSpeedToastLabel = [[UILabel alloc] init];
        self.YouModSpeedToastLabel.textAlignment = NSTextAlignmentCenter;
        self.YouModSpeedToastLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        self.YouModSpeedToastLabel.numberOfLines = 2;
        [self.YouModSpeedToastView addSubview:self.YouModSpeedToastLabel];
        
        [self.playerView addSubview:self.YouModSpeedToastView];
    }
    
    self.YouModSpeedToastView.backgroundColor = toastBgColor;
    self.YouModSpeedToastLabel.textColor = themeTextColor;

    NSTextAttachment *topAttachment = [[NSTextAttachment alloc] init];
    topAttachment.image = [[UIImage systemImageNamed:@"hare.fill"] imageWithTintColor:themeTextColor];
    topAttachment.bounds = CGRectMake(0, -2, 14, 14);
    
    NSTextAttachment *lockAttachment = nil;
    if (IS_ENABLED(LockSpeed)) {
        lockAttachment = [[NSTextAttachment alloc] init];
        NSString *lockIconName = isLocked ? @"lock.fill" : @"lock.open.fill";
        lockAttachment.image = [[UIImage systemImageNamed:lockIconName] imageWithTintColor:themeTextColor];
        lockAttachment.bounds = CGRectMake(0, -1, 12, 12);
    }
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = NSTextAlignmentCenter;
    paragraphStyle.lineSpacing = 3.0;

    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@\n", LOC(@"PLAYBACK_SPEED")]];
    
    if (topAttachment.image) {
        NSAttributedString *topIconString = [NSAttributedString attributedStringWithAttachment:topAttachment];
        [attrString insertAttributedString:topIconString atIndex:0];
    }
    
    if (lockAttachment && lockAttachment.image) {
        NSAttributedString *lockIconString = [NSAttributedString attributedStringWithAttachment:lockAttachment];
        [attrString appendAttributedString:lockIconString];
        [attrString appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
    }
    
    NSAttributedString *speedText = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%gx", speed]];
    [attrString appendAttributedString:speedText];
    [attrString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, attrString.length)];
    
    self.YouModSpeedToastLabel.attributedText = attrString;

    CGFloat activeWidth = remainingOverlayWidth(self, self.playerView.bounds.size.width);
    CGFloat maxAvailableWidth = activeWidth * 0.8;
    CGSize maxLabelSize = CGSizeMake(maxAvailableWidth, CGFLOAT_MAX);
    
    CGRect boundingBox = [attrString boundingRectWithSize:maxLabelSize 
                                                  options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading) 
                                                  context:nil];
    CGSize textSize = CGSizeMake(ceilf(boundingBox.size.width), ceilf(boundingBox.size.height));
    
    CGFloat paddingY = 16.0;
    CGFloat toastHeight = textSize.height + paddingY;
    
    // Dynamic horizontal padding based on capsule corner geometry (radius = toastHeight / 2.0)
    // Ensures text in any language sits comfortably inside the flat region of the pill container
    CGFloat paddingX = toastHeight + 24.0;
    CGFloat calculatedWidth = textSize.width + paddingX;
    CGFloat toastWidth = fminf(fmaxf(calculatedWidth, toastHeight * 2.2), maxAvailableWidth + 24.0);
    
    self.YouModSpeedToastView.frame = CGRectMake(0, 0, toastWidth, toastHeight);
    self.YouModSpeedToastView.layer.cornerRadius = toastHeight / 2.0;
    self.YouModSpeedToastLabel.frame = self.YouModSpeedToastView.bounds;

    self.YouModSpeedToastView.center = CGPointMake(activeWidth / 2.0, 36.0);
    self.YouModSpeedToastView.layer.zPosition = 999;
    [self.playerView bringSubviewToFront:self.YouModSpeedToastView];

    [UIView animateWithDuration:0.2 animations:^{
        self.YouModSpeedToastView.alpha = 1.0;
    }];
}

%new
- (void)YouModHoldToSpeed:(UILongPressGestureRecognizer *)gesture {
    if (isRelatedVideosPanelEnabled(self)) return;

    CGPoint touchLocation = [gesture locationInView:self.view];
    CGFloat activeWidth = remainingOverlayWidth(self, self.view.bounds.size.width);
    if (touchLocation.x > activeWidth) return;

    NSInteger speedIndex = INTFORVAL(HoldToSpeedIndex);
    CGFloat speed = YouModSpeedForHoldIndex(speedIndex);
    
    static CGPoint startLocation;
    static BOOL initialLockState;
    static BOOL isPendingToggle;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (gesture.state == UIGestureRecognizerStateBegan) {
        if (self.playerState != 3) return;
        YTMainAppVideoPlayerOverlayViewController *con = [self activeVideoPlayerOverlay];
        CGFloat currentRate = [con currentPlaybackRate];
        CGFloat savedNormal = FLOAT_FOR_KEY(GlobalSavedNormalRate);
        
        if (savedNormal <= 0) {
            savedNormal = (currentRate > 0) ? currentRate : 1.0;
            [defaults setFloat:savedNormal forKey:GlobalSavedNormalRate];
            [defaults setBool:NO forKey:GlobalSpeedLocked];
        }

        initialLockState = IS_ENABLED(GlobalSpeedLocked);
        isPendingToggle = NO;
        startLocation = [gesture locationInView:self.playerView];
        
        if (!initialLockState) {
            if (currentRate != speed) {
                savedNormal = (currentRate > 0) ? currentRate : 1.0;
                [defaults setFloat:savedNormal forKey:GlobalSavedNormalRate];
            }
            [self setPlaybackRate:speed];
            [self YouModShowSpeedToast:speed isLocked:NO];
        } else {
            [self setPlaybackRate:speed];
            [self YouModShowSpeedToast:speed isLocked:YES];
        }
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        if (!IS_ENABLED(LockSpeed)) return;
        
        CGPoint currentLocation = [gesture locationInView:self.playerView];
        CGFloat dragDistanceY = currentLocation.y - startLocation.y;
        
        BOOL stateChanged = NO;
        
        if (!isPendingToggle && dragDistanceY > 40.0) {
            isPendingToggle = YES;
            stateChanged = YES;
        } else if (isPendingToggle && dragDistanceY < 20.0) {
            isPendingToggle = NO;
            stateChanged = YES;
        }
        
        if (stateChanged) {
            UIImpactFeedbackStyle feedbackStyle = isPendingToggle ? UIImpactFeedbackStyleMedium : UIImpactFeedbackStyleLight;
            UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:feedbackStyle];
            [feedback impactOccurred];

            BOOL previewLockState = initialLockState ? !isPendingToggle : isPendingToggle;
            
            if (previewLockState) {
                [self YouModShowSpeedToast:speed isLocked:YES];
            } else {
                CGFloat toastSpeed;
                if (initialLockState) {
                    CGFloat savedNormal = [defaults floatForKey:GlobalSavedNormalRate];
                    toastSpeed = (savedNormal >= 0.25) ? savedNormal : 1.0;
                } else {
                    toastSpeed = speed;
                }
                [self YouModShowSpeedToast:toastSpeed isLocked:NO];
            }
        }
    } else if (gesture.state == UIGestureRecognizerStateEnded || 
               gesture.state == UIGestureRecognizerStateCancelled || 
               gesture.state == UIGestureRecognizerStateFailed) {

        BOOL finalLockState = initialLockState;
        if (gesture.state == UIGestureRecognizerStateEnded || (gesture.state == UIGestureRecognizerStateCancelled && isPendingToggle)) {
            if (IS_ENABLED(LockSpeed) && isPendingToggle) {
                finalLockState = !initialLockState;
                [defaults setBool:finalLockState forKey:GlobalSpeedLocked];
            }
        }
        if (finalLockState) {
            [self setPlaybackRate:speed];
        } else {
            CGFloat savedNormal = [defaults floatForKey:GlobalSavedNormalRate];
            CGFloat targetRate = (savedNormal >= 0.25) ? savedNormal : 1.0;
            [self setPlaybackRate:targetRate];
        }
        isPendingToggle = NO;
        [self YouModHideSpeedToast];
    }
}
%new
- (void)YouModAutoDRCAudio {
    BOOL value = NO;
    if (INTFORVAL(AutoDRCAudioIndex) == 1) {
        value = YES;
    }
    [self setAudioDRCEnabled:value];
}
%end

%ctor {
    %init;
    YouModConfigureRemoteSkipCommands();
    if (IS_ENABLED(OldQualityPicker)) {
        %init(OldVideoQuality);
    }
    if (IS_ENABLED(ExtraSpeed) || IS_ENABLED(GestureControls) || INTFORVAL(HoldToSpeedIndex) >= 9 || INTFORVAL(AutoSpeedIndex) >= 9) {
        %init(Speed);
    }
    if (IS_ENABLED(ForceMiniPlayer)) {
        %init(ForceMiniPlayer);
    }
}

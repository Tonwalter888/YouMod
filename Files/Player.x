#import "Headers.h"

BOOL isWiFiConnected(void) {
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

// static NSString *shortsVidID;

// static BOOL isShortsTab;

// Audio track list
static NSArray *getAllSystemLanguageTitles() {
    NSMutableArray *titles = [NSMutableArray array];
    NSArray *allLocales = [NSLocale availableLocaleIdentifiers];
    NSMutableSet *seenLanguages = [NSMutableSet set];
    NSLocale *currentLocale = [NSLocale currentLocale];
    
    for (NSString *localeId in allLocales) {
        NSDictionary *components = [NSLocale componentsFromLocaleIdentifier:localeId];
        NSString *langCode = components[NSLocaleLanguageCode];
        
        if (langCode && ![seenLanguages containsObject:langCode]) {
            [seenLanguages addObject:langCode];
            NSString *displayName = [currentLocale localizedStringForLocaleIdentifier:langCode];
            if (displayName) [titles addObject:displayName];
        }
    }
    return [titles sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

static NSArray *getAllSystemLanguageValues() {
    NSArray *sortedTitles = getAllSystemLanguageTitles();
    NSMutableArray *sortedCodes = [NSMutableArray array];
    NSArray *allLocales = [NSLocale availableLocaleIdentifiers];
    NSLocale *currentLocale = [NSLocale currentLocale];
    
    NSMutableDictionary *titleToCodeMap = [NSMutableDictionary dictionary];
    for (NSString *localeId in allLocales) {
        NSDictionary *components = [NSLocale componentsFromLocaleIdentifier:localeId];
        NSString *langCode = components[NSLocaleLanguageCode];
        if (langCode) {
            NSString *displayName = [currentLocale localizedStringForLocaleIdentifier:langCode];
            if (displayName) titleToCodeMap[displayName] = langCode;
        }
    }
    
    for (NSString *title in sortedTitles) {
        [sortedCodes addObject:titleToCodeMap[title] ? titleToCodeMap[title] : @"en"];
    }
    return [sortedCodes copy];
}

static float playbackRate = 1.0;

// static BOOL isExternal = NO;

static void YouModAddEndTime(YTPlayerViewController *self, YTSingleVideoController *video, YTSingleVideoTime *time) {
    if (!IS_ENABLED(ShowExtraTimeRemaining)) return;

    CGFloat rate = playbackRate != 0 ? playbackRate : 1.0;
    NSTimeInterval remainingSeconds = (lround(video.totalMediaTime) - lround(time.time)) / rate;

    NSString *remainingTimeText;
    if (IS_ENABLED(Uses24HoursTime)) {
        NSDate *estimatedEndTime = [NSDate dateWithTimeIntervalSinceNow:remainingSeconds];

        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
        [dateFormatter setDateFormat:@"HH:mm"];

        remainingTimeText = [dateFormatter stringFromDate:estimatedEndTime];
    } else {
        int hours = (int)(remainingSeconds / 3600);
        int minutes = (int)(((int)remainingSeconds % 3600) / 60);
        int seconds = (int)((int)remainingSeconds % 60);
        if (hours > 0) {
            remainingTimeText = [NSString stringWithFormat:@"%d:%02d:%02d", hours, minutes, seconds];
        } else {
            remainingTimeText = [NSString stringWithFormat:@"%d:%02d", minutes, seconds];
        }
    }
    YTPlayerView *playerView = (YTPlayerView *)self.playerView;
    if (![playerView.overlayView isKindOfClass:%c(YTMainAppVideoPlayerOverlayView)]) return;

    YTMainAppVideoPlayerOverlayView *overlay = (YTMainAppVideoPlayerOverlayView*)playerView.overlayView;
    YTLabel *durationLabel = overlay.playerBar.durationLabel;

    if (![durationLabel.text containsString:remainingTimeText]) {
        durationLabel.text = [durationLabel.text stringByAppendingString:[NSString stringWithFormat:@" • %@", remainingTimeText]];
        [durationLabel sizeToFit];
    }
}

%hook YTInlinePlayerBarContainerView
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
        UIView *gestureView = gesture.view;
        UIView *progressBar;

        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:%c(YTModularPlayerBarView)]) {
                progressBar = subview;
                break;
            }
        }
        if (!progressBar) return;
        
        UIWindow *keyWindow = nil;
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        keyWindow = window;
                        break;
                    }
                }
            }
            if (keyWindow) break;
        }

        CGPoint touchPointInWindow = [gesture locationInView:keyWindow];
        CGFloat barStartX = 0.0;
        CGFloat barWidth = gestureView.bounds.size.width;
        
        if (progressBar) {
            CGRect barFrameInWindow = [progressBar convertRect:progressBar.bounds toView:keyWindow];
            barStartX = barFrameInWindow.origin.x;
            barWidth = barFrameInWindow.size.width;
        }
        
        if (barWidth > 0) {
            CGFloat relativeX = touchPointInWindow.x - barStartX;
            CGFloat percentage = relativeX / barWidth;
            
            if (percentage < 0.0) percentage = 0.0;
            if (percentage > 1.0) percentage = 1.0;
            
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
- (void)showEndscreenControlsInPlayerBar:(BOOL)arg { IS_ENABLED(HideSuggestedVideo) ? %orig(NO) : %orig; }
%end

%hook YTSettings
- (BOOL)isAutoplayEnabled { return IS_ENABLED(HideAutoPlayToggle) ? NO : %orig; }
%end

%hook YTSettingsImpl
- (BOOL)isAutoplayEnabled { return IS_ENABLED(HideAutoPlayToggle) ? NO : %orig; }
%end

%hook YTColdConfig
- (BOOL)isLandscapeEngagementPanelEnabled { return IS_ENABLED(DisablesEngagementPanel) ? NO : %orig; }
%end

// Remove Dark Background in Overlay
%hook YTMainAppVideoPlayerOverlayView
- (void)setBackgroundVisible:(BOOL)arg1 isGradientBackground:(BOOL)arg2 { IS_ENABLED(RemoveDarkOverlay) ? %orig(NO, arg2) : %orig; }
// Hide Watermarks
- (BOOL)isWatermarkEnabled { return IS_ENABLED(HideWaterMark) ? NO : %orig; }
- (void)setWatermarkEnabled:(BOOL)arg { IS_ENABLED(HideWaterMark) ? %orig(NO) : %orig; }
- (void)layoutSubviews {
    %orig;
    if (IS_ENABLED(HideCastButtonPlayer)) self.playbackRouteButton.hidden = YES;    
}
- (BOOL)isFullscreenActionsVisible { return IS_ENABLED(HideFullAction) ? NO : %orig; }
%end

// No Endscreen Cards
%hook YTCreatorEndscreenView
- (void)setHidden:(BOOL)arg1 { IS_ENABLED(HideEndScreenCards) ? %orig(YES) : %orig; }
- (void)setHoverCardHidden:(BOOL)arg { IS_ENABLED(HideEndScreenCards) ? %orig(YES) : %orig; }
- (void)setHoverCardRenderer:(id)arg { if (!IS_ENABLED(HideEndScreenCards)) %orig; }
%end

%hook YTMainAppVideoPlayerOverlayViewController
// Disable Double Tap To Seek
- (BOOL)allowDoubleTapToSeekGestureRecognizer { return IS_ENABLED(DisablesDoubleTap) ? NO : %orig; }
// Disable long hold
- (BOOL)allowLongPressGestureRecognizerInView:(id)arg { return IS_ENABLED(DisablesLongHold) ? NO : %orig; }
// Copy timestamp on pause
- (void)didPressPause:(id)arg {
    %orig;
    if (!IS_ENABLED(CopyWithTimestampOnPause)) return;
    CGFloat mediaTimeIn = self.mediaTime;
    NSString *vidID = self.videoID;
    if (vidID.length)
        UIPasteboard.generalPasteboard.string = [NSString stringWithFormat:@"https://www.youtube.com/watch?v=%@&t=%lds", vidID, (long)mediaTimeIn];
}
- (BOOL)isZoomEnabled { return IS_ENABLED(DisablesFreeZoom) ? NO : %orig; }
%end

%hook YTColdConfig
- (BOOL)removeNextPaddleForAllVideos { return IS_ENABLED(HideNextAndPrevButtons) ? YES : %orig; }
- (BOOL)removePreviousPaddleForAllVideos { return IS_ENABLED(HideNextAndPrevButtons) ? YES : %orig; }
%end

// YTNoPaidPromo (https://github.com/PoomSmart/YTNoPaidPromo)
%hook YTMainAppVideoPlayerOverlayViewController
- (void)setPaidContentWithPlayerData:(id)data { if (!IS_ENABLED(HidePaidPromoOverlay)) %orig; }
%end

%hook YTInlineMutedPlaybackPlayerOverlayViewController
- (void)setPaidContentWithPlayerData:(id)data { if (!IS_ENABLED(HidePaidPromoOverlay)) %orig; }
%end

// Remove Watermarks
%hook YTAnnotationsViewController
- (void)loadFeaturedChannelWatermark { if (!IS_ENABLED(HideWaterMark)) %orig; }
- (void)setWatermarkImage:(id)arg1 height:(unsigned long long)arg2 { if (!IS_ENABLED(HideWaterMark)) %orig; }
%end

// Exit Fullscreen on Finish
%hook YTWatchFlowController
- (BOOL)shouldExitFullScreenOnFinish { return IS_ENABLED(AutoExitFullScreen) ? YES : %orig; }
%end

// Disable toggle time remaining - @bhackel
%hook YTInlinePlayerBarContainerView
- (void)setShouldDisplayTimeRemaining:(BOOL)arg1 { 
    if (IS_ENABLED(DisablesShowRemaining)) {
        %orig(NO);
        return;
    }
    IS_ENABLED(AlwaysShowRemaining) ? %orig(YES) : %orig;
}
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
    if (IS_ENABLED(MuteButton)) [playerviewController YouModAutoMute];
    if (IS_ENABLED(AutoFullScreen)) [playerviewController performSelector:@selector(YouModAutoFullscreen) withObject:nil afterDelay:0.5];
    if (IS_ENABLED(DisablesCaptions)) [playerviewController performSelector:@selector(YouModTurnOffCaptions) withObject:nil afterDelay:0.5];
    if (INTFORVAL(AutoSpeedIndex) != 0) [playerviewController performSelector:@selector(YouModSetAutoSpeed) withObject:nil afterDelay:0.5];
    if (INTFORVAL(AudioTrack) != 0) [playerviewController performSelector:@selector(YouModAutoAudioTrack) withObject:nil afterDelay:0.5];
}
%end

// Disable Fullscreen Actions
%hook YTFullscreenActionsView
- (CGSize)sizeThatFits:(CGSize)size { return IS_ENABLED(HideFullAction) ? CGSizeMake(1, 35) : %orig; }
%end

// Disable Ambiant mode (Hide the lights)
%hook YTCinematicContainerView
- (void)layoutSubviews { if (!IS_ENABLED(RemoveAmbiant)) %orig; }
- (void)loadWithModel:(id)arg { if (!IS_ENABLED(RemoveAmbiant)) %orig; }
- (id)initWithFrame:(CGRect)arg { return IS_ENABLED(RemoveAmbiant) ? nil : %orig; }
%end

// Disable Autoplay 
%hook YTPlaybackConfig
- (void)setStartPlayback:(BOOL)arg1 { IS_ENABLED(StopAutoplayVideo) ? %orig(NO) : %orig; }
%end

// Skip Content Warning (https://github.com/qnblackcat/uYouPlus/blob/main/uYouPlus.xm#L452-L454)
%hook YTPlayabilityResolutionUserActionUIController
- (void)showConfirmAlert { IS_ENABLED(HideContentWarning) ? [self confirmAlertDidPressConfirm] : %orig; }
%end

%hook YTPlayabilityResolutionUserActionUIControllerImpl
- (void)showConfirmAlert { IS_ENABLED(HideContentWarning) ? [self confirmAlertDidPressConfirm] : %orig; }
%end

// Always show seekbar
%hook YTInlinePlayerBarContainerView
- (void)setPlayerBarAlpha:(CGFloat)alpha { IS_ENABLED(AlwaysShowSeekbar) ? %orig(1.0) : %orig; }
%end

// Portrait Fullscreen
%hook YTWatchViewController
- (unsigned long long)allowedFullScreenOrientations { return IS_ENABLED(PortFull) ? UIInterfaceOrientationMaskAllButUpsideDown : %orig; }
%end

// Disable Snap To Chapter (https://github.com/qnblackcat/uYouPlus/blob/main/uYouPlus.xm#L457-464) - GOT REMOVED
%hook YTSegmentableInlinePlayerBarView
- (void)didMoveToWindow { 
    %orig; 
    if (IS_ENABLED(DontSnapToChapter)) self.enableSnapToChapter = NO;
}
%end

%hook YTInlinePlayerBarContainerView
- (void)inlinePlayerBarView:(id)arg1 didScrubToChapteredTime:(CGFloat)arg2 shouldSnap:(BOOL)arg3 { 
    IS_ENABLED(DontSnapToChapter) ? %orig(arg1, arg2, NO) : %orig;
}
%end

// Replace previous/next buttons with back and forward
%hook YTColdConfig
- (BOOL)replaceNextPaddleWithFastForwardButtonForSingletonVods { return IS_ENABLED(ReplacePrevNextButtons) ? YES : %orig; }
- (BOOL)replacePreviousPaddleWithRewindButtonForSingletonVods { return IS_ENABLED(ReplacePrevNextButtons) ? YES : %orig; }
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

%hook YTVarispeedSwitchControllerImpl

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

static CGFloat YouModRateBeforeHoldToSpeed = 1.0;

static NSArray *YouModHoldSpeedValues(void) {
    return @[@0.0, @0.25, @0.5, @0.75, @1.0, @1.25, @1.5, @1.75, @2.0, @3.0, @4.0, @5.0];
}

static CGFloat YouModSpeedForHoldIndex(NSInteger index) {
    NSArray *values = YouModHoldSpeedValues();
    return [values[index] floatValue];
}

static void YouModManageHoldToSpeed(UILongPressGestureRecognizer *gesture, YTMainAppVideoPlayerOverlayViewController *delegate) {
    NSInteger speedIndex = INTFORVAL(HoldToSpeedIndex);
    CGFloat speed = YouModSpeedForHoldIndex(speedIndex);

    if (gesture.state == UIGestureRecognizerStateBegan) {
        YouModRateBeforeHoldToSpeed = [delegate currentPlaybackRate];
        [delegate setPlaybackRate:speed];
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled || gesture.state == UIGestureRecognizerStateFailed) {
        [delegate setPlaybackRate:YouModRateBeforeHoldToSpeed];
    }
}

%hook YTMainAppVideoPlayerOverlayView
- (void)setLongPressGestureRecognizer:(id)arg1 {
    if (INTFORVAL(HoldToSpeedIndex) != 0) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(YouModHoldToSpeed:)];
        longPress.minimumPressDuration = 0.4;
        [self addGestureRecognizer:longPress];
    } else {
        %orig;
    }
}
%new
- (void)YouModHoldToSpeed:(UILongPressGestureRecognizer *)gesture {
    YouModManageHoldToSpeed(gesture, self.delegate);
}
%end

/*

%hook YTReelPlayerViewController

- (void)loadPlayerBar {
    %orig;
    if (!IS_ENABLED(ShortsToRegular)) return;
    YTPlayerViewController *playerviewController = self.player;
    if (shortsVidID != playerviewController.currentVideoID && !isShortsTab) {
        [playerviewController performSelector:@selector(YouModShortsToRegular)];
    }
    shortsVidID = playerviewController.currentVideoID;
}

%end

// Check if it's Shorts tab
%hook YTInlinePlayerBarContainerView
- (void)setLayout:(int)arg {
    %orig;
    if (![self.superview isKindOfClass:NSClassFromString(@"YTPivotBarView")]) return;
    YTPivotBarView *pivotView = (YTPivotBarView *)self.superview;
    YTPivotBarViewController *pivotController = [pivotView valueForKey:@"_delegate"];
    NSString *pivotIdentifier = [pivotController valueForKey:@"_pivotIdentifier"];
    if ([pivotIdentifier isEqualToString:@"FEshorts"]) {
        isShortsTab = YES;
    } else {
        isShortsTab = NO;
    }
}
%end

*/

%hook YTSingleVideoController

- (void)playerItem:(id)arg1 hasSelectableVideoFormats:(id)arg2 {
    %orig;
    if (!arg2) return;
    [self YouModAutoQuality];
}

%new
- (void)YouModAutoQuality {
    NSInteger kQualityIndex = isWiFiConnected() ? INTFORVAL(WifiQualityIndex) : INTFORVAL(CellQualityIndex);
    if ([NSProcessInfo processInfo].lowPowerModeEnabled) kQualityIndex = INTFORVAL(LowPowerQualityIndex);
    if (kQualityIndex == 0) return;

    NSString *bestQualityLabel;
    int highestResolution = 0;
    for (MLFormat *format in self.selectableVideoFormats) {
        int reso = format.singleDimensionResolution;
        if (reso > highestResolution) {
            highestResolution = reso;
            bestQualityLabel = format.qualityLabel;
        }
    }

    NSArray *qualityLabels = @[@"Default", bestQualityLabel, @"2160p60", @"2160p", @"1440p60", @"1440p", @"1080p60", @"1080p", @"720p60", @"720p", @"480p", @"360p", @"240p", @"144p"];
    NSString *qualityLabel = qualityLabels[kQualityIndex];

    if (![qualityLabel isEqualToString:bestQualityLabel]) {
        BOOL exactMatch = NO;
        NSString *closestQualityLabel = qualityLabel;

        for (MLFormat *format in self.selectableVideoFormats) {
            if ([format.qualityLabel isEqualToString:qualityLabel]) {
                exactMatch = YES;
                break;
            }
        }

        if (!exactMatch) {
            NSInteger bestQualityDifference = NSIntegerMax;

            for (MLFormat *format in self.selectableVideoFormats) {
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

%hook YTPlayerViewController

%new
- (void)YouModTurnOffCaptions {
    if ([self.view.superview isKindOfClass:NSClassFromString(@"YTWatchView")]) {
        @try {
            [self setActiveCaptionTrack:nil source:0];
        } @catch (id ex) {
            [self setActiveCaptionTrack:nil];
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
    if ([self.view.superview isKindOfClass:NSClassFromString(@"YTWatchView")]) {
        NSArray *speedLabels = @[@0.01, @0.25, @0.5, @0.75, @1.0, @1.25, @1.5, @1.75, @2.0, @3.0, @4.0, @5.0];
        [self setPlaybackRate:[speedLabels[INTFORVAL(AutoSpeedIndex)] floatValue]];
    }
}

- (void)singleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    YouModAddEndTime(self, video, time);
}

- (void)potentiallyMutatedSingleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    YouModAddEndTime(self, video, time);
}

- (void)setPlaybackRate:(float)rate {
    playbackRate = rate;
    %orig;
}

%new
- (void)YouModShortsToRegular {
    if (self.contentVideoID != nil && ([self.parentViewController isKindOfClass:NSClassFromString(@"YTReelPlayerViewController")] || [self.parentViewController isKindOfClass:NSClassFromString(@"YTShortsPlayerViewController")])) {
        NSString *vidLink = [NSString stringWithFormat:@"vnd.youtube://%@", self.contentVideoID];
        if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:vidLink]]) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:vidLink] options:@{} completionHandler:nil];
        }
    }
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
    YTAudioTrackSwitchController *switchcon = self.audioTrackController;
    NSArray *availableTracks = [switchcon valueForKey:@"_availableAudioTracks"];
    if (!availableTracks || availableTracks.count == 0) return;
    // Check if the current audio track is already the same as the user perferences
    // YTIAudioTrack *currentTrack = [switchcon valueForKey:@"_lastSelectedAudioTrack"]; Doesn't work for some reasons
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
        if (matchedTrack && [matchedTrack isAutoDubbed] && IS_ENABLED(NoDubbedAudioTrack)) {
            matchedTrack = nil;
            return;
        }
    }

    // If found, change to it
    if (matchedTrack) {
        [switchcon notifyObserversAudioTrackWillChange:matchedTrack source:0];
        [switchcon switchToAudioTrack:matchedTrack source:0];
        [switchcon notifyObserversAudioTrackDidChange:matchedTrack source:0];
    }
}
%end

/*
// Fix Playlist Mini-bar Height For Small Screens
%hook YTPlaylistMiniBarView
- (void)setFrame:(CGRect)frame {
    if (frame.size.height < 54.0) frame.size.height = 54.0; // what
    %orig(frame);
}
%end
*/

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
        // check to see if the pan gesture is already created
        if (!playerViewController.YouModPanGesture && IS_ENABLED(GestureControls)) {
            playerViewController.YouModPanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:playerViewController action:@selector(YouModHandlePanGesture:)];
            playerViewController.YouModPanGesture.delegate = playerViewController;
            [playerViewController.playerView addGestureRecognizer:playerViewController.YouModPanGesture];
        }
        if (!playerViewController.YouModTapGesture && IS_ENABLED(PauseTwoFingers)) {
            playerViewController.YouModTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:playerViewController action:@selector(YouModHandleTapGesture:)];
            playerViewController.YouModTapGesture.numberOfTouchesRequired = 2;
            playerViewController.YouModTapGesture.delegate = playerViewController;
            [playerViewController.playerView addGestureRecognizer:playerViewController.YouModTapGesture];
        }        
    }
    %orig;
}
%end

%hook YTPlayerViewController
%property (nonatomic, retain) UIPanGestureRecognizer *YouModPanGesture;
%property (nonatomic, retain) UITapGestureRecognizer *YouModTapGesture;
%property (nonatomic, retain) UILabel *YouModGestureHUD;
%new
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.YouModPanGesture) {
        UIPanGestureRecognizer *panGesture = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint startLocation = [panGesture locationInView:self.view];
        CGFloat viewWidth = self.view.bounds.size.width;

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

        // Ignore touches in the center area -> YouTube's default features (swipe down to dismiss, etc.) work normally
        if (startLocation.x > viewWidth * areaPercent && startLocation.x < viewWidth * (1.0 - areaPercent)) return NO;

        // Ignore touches in the area where 'None' is selected in settings
        if (startLocation.x <= viewWidth * areaPercent && leftAction == 0) return NO;
        if (startLocation.x >= viewWidth * (1.0 - areaPercent) && rightAction == 0) return NO;

        // Only works for vertical swipes -> Does not interfere with YouTube's horizontal seek bar
        CGPoint velocity = [panGesture velocityInView:self.view];
        if (fabs(velocity.x) > fabs(velocity.y)) return NO;

        return YES;
    }
    return YES;
}
%new
- (void)YouModHandlePanGesture:(UIPanGestureRecognizer *)panGestureRecognizer {
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
        CGPoint startLocation = [panGestureRecognizer locationInView:self.view];
        CGFloat viewWidth = self.view.bounds.size.width;

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

        if (startLocation.x <= viewWidth * areaPercent) {
            controlType = leftAction; 
        } else if (startLocation.x >= viewWidth * (1.0 - areaPercent)) {
            controlType = rightAction;
        } else {
            controlType = 0; // Center area
        }
        
        deadzoneStartingTranslation = [panGestureRecognizer translationInView:self.view].y;
        
        if (controlType == 1) {
            initialBrightness = [UIScreen mainScreen].brightness;
        } else if (controlType == 2) {
            initialVolume = [[AVAudioSession sharedInstance] outputVolume];
        } else if (controlType == 3) {
            initialSpeed = playbackRate;
        }

        if (IS_ENABLED(GestureHUD)) {
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
            self.YouModGestureHUD.center = CGPointMake(viewWidth / 2, centerY);
        }
    }

    if (panGestureRecognizer.state == UIGestureRecognizerStateChanged) {
        if (controlType == 0) return;
        
        CGPoint translation = [panGestureRecognizer translationInView:self.view];
        CGFloat adjustedTranslation = translation.y - deadzoneStartingTranslation;
        
        // Vertical swipe: Value increases as it goes up (translation.y decreases)
        float delta = (-adjustedTranslation / self.view.bounds.size.height) * sensitivityFactor;
        
        NSString *symbolName = nil;
        NSString *percentString = nil;

        if (controlType == 1) {
            float newBrightness = fmaxf(fminf(initialBrightness + delta, 1.0), 0.0);
            [[UIScreen mainScreen] setBrightness:newBrightness];
            symbolName = @"sun.max.fill";
            percentString = [NSString stringWithFormat:@" %d%%", (int)(newBrightness * 100)];
        } else if (controlType == 2) {
            float newVolume = fmaxf(fminf(initialVolume + delta, 1.0), 0.0);
            volumeViewSlider.value = newVolume;
            symbolName = @"speaker.wave.2.fill";
            percentString = [NSString stringWithFormat:@" %d%%", (int)(newVolume * 100)];
        } else if (controlType == 3) {
            float speedSensitivity = 8.0; 
            float speedDelta = (-adjustedTranslation / self.view.bounds.size.height) * speedSensitivity;
            float rawSpeed = initialSpeed + speedDelta;
            float clampedSpeed = fmaxf(fminf(rawSpeed, 10.0), 0.25);
            // Quantize to 0.25x increments (e.g., 1.12 -> 1.0, 1.38 -> 1.25)
            float steppedSpeed = roundf(clampedSpeed * 4.0) / 4.0;

            // Only update if the stepped value has actually changed
            static float lastUpdatedSpeed = 0;
            if (steppedSpeed != lastUpdatedSpeed) {
                [self setPlaybackRate:steppedSpeed];
                lastUpdatedSpeed = steppedSpeed;
            }
            symbolName = @"speedometer";
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
        }
        if (IS_ENABLED(GestureHUD)) self.YouModGestureHUD.alpha = 1.0;
    } else if (panGestureRecognizer.state == UIGestureRecognizerStateEnded || panGestureRecognizer.state == UIGestureRecognizerStateCancelled || panGestureRecognizer.state == UIGestureRecognizerStateFailed) {
        if (IS_ENABLED(GestureHUD)) {
            [UIView animateWithDuration:0.3 delay:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.YouModGestureHUD.alpha = 0.0;
            } completion:nil];
        }
    }
}
%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    // Require other gestures (like YouTube's related videos swipe) to fail when our gesture is active to prevent conflicts.
    if (gestureRecognizer == self.YouModPanGesture && [otherGestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        return YES;
    }
    return NO;
}
%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == self.YouModPanGesture) {
        return NO; // Prevents simultaneous recognition with YouTube's default swipe when gestures overlap.
    }
    return YES;
}
// Pause using Two fingers
%new
- (void)YouModHandleTapGesture:(UITapGestureRecognizer *)tapGestureRecognizer {
    if (tapGestureRecognizer.state == UIGestureRecognizerStateEnded) {
        if (self.playerState == 3) {
            [self pause];
        } else if (self.playerState == 4) {
            [self play];
        }
    }
}
%end

%ctor {
    %init;
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

#import "Headers.h"

extern void YouModDownloadSetCurrentPlayer(YTPlayerViewController *player);

float playbackRate = 1.0;

static const NSTimeInterval YouModRemoteSkipInterval = 10.0;
static __weak YTPlayerViewController *YouModCurrentPlayerViewController;
static NSTimeInterval YouModCurrentPlaybackTime = 0;
static NSTimeInterval YouModCurrentDuration = 0;
static BOOL YouModHasPlaybackTime = NO;
static id YouModSkipBackwardCommandTarget;
static id YouModSkipForwardCommandTarget;
static NSMutableArray *YouModRemoteCommandTargetProxies;
typedef MPRemoteCommandHandlerStatus (^YouModRemoteCommandHandler)(MPRemoteCommandEvent *event);

static void YouModUpdateCurrentPlayer(YTPlayerViewController *player) {
    YouModCurrentPlayerViewController = player;
}

static void YouModUpdatePlaybackTime(YTPlayerViewController *player, YTSingleVideoController *video, YTSingleVideoTime *time) {
    YouModUpdateCurrentPlayer(player);
    YouModCurrentPlaybackTime = time.time;
    YouModCurrentDuration = video.totalMediaTime;
    YouModHasPlaybackTime = YES;
}

static BOOL YouModIsPreviousNextCommand(MPRemoteCommand *command) {
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    return command == commandCenter.previousTrackCommand || command == commandCenter.nextTrackCommand;
}

static BOOL YouModSeekByInterval(NSTimeInterval interval) {
    if (!IS_ENABLED(ReplacePrevNextButtons) || !YouModCurrentPlayerViewController || !YouModHasPlaybackTime) return NO;
    if (![YouModCurrentPlayerViewController respondsToSelector:@selector(seekToTime:)]) return NO;

    NSTimeInterval targetTime = YouModCurrentPlaybackTime + interval;
    if (YouModCurrentDuration > 0) targetTime = fmin(targetTime, YouModCurrentDuration);
    targetTime = fmax(targetTime, 0);

    [YouModCurrentPlayerViewController seekToTime:(CGFloat)targetTime];
    YouModCurrentPlaybackTime = targetTime;
    return YES;
}

static MPRemoteCommandHandlerStatus YouModStatusForSeek(BOOL handled) {
    return handled ? MPRemoteCommandHandlerStatusSuccess : MPRemoteCommandHandlerStatusNoActionableNowPlayingItem;
}

static BOOL YouModHandlePreviousNextRemoteCommand(MPRemoteCommandEvent *event) {
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    if (event.command == commandCenter.previousTrackCommand) return YouModSeekByInterval(-YouModRemoteSkipInterval);
    if (event.command == commandCenter.nextTrackCommand) return YouModSeekByInterval(YouModRemoteSkipInterval);
    return NO;
}

static BOOL YouModIsPreviousNextRemoteCommandEvent(MPRemoteCommandEvent *event) {
    return YouModIsPreviousNextCommand(event.command);
}

@interface YouModRemoteCommandTargetProxy : NSObject
@property (nonatomic, weak) MPRemoteCommand *command;
@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL action;
- (MPRemoteCommandHandlerStatus)youModHandleRemoteCommandEvent:(MPRemoteCommandEvent *)event;
@end

@implementation YouModRemoteCommandTargetProxy
- (MPRemoteCommandHandlerStatus)youModHandleRemoteCommandEvent:(MPRemoteCommandEvent *)event {
    if (IS_ENABLED(ReplacePrevNextButtons) && YouModIsPreviousNextRemoteCommandEvent(event)) {
        return YouModStatusForSeek(YouModHandlePreviousNextRemoteCommand(event));
    }

    if (!self.target || !self.action) return MPRemoteCommandHandlerStatusCommandFailed;

    NSMethodSignature *signature = [self.target methodSignatureForSelector:self.action];
    if (!signature) return MPRemoteCommandHandlerStatusCommandFailed;

    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.target = self.target;
    invocation.selector = self.action;
    if (signature.numberOfArguments > 2) [invocation setArgument:&event atIndex:2];
    [invocation invoke];

    if (signature.methodReturnLength == 0) return MPRemoteCommandHandlerStatusSuccess;

    MPRemoteCommandHandlerStatus status = MPRemoteCommandHandlerStatusSuccess;
    [invocation getReturnValue:&status];
    return status;
}
@end

static void YouModConfigureRemoteSkipCommands(void) {
    MPRemoteCommandCenter *commandCenter = [MPRemoteCommandCenter sharedCommandCenter];
    BOOL enabled = IS_ENABLED(ReplacePrevNextButtons);
    NSArray *intervals = @[@(YouModRemoteSkipInterval)];

    commandCenter.skipBackwardCommand.enabled = enabled;
    commandCenter.skipBackwardCommand.preferredIntervals = intervals;
    commandCenter.skipForwardCommand.enabled = enabled;
    commandCenter.skipForwardCommand.preferredIntervals = intervals;
    commandCenter.previousTrackCommand.enabled = !enabled;
    commandCenter.nextTrackCommand.enabled = !enabled;

    if (!YouModSkipBackwardCommandTarget) {
        YouModSkipBackwardCommandTarget = [commandCenter.skipBackwardCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
            return YouModStatusForSeek(YouModSeekByInterval(-YouModRemoteSkipInterval));
        }];
    }

    if (!YouModSkipForwardCommandTarget) {
        YouModSkipForwardCommandTarget = [commandCenter.skipForwardCommand addTargetWithHandler:^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
            return YouModStatusForSeek(YouModSeekByInterval(YouModRemoteSkipInterval));
        }];
    }
}

/*
static void YouModAddEndTime(YTPlayerViewController *self, YTSingleVideoController *video, YTSingleVideoTime *time) {
    if (!IS_ENABLED(ShowExtraTimeRemaining)) return;

    CGFloat rate = playbackRate != 0 ? playbackRate : 1.0;
    NSTimeInterval remainingTime = (lround(video.totalMediaTime) - lround(time.time)) / rate;

    NSDate *estimatedEndTime = [NSDate dateWithTimeIntervalSinceNow:remainingTime];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    [dateFormatter setDateFormat:@"HH:mm"];
    // [dateFormatter setDateFormat:ytlBool(@"24hrFormat") ? @"HH:mm" : @"h:mm a"];

    NSString *formattedEndTime = [dateFormatter stringFromDate:estimatedEndTime];

    YTPlayerView *playerView = (YTPlayerView *)self.view;
    if (![playerView.overlayView isKindOfClass:%c(YTMainAppVideoPlayerOverlayView)]) return;

    YTMainAppVideoPlayerOverlayView *overlay = (YTMainAppVideoPlayerOverlayView*)playerView.overlayView;
    YTLabel *durationLabel = overlay.playerBar.durationLabel;
    overlay.playerBar.endTimeString = formattedEndTime;

    if (![durationLabel.text containsString:formattedEndTime]) {
        durationLabel.text = [durationLabel.text stringByAppendingString:[NSString stringWithFormat:@" • %@", formattedEndTime]];
        [durationLabel sizeToFit];
    }
}
*/

%hook YTMainAppControlsOverlayView
// Hide autoplay Switch
- (void)setAutoplaySwitchButtonRenderer:(id)arg1 { if (!IS_ENABLED(HideAutoPlayToggle)) %orig; }
// Hide captions Button
- (void)setClosedCaptionsOrSubtitlesButtonAvailable:(BOOL)arg1 { if (!IS_ENABLED(HideCaptionsButton)) %orig; }
- (void)setPreviousButtonHidden:(BOOL)arg { IS_ENABLED(HidePrevButton) ? %orig(YES) : %orig; }
- (void)setNextButtonHidden:(BOOL)arg { IS_ENABLED(HideNextButton) ? %orig(YES) : %orig; }
// Hide video title in full screen
- (BOOL)titleViewHidden { return IS_ENABLED(HideFullvidTitle) ? YES : %orig; }
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

/* idk what is this thing does
%hook YTColdConfig
- (BOOL)isLandscapeEngagementPanelEnabled {
    return NO;
}
%end
*/

/*
%hook YTHeaderView
- (BOOL)stickyNavHeaderEnabled { return IS_ENABLED(YTPremiumLogo) ? YES : NO; } // idk what is this does, the nav is already sticky... Or this thing only happens in iPhone?
- (void)setStickyNavHeaderEnabled:(BOOL)arg { IS_ENABLED(YTPremiumLogo) ? %orig(YES) : %orig(NO); }
%end
*/

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
%end

// YTNoPaidPromo (https://github.com/PoomSmart/YTNoPaidPromo)
%group PaidPromoOverlay
%hook YTMainAppVideoPlayerOverlayViewController
- (void)setPaidContentWithPlayerData:(id)data {}
- (void)playerOverlayProvider:(YTPlayerOverlayProvider *)provider didInsertPlayerOverlay:(YTPlayerOverlay *)overlay {
    if ([[overlay overlayIdentifier] isEqualToString:@"player_overlay_paid_content"]) return;
    %orig;
}
%end

%hook YTInlineMutedPlaybackPlayerOverlayViewController
- (void)setPaidContentWithPlayerData:(id)data {}
%end
%end

// Remove Watermarks
%hook YTAnnotationsViewController
- (void)loadFeaturedChannelWatermark { if (!IS_ENABLED(HideWaterMark)) %orig; }
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

/* Disable Snap To Chapter (https://github.com/qnblackcat/uYouPlus/blob/main/uYouPlus.xm#L457-464) - GOT REMOVED
%hook YTSegmentableInlinePlayerBarView
- (void)didMoveToWindow { %orig; if (ytlBool(@"dontSnapToChapter")) self.enableSnapToChapter = NO; }
%end

%hook YTModularPlayerBarController
- (void)setEnableSnapToChapter:(BOOL)arg { %orig(NO); } // idk this works or not
%end
*/

// Replace previous/next buttons with back and forward
%hook YTColdConfig
- (BOOL)replaceNextPaddleWithFastForwardButtonForSingletonVods { return IS_ENABLED(ReplacePrevNextButtons) ? YES : %orig; }
- (BOOL)replacePreviousPaddleWithRewindButtonForSingletonVods { return IS_ENABLED(ReplacePrevNextButtons) ? YES : %orig; }
%end

%hook MPRemoteCommand
- (void)addTarget:(id)target action:(SEL)action {
    if (YouModIsPreviousNextCommand(self)) {
        if (!YouModRemoteCommandTargetProxies) YouModRemoteCommandTargetProxies = [NSMutableArray array];

        YouModRemoteCommandTargetProxy *proxy = [[YouModRemoteCommandTargetProxy alloc] init];
        proxy.command = self;
        proxy.target = target;
        proxy.action = action;
        [YouModRemoteCommandTargetProxies addObject:proxy];
        %orig(proxy, @selector(youModHandleRemoteCommandEvent:));
        return;
    }

    %orig;
}

- (id)addTargetWithHandler:(YouModRemoteCommandHandler)handler {
    if (YouModIsPreviousNextCommand(self)) {
        YouModRemoteCommandHandler wrappedHandler = ^MPRemoteCommandHandlerStatus(MPRemoteCommandEvent *event) {
            if (IS_ENABLED(ReplacePrevNextButtons) && YouModIsPreviousNextRemoteCommandEvent(event)) {
                return YouModStatusForSeek(YouModHandlePreviousNextRemoteCommand(event));
            }

            return handler(event);
        };
        return %orig(wrappedHandler);
    }

    return %orig;
}

- (void)removeTarget:(id)target action:(SEL)action {
    if (YouModIsPreviousNextCommand(self) && YouModRemoteCommandTargetProxies.count > 0) {
        NSArray *proxies = [YouModRemoteCommandTargetProxies copy];
        for (YouModRemoteCommandTargetProxy *proxy in proxies) {
            BOOL targetMatches = !target || proxy.target == target;
            BOOL actionMatches = !action || proxy.action == action;
            if (proxy.command == self && targetMatches && actionMatches) {
                %orig(proxy, @selector(youModHandleRemoteCommandEvent:));
                [YouModRemoteCommandTargetProxies removeObject:proxy];
            }
        }
    }

    %orig;
}

- (void)removeTarget:(id)target {
    if (YouModIsPreviousNextCommand(self) && YouModRemoteCommandTargetProxies.count > 0) {
        NSArray *proxies = [YouModRemoteCommandTargetProxies copy];
        for (YouModRemoteCommandTargetProxy *proxy in proxies) {
            if (proxy.command == self && (!target || proxy.target == target)) {
                %orig(proxy);
                [YouModRemoteCommandTargetProxies removeObject:proxy];
            }
        }
    }

    %orig;
}
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

// Disable Hints
%hook YTSettings
- (BOOL)areHintsDisabled { return IS_ENABLED(DisableHints) ? YES : %orig; }
- (void)setHintsDisabled:(BOOL)arg1 { IS_ENABLED(DisableHints) ? %orig(YES) : %orig; }
%end

%hook YTSettingsImpl
- (BOOL)areHintsDisabled { return IS_ENABLED(DisableHints) ? YES : %orig; }
- (void)setHintsDisabled:(BOOL)arg1 { IS_ENABLED(DisableHints) ? %orig(YES) : %orig; }
%end

%hook YTUserDefaults
- (BOOL)areHintsDisabled { return IS_ENABLED(DisableHints) ? YES : %orig; }
- (void)setHintsDisabled:(BOOL)arg1 { IS_ENABLED(DisableHints) ? %orig(YES) : %orig; }
%end

%hook YTPlayerViewController
- (void)loadWithPlayerTransition:(id)arg1 playbackConfig:(id)arg2 {
    %orig;
    YouModUpdateCurrentPlayer(self);
    YouModConfigureRemoteSkipCommands();
    YouModDownloadSetCurrentPlayer(self);
    if (IS_ENABLED(AutoFullScreen)) [self performSelector:@selector(YouModAutoFullscreen) withObject:nil afterDelay:0.75];
    // if (ytlBool(@"shortsToRegular")) [self performSelector:@selector(shortsToRegular) withObject:nil afterDelay:0.75];
    if (IS_ENABLED(DisablesCaptions)) [self performSelector:@selector(YouModTurnOffCaptions) withObject:nil afterDelay:1.0];
}

- (void)prepareToLoadWithPlayerTransition:(id)arg1 expectedLayout:(id)arg2 {
    %orig;
    YouModUpdateCurrentPlayer(self);
    YouModConfigureRemoteSkipCommands();
    YouModDownloadSetCurrentPlayer(self);
    if (IS_ENABLED(AutoFullScreen)) [self performSelector:@selector(YouModAutoFullscreen) withObject:nil afterDelay:0.75];
    // if (ytlBool(@"shortsToRegular")) [self performSelector:@selector(shortsToRegular) withObject:nil afterDelay:0.75];
    if (IS_ENABLED(DisablesCaptions)) [self performSelector:@selector(YouModTurnOffCaptions) withObject:nil afterDelay:1.0];
}

%new
- (void)YouModTurnOffCaptions {
    if ([self.view.superview isKindOfClass:NSClassFromString(@"YTWatchView")]) {
        [self setActiveCaptionTrack:nil source:0];
    }
}

%new
- (void)YouModAutoFullscreen {
    YTWatchController *watchController = [self valueForKey:@"_UIDelegate"];
    [watchController showFullScreen];
}

/*
- (void)singleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    YouModAddEndTime(self, video, time);
}

- (void)potentiallyMutatedSingleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    YouModAddEndTime(self, video, time);
}
*/

- (void)singleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    YouModUpdatePlaybackTime(self, video, time);
}

- (void)potentiallyMutatedSingleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    YouModUpdatePlaybackTime(self, video, time);
}

- (void)setPlaybackRate:(float)rate {
    playbackRate = rate;
    %orig;
}
%end

/*
%new
- (void)shortsToRegular {
    if (self.contentVideoID != nil && [self.parentViewController isKindOfClass:NSClassFromString(@"YTShortsPlayerViewController")]) {
        NSString *vidLink = [NSString stringWithFormat:@"vnd.youtube://%@", self.contentVideoID]; // idk about this
        if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:vidLink]]) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:vidLink] options:@{} completionHandler:nil];
        }
    }
}
%end

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
%group Gestures
%hook YTWatchLayerViewController
// invoked when the player view controller is either created or destroyed
- (void)watchController:(YTWatchController *)watchController didSetPlayerViewController:(YTPlayerViewController *)playerViewController {
    if (playerViewController) {
        // check to see if the pan gesture is already created
        if (!playerViewController.YouModPanGesture) {
            playerViewController.YouModPanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:playerViewController action:@selector(YouModHandlePanGesture:)];
            playerViewController.YouModPanGesture.delegate = playerViewController;
            [playerViewController.playerView addGestureRecognizer:playerViewController.YouModPanGesture];
        }        
    }
    %orig;
}
%end

%hook YTPlayerViewController
%property (nonatomic, retain) UIPanGestureRecognizer *YouModPanGesture;
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
            int sizeSetting = [[NSUserDefaults standardUserDefaults] objectForKey:@"GestureHUDSize"] ? (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"GestureHUDSize"] : 1;
            CGFloat fontSize = 14.0 + (sizeSetting * 2.0);
            CGFloat hudWidth = 74.0 + (sizeSetting * 10.0);
            CGFloat hudHeight = 30.0 + (sizeSetting * 4.0);
            
            self.YouModGestureHUD.frame = CGRectMake(0, 0, hudWidth, hudHeight);
            self.YouModGestureHUD.layer.cornerRadius = hudHeight / 2.0;
            self.YouModGestureHUD.font = [UIFont boldSystemFontOfSize:fontSize];

            int posSetting = [[NSUserDefaults standardUserDefaults] objectForKey:@"GestureHUDPosition"] ? (int)[[NSUserDefaults standardUserDefaults] integerForKey:@"GestureHUDPosition"] : 0;
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
%end
%end

%ctor {
    %init;
    YouModConfigureRemoteSkipCommands();
    if (IS_ENABLED(OldQualityPicker)) {
        %init(OldVideoQuality);
    }
    if (IS_ENABLED(ExtraSpeed) || IS_ENABLED(GestureControls)) {
        %init(Speed);
    }
    if (IS_ENABLED(HidePaidPromoOverlay)) {
        %init(PaidPromoOverlay);
    }
    if (IS_ENABLED(GestureControls)) {
        %init(Gestures);
    }
    if (IS_ENABLED(ForceMiniPlayer)) {
        %init(ForceMiniPlayer);
    }
}

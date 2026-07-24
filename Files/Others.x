#import "Headers.h"

// Background playback
%hook MLVideo
- (BOOL)playableInBackground { return IS_ENABLED(BackgroundPlayback) ? YES : %orig; }
%end

%hook YTIPlayabilityStatus
- (BOOL)isPlayableInBackground { return IS_ENABLED(BackgroundPlayback) ? YES : %orig; }
%end

%hook YTPlaybackData
- (BOOL)isPlayableInBackground { return IS_ENABLED(BackgroundPlayback) ? YES : %orig; }
%end

%hook YTIPlayerResponse
- (BOOL)isPlayableInBackground { return IS_ENABLED(BackgroundPlayback) ? YES : %orig; }
%end

%hook YTColdConfig
// Try to disable Shorts PiP
- (BOOL)shortsPlayerGlobalConfigEnableReelsPictureInPicture { return IS_ENABLED(DisablesShortsPiP) ? NO : %orig; }
- (BOOL)shortsPlayerGlobalConfigEnableReelsPictureInPictureIos { return IS_ENABLED(DisablesShortsPiP) ? NO : %orig; }
// Hide startup animations
- (BOOL)mainAppCoreClientIosEnableStartupAnimation { return IS_ENABLED(HideStartupAni) ? NO : %orig; }
// Prevent YouTube from asking "Are you there?"
- (BOOL)enableYouthereCommandsOnIos { return IS_ENABLED(BlockUpgradeDialogs) ? NO : %orig; }
// Fixes slow miniplayer
- (BOOL)enableIosFloatingMiniplayerDoubleTapToResize { return IS_ENABLED(FixesSlowMiniPlayer) ? NO : %orig; }
// Use old miniplayer
- (BOOL)enableIosFloatingMiniplayer { return IS_ENABLED(DisablesNewMiniPlayer) ? NO : %orig; }
%end

%hook YTHotConfig
- (BOOL)shortsPlayerGlobalConfigEnableReelsPictureInPictureAllowedFromPlayer { return IS_ENABLED(DisablesShortsPiP) ? NO : %orig; }
%end

%hook YTReelModel
- (BOOL)isPiPSupported { return IS_ENABLED(DisablesShortsPiP) ? NO : %orig; }
%end

%hook YTReelPlayerViewController
- (BOOL)isPictureInPictureAllowed { return IS_ENABLED(DisablesShortsPiP) ? NO : %orig; }
- (void)setupPlayerForPiP { if (!IS_ENABLED(DisablesShortsPiP)) %orig; }
%end

%hook YTReelWatchRootViewController
- (void)switchToPictureInPicture { if (!IS_ENABLED(DisablesShortsPiP)) %orig; }
%end

// Disable Hints
%hook YTSettings
- (BOOL)areHintsDisabled { return IS_ENABLED(DisableHints) ? YES : %orig; }
- (void)setHintsDisabled:(BOOL)arg1 {
    BOOL temp = IS_ENABLED(DisableHints) ? YES : arg1;
    %orig(temp);
}
%end

%hook YTSettingsImpl
- (BOOL)areHintsDisabled { return IS_ENABLED(DisableHints) ? YES : %orig; }
- (void)setHintsDisabled:(BOOL)arg1 {
    BOOL temp = IS_ENABLED(DisableHints) ? YES : arg1;
    %orig(temp);
}
%end

%hook YTUserDefaults
- (BOOL)areHintsDisabled { return IS_ENABLED(DisableHints) ? YES : %orig; }
- (void)setHintsDisabled:(BOOL)arg1 {
    BOOL temp = IS_ENABLED(DisableHints) ? YES : arg1;
    %orig(temp);
}
%end

// Block upgrade dialogs
%hook YTGlobalConfig
- (BOOL)shouldBlockUpgradeDialog { return IS_ENABLED(BlockUpgradeDialogs) ? YES : %orig; }
- (BOOL)shouldShowUpgradeDialog { return IS_ENABLED(BlockUpgradeDialogs) ? NO : %orig; }
- (BOOL)shouldShowUpgrade { return IS_ENABLED(BlockUpgradeDialogs) ? NO : %orig; }
- (BOOL)shouldForceUpgrade { return IS_ENABLED(BlockUpgradeDialogs) ? NO : %orig; }
%end

%hook YTYouThereController
- (BOOL)shouldShowYouTherePrompt { return IS_ENABLED(HideAreYouThereDialog) ? NO : %orig; }
- (void)showYouTherePrompt { if (!IS_ENABLED(HideAreYouThereDialog)) %orig; }
%end

%hook YTYouThereControllerImpl
- (BOOL)shouldShowYouTherePrompt { return IS_ENABLED(HideAreYouThereDialog) ? NO : %orig; }
- (void)showYouTherePrompt { if (!IS_ENABLED(HideAreYouThereDialog)) %orig; }
%end

// Disables Snackbar
%hook GOOHUDManagerInternal
- (id)sharedInstance { return IS_ENABLED(DisablesSnackBar) ? nil : %orig; }
- (void)showMessageMainThread:(id)arg { if (!IS_ENABLED(DisablesSnackBar)) %orig; }
- (void)activateOverlay:(id)arg { if (!IS_ENABLED(DisablesSnackBar)) %orig; }
- (void)displayHUDViewForMessage:(id)arg { if (!IS_ENABLED(DisablesSnackBar)) %orig; }
%end

// Remove "Play next in queue" from the menu @PoomSmart (https://github.com/qnblackcat/uYouPlus/issues/1138#issuecomment-1606415080)
%hook YTMenuItemVisibilityHandler
- (BOOL)shouldShowServiceItemRenderer:(YTIMenuConditionalServiceItemRenderer *)renderer {
    if (renderer.icon.iconType == 251 && IS_ENABLED(RemovePlayInNextQueueOption)) {
        return NO;
    }
    return %orig;
}
%end

%hook YTMenuItemVisibilityHandlerImpl
- (BOOL)shouldShowServiceItemRenderer:(YTIMenuConditionalServiceItemRenderer *)renderer {
    if (renderer.icon.iconType == 251 && IS_ENABLED(RemovePlayInNextQueueOption)) {
        return NO;
    }
    return %orig;
}
%end

// Remove flyout menu options
%hook YTDefaultSheetController
- (void)addAction:(YTActionSheetAction *)action {
    if (![action.button isKindOfClass:%c(YTMenuItemMDCButton)]) {
        %orig;
        return;
    }
    YTMenuItemMDCButton *button = (YTMenuItemMDCButton *)action.button;
    NSString *iden = button.accessibilityIdentifier;
    NSString *imageName = [button.currentImage description];

    // Method 1: Filter from accessibilityIdentifier
    NSDictionary *actionsToRemove = @{
        @"7": @(IS_ENABLED(RemoveDownloadOption)),
        @"1": @(IS_ENABLED(RemoveWatchLaterOption)),
        @"3": @(IS_ENABLED(RemoveSaveOption)),
        @"4": @(IS_ENABLED(RemoveRemoveFromPlaylistOption)),
        @"5": @(IS_ENABLED(RemoveShareOption)),
        @"6": @(IS_ENABLED(RemoveShareOption)),
        @"12": @(IS_ENABLED(RemoveNotInterestedOption)),
        @"22": @(IS_ENABLED(RemoveInfoOption)),
        @"36": @(IS_ENABLED(RemoveFilterOption)),
        @"40": @(IS_ENABLED(RemoveNotifyOption)),
        @"58": @(IS_ENABLED(RemoveReportOption))
    };
    if ([actionsToRemove[iden] boolValue]) return;

    // Method 2: Filter from imageName
    NSDictionary *imageNameToRemove = @{
        @"youtube_music": @(IS_ENABLED(RemoveYouTubeMusicOption)),
        @"flag": @(IS_ENABLED(RemoveReportOption)),
        @"alert_bubble": @(IS_ENABLED(RemoveFeedBackOption)),
        @"bookmark": @(IS_ENABLED(RemoveSaveOption)),
        @"circle_slash": @(IS_ENABLED(RemoveNotInterestedOption)),
        @"x_circle": @(IS_ENABLED(RemoveDontRecommendOption)),
        @"chromecast": @(IS_ENABLED(RemoveCastOption)),
        @"shuffle": @(IS_ENABLED(RemoveShuffleOption)),
        @"person_x": @(IS_ENABLED(RemoveUnSubOption)),
        @"help_circle": @(IS_ENABLED(RemoveHelpOption)),
        @"eye_slash": @(IS_ENABLED(RemoveHideFromPlaylistOption)),
        @"player_full_enter_alt": @(IS_ENABLED(RemoveClearScreenOption)),
        @"info_circle": @(IS_ENABLED(RemoveInfoOption))
    };
    for (NSString *key in imageNameToRemove) {
        if ([imageName containsString:key]) {
            if ([imageNameToRemove[key] boolValue]) {
                return;
            }
            break;
        }
    }
    %orig;
}
%end

// YTSlientVote (https://github.com/PoomSmart/YTSilentVote)
%hook YTInnerTubeResponseWrapper
- (id)initWithResponse:(id)response cacheContext:(id)arg2 requestStatistics:(id)arg3 mutableSharedData:(id)arg4 {
    if (!IS_ENABLED(HideLikeDislikeVotes)) return %orig;
    if ([response isKindOfClass:%c(YTILikeResponse)]
        || [response isKindOfClass:%c(YTIDislikeResponse)]
        || [response isKindOfClass:%c(YTIRemoveLikeResponse)]) return nil;
    return %orig;
}
%end

%hook NSParagraphStyle
+ (NSWritingDirection)defaultWritingDirectionForLanguage:(id)lang { return IS_ENABLED(DisablesRTL) ? NSWritingDirectionLeftToRight : %orig; }
+ (NSWritingDirection)_defaultWritingDirection { return IS_ENABLED(DisablesRTL) ? NSWritingDirectionLeftToRight : %orig; }
%end

%hook UIDevice
- (UIUserInterfaceIdiom)userInterfaceIdiom {
    if (INTFORVAL(DeviceUIIndex) == 1) {
        return UIUserInterfaceIdiomPad;
    }
    if (INTFORVAL(DeviceUIIndex) == 2) {
        return UIUserInterfaceIdiomPhone;
    }
    return %orig;
}
%end

%hook UIKeyboardImpl
+ (BOOL)isFloating { return IS_ENABLED(FloatingKeyboard) ? YES : %orig; }
%end
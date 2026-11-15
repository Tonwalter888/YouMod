// YouMod — umbrella preferences and headers
// Interfaces live in per-class headers under Headers/. This file keeps
// the imports, the YouMod preference keys, the shared externs, and the
// Foundation/UIKitCore interfaces.

#import "Headers/_ASDisplayView.h"
#import "Headers/YTIIcon.h"
#import "Headers/YTRightNavigationButtons.h"
#import "Headers/YTIElementRenderer.h"
#import "Headers/YTPlayerBarController.h"
#import "Headers/YTPlayerViewController.h"
#import "Headers/YTWatchController.h"
#import "Headers/YTIMenuConditionalServiceItemRenderer.h"
#import "Headers/YTIPivotBarRenderer.h"
#import "Headers/YTIPivotBarItemRenderer.h"
#import "Headers/YTPivotBarItemView.h"
#import "Headers/YTActionSheetAction.h"
#import "Headers/YTIMenuItemSupportedRenderers.h"
#import "Headers/YTMainAppControlsOverlayView.h"
#import "Headers/YTMainAppVideoPlayerOverlayView.h"
#import "Headers/YTMainAppVideoPlayerOverlayViewController.h"
#import "Headers/YTVideoQualitySwitchOriginalController.h"
#import "Headers/YTVideoQualitySwitchRedesignedController.h"
#import "Headers/YTInnerTubeCollectionViewController.h"
#import "Headers/YTIShowFullscreenInterstitialCommand.h"
#import "Headers/YTISectionListRenderer.h"
#import "Headers/YTIShelfRenderer.h"
#import "Headers/YTIWatchNextResponse.h"
#import "Headers/YTPlayerOverlay.h"
#import "Headers/YTPlayerOverlayProvider.h"
#import "Headers/YTReelModel.h"
#import "Headers/YTAlertView.h"
#import "Headers/YTVarispeedSwitchController.h"
#import "Headers/YTVarispeedSwitchControllerOption.h"
#import "Headers/YTInlinePlayerBarContainerView.h"
#import "Headers/YTFrostedGlassView.h"
#import "Headers/YTSingleVideoTime.h"
#import "Headers/YTSingleVideoController.h"
#import "Headers/YTPlayerView.h"
#import "Headers/YTShortsPlayerViewController.h"
#import "Headers/YTReelPlayerViewController.h"
#import "Headers/YTLabel.h"
#import "Headers/MLFormat.h"
#import "Headers/MLQuickMenuVideoQualitySettingFormatConstraint.h"
#import "Headers/YTCommonColorPalette.h"
#import "Headers/YTIPivotBarSupportedRenderers.h"
#import "Headers/YTIBrowseRequest.h"
#import "Headers/YTAssetLoader.h"
#import <MediaPlayer/MediaPlayer.h>
#import "Headers/ASCollectionView.h"
#import "Headers/YTColor.h"
#import "Headers/YTTypeStyle.h"
#import "Headers/YTModularPlayerBarController.h"
#import <dlfcn.h>
#import <Network/Network.h>
#import "Headers/YTAppViewControllerImpl.h"
#import "Headers/YTAppViewController.h"
#import "Headers/YTDefaultSheetController.h"
#import "Headers/YTIFormatStream.h"
#import "Headers/YTIPlayerResponse.h"
#import "Headers/YTPlayerResponse.h"
#import "Headers/YTIVideoDetails.h"
#import "Headers/YTIStreamingData.h"
#import "Headers/YTIFormattedString.h"
#import "Headers/YTICommand.h"
#import "Headers/YTCommandResponderEvent.h"
#import "Headers/GOOHUDManagerInternal.h"
#import "Headers/MLInnerTubeCaptionTrack.h"
#import "Headers/MLCaption.h"
#import "Headers/MLFormat3Captions.h"
#import "Headers/YTFormat3CaptionViewController.h"
#import "Headers/YTWatchNextResultsViewController.h"
#import "Headers/YTIThumbnailDetails.h"
#import "Headers/YTIThumbnailDetails_Thumbnail.h"
#import "Headers/_ASCollectionViewCell.h"
#import "Headers/YTReelElementAsyncComponentView.h"
#import "Headers/YTIPlayerBarDecorationModel.h"
#import "Headers/YTPlayerBarProgressDecorationView.h"
#import "Headers/YTPlayerBarRectangleDecorationView.h"
#import "Headers/ELMNodeController.h"
#import "Headers/ELMImageNode.h"
#import <objc/runtime.h>
#import "Headers/GPBMessage.h"
#import "Headers/YTReelNonVideoContentModel.h"
#import "Headers/GOODialogView.h"
#import "Headers/GOOShrinkWrapView.h"
#import "Headers/YTShortsContentPresenterView.h"
#import "Headers/YTReelContainerView.h"

// For Settings.x and SponsorBlockSettings.x
#import <roothide.h>
#import "Headers/YTSettingsGroupData.h"
#import "Headers/YTSettingsSectionItem.h"
#import "Headers/YTSettingsSectionItemManager.h"
#import "Headers/YTSettingsViewController.h"
#import "Headers/YTSettingsSectionController.h"
#import "Headers/YTUIUtils.h"
#import "Headers/YTResponderEvent.h"

// YouMod interfaces
#import "Headers/YTNavigationController.h"
#import "Headers/YTPresentModalResponderEvent.h"
#import "Headers/YTInlineSignInChannelCell.h"
#import "Headers/MDCInkView.h"
#import "Headers/YTPageHeaderViewController.h"
#import "Headers/YTELMViewController.h"
#import "Headers/YTInlineScrubGestureView.h"
#import "Headers/YTPivotBarView.h"
#import "Headers/YTContextualWrapView.h"
#import "Headers/YTIPlayerCueRangeSet.h"
#import "Headers/YTITopbarLogoRenderer.h"
#import "Headers/YTVideoFreeZoomOverlayController.h"
#import "Headers/YTVideoFreeZoomOverlayView.h"
#import "Headers/YTFullscreenActionsView.h"
#import "Headers/YTSearchBarView.h"
#import "Headers/GSKRedMicButton.h"
#import "Headers/YTReelContainerViewController.h"
#import "Headers/YTReelPlayerBarIntegrationController.h"
#import "Headers/YTHeaderView.h"
#import "Headers/YTNavigationBarTitleView.h"
#import "Headers/YTSearchViewController.h"
#import "Headers/YTPlayabilityResolutionUserActionUIController.h"
#import "Headers/YTPlayabilityResolutionUserActionUIControllerImpl.h"
#import "Headers/YTPivotBarViewController.h"
#import "Headers/GOODialogContentView.h"
#import "Headers/YTReelWatchPlaybackOverlayView.h"
#import "Headers/YTLanguages.h"
#import "Headers/YTReelFreeZoomOverlayView.h"
#import "Headers/YTFullscreenEngagementOverlayView.h"
#import "Headers/YTAnnotationsViewController.h"
#import "Headers/YTRelatedVideosView.h"
#import "Headers/YTAutoplayAutonavController.h"
#import "Headers/YTInlineMutedPlaybackPlayerOverlayViewController.h"
#import "Headers/YTInlineMutedPlaybackScrubbingSlider.h"
#import "Headers/YTInlineMutedPlaybackScrubberView.h"
#import "Headers/YTInlineMutedPlaybackPlayerOverlayView.h"
#import "Headers/YTWatchFloatingMiniplayerProgressBarView.h"
#import "Headers/YTWatchFloatingMiniplayerWithPersistentControlsView.h"
#import "Headers/YTWatchFloatingMiniplayerViewController.h"
#import "Headers/SSOConfiguration.h"
#import "Headers/YTEngagementPanelHeaderView.h"
#import "Headers/YTEngagementPanelView.h"
#import "Headers/YTEngagementPanelContainerView.h"
#import "Headers/YTRelatedVideosViewController.h"
#import "Headers/YTTransportControlsButtonView.h"
#import "Headers/YTIChipCloudChipRenderer.h"
#import "Headers/YTChipCloudChipView.h"
#import "Headers/YTPlaybackButton.h"
#import "Headers/YTPausedStateCarouselView.h"
#import "Headers/YTAppDelegate.h"
#import "Headers/YouModPrefsManager.h"
#import "Headers/YTCaptionTrackSwitchController.h"
#import "Headers/ASScrollView.h"
#import "Headers/YTDialogContainerScrollView.h"
#import "Headers/YTContextualSheetView.h"
#import "Headers/YTSlimStatusBarConfiguration.h"
#import "Headers/YTSlimStatusBarView.h"
#import "Headers/YTSlimStatusBarControllerImpl.h"
#import "Headers/YTIPlayerCaptionsTrackListRenderer.h"
#import "Headers/YTICaptionsSupportedRenderers.h"
#import "Headers/YTIVideoWithContextRenderer.h"
#import "Headers/YTDataUtils.h"
#import "Headers/YCHAsyncLiveChatCollectionViewController.h"
#import "Headers/YTStartupAnimationViewController.h"
#import "Headers/YTWatchFloatingMiniplayerBadgeView.h"
#import "Headers/YTReelTopBarView.h"
#import "Headers/SBSegment.h"
#import "Headers/YTIPlayerBarItemData.h"
#import "Headers/SBRequest.h"
#import "Headers/YTIEngagementPanelTitleHeaderRenderer.h"
#import "Headers/YTIEngagementPanelSectionListHeaderSupportedRenderers.h"
#import "Headers/YTIEngagementPanelSectionListRenderer.h"
#import "Headers/YTIEngagementPanelSupportedRenderers.h"
#import "Headers/YTEngagementPanelIdentifier.h"
#import "Headers/YTEngagementPanelViewControllerImpl.h"
#import "Headers/YTMainAppEngagementPanelViewController.h"
#import "Headers/YTReelWatchRootViewController.h"
#import "Headers/SBPassthroughView.h"
#import "Headers/SBPassthroughWindow.h"
#import "Headers/YMSBCardItem.h"
#import "Headers/YMSBCardViewController.h"
#import "Headers/YMIconProvider.h"
#import "Headers/YMOverlayButtonSpec.h"
#import "Headers/YMSettingsItem.h"
#import "Headers/YMVisibilityCondition.h"
#import "Headers/YMSearchRow.h"
#import "Headers/YMSubSettingsViewController.h"
#import "Headers/YMDeArrow.h"
#import "Headers/YMFormat.h"
#import "Headers/YMCaptionTrack.h"
#import "Headers/YMDownloadSheet.h"
#import "Headers/YouModPillView.h"
#import "Headers/YMDownloadProgressView.h"
#import "Headers/YouModThumbnailViewController.h"
#import "Headers/YouModTranslationViewController.h"
#import "Headers/YouModLanguagePickerViewController.h"
#import "Headers/YMSABR.h"
#import "Headers/YTTouchFeedbackView.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <CoreMedia/CoreMedia.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <math.h>
#import <Photos/Photos.h>

#define SABRDownload @"YouModSABRDownload"

#define IS_ENABLED(k) [[NSUserDefaults standardUserDefaults] boolForKey:k]
#define INTFORVAL(v) [[NSUserDefaults standardUserDefaults] integerForKey:v]
#define FixPlaybackIssues @"YouModFixPlaybackIssues"
#define MuteButton @"YouModMuteButton"
#define SpeedButton @"YouModSpeedButton"
#define ShareButton @"YouModShareButton"
#define LoopButton @"YouModLoopButton"
#define CaptionButton @"YouModCaptionButton"
#define KeepMutedKey @"YouModKeepMutedKey"
#define KeepLoopKey @"YouModKeepLoopKey"
#define QualityButton @"YouModQualityButton"
#define OverlayButtonOrder @"YouModOverlayButtonOrder"
#define GlobalSpeedLocked @"YouModGlobalSpeedLocked"
#define GlobalSavedNormalRate @"YouModGlobalSavedNormalRate"
// Sleep timer
#define SleepTimerEndDate @"YouModSleepTimerEndDate"
#define SleepTimerMode @"YouModSleepTimerMode"
// 0 = off, 1 = tab bar menu, 2 = overlay button, 3 = both
#define SleepTimerEntry @"YouModSleepTimerEntry"
// Downloading
#define DownloadManager @"YouModDownloadManager"
#define DownloadButtonPosition @"YouModDownloadButtonPosition"
#define DownloadButtonPositionUnderPlayer 0
#define DownloadButtonPositionOverlay 1
#define AddDownloadToShorts @"YouModAddDownloadToShorts"
#define HideAutoDubbedDownloads @"YouModHideAutoDubbedDownloads"
#define DownloadLibraryTab @"YouModDownloadLibraryTab"
#define DownloadComment @"YouModDownloadComment"
#define DownloadPost @"YouModDownloadPost"
// Cache
#define AutoClearCache @"YouModAutoClearCache"
#define NotifyUpdates @"YouModNotifyUpdates"
#define UpdateHasChecked @"YouModUpdateHasChecked"
#define UpdateSkippedVersion @"YouModUpdateSkippedVersion"
// Appearance
#define OLEDTheme @"YouModEnablesOLEDTheme"
#define OLEDKeyboard @"YouModEnablesOLEDKeyboard"
// Navigation bar
#define YTLogoIndex @"YouModYTLogoIndex"
#define StickyNavBar @"YouModStickyNavBar"
#define HideNoti @"YouModHideNotificationButton"
#define HideSearch @"YouModHideSearchButton"
#define HideVoiceSearch @"YouModHideVoiceSearchButton"
#define HideCastButtonNav @"YouModHideCastButtonNavigationBar"
#define HideMessages @"YouModHideMessagesButton"
// Feed
#define RemoveAds @"YouModRemoveAds"
#define HideSubbar @"YouModHideSubbar"
#define HideHoriShelf @"YouModHideHoriShelf"
#define HideGenMusicShelf @"YouModHideGenMusicShelf"
#define HideFeedPost @"YouModHideFeedPost"
#define HidePlayables @"YouModHidePlayables"
#define HideShortsShelf @"YouModHideShortsShelf"
#define KeepShortsSubscript @"YouModKeepShortsSubscript"
#define HideSearchHis @"YouModHideSearchHistoryAndSuggestions"
#define HideSurveys @"YouModHideSurveys"
#define HideRelatedVideos @"YouModHideRelatedVideos"
#define DeArrowEnabled @"YouModDeArrowEnabled"
// Player
#define WifiQualityIndex @"YouModWifiQualityIndex"
#define CellQualityIndex @"YouModCellQualityIndex"
#define LowPowerQualityIndex @"YouModLowPowerQualityIndex"
#define AudioTrack @"YouModAudioTrackSegment"
#define AudioTrackLangIndex @"YouModAudioTrackLangIndex"
#define NoDubbedAudioTrack @"YouModNoDubbedAudioTrack"
#define NoTranslatedTitles @"YouModNoTranslatedTitles"
#define CaptionTrack @"YouModCaptionTrack"
#define CaptionTrackLangIndex @"YouModCaptionTrackLangIndex"
#define DisablesCaptionTrack @"YouModDisablesCaptionTrack"
#define AutoSpeedIndex @"YouModAutoSpeedIndex"
#define ShortsAutoSpeedIndex @"YouModShortsAutoSpeedIndex"
#define HoldToSpeedEnabled @"YouModHoldToSpeedEnabled"
#define HoldToSpeedRate @"YouModHoldToSpeedRate"
#define HideAutoPlayToggle @"YouModHideAutoPlayToggle"
#define HideCaptionsButton @"YouModHideCaptionsButton"
#define HideCastButtonPlayer @"YouModHideCastButtonPlayer"
#define HideNextAndPrevButtons @"YouModHideNextAndPrevButtons"
#define ReplacePrevNextButtons @"YouModReplacePrevNextButtons"
#define SkipBackwardEnabled @"YouModSkipBackwardEnabled"
#define SkipForwardEnabled @"YouModSkipForwardEnabled"
#define RewindSeconds @"YouModRewindSeconds"
#define ForwardSeconds @"YouModForwardSeconds"
#define RemoveDarkOverlay @"YouModRemoveDarkOverlay"
#define RemoveAmbiant @"YouModRemoveAmbiantColors"
#define HideEndScreenCards @"YouModHideEndScreenCards"
#define HideSuggestedVideo @"YouModHideSuggestedVideoOnFinish"
#define HidePaidPromoOverlay @"YouModHidePaidPromoOverlay"
#define HideSponsorButton @"YouModHideSponsorButton"
#define HideWaterMark @"YouModHideWaterMark"
#define DisablesEngagementPanel @"YouModDisablesEngagementPanel"
#define DontSnapToChapter @"YouModDontSnapToChapter"
#define PauseOnOverlay @"YouModPauseOnOverlay"
#define GestureControls @"YouModEnableGesturesControls"
#define GestureActivationArea @"YouModGestureActivationArea"
#define LeftSideGesture @"YouModLeftSideGesture"
#define RightSideGesture @"YouModRightSideGesture"
#define GestureHUD @"YouModGestureHUD"
#define GestureHUDSize @"YouModGestureHUDSize"
#define GestureHUDPosition @"YouModGestureHUDPosition"
#define DisablesDoubleTap @"YouModDisablesDoubleTap"
#define DisablesLongHold @"YouModDisablesLongHold"
#define AutoExitFullScreen @"YouModAutoExitFullScreen"
#define DisablesShowRemaining @"YouModDisablesShowRemainingTime"
#define AlwaysShowRemaining @"YouModAlwaysShowRemainingTime"
#define ShowExtraTimeRemaining @"YouModShowExtraTimeRemaining"
#define Uses24HoursTime @"YouModUses24HoursTime"
#define CopyWithTimestampOnPause @"YouModCopyWithTimestampOnPause"
#define HideFullAction @"YouModHideFullScreenAction"
#define HideFullvidTitle @"YouModHideFullscreenVideoTitle"
#define StopAutoplayVideo @"YouModStopAutoplayVideo"
#define HideContentWarning @"YouModHideContentWarning"
#define AutoFullScreen @"YouModAutoFullScreen"
#define PortFull @"YouModPortraitFullscreen"
#define OldQualityPicker @"YouModUseOldQualityPicker"
#define ExtraSpeed @"YouModAddExtraSpeed"
#define ForceMiniPlayer @"YouModForceMiniPlayer"
#define AlwaysShowSeekbar @"YouModAlwaysShowSeekbar"
#define DisablesFreeZoom @"YouModDisablesFreeZoom"
#define TapToSeek @"YouModTapToSeek"
#define PauseTwoFingers @"YouModPauseTwoFingers"
#define HideCommentsSection @"YouModHideCommentsSection"
#define HideCommentsPreview @"YouModHideCommentsPreview"
#define LockSpeed @"YouModLockSpeed"
#define SeekOnOverlay @"YouModSeekOnOverlay"
#define AutoDRCAudioIndex @"YouModAutoDRCAudioIndex"
#define RemoveVideoLikeButton @"YouModRemoveVideoLikeButton"
#define RemoveVideoDislikeButton @"YouModRemoveVideoDislikeButton"
#define RemoveVideoShareButton @"YouModRemoveVideoShareButton"
#define RemoveVideoSaveButton @"YouModRemoveVideoSaveButton"
#define RemoveVideoDownloadButton @"YouModRemoveVideoDownloadButton"
#define RemoveVideoClipButton @"YouModRemoveVideoClipButton"
#define RemoveVideoRemixButton @"YouModRemoveVideoRemixButton"
#define RemoveVideoLiveChatButton @"YouModRemoveVideoLiveChatButton"
#define AutoFeedMute @"YouModAutoFeedMute"
// Shorts
#define HideShortsTopbar @"YouModHideShortsTopbar"
#define HideShortsSubbar @"YouModHideShortsSubbar"
#define FullScreenShorts @"YouModFullScreenShorts"
#define RemoveShortsLive @"YouModRemoveShortsLive"
#define RemoveShortsPosts @"YouModRemoveShortsPosts"
#define HideShortsProducts @"YouModHideShortsProducts"
#define HideShortsRecbar @"YouModHideShortsRecbar"
#define EnablesShortsQuality @"YouModEnablesShortsQuality"
#define ShowShortsSeekbar @"YouModShowShortsSeekbar"
#define ShortsActionIndex @"YouModMakeAShortsAction"
#define ShortsOnly @"YouModShortsOnly"
#define RemoveShortsLikeButton @"YouModRemoveShortsLikeButton"
#define RemoveShortsCommentBar @"YouModRemoveShortsCommentBar"
#define RemoveShortsRelatedButtons @"YouModRemoveShortsRelatedButtons"
#define RemoveShortsCommentButton @"YouModRemoveShortsCommentButton"
#define RemoveShortsSaveButton @"YouModRemoveShortsSaveButton"
#define RemoveShortsShareButton @"YouModRemoveShortsShareButton"
#define RemoveShortsRemixButton @"YouModRemoveShortsRemixButton"
#define RemoveShortsSoundMetadataButton @"YouModRemoveShortsSoundMetadataButton"
#define RemoveShortsSubButton @"YouModRemoveShortsSubButton"
#define RemoveShortsPausedSubButton @"YouModRemoveShortsPausedSubButton"
#define RemoveShortsPausedLiveButton @"YouModRemoveShortsPausedLiveButton"
#define RemoveShortsPausedLensButton @"YouModRemoveShortsPausedLensButton"
#define RemoveShortsPausedTrendsButton @"YouModRemoveShortsPausedTrendsButton"
#define RemoveShortsDisclosure @"YouModRemoveShortsDisclosure"
// Tab bar
#define DefaultTab @"YouModDefaultStartupTab"
#define TabOrder @"YouModTabOrder"
#define HideTabIndi @"YouModHideTabIndicators"
#define HideTabLabels @"YouModHideTabLabels"
#define UseFrostedTabBar @"YouModUseFrostedTabBar"
// Miscellaneous
#define BackgroundPlayback @"YouModEnablesBackgroundPlayback"
#define DisablesShortsPiP @"YouModTrytoDisablesShortsPiP"
#define DisableHints @"YouModDisableHints"
#define HideAreYouThereDialog @"YouModHideAreYouThereDialog"
#define FixesSlowMiniPlayer @"YouModFixesSlowMiniPlayer"
#define DisablesNewMiniPlayer @"YouModDisablesNewMiniPlayer"
#define DisablesSnackBar @"YouModDisablesSnackBar"
#define StartupAnimation @"YouModStartupAnimation"
#define HideLikeDislikeVotes @"YouModHideLikeDislikeVotes"
#define HideCommuGuide @"YouModHideCommuGuide"
#define HideEngagementSubbar @"YouModHideEngagementSubbar"
#define HideInfoButtonPanel @"YouModHideInfoButtonPanel"
#define HideCommunityButtonPanel @"YouModHideCommunityButtonPanel"
#define HideSortFilerPanel @"YouModHideSortFilterPanel"
#define DisablesRTL @"YouModDisablesRTL"
#define DeviceUIIndex @"YouModDeviceUIIndex"
#define FloatingKeyboard @"YouModFloatingKeyboard"
#define AutoOpenLink @"YouModAutoOpenLink"
// Flyout menu
#define RemovePlayInNextQueueOption @"YouModRemovePlayInNextQueueOption"
#define RemoveDownloadOption @"YouModRemoveDownloadOption"
#define RemoveWatchLaterOption @"YouModRemoveWatchLaterOption"
#define RemoveSaveOption @"YouModRemoveSaveOption"
#define RemoveRemoveFromPlaylistOption @"YouModRemoveRemoveFromPlaylistOption"
#define RemoveShareOption @"YouModRemoveShareOption"
#define RemoveNotInterestedOption @"YouModRemoveNotInterestedOption"
#define RemoveInfoOption @"YouModRemoveInfoOption"
#define RemoveFilterOption @"YouModRemoveFilterOption"
#define RemoveReportOption @"YouModRemoveReportOption"
#define RemoveYouTubeMusicOption @"YouModRemoveYouTubeMusicOption"
#define RemoveFeedBackOption @"YouModRemoveFeedBackOption"
#define RemoveDontRecommendOption @"YouModRemoveDontRecommendOption"
#define RemoveCastOption @"YouModRemoveCastOption"
#define RemoveShuffleOption @"YouModRemoveShuffleOption"
#define RemoveUnSubOption @"YouModRemoveUnSubOption"
#define RemoveHideFromPlaylistOption @"YouModRemoveHideFromPlaylistOption"
#define RemoveHelpOption @"YouModRemoveHelpOption"
#define RemoveNotifyOption @"YouModRemoveNotifyOption"
#define RemoveClearScreenOption @"YouModRemoveClearScreenOption"
#define RemoveAddToLastQueueOption @"YouModRemoveAddToLastQueueOption"
#define YouModVersion @"DEV"
#define YouModCommit @"dev"
// SponsorBlock
#define SBEnabled @"YouModSBEnabled"
#define SBShowButton @"YouModSBShowButton"
#define SBShowNotifications @"YouModSBShowNotifications"
#define SBShowFullVideoLabel @"YouModSBShowFullVideoLabel"
#define SBAudioNotification @"YouModSBAudioNotification"
#define SBSegmentsInPlayer @"YouModSBSegmentsInPlayer"
#define SBSegmentsInFeed @"YouModSBSegmentsInFeed"
#define SBSegmentsInMiniPlayer @"YouModSBSegmentsInMiniPlayer"
#define SBShowDuration @"YouModSBShowDuration"
#define SBMinDuration @"YouModSBMinDuration"
#define SBSkipAlertDuration @"YouModSBSkipAlertDuration"
#define SBUnskipAlertDuration @"YouModSBUnskipAlertDuration"
#define SBButtonKey @"YouModSBButtonKey"
#define SBPrivateUserIDKey @"YouModSBPrivateUserID"
#define SBPublicUserIDKey @"YouModSBPublicUserID"
#define SBWhitelistKey @"YouModSBWhitelist"

#define SB_ACTION_KEY(cat) [NSString stringWithFormat:@"YouModSBAction_%@", cat]
#define SB_COLOR_KEY(cat) [NSString stringWithFormat:@"YouModSBColor_%@", cat]

#define FLOAT_FOR_KEY(k) [[NSUserDefaults standardUserDefaults] floatForKey:k]

#define YT_BUNDLE_ID @"com.google.ios.youtube"
#define YT_NAME @"YouTube"

// Gesture Section Enum
typedef NS_ENUM(NSUInteger, GestureSection) {
    GestureSectionTop,
    GestureSectionBottom,
    GestureSectionInvalid
};

// Download library (YMLibrary.x)
@interface YMLibraryRow : NSObject
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) unsigned long long bytes;
@property (nonatomic, copy) NSString *sizeText;
@property (nonatomic, strong) UIImage *thumbnail;
@property (nonatomic, assign) BOOL isAudio;
@property (nonatomic, assign) BOOL isShorts;
@property (nonatomic, assign) BOOL isPrivate;
@property (nonatomic, copy) NSArray<NSString *> *playlistIDs;
@property (nonatomic, strong) NSDate *modifiedDate;
@property (nonatomic, assign) BOOL isPlaylist;
@property (nonatomic, copy) NSString *playlistID;
@property (nonatomic, assign) BOOL isLocked; // playlist rows only: hidden behind the Private tab
- (BOOL)isInAnyPlaylist:(NSArray<NSDictionary *> *)playlists;
@end

@interface YMLibraryHelpers : NSObject
+ (NSSet<NSString *> *)mediaExtensions;
+ (NSHashTable<AVPlayer *> *)liveAVPlayers;
+ (BOOL)isAudioOnlyExtension:(NSString *)extension;
+ (NSArray<NSString *> *)types;
+ (NSString *)metadataKeyForURL:(NSURL *)url;
+ (NSDictionary *)metadataForURL:(NSURL *)url;
+ (void)setMetadataForURL:(NSURL *)url entry:(NSDictionary *)entry;
+ (NSArray<NSDictionary *> *)playlists;
+ (void)savePlaylists:(NSArray<NSDictionary *> *)playlists;
+ (BOOL)playlistLocked:(NSDictionary *)playlist;
+ (NSArray<NSDictionary *> *)playlistsMatchingLockState:(BOOL)locked;
+ (NSString *)localizedText:(NSString *)key fallback:(NSString *)fallback;
+ (NSString *)displayTitleForFileName:(NSString *)baseName;
+ (NSString *)videoIDForFileName:(NSString *)baseName;
+ (NSString *)formattedFileSize:(unsigned long long)bytes;
+ (NSArray<NSURL *> *)fileURLsNewestFirst;
+ (NSURL *)siblingThumbnailURL:(NSURL *)fileURL;
+ (NSURL *)thumbCacheDirectory;
+ (NSURL *)generatedThumbCacheURL:(NSURL *)fileURL;
+ (UIImage *)thumbnailForVideoFile:(NSURL *)fileURL;
+ (void)deleteThumbnailsForFile:(NSURL *)fileURL;
+ (NSString *)fourCCString:(FourCharCode)code;
+ (NSString *)mediaInfoStringForFile:(NSURL *)fileURL bytes:(unsigned long long)bytes;
@end

@interface YMLibraryStyle : NSObject
+ (UIColor *)youTubeBackgroundColor;
@end

@interface YMLibraryVideoCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *thumbnailImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *sizeLabel;
@property (nonatomic, strong) YTQTMButton *menuButton;
// Playlist rows swap the ellipsis for a lock toggle in the same slot/layout.
@property (nonatomic, strong) YTQTMButton *lockButton;
@property (nonatomic, strong) UIView *selectionBox;
@property (nonatomic, strong) UIImageView *selectionCheckView;
// Called with the button itself so the sheet can anchor its iPad popover.
@property (nonatomic, copy) void (^menuTappedHandler)(UIView *sourceView);
@property (nonatomic, copy) void (^lockTappedHandler)(UIView *sourceView);
@end

@interface YMLibraryGridLayout : UICollectionViewFlowLayout
@end

@interface YMLibraryPlayerPiPDelegate : NSObject <AVPlayerViewControllerDelegate>
+ (instancetype)sharedDelegate;
@end

@interface YMLibraryRefreshControl : UIView
@property (nonatomic, copy) void (^onRefresh)(void);
@property (nonatomic, readonly, getter=isRefreshing) BOOL refreshing;
- (void)draggingBeganInScrollView:(UIScrollView *)scrollView;
- (void)scrollViewDidScroll:(UIScrollView *)scrollView;
- (void)draggingEndedInScrollView:(UIScrollView *)scrollView;
- (void)beginRefreshing;
- (void)endRefreshing;
@end

@interface YMLibraryRefreshControl ()
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, assign, getter=isRefreshing) BOOL refreshing; // readwrite privately
@property (nonatomic, assign) BOOL pullArmed; // the pull crossed the trigger distance during the current drag
@end

@interface YMLibraryViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) YTQTMButton *sortButton;
@property (nonatomic, strong) YTQTMButton *settingsButton;
@property (nonatomic, strong) YTQTMButton *selectButton;
@property (nonatomic, strong) YTQTMButton *moreMenuButton;
@property (nonatomic, strong) YTQTMButton *selectionExitButton;
@property (nonatomic, strong) UIStackView *headerButtonStack;
@property (nonatomic, strong) UIImageView *emptyIconView;
@property (nonatomic, strong) UIView *typeGlassView;
@property (nonatomic, strong) UIScrollView *typeScrollView;
@property (nonatomic, strong) UIStackView *typeStackView;
@property (nonatomic, strong) NSLayoutConstraint *typeGlassTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *typeScrollTrailingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *typeGlassLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *typeScrollLeadingConstraint;
@property (nonatomic, strong) YTQTMButton *playlistBackButton;
@property (nonatomic, strong) UIView *playlistActionsView;
@property (nonatomic, strong) YTQTMButton *addPlaylistButton;
@property (nonatomic, strong) YTQTMButton *deletePlaylistButton;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) YMLibraryRefreshControl *refreshControl;
@property (nonatomic, strong) NSMutableArray<YMLibraryRow *> *allRows; // unfiltered backing store
@property (nonatomic, strong) NSMutableArray<YMLibraryRow *> *rows;    // currently displayed (search-filtered)
@property (nonatomic, weak) id hostParentResponder;
@property (nonatomic, copy) NSString *selectedType;
@property (nonatomic, copy) NSString *selectedSort;
@property (nonatomic, copy) NSString *selectedPlaylistID;
@property (nonatomic, assign) BOOL privateUnlocked;
@property (nonatomic, assign) BOOL isAuthenticatingPrivate;
@property (nonatomic, assign) BOOL privateAuthWasBackgrounded;
@property (nonatomic, assign) BOOL isSelectionMode;
@property (nonatomic, strong) NSMutableSet<NSIndexPath *> *selectedIndexPaths;
@property (nonatomic, assign) BOOL isEnteringPlaylist;
@property (nonatomic, assign) BOOL isExitingPlaylist;
- (NSString *)displayTitleForSort:(NSString *)sort isSelected:(BOOL)selected;
- (void)updateSortMenu;
- (void)updateSortButtonAccessibilityLabel;
- (void)rebuildLibraryControls;
- (void)refreshTypeSelection;
- (void)updateHeaderVisibility;
- (void)applyFiltersAndSort;
- (void)reloadWithCompletion:(void (^)(void))completion;
- (void)reload;
- (void)updateSearchBarTheme;
- (void)scrollToSelectedTypeAnimated:(BOOL)animated;
@end

@interface YMGlassBackdropView : UIView
@end

@interface YouModRemoteCommandTargetProxy : NSObject
@property (nonatomic, weak) MPRemoteCommand *command;
@property (nonatomic, weak) id target;
@property (nonatomic, assign) SEL action;
- (MPRemoteCommandHandlerStatus)youModHandleRemoteCommandEvent:(MPRemoteCommandEvent *)event;
@end

@interface YouModOverlayRefreshHandler : NSObject
@property (nonatomic, weak) YTMainAppControlsOverlayView *overlay;
- (void)refreshSoon;
+ (instancetype)handlerForOverlay:(YTMainAppControlsOverlayView *)overlay;
@end

@interface YouModSeekTapHandler : NSObject
@property (nonatomic, assign) BOOL rewind;
@property (nonatomic, weak) YTMainAppControlsOverlayView *overlay;
- (void)handleTap:(UITapGestureRecognizer *)gr;
+ (instancetype)rewindHandlerForOverlay:(YTMainAppControlsOverlayView *)overlay;
+ (instancetype)forwardHandlerForOverlay:(YTMainAppControlsOverlayView *)overlay;
@end

@interface YouModSeekRefreshTapHandler : NSObject
@property (nonatomic, weak) YTMainAppControlsOverlayView *overlay;
- (void)handleTap:(UITapGestureRecognizer *)gr;
+ (instancetype)handlerForOverlay:(YTMainAppControlsOverlayView *)overlay;
@end

// Player.x helper classes — grouped logic instead of file-static functions.
@interface YouModNetworkMonitor : NSObject
+ (void)startMonitoring;
+ (int)networkType;
@end

@interface YouModRemoteSkipCommands : NSObject
+ (void)configure;
+ (CGFloat)rewindSeconds;
+ (CGFloat)forwardSeconds;
+ (BOOL)seekByInterval:(CGFloat)delta;
+ (BOOL)isPreviousTrackCommand:(MPRemoteCommand *)command;
+ (BOOL)isNextTrackCommand:(MPRemoteCommand *)command;
+ (BOOL)isPreviousNextCommand:(MPRemoteCommand *)command;
+ (BOOL)isSkipBackwardCommand:(MPRemoteCommand *)command;
+ (BOOL)isSkipForwardCommand:(MPRemoteCommand *)command;
+ (MPRemoteCommandHandlerStatus)statusForSeek:(BOOL)handled;
+ (BOOL)handlePreviousNextRemoteCommand:(MPRemoteCommandEvent *)event;
@end

@interface YouModPrevNextReplacement : NSObject
+ (BOOL)shouldForceReplacement;
+ (UIView *)overlayIvarView:(id)object name:(const char *)name;
+ (void)setOverlayIvarHidden:(id)object name:(const char *)name hidden:(BOOL)hidden;
+ (YTMainAppControlsOverlayView *)overlayForSubview:(UIView *)view;
+ (BOOL)isPrevNextSubview:(UIView *)view overlay:(YTMainAppControlsOverlayView *)overlay;
+ (BOOL)isSeekSubview:(UIView *)view overlay:(YTMainAppControlsOverlayView *)overlay;
+ (void)enforceVisibility:(YTMainAppControlsOverlayView *)overlay;
+ (void)remapPrevNextToSeek:(YTMainAppControlsOverlayView *)overlay;
+ (void)attachSeekRemap:(UIView *)view handler:(YouModSeekTapHandler *)handler;
+ (void)attachSeekRefresh:(UIView *)view overlay:(YTMainAppControlsOverlayView *)overlay;
+ (void)applyToOverlay:(YTMainAppControlsOverlayView *)overlay;
@end

@interface YouModPlayerGestures : NSObject
+ (void)requireAncestorPansToFail:(UIView *)playerView gesture:(UIGestureRecognizer *)gesture;
+ (NSArray<UIGestureRecognizer *> *)gesturesAroundPlayer:(UIView *)playerView;
+ (void)suspendGesturesForHold:(YTPlayerViewController *)player hold:(UIGestureRecognizer *)hold;
+ (void)restoreGesturesSuspendedByHold:(YTPlayerViewController *)player;
+ (YTMainAppVideoPlayerOverlayView *)mainVideoOverlayForPlayer:(YTPlayerViewController *)player;
+ (BOOL)isRelatedVideosPanelEnabled:(YTPlayerViewController *)player;
+ (CGFloat)remainingOverlayWidth:(YTPlayerViewController *)player fullWidth:(CGFloat)fullWidth;
+ (UISlider *)volumeSlider;
@end

@interface YouModPlaybackSpeed : NSObject
+ (void)applyExtraSpeedOptions:(id)controller;
+ (CGFloat)configuredHoldToSpeedRate;
@end

@interface NSObject (YouModReelDelegate)
- (void)playbackSequentialItemControllerDidRequestNextReel:(id)controller isAutoAdvance:(BOOL)auto_;
@end

@interface NSObject (YouModPivotBarDelegate)
- (void)didTapPivotBarItem:(id)renderer withViewControllers:(NSArray *)viewControllers animated:(BOOL)animated;
@end

@interface NSArray (YouMod)
- (void)removeObject:(id)object;
@end

@interface UIView (YouMod)
@property (nonatomic, assign, readonly) BOOL _mapkit_isDarkModeEnabled;
- (UIViewController *)_viewControllerForAncestor;
- (void)tuui_applyFlexibleSmallGlassBackground;
- (void)tuui_applyFlexibleClearGlassWithShadowBackground;
@end

@interface UIKeyboard : UIView // Regular keyboard
+ (instancetype)activeKeyboard;
@end

@interface UIPredictionViewController : UIViewController // Keyboard with enabled predictions panel
@end

@interface UIKeyboardDockView : UIView // Dock under keyboard for notched devices
@end

@interface UIKBVisualEffectView : UIVisualEffectView
@property (nonatomic, copy, readwrite) NSArray *backgroundEffects;
@end

@interface UIKBInputBackdropView : UIView
@end

extern UIView *sbGetNotificationParent(void);
extern void sbDismissAllNotifications(void);
extern void sbUpdateOverlayInsetForPivotBar(void);
extern void YMPresentTabOrder(id presenter);
extern void YouModShowPill(NSString *message, BOOL success);
extern void YouModCheckForUpdateManually(void);

// SponsorBlock menu / voting / whitelist (SponsorBlockMenu.x)
extern BOOL sbActiveForVideo(YTPlayerViewController *player);
extern void sbInvalidateSegmentCache(NSString *videoID);
extern NSString *sbLocalUserID(void);
extern NSString *sbPublicUserID(void);
extern void sbSetPrivateUserID(NSString *userID);
extern void sbSetPublicUserIDManual(NSString *userID);
extern void YMSBPresentWhitelistManager(void);
extern YTPlayerViewController *YouModCurrentPlayerViewController;

// SponsorBlock categories YouMod supports — one list shared by the core
// (fetch/skip) and the settings UI, so both always agree on the categories.
extern NSArray<NSString *> *sbAllCategories(void);
extern UIColor *SBColorFromHex(NSString *hexString);

// Skip/unskip banner duration range and default (seconds) — shared by the
// settings sliders and the core's clamp so they can't drift apart.
static const CGFloat SBAlertDurationMin = 2.0;
static const CGFloat SBAlertDurationMax = 20.0;
static const CGFloat SBAlertDurationDefault = 4.0;

// Shared search-bar corner radius — larger than a button pill, smaller than
// height/2.0, matching the system UISearchTextField rounding.
static CGFloat const YMCornerRadiusSearchBar = 10.0;

extern void YMRegisterOverlayButton(YMOverlayButtonSpec *spec);
extern NSArray<YMOverlayButtonSpec *> *YMRegisteredOverlayButtons(void);
extern NSArray<YMOverlayButtonSpec *> *YMOrderedOverlayButtons(void);
extern BOOL YMIsOverlayButtonEnabled(NSString *identifier);
extern BOOL YMIsOverlayButtonBottom(NSString *identifier);
extern void YMPushOverlayButtonOrder(id host);

// Page pushes and item factories (defined in YouModSettings.x)
extern YMSettingsItem *YMToggle(NSString *title, NSString *subtitle, NSString *key);
extern YMSettingsItem *YMSlider(NSString *title, NSString *subtitle, NSString *key, float min, float max, float step, float defaultValue);
extern YMSettingsItem *YMPicker(NSString *title, NSString *subtitle, NSString *key, NSArray<NSString *> *options, NSInteger defaultValue);
extern YMSettingsItem *YMAction(NSString *title, NSString *subtitle, void (^action)(UIViewController *vc));
extern YMSettingsItem *YMNavAction(NSString *title, NSString *subtitle, void (^action)(UIViewController *vc));
extern YMSettingsItem *YMHeader(NSString *title);
extern YMSettingsItem *YMSegment(NSString *title, NSString *key, NSArray<NSNumber *> *icons, NSInteger defaultValue);
extern YMSettingsItem *YMTextSegment(NSString *title, NSString *key, NSArray<NSString *> *labels, NSInteger defaultValue);
extern YMSettingsItem *YMImageSegment(NSString *title, NSString *key, NSArray<UIImage *> *images, NSInteger defaultValue);
extern YMSettingsItem *YMDeveloper(NSString *name, NSString *role, NSString *profileURL, NSString *avatarBaseURL);
extern void YMPushTabOrder(id host);
extern void YMRegisterSettingsGroup(NSString *title, NSArray<YMSettingsItem *> *items);
extern void YMPresentSponsorBlockSettings(id presenter);

// Navigation helpers (defined in YouModSettings.x)
// UINavigationBarAppearance for the settings pages: solid background and a
// heavy ("thick") header title font.
extern UINavigationBarAppearance *YMNavBarAppearance(UIColor *bgColor, UIColor *titleColor);
// Runs theme (dark/light) color updates as a smooth cross-fade on the given
// view's window instead of snapping.
extern void YMAnimateThemeChange(UIView *view, void (^changes)(void));
// Presents root as the YouMod settings: a full-screen UINavigationController
// sliding up from the bottom (no YouTube settings chrome). The root page gets a
// close button; pages pushed inside get the standard back button.
extern void YMPresentSettingsPage(UIViewController *root, id presenter);
// Pushes child within the current settings modal navigation stack; presents a
// new settings modal when host is outside one (entry points). Resolved from the
// live host at call time — never a captured view controller — so row taps can't
// dead-end on a stale/detached stack.
extern void YMPushOntoHost(UIViewController *child, id host);
// Opens a row's/group's page: routes to the host's groupHandler (iPad split
// view), otherwise pushes. kind is a YMSubmenuKind.
extern void YMOpenGroupFromHost(id host, NSString *title, NSArray<YMSettingsItem *> *items, NSInteger kind);
// Page factories (build without presenting).
extern UIViewController *YMNewSubSettings(NSString *title, NSArray<YMSettingsItem *> *items);
extern UIViewController *YMNewSponsorBlockSettings(void); // SponsorBlockSettings.x
extern UIViewController *YMNewSplitSettings(NSArray<YMSettingsItem *> *sidebarItems); // YMSplitSettings.x
// YES on physical iPad hardware (ignores the Device UI override).
extern BOOL isPadHardware(void);

// SponsorBlock's searchable rows, rendered by its own cell builders so its
// settings are editable inline in search. host adopts the rendering VC as a child
// for correct light/dark traits. Defined in SponsorBlockSettings.x.
extern NSArray<YMSearchRow *> *sbSearchRows(UIViewController *host);

extern void YouModPauseAllPlayers(void);
extern NSBundle *YouModBundle();
extern UIColor *YouModAccentColor(void);
extern UIImage *YouModYTIconImage(NSInteger iconType, BOOL useCustomColor, UIColor *customColor);
extern UIImage *YouModSymbolImageInCanvas(NSString *symbolName, CGFloat canvasSize, CGFloat pointSize, UIImageSymbolWeight weight);
extern NSArray *getAllSystemLanguageTitles();
extern NSArray *getAllSystemLanguageValues();
extern UIWindow *YouModKeyWindow(void);
extern UIViewController *YouModTopViewController(UIViewController *root);
extern BOOL isDarkMode(UIView *view);
extern BOOL isPad();
extern void YouModConfigureSharePopover(UIActivityViewController *activityVC, UIView *sourceView);
extern void YouModApplyPrevNextReplacement(YTMainAppControlsOverlayView *overlay);
extern void YouModConfigureRemoteSkipCommands();
extern NSString *YMExtractYouTubeVideoID(NSString *urlString);

extern NSArray<YMCaptionTrack *> *YMCaptionTracksFromPlayer(YTPlayerViewController *player);

extern NSArray<YMFormat *> *YMFormatsFromPlayer(YTPlayerViewController *player);
extern NSArray<YMFormat *> *YMFormatsFromResponse(YTPlayerResponse *response);
extern NSArray<NSString *> *YMVideoCodecsInFormats(NSArray<YMFormat *> *formats);
extern NSArray<YMFormat *> *YMVideoFormatsForCodec(NSArray<YMFormat *> *formats, NSString *codec);
extern NSArray<YMFormat *> *YMAudioTracksInFormats(NSArray<YMFormat *> *formats);
extern NSArray<NSString *> *YMAudioCodecsInFormats(NSArray<YMFormat *> *formats);
extern NSArray<YMFormat *> *YMAudioTracksForCodec(NSArray<YMFormat *> *formats, NSString *codec);

extern NSUInteger YMAttachURLs(NSArray<YMFormat *> *formats, NSArray *innerTubeFormats);

extern NSString *YMCodecDisplayName(NSString *codec);
extern NSString *YMCodecQualifier(NSString *codec);
extern NSString *YMCodecFriendlyName(NSString *codec);
extern BOOL YMCodecIsApplePlayable(NSString *codec, BOOL isVideo);
extern BOOL YMFormatsArePhotosCompatible(YMFormat *video, YMFormat *audio);
extern NSString *YMContainerExtensionFor(YMFormat *video, YMFormat *audio);
extern NSArray<YMFormat *> *YMPhotosCompatibleFormats(NSArray<YMFormat *> *formats);

extern BOOL YMFFmpegIsAvailable(void);
extern NSString *YMFFmpegUnavailableReason(void);
extern void YMFFmpegMux(NSURL *videoURL, NSURL *audioURL, NSArray<YMCaptionTrack *> *subtitles,
                        NSURL *outputURL, void (^completion)(BOOL success, NSString *failure));
extern void YMFFmpegMuxTracks(NSURL *videoURL, NSArray<NSURL *> *audioURLs,
                              NSArray<YMCaptionTrack *> *subtitles, NSURL *outputURL,
                              void (^completion)(BOOL success, NSString *failure));
extern BOOL YMFFmpegConvertStartupVideo(NSURL *inputURL, NSURL *outputURL, NSString **failureOut);
extern BOOL YMStartupVideoFileExists(void);
extern void YMStartupVideoPresentPicker(UIViewController *presenter);
extern void YMStartupVideoDelete(UIViewController *presenter);
extern void YMStartupVideoDismiss(YTStartupAnimationViewController *controller, BOOL animated);

extern void YMDownloadStart(YMFormat *video, NSArray<YMFormat *> *audioTracks, NSArray<YMCaptionTrack *> *captions,
                            NSString *fileName, YMDownloadDestination destination, NSURL *thumbnailURL, BOOL isShorts, UIViewController *presenter);

extern NSString *YouModTitleForPlayer(YTPlayerViewController *player);
extern NSString *YouModAuthorForPlayer(YTPlayerViewController *player);
extern NSString *YouModVideoIDForPlayer(YTPlayerViewController *player);
extern NSURL *YouModThumbnailURL(YTPlayerViewController *player);

extern void YouModSendToast(NSString *message);
extern void YouModSendSuccess(NSString *message);
extern void YouModSendError(NSString *message);

// Sleep timer (SleepTimer.x)
extern void YMSleepTimerStartWithMinutes(NSInteger minutes);
extern void YMSleepTimerStartEndOfVideo(void);
extern void YMSleepTimerCancel(void);
extern BOOL YMSleepTimerIsActive(void);
extern NSString *YMSleepTimerRemainingText(void);
extern void YMSleepTimerPresentPicker(UIView *sourceView);
extern void YMSleepTimerUpdateSlimBars(void);

extern NSString *YouModSanitizedFileName(NSString *name);
extern NSURL *YouModDownloadsDirectoryURL(void);
extern NSURL *YouModUniqueFileURL(NSString *fileName, NSString *extension);
extern NSURL *YouModTemporaryFileURL(NSString *extension);

extern void YouModRequestPhotoAccess(void (^completion)(BOOL granted));
extern void YouModSaveVideoToPhotos(NSURL *fileURL, UIViewController *presenter, void (^completion)(BOOL success, NSError *error));
extern void YouModShareItem(id item, UIViewController *presenter, UIView *sourceView);
extern void YouModShareFile(NSURL *fileURL, UIViewController *presenter, UIView *sourceView);
extern BOOL YouModFileIsPhotosCompatible(NSURL *fileURL);
extern void YouModHandlePostDownloadFile(NSURL *fileURL, BOOL isVideo, YMDownloadDestination destination, UIViewController *presenter);
extern void YouModHandlePostDownloadImage(UIImage *image, UIViewController *presenter);

extern UIViewController *YouModDownloadLibraryViewController(id hostParentResponder);

extern NSString *YouModGlobalAuthHeader;

#define LOC(x) [YouModBundle() localizedStringForKey:x value:nil table:nil]

// _ASDisplayView/YTELMViewController centralized helpers
extern void YouModApplyOLEDToDisplayView(_ASDisplayView *view, NSString *iden);
extern void YouModFilterAdsDisplayView(_ASDisplayView *view, NSString *iden);
extern void YouModConfigureDownloadButton(_ASDisplayView *view, NSString *iden);
extern void YouModSetupDownloadGestures(_ASDisplayView *view, NSString *iden);
extern void YouModHandleCommentLongPressAction(_ASDisplayView *view);
extern void YouModHandlePostLongPressAction(_ASDisplayView *view);
extern void YouModHandleDownloadButtonAction(_ASDisplayView *view);
extern void YouModFilterVideoButtons(_ASDisplayView *view, NSString *iden);
extern void YouModFilterShortsDisplayView(_ASDisplayView *view, NSString *iden);
extern void YouModRemoveShortsPausedButtons(_ASDisplayView *view, NSString *iden);
extern void YouModApplyOLEDCollectionView(ASCollectionView *view, NSString *iden);
extern void YouModRemoveDrawerAds(YTELMViewController *self);
extern void YouModRemoveFullscreenActionsButtons(YTELMViewController *controller);
// LiquidGlass.x — whether the host app was built against an SDK with Liquid Glass (26+).
extern BOOL YMHostBundleSupportsLiquidGlass(void);
extern void YouModApplyLiquidGlassToView(UIView *view, BOOL arg);
extern void YouModApplyFrostedPanelBackgroundToView(UIView *view);

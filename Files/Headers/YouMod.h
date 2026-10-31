// Perferences and headers
// For Tweak.x
#import "_ASDisplayView.h"
#import "YTIIcon.h"
#import "YTRightNavigationButtons.h"
#import "YTIElementRenderer.h"
#import "YTPlayerBarController.h"
#import "YTPlayerViewController.h"
#import "YTWatchController.h"
#import "YTIMenuConditionalServiceItemRenderer.h"
#import "YTIPivotBarRenderer.h"
#import "YTIPivotBarItemRenderer.h"
#import "YTPivotBarItemView.h"
#import "YTActionSheetAction.h"
#import "YTIMenuItemSupportedRenderers.h"
#import "YTMainAppControlsOverlayView.h"
#import "YTMainAppVideoPlayerOverlayView.h"
#import "YTMainAppVideoPlayerOverlayViewController.h"
#import "YTVideoQualitySwitchOriginalController.h"
#import "YTVideoQualitySwitchRedesignedController.h"
#import "YTInnerTubeCollectionViewController.h"
#import "YTIShowFullscreenInterstitialCommand.h"
#import "YTISectionListRenderer.h"
#import "YTIShelfRenderer.h"
#import "YTIWatchNextResponse.h"
#import "YTPlayerOverlay.h"
#import "YTPlayerOverlayProvider.h"
#import "YTReelModel.h"
#import "YTAlertView.h"
#import "YTVarispeedSwitchController.h"
#import "YTVarispeedSwitchControllerOption.h"
#import "YTInlinePlayerBarContainerView.h"
#import "YTFrostedGlassView.h"
#import "YTSingleVideoTime.h"
#import "YTSingleVideoController.h"
#import "YTPlayerView.h"
#import "YTShortsPlayerViewController.h"
#import "YTReelPlayerViewController.h"
#import "YTLabel.h"
#import "MLFormat.h"
#import "MLQuickMenuVideoQualitySettingFormatConstraint.h"
#import "YTCommonColorPalette.h"
#import "YTIPivotBarSupportedRenderers.h"
#import "YTIBrowseRequest.h"
#import "YTAssetLoader.h"
#import <MediaPlayer/MediaPlayer.h>
#import "ASCollectionView.h"
#import "YTColor.h"
#import "YTTypeStyle.h"
#import "YTModularPlayerBarController.h"
#import <dlfcn.h>
#import <Network/Network.h>
#import "YTAppViewControllerImpl.h"
#import "YTAppViewController.h"
#import "YTDefaultSheetController.h"
#import "YTIFormatStream.h"
#import "YTIPlayerResponse.h"
#import "YTPlayerResponse.h"
#import "YTIVideoDetails.h"
#import "YTIStreamingData.h"
#import "YTIFormattedString.h"
#import "YTICommand.h"
#import "YTCommandResponderEvent.h"
#import "GOOHUDManagerInternal.h"
#import "MLInnerTubeCaptionTrack.h"
#import "MLCaption.h"
#import "MLFormat3Captions.h"
#import "YTFormat3CaptionViewController.h"
#import "YTWatchNextResultsViewController.h"
#import "YTIThumbnailDetails.h"
#import "YTIThumbnailDetails_Thumbnail.h"
#import "_ASCollectionViewCell.h"
#import "YTReelElementAsyncComponentView.h"
#import "YTIPlayerBarDecorationModel.h"
#import "YTPlayerBarProgressDecorationView.h"
#import "YTPlayerBarRectangleDecorationView.h"
#import "ELMNodeController.h"
#import <objc/runtime.h>
#import "GPBMessage.h"
#import "YTReelNonVideoContentModel.h"
#import "GOODialogView.h"
#import "GOOShrinkWrapView.h"
#import "YTShortsContentPresenterView.h"
#import "YTReelContainerView.h"

// For Settings.x and SponsorBlockSettings.x
#import <roothide.h>
#import "YTSettingsGroupData.h"
#import "YTSettingsSectionItem.h"
#import "YTSettingsSectionItemManager.h"
#import "YTSettingsViewController.h"
#import "YTSettingsSectionController.h"
#import "YTUIUtils.h"
#import "YTResponderEvent.h"

@interface YTSettingsViewController (YouMod)
- (instancetype)initWithAccountID:(id)accountID parentResponder:(id)parentResponder;
@property (nonatomic, assign) NSInteger appearance;
@end

@interface YTNavigationController : UINavigationController
- (instancetype)initWithParentResponder:(id)parentResponder;
@end

@interface YTPresentModalResponderEvent : YTResponderEvent
+ (instancetype)eventWithViewController:(UIViewController *)viewController animated:(BOOL)animated firstResponder:(id)firstResponder;
@end

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
#define HideMoreButtonNav @"YouModHideMoreButtonNav"
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
#define BlockUpgradeDialogs @"YouModBlockUpgradeDialogs"
#define HideAreYouThereDialog @"YouModHideAreYouThereDialog"
#define FixesSlowMiniPlayer @"YouModFixesSlowMiniPlayer"
#define DisablesNewMiniPlayer @"YouModDisablesNewMiniPlayer"
#define DisablesSnackBar @"YouModDisablesSnackBar"
#define HideStartupAni @"YouModHideStartupAnimations"
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
#define YouModVersion @"2.1.0"
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

@interface MDCInkView : UIView
@end

@interface YTPageHeaderViewController : UIViewController
@end

@interface YTDefaultSheetController (YouMod)
+ (instancetype)sheetControllerWithParentResponder:(id)parentResponder;
- (void)addAction:(YTActionSheetAction *)action;
- (void)presentFromView:(UIView *)view animated:(BOOL)animated completion:(void (^)(void))completion;
- (void)presentFromViewController:(UIViewController *)vc animated:(BOOL)animated completion:(void (^)(void))completion;
- (void)addHeaderWithTitle:(NSString *)arg1 subtitle:(NSString *)arg2;
- (void)dismissViewControllerAnimated:(BOOL)arg1 completion:(void (^)(void))arg2;
@end

// Gesture Section Enum
typedef NS_ENUM(NSUInteger, GestureSection) {
    GestureSectionTop,
    GestureSectionBottom,
    GestureSectionInvalid
};

@interface YTWatchController (YouMod)
- (void)reload;
@end

@interface YTPlayerOverlayProvider (YouMod)
- (void)removePlayerOverlayWithIdentifier:(NSString *)identifier;
@end

@interface YTELMViewController : UIViewController
@end

@interface YTInlineScrubGestureView : UIView
@end

@interface YTPivotBarView : UIView
@end

@interface YTPivotBarItemView (YouMod) <UIContextMenuInteractionDelegate>
@end

@interface YTContextualWrapView : UIView
@end

@interface YTIBrowseRequest (YouMod)
+ (NSString *)browseIDForGamingDestination;
+ (NSString *)browseIDForSportsDestination;
+ (NSString *)browseIDForNotificationsInbox;
+ (NSString *)browseIDForHistory;
+ (NSString *)browseIDForWhatToWatch;
+ (NSString *)browseIDForSubscriptionsTab;
+ (NSString *)browseIDForLibraryTab;
+ (NSString *)browseIDForLearningDestination;
@end

@interface YTITopbarLogoRenderer : NSObject
@property(readonly, nonatomic) YTIIcon *iconImage;
@end

@interface YTRightNavigationButtons (YouMod)
- (YTLightweightQTMButton *)notificationButton;
- (YTLightweightQTMButton *)searchButton;
- (YTLightweightQTMButton *)connectionsInboxButton;
- (YTLightweightQTMButton *)MDXButton;
- (YTLightweightQTMButton *)rightButton;
- (NSArray <YTQTMButton *> *)visibleButtons;
@end

@interface YTVideoFreeZoomOverlayController : NSObject
- (NSUInteger)state;
@end

@interface YTVideoFreeZoomOverlayView : UIView
@end

@interface YTFullscreenActionsView : UIView
@end

@interface YTSearchBarView : UIView
@end

@interface GSKRedMicButton : UIButton
@end

@interface YTMainAppVideoPlayerOverlayView (YouMod) <UIGestureRecognizerDelegate>
@property (nonatomic, weak, readwrite) YTMainAppVideoPlayerOverlayViewController *delegate;
@property (nonatomic, strong, readwrite) YTFullscreenActionsView *fullscreenActionsView;
- (YTVideoFreeZoomOverlayView *)videoFreeZoomOverlayView;
- (YTQTMButton *)playbackRouteButton;
- (BOOL)isFullscreen;
@end

@interface YTQTMButton (YouMod)
- (void)enableNewTouchFeedback;
@end

@interface YTReelContainerViewController : UIViewController
@property (nonatomic, strong, readwrite) YTPlayerViewController *player;
@end

@interface YTHeaderView : UIView
- (void)setStickyNavHeaderEnabled:(BOOL)arg;
@end

@interface YTNavigationBarTitleView : UIView
@end

@interface YTSearchViewController : UIViewController
@end

@interface YTPlayabilityResolutionUserActionUIController : NSObject
- (void)confirmAlertDidPressConfirm;
@end

@interface YTPlayabilityResolutionUserActionUIControllerImpl : NSObject
- (void)confirmAlertDidPressConfirm;
@end

@interface YTPivotBarViewController : UIViewController
- (void)selectItemWithPivotIdentifier:(id)pivotIndentifier;
- (void)selectItemWithPivotBarItem:(id)item;
- (void)selectItemWithPivotRenderer:(id)item;
- (void)cacheCurrentViewControllers;
- (void)updateViewsWithSelectedPivotIdentifier:(id)pivotIdentifier;
- (id)delegate;
- (void)YouModReloadTabBar:(id)arg;
@end

@interface NSObject (YouModPivotBarDelegate)
- (void)didTapPivotBarItem:(id)renderer withViewControllers:(NSArray *)viewControllers animated:(BOOL)animated;
@end

@interface GOODialogContentView : UIView
@end

@interface YTReelWatchPlaybackOverlayView : UIView
@end

@interface YTReelContentView (YouMod)
@property (nonatomic, retain) UILongPressGestureRecognizer *YouModExitShortsOnlyGesture;
@property (nonatomic, retain) UIPinchGestureRecognizer *YouModPinchGesture;
- (YTReelWatchPlaybackOverlayView *)playbackOverlay;
@end

@interface YTLanguages : NSObject
+ (instancetype)languageList;
@end

@interface YTReelFreeZoomOverlayView : UIView
@end

@interface YTSettingsSectionItem (YouMod)
- (NSNumber *)categoryId;
@end

@interface NSArray (YouMod)
- (void)removeObject:(id)object;
@end

@interface YTPlayerViewController (YouMod) <UIGestureRecognizerDelegate>
@property (nonatomic, retain) UIPanGestureRecognizer *YouModPanGesture;
@property (nonatomic, retain) UITapGestureRecognizer *YouModTapGesture;
@property (nonatomic, retain) UILabel *YouModGestureHUD;
@property (nonatomic, weak, readwrite) UIViewController *parentViewController;
@property (nonatomic, assign, readonly) BOOL isInlinePlaybackActive;
@property (nonatomic, assign, readonly) BOOL isPlayingAd;
@property (nonatomic, strong) UIView *YouModSpeedToastView;
@property (nonatomic, strong) UILabel *YouModSpeedToastLabel;
@property (nonatomic, retain) UILongPressGestureRecognizer *YouModHoldGesture;
@property (nonatomic, strong) NSArray *YouModGesturesSuspendedByHold;
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer;
- (void)YouModAutoFullscreen;
- (void)YouModSetAutoSpeed;
- (void)setPlaybackRate:(float)rate;
- (void)setActiveCaptionTrack:(MLInnerTubeCaptionTrack *)arg1 source:(NSInteger)arg2;
- (BOOL)isPlaybackFinished;
- (void)didPressReplay;
- (void)play;
- (void)pause;
- (void)YouModAutoAudioTrack;
- (void)YouModAutoCaptions;
- (void)YouModLoopButton;
- (void)YouModShareButton:(UIView *)sourceView;
- (NSInteger)playerState;
- (YTPlayerResponse *)contentPlayerResponse;
- (YTPlayerResponse *)playerResponse;
- (id)audioTrackController;
- (void)YouModHideSpeedToast;
- (void)YouModShowSpeedToast:(CGFloat)speed isLocked:(BOOL)isLocked;
- (void)YouModAutoDRCAudio;
- (void)setAudioTrack:(YTIAudioTrack *)arg1 source:(NSInteger)arg2;
- (void)setAudioDRCEnabled:(BOOL)arg;
@end

@interface YTPlayerBarController (YouMod)
- (void)didScrub:(UIPanGestureRecognizer *)gesture;
@end

@interface YTFullscreenEngagementOverlayView : UIView
@end

@interface YTAnnotationsViewController : UIViewController
@end

@interface YTRelatedVideosView : UIView
@end

@interface YTAutoplayAutonavController : NSObject
- (void)setLoopMode:(NSInteger)loopMode;
@end

@interface YTInlineMutedPlaybackPlayerOverlayViewController : UIViewController
@end

@interface YTInlineMutedPlaybackScrubbingSlider : UISlider
@end

@interface YTInlineMutedPlaybackScrubberView : UIView
- (YTInlineMutedPlaybackScrubbingSlider *)scrubber;
- (BOOL)modularPlayerBarEnabled;
- (YTModularPlayerBarController *)modularPlayerBar;
@end

@interface YTInlineMutedPlaybackPlayerOverlayView : UIView
@property (nonatomic, retain) UIPanGestureRecognizer *ymSeekPan;
- (YTInlineMutedPlaybackScrubberView *)scrubberView;
@end

@interface YTWatchFloatingMiniplayerProgressBarView : UIView
@end

@interface YTWatchFloatingMiniplayerWithPersistentControlsView : UIView
- (YTWatchFloatingMiniplayerProgressBarView *)progressBarView;
@end

@interface YTWatchFloatingMiniplayerViewController : UIViewController
- (YTWatchFloatingMiniplayerWithPersistentControlsView *)watchFloatingMiniplayerView;
@end

@interface SSOConfiguration : NSObject
@end

@interface YTIPivotBarItemRenderer (YouMod)
@property (nonatomic, strong, readwrite) YTIFormattedString *title;
@end

@interface ASDisplayNode (YouMod)
- (void)removeYogaChild:(ASDisplayNode *)child;
- (ELMNodeController *)nodeController;
@end

@interface YTEngagementPanelHeaderView : UIView
- (YTQTMButton *)informationButton;
- (YTQTMButton *)sortFilterMenuButton;
- (YTQTMButton *)closeButton;
- (YTQTMButton *)backButton;
- (YTQTMButton *)actionButton;
@end

@interface YTEngagementPanelView : UIView
@end

@interface YTEngagementPanelContainerView : UIView
- (NSInteger)engagementPanelState;
@end

@interface YTRelatedVideosViewController : UIViewController
- (BOOL)isExpanded;
@end

@interface YTTransportControlsButtonView : UIView
@end

@interface YTMainAppControlsOverlayView (YouMod)
- (YTMainAppVideoPlayerOverlayViewController *)eventsDelegate;
@property (nonatomic, assign, readonly) YTQTMButton *overflowButton;
@end

@interface YTVideoQualitySwitchOriginalController (YouMod)
@property (retain, nonatomic) YTVideoQualitySwitchRedesignedController *redesignedController;
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

@interface YTIChipCloudChipRenderer : GPBMessage
@end

@interface YTChipCloudChipView : UIControl
@property (nonatomic, strong, readwrite) YTIChipCloudChipRenderer *renderer;
@end

@interface YTPlaybackButton : UIControl
@end

@interface YTPausedStateCarouselView : UIView
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

@interface YTAppDelegate : UIResponder
- (void)YouModAutoClearCache;
@end

@interface YTInlinePlayerBarContainerView (YouMod)
@property (nonatomic, strong) NSString *endTimeString;
- (UIView *)enterExitFullscreenButton;
- (BOOL)isPeekableViewVisible;
- (YTQTMButton *)exitFullscreenButton;
@end

@interface YTFirstTimeSignInView : UIView
- (YTQTMButton *)chooseAccountButton;
- (YTQTMButton *)alternateAccountButton;
@end

// Custom perferences logics
@interface YouModPrefsManager : NSObject <UIDocumentPickerDelegate>
+ (instancetype)sharedManager;
- (void)exportYouModSettingsFromVC:(UIViewController *)vc;
- (void)importYouModSettingsFromVC:(UIViewController *)vc;
- (void)restoreYouModDefaults;
@end

@interface YTIAudioTrack (YouMod)
@property (nonatomic, assign, readwrite) BOOL isAutoDubbed;
- (BOOL)hasId_p;
@end

@interface MLInnerTubeCaptionTrack (YouMod)
- (NSString *)languageCode;
- (NSString *)VSSID;
@end

@interface YTCaptionTrackSwitchController : NSObject
@end

@interface ASScrollView : UIScrollView
- (ASDisplayNode *)scrollNode;
@end

@interface YTDialogContainerScrollView : UIScrollView
@end

@interface YTContextualSheetView : UIView
@end

// Sleep timer - For newer YT versions (starting with YT 21.40)
@interface YTSlimStatusBarConfiguration : NSObject
@property (nonatomic, readwrite, copy) NSString *text;
@property (nonatomic, readwrite, strong) UIImage *icon;
@property (nonatomic, readwrite, assign) BOOL animated;
+ (id)configurationWithText:(NSString *)text style:(NSInteger)style;
// 21.41 or newer
@property (nonatomic, readwrite, strong) UIColor *backgroundColor;
@property (nonatomic, readwrite, strong) UIColor *textColor;
@end

// For older YTs
@interface YTSlimStatusBarView : UIView
- (void)updateAppearanceToSleepTimerActiveWithText:(NSString *)text;
// new one
- (void)updateWithConfiguration:(YTSlimStatusBarConfiguration *)config;
@end

@interface YTSlimStatusBarControllerImpl : NSObject
- (void)updateWithSleepTimerActiveStatus:(BOOL)arg;
@end

// Player Gestures - @bhackel (YTLitePlus)
@interface YTMainAppVideoPlayerOverlayViewController (YouMod)
- (YTCaptionTrackSwitchController *)captionTrackController;
- (NSString *)videoID;
- (CGFloat)mediaTime;
@end

@interface YTSingleVideo (YouMod)
- (BOOL)isLivePlayback;
@end

@interface YTSingleVideoController (YouMod)
- (CGFloat)totalMediaTime;
- (void)setVideoFormatConstraint:(MLQuickMenuVideoQualitySettingFormatConstraint *)arg;
- (void)YouModAutoQuality;
- (NSArray *)availableCaptionTracks;
- (MLInnerTubeCaptionTrack *)activeCaptionTrack;
- (float)volume;
- (void)setVolume:(float)volume;
@end

@interface YTReelPlayerViewController (YouMod)
- (void)reelContentViewRequestsAdvanceToNextVideo:(id)arg;
- (void)reelContentViewRequestsPlayPauseToggle:(id)arg;
- (id)audioTrackController;
- (void)YouModAutoAudioTrack:(YTPlayerViewController *)pv;
@end

@interface YTIPlayerCaptionsTrackListRenderer : GPBMessage
- (NSMutableArray *)captionTracksArray;
@end

@interface YTICaptionsSupportedRenderers : GPBMessage
- (YTIPlayerCaptionsTrackListRenderer *)playerCaptionsTracklistRenderer;
@end

@interface YTIPlayerResponse (YouMod)
- (YTIStreamingData *)streamingData;
- (YTICaptionsSupportedRenderers *)captions;
@end

@interface YTIFormatStream (YouMod)
- (NSString *)mimeType;
- (NSInteger)contentLength;
- (NSUInteger)approxDurationMs;
- (int)height;
- (int)width;
- (int)fps;
- (int)bitrate;
- (YTIAudioTrack *)audioTrack;
- (int)itag;
- (YTIColorInfo *)colorInfo;
- (NSString *)xtags;
@end

@interface YTIVideoWithContextRenderer : GPBMessage
- (YTIFormattedString *)title;
- (BOOL)hasUntranslatedTitle;
- (YTIFormattedString *)untranslatedTitle;
@end

@interface YTIFormattedString (YouMod)
- (NSString *)dropdownOptionTitle;
- (NSString *)stringWithFormattingRemoved;
@end

@interface YTIVideoDetails (YouMod)
- (NSString *)title;
- (NSString *)author;
- (NSString *)channelId;
- (NSString *)shortDescription;
- (YTIThumbnailDetails *)thumbnail;
@end

@interface YTDataUtils : NSObject
+ (instancetype)generateClientSideNonce;
@end

@interface YCHAsyncLiveChatCollectionViewController : UIViewController
@end

@interface YTStartupAnimationViewController : UIViewController
- (void)forceDismissStartupAnimationAnimated:(BOOL)animated;
@end

@interface YTWatchFloatingMiniplayerBadgeView : UIView
@end

@interface YTReelTopBarView : UIView
@end

// SponsorBlock action modes
typedef NS_ENUM(NSInteger, SBSegmentAction) {
    SBSegmentActionDisable = 0,
    SBSegmentActionAutoSkip = 1,
    SBSegmentActionAsk = 2,
    SBSegmentActionDisplay = 3,
    SBSegmentActionSkipTo = 4,
    SBSegmentActionAlwaysSkip = 5
};

@interface YTIPlayerBarItemData : GPBMessage
- (CGFloat)startTimeSec;
- (CGFloat)endTimeSec;
@end

@interface YTIPlayerBarDecorationModel (YouMod)
- (YTIPlayerBarItemData *)itemData;
- (YTIPlayerBarPlayingState *)playingState;
@end

@interface YTIPlayerBarDecorationStyle (YouMod)
@property (nonatomic, assign, readwrite) BOOL hasRoundedCorners;
@end

@interface SBSegment : NSObject
@property (nonatomic, strong) NSString *UUID;
@property (nonatomic, strong) NSString *category;
@property (nonatomic, assign) float startTime;
@property (nonatomic, assign) float endTime;
@property (nonatomic, strong) NSString *actionType;
@property (nonatomic, assign) NSInteger votes;
+ (instancetype)segmentWithUUID:(NSString *)UUID category:(NSString *)category start:(float)start end:(float)end action:(NSString *)actionType;
- (SBSegmentAction)configuredAction;
- (UIColor *)segmentColor;
@end

@interface SBRequest : NSObject
+ (void)fetchSegmentsForVideoID:(NSString *)videoID completion:(void (^)(NSArray<SBSegment *> *segments))completion;
@end

@interface SBRequest (Write)
+ (void)voteOnSegment:(SBSegment *)segment videoID:(NSString *)videoID type:(NSInteger)voteType completion:(void (^)(BOOL success, NSString *errorMessage))completion;
+ (void)voteCategoryOnSegment:(SBSegment *)segment videoID:(NSString *)videoID category:(NSString *)category completion:(void (^)(BOOL success, NSString *errorMessage))completion;
+ (void)submitSegmentForVideoID:(NSString *)videoID category:(NSString *)category start:(float)start end:(float)end duration:(float)duration completion:(void (^)(BOOL success, NSString *errorMessage))completion;
@end

// Engagement panel pieces hosting YMSBCardViewController (SponsorBlockMenu.x).
// Protobuf fields resolve at runtime — declarations only.
@interface YTIEngagementPanelTitleHeaderRenderer : GPBMessage
@property (nonatomic, strong) YTIFormattedString *title;
@end
@interface YTIEngagementPanelSectionListHeaderSupportedRenderers : GPBMessage
@property (nonatomic, strong) YTIEngagementPanelTitleHeaderRenderer *engagementPanelTitleHeaderRenderer;
@end
@interface YTIEngagementPanelSectionListRenderer : GPBMessage
@property (nonatomic, copy) NSString *panelIdentifier;
@property (nonatomic, strong) YTIEngagementPanelSectionListHeaderSupportedRenderers *header;
@property (nonatomic, assign) int32_t supportedOrientations;
@property (nonatomic, assign) BOOL allowReplace;
@end
@interface YTIEngagementPanelSupportedRenderers : GPBMessage
@property (nonatomic, strong) YTIEngagementPanelSectionListRenderer *engagementPanelSectionListRenderer;
@end
@interface YTIShowEngagementPanelEndpoint (YouMod)
@property (nonatomic, strong) YTIEngagementPanelSupportedRenderers *engagementPanel;
@end
@interface GPBMessage (YouMod)
+ (instancetype)goog_parseFromData:(NSData *)data error:(NSError **)error; // parses with the app's extension registry
@end
@interface YTEngagementPanelIdentifier : NSObject
- (NSString *)identifierString;
@end
@interface YTEngagementPanelViewControllerImpl : UIViewController
- (void)setContentViewController:(UIViewController *)contentViewController;
- (void)didTapCloseButton;
@end
@interface YTMainAppEngagementPanelViewController : UIViewController // 19.x name of the above
- (void)didTapCloseButton;
@end

@interface YTReelWatchRootViewController : UIViewController
@property (nonatomic, assign, readonly) YTPlayerViewController *player;
@end

// Overlay window/view taking touches only on their subviews; empty areas fall
// through to YouTube's window underneath (SponsorBlock.x).
@interface SBPassthroughView : UIView
@end
@interface SBPassthroughWindow : UIWindow
@end

extern UIView *sbGetNotificationParent(void);
extern void sbDismissAllNotifications(void);
extern void sbUpdateOverlayInsetForPivotBar(void);
extern void YMPresentTabOrderModally(id parentResponder);
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

// Form-sheet card dialog (UIModalPresentationFormSheet + UINavigationController)
// for segment voting, whitelist and user-ID editing. Rows are plain table items;
// swipeToDelete + onDeleteItem add swipe-left delete, searchBar filters rows.
@class YMSBCardViewController;
@interface YMSBCardItem : NSObject
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, strong) UIColor *tintColor;
@property (nonatomic, copy) NSString *identifier; // e.g. channelID on whitelist rows
@property (nonatomic, strong) UIView *accessoryView; // optional trailing controls
@property (nonatomic, copy) void (^handler)(YMSBCardViewController *card);
+ (instancetype)itemWithImage:(UIImage *)image title:(NSString *)title subtitle:(NSString *)subtitle tintColor:(UIColor *)tint handler:(void (^)(YMSBCardViewController *card))handler;
@end

@interface YMSBCardViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, copy) NSString *cardTitle;
@property (nonatomic, copy) NSString *message;        // informational label row on top
@property (nonatomic, copy) NSString *emptyText;      // centered text shown while items is empty
@property (nonatomic, strong) UITextField *textField; // optional editable field row on top
@property (nonatomic, strong) UISearchBar *searchBar; // optional search bar; filters items by title/subtitle
@property (nonatomic, strong) NSArray<YMSBCardItem *> *items;
@property (nonatomic, assign) BOOL swipeToDelete;
@property (nonatomic, copy) void (^onDeleteItem)(YMSBCardViewController *card, YMSBCardItem *item);
- (void)reloadItems;
- (void)dismissCard;
+ (UINavigationController *)presentCard:(YMSBCardViewController *)card;
+ (void)presentCardInEngagementPanel:(YMSBCardViewController *)card fromResponder:(id)responder; // YouTube engagement panel
@end

// SponsorBlock categories YouMod supports — one list shared by the core
// (fetch/skip) and the settings UI, so both always agree on the categories.
extern NSArray<NSString *> *sbAllCategories(void);
extern UIColor *SBColorFromHex(NSString *hexString);

// Skip/unskip banner duration range and default (seconds) — shared by the
// settings sliders and the core's clamp so they can't drift apart.
static const CGFloat SBAlertDurationMin = 2.0;
static const CGFloat SBAlertDurationMax = 20.0;
static const CGFloat SBAlertDurationDefault = 4.0;

#pragma mark - Custom Overlay Button Registry

// A button registered into the player's controls overlay (top-right, under
// YouTube's gear). Features register a spec from their %ctor; OverlayButtons.x
// lays them all out.
@interface YMOverlayButtonSpec : NSObject
@property (nonatomic, copy) NSString *identifier;       // unique, e.g. @"sponsorblock.toggle"
@property (nonatomic, copy) NSString *symbolName;       // SF Symbol name (icon button)
@property (nonatomic, copy) NSString *title;            // text label; set this instead of symbolName for a text button
@property (nonatomic, copy) NSString *displayName;      // localized display name for settings
@property (nonatomic, copy) NSString *settingsSymbolName; // custom symbol name for settings table view
@property (nonatomic, assign) NSInteger sortOrder;      // ascending; lower = closer to gear (rightmost)
@property (nonatomic, copy) void (^onTap)(YTPlayerViewController *player, YTQTMButton *button);
@property (nonatomic, copy) BOOL (^isVisible)(YTPlayerViewController *player);     // nil = always visible
@property (nonatomic, assign) NSInteger viewTag;        // assigned by the registry; do not set
@end

extern void YMRegisterOverlayButton(YMOverlayButtonSpec *spec);
extern NSArray<YMOverlayButtonSpec *> *YMRegisteredOverlayButtons(void);
extern NSArray<YMOverlayButtonSpec *> *YMOrderedOverlayButtons(void);
extern BOOL YMIsOverlayButtonEnabled(NSString *identifier);
extern BOOL YMIsOverlayButtonBottom(NSString *identifier);
extern void YMPushOverlayButtonOrder(id settingsVC, id parentResponder);

#pragma mark - YouMod Settings Framework (YouModSettings.x)

typedef NS_ENUM(NSInteger, YMRowType) {
    YMRowTypeToggle = 0,
    YMRowTypePicker,
    YMRowTypeAction,
    YMRowTypeHeader,
    YMRowTypeSegment,
    YMRowTypeTextSegment,
    YMRowTypeImageSegment,
    YMRowTypeSlider,
    YMRowTypeDeveloper
};

typedef NS_ENUM(NSInteger, YMVisibilityOperator) {
    YMVisibilityOperatorBoolEquals = 0,
    YMVisibilityOperatorIntEquals,
    YMVisibilityOperatorIntNotEquals,
    YMVisibilityOperatorIntGreaterThan,
    YMVisibilityOperatorIntGreaterThanOrEqual,
    YMVisibilityOperatorIntLessThan,
    YMVisibilityOperatorIntLessThanOrEqual,
    YMVisibilityOperatorIntInValues,
    YMVisibilityOperatorIntNotInValues,
    YMVisibilityOperatorCustomBlock
};

@interface YMVisibilityCondition : NSObject
@property (nonatomic, copy) NSString *key;
@property (nonatomic, assign) YMVisibilityOperator op;
@property (nonatomic, assign) BOOL boolValue;
@property (nonatomic, assign) NSInteger intValue;
@property (nonatomic, strong) NSArray<NSNumber *> *intValues;
@property (nonatomic, copy) BOOL (^customBlock)(NSUserDefaults *defaults);

+ (instancetype)conditionWithBoolKey:(NSString *)key equals:(BOOL)value;
+ (instancetype)conditionWithKey:(NSString *)key intOperator:(YMVisibilityOperator)op value:(NSInteger)value;
+ (instancetype)conditionWithKey:(NSString *)key inValues:(NSArray<NSNumber *> *)values;
+ (instancetype)conditionWithKey:(NSString *)key notInValues:(NSArray<NSNumber *> *)values;
+ (instancetype)conditionWithBlock:(BOOL (^)(NSUserDefaults *defaults))block;

- (BOOL)evaluateWithDefaults:(NSUserDefaults *)defaults;
@end

@interface YMSettingsItem : NSObject
@property (nonatomic, assign) YMRowType type;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *subtitle;
@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) NSArray<NSString *> *pickerOptions;
@property (nonatomic, assign) NSInteger pickerDefault;
@property (nonatomic, copy) void (^action)(UIViewController *vc);
@property (nonatomic, assign) BOOL opensPage; // YES -> row pushes another page, gets a disclosure chevron
@property (nonatomic, assign) NSInteger iconType; // YT icon (YTIIcon type) shown leading; 0 = no icon
@property (nonatomic, strong) NSArray<NSNumber *> *segmentIcons;
@property (nonatomic, strong) NSArray<NSString *> *segmentLabels;
@property (nonatomic, strong) NSArray<UIImage *> *segmentImages;
@property (nonatomic, assign) float sliderMin;
@property (nonatomic, assign) float sliderMax;
@property (nonatomic, assign) float sliderStep;
@property (nonatomic, assign) float sliderDefault;
// Developer row: circular GitHub avatar + name + role; tap opens profileURL,
// avatarURL (github.com/<user>.png) is fetched async and cached.
@property (nonatomic, strong) NSString *profileURL;
@property (nonatomic, strong) NSString *avatarURL;

// Visibility predicates: all must match (AND), or any when matchAnyCondition is YES (OR).
@property (nonatomic, strong) NSMutableArray<YMVisibilityCondition *> *visibilityConditions;
@property (nonatomic, assign) BOOL matchAnyCondition;

+ (instancetype)toggleWithTitle:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key;
+ (instancetype)sliderWithTitle:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key min:(float)min max:(float)max step:(float)step defaultValue:(float)defaultValue;
+ (instancetype)pickerWithTitle:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key options:(NSArray<NSString *> *)options defaultValue:(NSInteger)defaultValue;
+ (instancetype)actionWithTitle:(NSString *)title subtitle:(NSString *)subtitle action:(void (^)(UIViewController *vc))action;
+ (instancetype)navActionWithTitle:(NSString *)title subtitle:(NSString *)subtitle action:(void (^)(UIViewController *vc))action;
+ (instancetype)headerWithTitle:(NSString *)title;
+ (instancetype)segmentWithTitle:(NSString *)title key:(NSString *)key icons:(NSArray<NSNumber *> *)icons defaultValue:(NSInteger)defaultValue;
+ (instancetype)textSegmentWithTitle:(NSString *)title key:(NSString *)key labels:(NSArray<NSString *> *)labels defaultValue:(NSInteger)defaultValue;
+ (instancetype)imageSegmentWithTitle:(NSString *)title key:(NSString *)key images:(NSArray<UIImage *> *)images defaultValue:(NSInteger)defaultValue;
+ (instancetype)developerWithName:(NSString *)name role:(NSString *)role profileURL:(NSString *)profileURL avatarURL:(NSString *)avatarURL;

// Chainable row styling
- (instancetype)withIconType:(NSInteger)iconType;

// Evaluation
- (BOOL)isVisible;
- (BOOL)isVisibleWithDefaults:(NSUserDefaults *)defaults;

// Integer conditions (chainable)
- (instancetype)visibleWhenKey:(NSString *)key equals:(NSInteger)value;
- (instancetype)visibleWhenKey:(NSString *)key isNotEqualTo:(NSInteger)value;
- (instancetype)visibleWhenKey:(NSString *)key isGreaterThan:(NSInteger)value;
- (instancetype)visibleWhenKey:(NSString *)key isGreaterThanOrEqualTo:(NSInteger)value;
- (instancetype)visibleWhenKey:(NSString *)key isLessThan:(NSInteger)value;
- (instancetype)visibleWhenKey:(NSString *)key isLessThanOrEqualTo:(NSInteger)value;
- (instancetype)visibleWhenKey:(NSString *)key inValues:(NSArray<NSNumber *> *)values;
- (instancetype)visibleWhenKey:(NSString *)key notInValues:(NSArray<NSNumber *> *)values;
- (instancetype)visibleWhenKeyDictionary:(NSDictionary<NSString *, NSNumber *> *)keyValues;

// Boolean conditions (chainable)
- (instancetype)visibleWhenBoolKey:(NSString *)key equals:(BOOL)value;
- (instancetype)visibleWhenBoolKey:(NSString *)key;
- (instancetype)visibleWhenBoolKeys:(NSArray<NSString *> *)keys;
- (instancetype)visibleWhenBoolKeys:(NSArray<NSString *> *)keys allEqualTo:(BOOL)value;
- (instancetype)visibleWhenAnyBoolKey:(NSArray<NSString *> *)keys;
- (instancetype)visibleWhenBoolDictionary:(NSDictionary<NSString *, NSNumber *> *)keyValues;

// Block / Custom conditions & modifier
- (instancetype)visibleWhen:(BOOL (^)(NSUserDefaults *defaults))block;
- (instancetype)requireAnyCondition;
@end

// Page pushes and item factories (defined in YouModSettings.x)
extern void YMPushSubSettings(NSString *title, NSArray<YMSettingsItem *> *items, id settingsVC, id parentResponder);
extern void YMPushSubSettingsWithFooter(NSString *title, NSArray<YMSettingsItem *> *items, id settingsVC, id parentResponder);
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
extern void YMPushTabOrder(id settingsVC, id parentResponder);
extern void YMRegisterSettingsGroup(NSString *title, NSArray<YMSettingsItem *> *items);
extern void YMPushSponsorBlockSettings(id settingsVC);

@interface YTSettingsSectionItemManager (YouMod)
- (void)updateYouModSectionWithEntry:(id)entry;
@end

#pragma mark - Settings Search

// One row in the global settings-search results: renders its own cell (makeCell)
// and optionally handles its own tap (onSelect, with a reload block). searchText
// is what the query matches against (title + description).
@interface YMSearchRow : NSObject
@property (nonatomic, copy) NSString *searchText;
@property (nonatomic, copy) UITableViewCell *(^makeCell)(UITableView *tableView);
@property (nonatomic, assign) CGFloat cellHeight; // 0 = UITableViewAutomaticDimension
@property (nonatomic, copy) void (^onSelect)(UIViewController *presenter, void (^reload)(void));
@end

// SponsorBlock's searchable rows, rendered by its own cell builders so its
// settings are editable inline in search. host adopts the rendering VC as a child
// for correct light/dark traits. Defined in SponsorBlockSettings.x.
extern NSArray<YMSearchRow *> *sbSearchRows(UIViewController *host);

extern NSBundle *YouModBundle();
extern UIImage *YouModYTIconImage(NSInteger iconType, BOOL useCustomColor, UIColor *customColor);
extern UIImage *YouModSymbolImageInCanvas(NSString *symbolName, CGFloat canvasSize, CGFloat pointSize, UIImageSymbolWeight weight);
extern NSArray *getAllSystemLanguageTitles();
extern NSArray *getAllSystemLanguageValues();
extern UIViewController *YouModTopViewController(UIViewController *root);
extern BOOL isDarkMode(UIView *view);
extern BOOL isPad();
extern void YouModConfigureSharePopover(UIActivityViewController *activityVC, UIView *sourceView);
extern void YouModApplyPrevNextReplacement(YTMainAppControlsOverlayView *overlay);
extern void YouModConfigureRemoteSkipCommands();

@interface YMFormat : NSObject
@property (nonatomic, assign) int itag;
@property (nonatomic, copy) NSString *mimeType;
@property (nonatomic, copy) NSString *codec;
@property (nonatomic, copy) NSString *qualityLabel;
@property (nonatomic, copy) NSString *xtags;
@property (nonatomic, assign) int height, width, fps;
@property (nonatomic, assign) long long contentLength, bitrate;
@property (nonatomic, assign) unsigned long long durationMs;
@property (nonatomic, assign) BOOL isVideo, isHDR;
@property (nonatomic, copy) NSString *audioTrackID, *audioTrackName;
@property (nonatomic, assign) BOOL audioIsDefault;
@property (nonatomic, assign) BOOL isDubbed;
@property (nonatomic, assign) BOOL isOriginal, isAutoDubbed, isDRC;
@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, readonly) BOOL isAudio;
@property (nonatomic, readonly) NSString *displayLabel;
@property (nonatomic, strong) YTIFormatStream *source;
@end

@interface YMCaptionTrack : NSObject
@property (nonatomic, copy) NSString *name;          // "English (US)"
@property (nonatomic, copy) NSString *languageCode;  // "en"
@property (nonatomic, copy) NSString *vttURL;        // fetched just before muxing
@property (nonatomic, strong) NSURL *localURL;       // set once fetched
@end
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

typedef NS_ENUM(NSInteger, YMDownloadDestination) {
    YMDownloadDestinationPhotos,
    YMDownloadDestinationFiles,
};

extern void YMDownloadStart(YMFormat *video, NSArray<YMFormat *> *audioTracks, NSArray<YMCaptionTrack *> *captions,
                            NSString *fileName, YMDownloadDestination destination, NSURL *thumbnailURL, BOOL isShorts, UIViewController *presenter);

@interface YMDownloadSheet : UIViewController
+ (void)presentForPlayer:(YTPlayerViewController *)player
            destination:(YMDownloadDestination)destination
                isShorts:(BOOL)isShorts
              presenter:(UIViewController *)presenter;
@end

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

// Shared success, error, and action feedback pill (YouModPill.x).
@interface YouModPillView : UIView
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UIView *progressOverlay;
@property (nonatomic, strong) UIImageView *infoIconView;
@property (nonatomic, assign) BOOL showsInfoIcon;
@property (nonatomic, copy) void (^onAction)(void);
@property (nonatomic, assign) NSTimeInterval totalDuration;
@property (nonatomic, assign) NSTimeInterval remainingDuration;
@property (nonatomic, assign) BOOL isPaused;
@property (nonatomic, assign) BOOL isHighlightPill;
@property (nonatomic, assign) BOOL isDismissing;
@property (nonatomic, strong) NSDate *backgroundDate;
+ (instancetype)showInView:(UIView *)parentView message:(NSString *)message buttonTitle:(NSString *)buttonTitle action:(void (^)(void))action duration:(NSTimeInterval)duration;
+ (instancetype)showDownloadCompleteDialogInView:(UIView *)parentView message:(NSString *)message saveHandler:(void (^)(void))saveHandler shareHandler:(void (^)(void))shareHandler duration:(NSTimeInterval)duration;
+ (instancetype)showSuccessInView:(UIView *)parentView message:(NSString *)message duration:(NSTimeInterval)duration;
+ (instancetype)showErrorInView:(UIView *)parentView message:(NSString *)message duration:(NSTimeInterval)duration;
+ (NSInteger)nextAnimationSequence;
+ (NSInteger)currentAnimationSequence;
+ (void)dismissExistingPillsInView:(UIView *)parentView completion:(void (^)(void))completion;
- (void)dismiss;
- (void)dismissWithCompletion:(void (^)(void))completion;
- (void)pauseProgress;
- (void)resumeProgress;
@end

@interface YMDownloadProgressView : UIView
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIProgressView *progressBar;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, copy) void (^onCancel)(void);
@property (nonatomic, assign) BOOL isDismissing;
+ (instancetype)showInView:(UIView *)parentView message:(NSString *)message cancelAction:(void (^)(void))cancelAction;
- (void)updateProgress:(float)progress title:(NSString *)title subtitle:(NSString *)subtitle;
- (void)dismiss;
- (void)dismissWithCompletion:(void (^)(void))completion;
@end

@interface YTPlayerViewController (SponsorBlock)
@property (nonatomic, strong) NSString *sbLastVideoID;
@property (nonatomic, strong) NSArray<SBSegment *> *sbSegments;
@property (nonatomic, strong) NSMutableSet<NSString *> *sbSkippedSegments;
@property (nonatomic, strong) YouModPillView *sbNotificationView;
@property (nonatomic, strong) NSMutableSet<NSString *> *sbAcceptedMutes;
@property (nonatomic, assign) BOOL sbMutedBySegment;
@property (nonatomic, strong) NSMutableDictionary *sbDraft;
- (void)sbCheckSegmentsAtCurrentTime;
- (void)sbUpdateMuteAtTime:(CGFloat)currentTime;
- (void)sbShowFullVideoLabelIfNeeded:(NSArray<SBSegment *> *)segments;
- (void)sbShowSubmitCard;
- (NSArray<YMSBCardItem *> *)sbSubmitItemsForCard:(YMSBCardViewController *)card;
- (void)sbPerformSkip:(SBSegment *)segment;
- (void)sbShowAskNotification:(SBSegment *)segment;
- (void)sbShowHighlightBannerIfNeeded:(NSArray<SBSegment *> *)segments;
- (void)sbSkipToHighlight;
- (void)sbRefreshMarkers:(NSArray<SBSegment *> *)segments;
- (void)sbShowMainMenuFromView:(UIView *)sourceView;
- (void)sbShowVoteCard;
- (void)sbToggleWhitelistFromMenu;
- (void)sbPushVoteOptionsForSegment:(SBSegment *)segment fromCard:(YMSBCardViewController *)card;
- (void)sbPushCategoryPickerForSegment:(SBSegment *)segment fromCard:(YMSBCardViewController *)card;
@end

@interface YouModThumbnailViewController : UIViewController <UIScrollViewDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIImage *thumbnailImage;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *imageView;
@end

typedef NS_ENUM(NSInteger, YouModTranslationState) {
    YouModTranslationStateLoading = 0,
    YouModTranslationStateSuccess = 1,
    YouModTranslationStateFailed = 2
};

@interface YouModTranslationViewController : UIViewController
@property (nonatomic, copy) NSString *originalText;
@property (nonatomic, strong) UILabel *langValueLabel;
@property (nonatomic, strong) UIButton *reloadButton;
@property (nonatomic, strong) UITextView *resultTextView;
@property (nonatomic, copy) NSString *selectedLangCode;
@property (nonatomic, copy) NSString *selectedLangName;
@property (nonatomic, strong) NSArray<NSString *> *languageTitles;
@property (nonatomic, strong) NSArray<NSString *> *languageCodes;
@property (nonatomic, assign) YouModTranslationState translationState;
- (void)performTranslation;
@end

@interface YouModLanguagePickerViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate>
@property (nonatomic, copy) NSString *selectedLangCode;
@property (nonatomic, copy) NSArray<NSString *> *titles;
@property (nonatomic, copy) NSArray<NSString *> *codes;
@property (nonatomic, copy) void (^onSelectLanguage)(NSString *code, NSString *title);
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *containerView;
@end

// On-device SABR downloader (SABRDownload.x): produces video mp4 + audio m4a for
// the existing muxer; progress/completion on the main queue.
//
// audioStream is the picked audio format from the player response. Language dubs
// share one itag (140) and differ only in the FormatId's xtags, so the track
// identity is read from this format (nil = no preference, first match wins).
@interface YMSABR : NSObject
+ (void)downloadVideoItag:(int)videoItag audioItag:(int)audioItag audioStream:(YTIFormatStream *)audioStream
                 progress:(void (^)(float fraction, unsigned long long bytesDownloaded, BOOL isAudio))progress
               completion:(void (^)(NSURL *videoURL, NSURL *audioURL, NSString *err))completion;
+ (void)downloadAudioItag:(int)audioItag audioStream:(YTIFormatStream *)audioStream
                 progress:(void (^)(float fraction, unsigned long long bytesDownloaded))progress
               completion:(void (^)(NSURL *audioURL, NSString *err))completion;
+ (void)cancelCurrent;
@end

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
extern void YouModApplyLiquidGlassToView(UIView *view, BOOL arg);
extern void YouModApplyLiquidGlassBackdropToView(UIView *view, CGFloat cornerRadius);

// Perferences and headers
// For Tweak.x
#import <YouTubeHeader/_ASDisplayView.h>
#import <YouTubeHeader/YTIIcon.h>
#import <YouTubeHeader/YTRightNavigationButtons.h>
#import <YouTubeHeader/YTIElementRenderer.h>
#import <YouTubeHeader/YTPlayerBarController.h>
#import <YouTubeHeader/YTPlayerViewController.h>
#import <YouTubeHeader/YTWatchController.h>
#import <YouTubeHeader/YTIMenuConditionalServiceItemRenderer.h>
#import <YouTubeHeader/YTIPivotBarRenderer.h>
#import <YouTubeHeader/YTPivotBarItemView.h>
#import <YouTubeHeader/YTActionSheetAction.h>
#import <YouTubeHeader/YTIMenuItemSupportedRenderers.h>
#import <YouTubeHeader/YTMainAppControlsOverlayView.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayView.h>
#import <YouTubeHeader/YTMainAppVideoPlayerOverlayViewController.h>
#import <YouTubeHeader/YTVideoQualitySwitchOriginalController.h>
#import <YouTubeHeader/YTVideoQualitySwitchRedesignedController.h>
#import <YouTubeHeader/YTInnerTubeCollectionViewController.h>
#import <YouTubeHeader/YTIShowFullscreenInterstitialCommand.h>
#import <YouTubeHeader/YTISectionListRenderer.h>
#import <YouTubeHeader/YTIShelfRenderer.h>
#import <YouTubeHeader/YTIWatchNextResponse.h>
#import <YouTubeHeader/YTPlayerOverlay.h>
#import <YouTubeHeader/YTPlayerOverlayProvider.h>
#import <YouTubeHeader/YTReelModel.h>
#import <YouTubeHeader/YTAlertView.h>
#import <YouTubeHeader/YTVarispeedSwitchController.h>
#import <YouTubeHeader/YTVarispeedSwitchControllerOption.h>
#import <YouTubeHeader/YTInlinePlayerBarContainerView.h>
#import <YouTubeHeader/YTSingleVideoTime.h>
#import <YouTubeHeader/YTSingleVideoController.h>
#import <YouTubeHeader/YTPlayerView.h>
#import <YouTubeHeader/YTShortsPlayerViewController.h>
#import <YouTubeHeader/YTReelPlayerViewController.h>
#import <YouTubeHeader/YTLabel.h>
#import <YouTubeHeader/MLFormat.h>
#import <YouTubeHeader/MLQuickMenuVideoQualitySettingFormatConstraint.h>
#import <YouTubeHeader/YTCommonColorPalette.h>
#import <YouTubeHeader/YTIPivotBarSupportedRenderers.h>
#import <YouTubeHeader/YTIBrowseRequest.h>
#import <YouTubeHeader/YTAssetLoader.h>
#import <MediaPlayer/MediaPlayer.h>
#import <YouTubeHeader/ASCollectionView.h>
#import <YouTubeHeader/YTColor.h>
#import <YouTubeHeader/YTTypeStyle.h>
#import <YouTubeHeader/YTModularPlayerBarController.h>
#import <dlfcn.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>
#import <YouTubeHeader/YTAppViewControllerImpl.h>
#import <YouTubeHeader/YTAppViewController.h>
#import <YouTubeHeader/YTDefaultSheetController.h>
#import <YouTubeHeader/YTIFormatStream.h>
#import <YouTubeHeader/YTIPlayerResponse.h>
#import <YouTubeHeader/YTPlayerResponse.h>
#import <YouTubeHeader/YTIVideoDetails.h>
#import <YouTubeHeader/YTIStreamingData.h>
#import <YouTubeHeader/YTIFormattedString.h>
#import <YouTubeHeader/GOOHUDManagerInternal.h>
#import <YouTubeHeader/MLInnerTubeCaptionTrack.h>
#import <YouTubeHeader/MLCaption.h>
#import <YouTubeHeader/MLFormat3Captions.h>
#import <YouTubeHeader/YTFormat3CaptionViewController.h>

// For Settings.x and SponsorBlockSettings.x
#import <PSHeader/Misc.h>
#import <YouTubeHeader/YTSettingsGroupData.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import <YouTubeHeader/YTUIUtils.h>

#define DownloadFix @"YouModDownloadFix"
#define DownloadServerIndex @"YouModDownloadServerIndex"

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
// Downloading
#define DownloadManager @"YouModDownloadManager"
#define DownloadSaveToPhotos @"YouModDownloadSaveToPhotos"
#define AddDownloadToShorts @"YouModAddDownloadToShorts"
#define UseOrigAudio @"YouModUseOrigAudio"
// Cache
#define AutoClearCache @"YouModAutoClearCache"
// Appearance
#define OLEDTheme @"YouModEnablesOLEDTheme"
#define OLEDKeyboard @"YouModEnablesOLEDKeyboard"
// Navigation bar
#define HideYTLogo @"YouModHideYTLogo"
#define YTPremiumLogo @"YouModYTPremiumLogo"
#define StickyNavBar @"YouModStickyNavBar"
#define HideNoti @"YouModHideNotificationButton"
#define HideSearch @"YouModHideSearchButton"
#define HideVoiceSearch @"YouModHideVoiceSearchButton"
#define HideCastButtonNav @"YouModHideCastButtonNavigationBar"
// Feed
#define HideSubbar @"YouModHideSubbar"
#define HideHoriShelf @"YouModHideHoriShelf"
#define HideGenMusicShelf @"YouModHideGenMusicShelf"
#define HideFeedPost @"YouModHideFeedPost"
#define HidePlayables @"YouModHidePlayables"
#define HideShortsShelf @"YouModHideShortsShelf"
#define KeepShortsSubscript @"YouModKeepShortsSubscript"
#define HideSearchHis @"YouModHideSearchHistoryAndSuggestions"
#define HideSurveys @"YouModHideSurveys"
// Player
#define WifiQualityIndex @"YouModWifiQualityIndex"
#define CellQualityIndex @"YouModCellQualityIndex"
#define LowPowerQualityIndex @"YouModLowPowerQualityIndex"
#define AudioTrack @"YouModAudioTrackSegment"
#define AudioTrackLangIndex @"YouModAudioTrackLangIndex"
#define NoDubbedAudioTrack @"YouModNoDubbedAudioTrack"
#define CaptionTrack @"YouModCaptionTrack"
#define CaptionTrackLangIndex @"YouModCaptionTrackLangIndex"
#define DisablesCaptionTrack @"YouModDisablesCaptionTrack"
#define AutoSpeedIndex @"YouModAutoSpeedIndex"
#define HoldToSpeedIndex @"YouModHoldToSpeedIndex"
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
#define UseAnotherMiniplayer @"YouModUseAnotherMiniplayer"
#define SeekOnOverlay @"YouModSeekOnOverlay"
#define LockSpeed @"YouModLockSpeed"
#define RememberLoop @"YouModRememberLoop"
// Shorts
#define FullScreenShorts @"YouModFullScreenShorts"
#define RemoveShortsLive @"YouModRemoveShortsLive"
#define RemoveShortsPosts @"YouModRemoveShortsPosts"
#define HideShortsProducts @"YouModHideShortsProducts"
#define HideShortsRecbar @"YouModHideShortsRecbar"
#define EnablesShortsQuality @"YouModEnablesShortsQuality"
#define ShowShortsSeekbar @"YouModShowShortsSeekbar"
#define ShortsActionIndex @"YouModMakeAShortsAction"
#define ShortsOnly @"YouModShortsOnly"
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
#define HideLikeDislikeVotes @"YouModHideLikeDislikeVotes"
#define HideCommuGuide @"YouModHideCommuGuide"
#define DisablesRTL @"YouModDisablesRTL"
#define DeviceUIIndex @"YouModDeviceUIIndex"
#define FloatingKeyboard @"YouModFloatingKeyboard"
// #define CustomStartup @"YouModUseCustomVideoStartup"
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
// SponsorBlock
#define SBEnabled @"YouModSBEnabled"
#define SBShowButton @"YouModSBShowButton"
#define SBShowNotifications @"YouModSBShowNotifications"
#define SBAudioNotification @"YouModSBAudioNotification"
#define SBSegmentsInPlayer @"YouModSBSegmentsInPlayer"
#define SBSegmentsInFeed @"YouModSBSegmentsInFeed"
#define SBSegmentsInMiniPlayer @"YouModSBSegmentsInMiniPlayer"
#define SBShowDuration @"YouModSBShowDuration"
#define SBMinDuration @"YouModSBMinDuration"
#define SBSkipAlertDuration @"YouModSBSkipAlertDuration"
#define SBUnskipAlertDuration @"YouModSBUnskipAlertDuration"

#define SB_ACTION_KEY(cat) [NSString stringWithFormat:@"YouModSBAction_%@", cat]
#define SB_COLOR_KEY(cat) [NSString stringWithFormat:@"YouModSBColor_%@", cat]

#define FLOAT_FOR_KEY(k) [[NSUserDefaults standardUserDefaults] floatForKey:k]

#define YT_BUNDLE_ID @"com.google.ios.youtube"
#define YT_NAME @"YouTube"

@interface YTMenuItemMDCButton : UIButton
@end

@interface YTPageHeaderViewController : UIViewController
@end

@interface YTIPageHeaderRenderer : GPBMessage
@end

@interface YTDefaultSheetController (YouMod)
+ (instancetype)sheetControllerWithParentResponder:(id)parentResponder;
- (void)addAction:(YTActionSheetAction *)action;
- (void)presentFromView:(UIView *)view animated:(BOOL)animated completion:(void (^)(void))completion;
- (void)presentFromViewController:(UIViewController *)vc animated:(BOOL)animated completion:(void (^)(void))completion;
- (void)addHeaderWithTitle:(NSString *)arg1 subtitle:(NSString *)arg2;
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

@interface YTELMViewController : UIViewController
@end

@interface YTInlineScrubGestureView : UIView
@end

@interface YTReelContainerViewController : UIViewController
@end

@interface YTAppReelWatchRootViewController : UIViewController
@end

@interface YTPivotBarView : UIView
@end

@interface YTPivotBarItemView (YouMod) <UIContextMenuInteractionDelegate>
@end

@interface YTContextualSheetView : UIView
@end

@interface YTShortsAdsPlayerViewController : YTReelPlayerViewController
@end

@interface YTIBrowseRequest (YouMod)
+ (NSString *)browseIDForGamingDestination;
+ (NSString *)browseIDForSportsDestination;
+ (NSString *)browseIDForNotificationsInbox;
+ (NSString *)browseIDForHistory;
@end

@interface YTITopbarLogoRenderer : NSObject
@property(readonly, nonatomic) YTIIcon *iconImage;
@end

@interface YTRightNavigationButtons (YouMod)
@property (nonatomic, strong) YTQTMButton *notificationButton;
@property (nonatomic, strong) YTQTMButton *searchButton;
@end

@interface YTMainAppVideoPlayerOverlayView (YouMod)
@property (nonatomic, weak, readwrite) YTMainAppVideoPlayerOverlayViewController *delegate;
@property (nonatomic, strong) YTQTMButton *playbackRouteButton;
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
- (void)YouModReloadTabBar:(id)arg;
@end

@interface YTAppViewController (YouMod)
@property (nonatomic, assign, readonly) YTPivotBarViewController *pivotBarViewController;
- (void)hidePivotBar;
- (void)showPivotBar;
- (void)refreshPivotBarWithTriggedByNotification:(BOOL)arg;
- (BOOL)isPivotBarHidden;
@end

@interface YTAppViewControllerImpl (YouMod)
@property (nonatomic, assign, readonly) YTPivotBarViewController *pivotBarViewController;
- (void)hidePivotBar;
- (void)showPivotBar;
- (void)refreshPivotBarWithTriggedByNotification:(BOOL)arg;
- (BOOL)isPivotBarHidden;
@end

@interface YTReelWatchPlaybackOverlayView : UIView <UIGestureRecognizerDelegate>
@property (nonatomic, retain) UIPinchGestureRecognizer *YouModFullscreenGesture;
@end

@interface YTReelContentView (YouMod) <UIGestureRecognizerDelegate>
@property (nonatomic, retain) UILongPressGestureRecognizer *YouModExitShortsOnlyGesture;
- (YTReelWatchPlaybackOverlayView *)playbackOverlay;
@end

@interface YTLanguages : NSObject
+ (instancetype)languageList;
@end

@interface YTICaptionTrackEntry : GPBMessage
- (NSString *)baseURL;
- (NSString *)vssId;
- (NSString *)languageCode;
- (YTIFormattedString *)name;
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
@property (nonatomic, assign) BOOL YouModIsSpeedLocked;
@property (nonatomic, assign) CGFloat YouModSavedNormalRate;
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer;
- (void)YouModAutoFullscreen;
- (void)YouModSetAutoSpeed;
- (void)setPlaybackRate:(float)rate;
- (void)setActiveCaptionTrack:(MLInnerTubeCaptionTrack *)arg1 source:(NSInteger)arg2;
- (void)setActiveCaptionTrack:(MLInnerTubeCaptionTrack *)arg;
- (void)play;
- (void)pause;
- (void)YouModAutoMute;
- (void)YouModAutoAudioTrack;
- (void)YouModAutoCaptions;
- (void)YouModLoopButton;
- (void)YouModAutoLoop;
- (void)YouModCaptionsHelper:(MLInnerTubeCaptionTrack *)arg;
- (void)YouModShareButton:(UIView *)sourceView;
- (NSInteger)playerState;
- (YTPlayerResponse *)contentPlayerResponse;
- (YTPlayerResponse *)playerResponse;
- (id)audioTrackController;
- (void)setAudioTrack:(YTIAudioTrack *)arg1 source:(NSInteger)arg2;
- (void)YouModHideSpeedToast;
- (void)YouModShowSpeedToast:(CGFloat)speed isLocked:(BOOL)isLocked;
@end

@interface YTPlayerBarController (YouMod)
- (void)didScrub:(UIPanGestureRecognizer *)gesture;
@end

@interface YTAutoplayAutonavController : NSObject
- (void)setLoopMode:(NSInteger)loopMode;
@end

@interface YTInlineMutedPlaybackPlayerOverlayViewController : UIViewController
@end

@interface YTInlineMutedPlaybackPlayerOverlayView : UIView
@end

@interface YTWatchFloatingMiniplayerViewController : UIViewController
@end

@interface YTWatchFloatingMiniplayerWithPersistentControlsView : UIView
@end

@interface YTWatchFloatingMiniplayerProgressBarView : UIView
@end

@interface SSOConfiguration : NSObject
@end

@interface YTIMySubsFilterHeaderRenderer : GPBMessage
@end

@interface YTMySubsFilterHeaderViewController : UIViewController
@end

@interface YTEngagementPanelView : UIView
- (UIView *)footerView;
@end

@interface YTMainAppControlsOverlayView (YouMod)
- (YTMainAppVideoPlayerOverlayViewController *)eventsDelegate;
@end

@interface YTVideoQualitySwitchOriginalController (YouMod)
@property (retain, nonatomic) YTVideoQualitySwitchRedesignedController *redesignedController;
@end

@interface UIView (Private)
@property (nonatomic, assign, readonly) BOOL _mapkit_isDarkModeEnabled;
- (UIViewController *)_viewControllerForAncestor;
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

@interface YTAppDelegate : UIResponder
- (void)YouModAutoClearCache;
@end

@interface YTInlinePlayerBarContainerView (YouMod)
@property (nonatomic, strong) NSString *endTimeString;
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

// Player Gestures - @bhackel (YTLitePlus)
@interface YTMainAppVideoPlayerOverlayViewController (YouMod)
@property (nonatomic, assign) YTPlayerViewController *parentViewController;
- (YTCaptionTrackSwitchController *)captionTrackController;
- (NSString *)videoID;
- (CGFloat)mediaTime;
- (void)setVideoFreeZoomOverlayController:(id)arg;
@end

@interface YTSingleVideoController (YouMod)
@property (nonatomic, assign, readonly) CGFloat totalMediaTime;
- (YTSingleVideoTime *)currentVideoTime;
- (void)setVideoFormatConstraint:(id)arg;
- (void)YouModAutoQuality;
- (NSArray *)availableCaptionTracks;
- (MLInnerTubeCaptionTrack *)activeCaptionTrack;
@end

@interface YTReelPlayerViewController (YouMod)
- (void)reelContentViewRequestsAdvanceToNextVideo:(id)arg;
- (void)reelContentViewRequestsPlayPauseToggle:(id)arg;
- (id)audioTrackController;
- (void)YouModAutoAudioTrack:(YTPlayerViewController *)pv;
- (void)YouModOnlyShorts;
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
- (int)fps;
- (YTIAudioTrack *)audioTrack;
- (int)itag;
@end

@interface YTIFormattedString (YouMod)
- (NSString *)dropdownOptionTitle;
@end

@interface YTIVideoDetails (YouMod)
- (NSString *)title;
- (NSString *)author;
- (NSString *)shortDescription;
@end

@interface YTDataUtils : NSObject
+ (instancetype)generateClientSideNonce;
@end

@interface YCHAsyncLiveChatCollectionViewController : UIViewController
@end

@interface YTStartupAnimationViewController : UIViewController
@end

// SponsorBlock action modes
typedef NS_ENUM(NSInteger, SBSegmentAction) {
    SBSegmentActionDisable = 0,
    SBSegmentActionAutoSkip = 1,
    SBSegmentActionAsk = 2,
    SBSegmentActionDisplay = 3,
    SBSegmentActionSkipTo = 4
};

@interface SBSegment : NSObject
@property (nonatomic, strong) NSString *UUID;
@property (nonatomic, strong) NSString *category;
@property (nonatomic, assign) float startTime;
@property (nonatomic, assign) float endTime;
@property (nonatomic, strong) NSString *actionType;
+ (instancetype)segmentWithUUID:(NSString *)UUID category:(NSString *)category start:(float)start end:(float)end action:(NSString *)actionType;
- (SBSegmentAction)configuredAction;
- (UIColor *)segmentColor;
@end

@interface SBRequest : NSObject
+ (void)fetchSegmentsForVideoID:(NSString *)videoID completion:(void (^)(NSArray<SBSegment *> *segments))completion;
@end

@interface SBSkipNotificationView : UIView
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UIView *progressOverlay;
@property (nonatomic, copy) void (^onAction)(void);
@property (nonatomic, assign) NSTimeInterval totalDuration;
@property (nonatomic, assign) NSTimeInterval remainingDuration;
@property (nonatomic, assign) BOOL isPaused;
@property (nonatomic, assign) BOOL isHighlightPill;
@property (nonatomic, strong) NSDate *backgroundDate;
+ (instancetype)showInView:(UIView *)parentView message:(NSString *)message buttonTitle:(NSString *)buttonTitle action:(void (^)(void))action duration:(NSTimeInterval)duration;
+ (instancetype)showSuccessInView:(UIView *)parentView message:(NSString *)message duration:(NSTimeInterval)duration;
+ (instancetype)showErrorInView:(UIView *)parentView message:(NSString *)message duration:(NSTimeInterval)duration;
- (void)dismiss;
- (void)pauseProgress;
- (void)resumeProgress;
@end

extern UIView *sbGetNotificationParent(void);
extern void sbUpdateOverlayInsetForPivotBar(void);
extern void YMPresentTabOrderModally(id parentResponder);

// The ordered set of SponsorBlock categories YouMod supports. Both the core
// (segment fetching / skipping) and the settings UI read from this single list,
// so a category can never be fetchable without a control, or configurable
// without being fetched.
extern NSArray<NSString *> *sbAllCategories(void);

// Tag stamped on every seek-bar segment marker view, used to find and remove
// them across the player-bar layout hooks that don't hold a direct reference.
static const NSInteger SBSegmentMarkerTag = 9900;

// Supported range and default for the skip/unskip banner duration (seconds).
// The settings sliders expose this range and the core clamps stored values to
// it, so both read from one source and can never drift out of agreement.
static const CGFloat SBAlertDurationMin = 2.0;
static const CGFloat SBAlertDurationMax = 20.0;
static const CGFloat SBAlertDurationDefault = 4.0;

#pragma mark - Custom Overlay Button Registry

// A registered button shown in the player's controls overlay (top-right, under
// YouTube's settings gear). Features register a spec from their own %ctor; the
// single YTMainAppControlsOverlayView hook in OverlayButtons.x lays them all out.
@interface YMOverlayButtonSpec : NSObject
@property (nonatomic, copy) NSString *identifier;       // unique, e.g. @"sponsorblock.toggle"
@property (nonatomic, copy) NSString *symbolName;       // SF Symbol name (icon button)
@property (nonatomic, copy) NSString *title;            // text label; set this instead of symbolName for a text button
@property (nonatomic, strong) UIColor *tintColor;       // default tint (used if tintProvider is nil)
@property (nonatomic, assign) NSInteger sortOrder;      // ascending; lower = closer to gear (rightmost)
@property (nonatomic, copy) void (^onTap)(YTPlayerViewController *player, YTQTMButton *button);
@property (nonatomic, copy) BOOL (^isVisible)(YTPlayerViewController *player);     // nil = always visible
@property (nonatomic, copy) UIColor *(^tintProvider)(YTPlayerViewController *player); // nil = use tintColor
@property (nonatomic, assign) NSInteger viewTag;        // assigned by the registry; do not set
@end

extern void YMRegisterOverlayButton(YMOverlayButtonSpec *spec);
extern NSArray<YMOverlayButtonSpec *> *YMRegisteredOverlayButtons(void);

@interface YMDownloadProgressView : UIView
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIProgressView *progressBar;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, copy) void (^onCancel)(void);
+ (instancetype)showInView:(UIView *)parentView message:(NSString *)message cancelAction:(void (^)(void))cancelAction;
- (void)updateProgress:(float)progress title:(NSString *)title subtitle:(NSString *)subtitle;
- (void)dismiss;
@end

@interface YTPlayerViewController (SponsorBlock)
@property (nonatomic, strong) NSString *sbLastVideoID;
@property (nonatomic, strong) NSArray<SBSegment *> *sbSegments;
@property (nonatomic, strong) NSMutableSet<NSString *> *sbSkippedSegments;
@property (nonatomic, strong) SBSkipNotificationView *sbNotificationView;
@property (nonatomic, assign) BOOL sbEnabledForVideo;
- (void)sbCheckSegmentsAtCurrentTime;
- (void)sbPerformSkip:(SBSegment *)segment;
- (void)sbShowAskNotification:(SBSegment *)segment;
- (void)sbShowHighlightBannerIfNeeded:(NSArray<SBSegment *> *)segments;
- (void)sbSkipToHighlight;
- (void)sbRefreshMarkers:(NSArray<SBSegment *> *)segments;
@end

@interface YTSegmentableInlinePlayerBarView : UIView
@property (nonatomic, assign, readwrite) BOOL enableSnapToChapter;
@property (nonatomic, strong) NSArray<UIView *> *sbMarkerViews;
- (void)sbRenderSegments:(NSArray<SBSegment *> *)segments;
- (void)sbClearSegments;
- (void)sbRepositionMarkers;
@end

@interface YouModThumbnailViewController : UIViewController <UIScrollViewDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIImage *thumbnailImage;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIImageView *imageView;
@end

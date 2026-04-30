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
#import <YouTubeHeader/YTVarispeedSwitchControllerImpl.h>
#import <YouTubeHeader/YTVarispeedSwitchControllerOption.h>
#import <YouTubeHeader/YTMultiSizeViewController.h>
#import <YouTubeHeader/YTInlinePlayerBarContainerView.h>
#import <dlfcn.h>

// For Settings.x
#import <PSHeader/Misc.h>
#import <YouTubeHeader/YTSettingsGroupData.h>
#import <YouTubeHeader/YTSettingsPickerViewController.h>
#import <YouTubeHeader/YTSettingsSectionItem.h>
#import <YouTubeHeader/YTSearchableSettingsViewController.h>
#import <YouTubeHeader/YTSettingsSectionItemManager.h>
#import <YouTubeHeader/YTSettingsViewController.h>
#import <YouTubeHeader/YTToastResponderEvent.h>
#import <YouTubeHeader/YTUIUtils.h>

#define IS_ENABLED(k) [[NSUserDefaults standardUserDefaults] boolForKey:k]
#define INTFORVAL(v) [[NSUserDefaults standardUserDefaults] integerForKey:v]
// Cache
#define AutoClearCache @"YouModAutoClearCache"
// Appearance
#define OLEDKeyboard @"YouModEnablesOLEDKeyboard"
// Navigation bar
#define HideYTLogo @"YouModHideYTLogo"
#define YTPremiumLogo @"YouModYTPremiumLogo"
#define HideNoti @"YouModHideNotificationButton"
#define HideSearch @"YouModHideSearchButton"
#define HideVoiceSearch @"YouModHideVoiceSearchButton"
#define HideCastButtonNav @"YouModHideCastButtonNavigationBar"
// Feed
#define HideSubbar @"YouModHideSubbar"
#define HideGenMusicShelf @"YouModHideGenMusicShelf"
#define HideFeedPost @"YouModHideFeedPost"
// #define HideShortsShelf @"YouModHideShortsShelf"
#define HideSearchHis @"YouModHideSearchHistoryAndSuggestions"
#define HideSubButton @"YouModHideSubscribeButton"
#define HideShoppingButton @"YouModHideShoppingButton"
#define HideMemberButton @"YouModHideMemberButton"
// Player
#define HideAutoPlayToggle @"YouModHideAutoPlayToggle"
#define HideCaptionsButton @"YouModHideCaptionsButton"
#define HideCastButtonPlayer @"YouModHideCastButtonPlayer"
#define HidePrevButton @"YouModHidePrevButton"
#define HideNextButton @"YouModHideNextButton"
#define RemoveDarkOverlay @"YouModRemoveDarkOverlay"
#define HideEndScreenCards @"YouModHideEndScreenCards"
#define HideSuggestedVideo @"YouModHideSuggestedVideoOnFinish"
#define HidePaidPromoOverlay @"YouModHidePaidPromoOverlay"
#define HideWaterMark @"YouModHideWaterMark"
#define GestureControls @"YouModEnableGesturesControls"
#define DisablesDoubleTap @"YouModDisablesDoubleTap"
#define DisablesLongHold @"YouModDisablesLongHold"
#define AutoExitFullScreen @"YouModAutoExitFullScreen"
#define DisablesShowRemaining @"YouModDisablesShowRemainingTime"
#define AlwaysShowRemaining @"YouModAlwaysShowRemainingTime"
#define HideFullAction @"YouModHideFullScreenAction"
#define HideFullvidTitle @"YouModHideFullscreenVideoTitle"
#define StopAutoplayVideo @"YouModStopAutoplayVideo"
#define HideContentWarning @"YouModHideContentWarning"
#define AutoFullScreen @"YouModAutoFullScreen"
#define PortFull @"YouModPortraitFullscreen"
#define OldQualityPicker @"YouModUseOldQualityPicker"
#define ExtraSpeed @"YouModAddExtraSpeed"
#define HideLikeButton @"YouModHideLikeButton"
#define HideDisLikeButton @"YouModHideDisLikeButton"
#define HideShareButton @"YouModHideShareButton"
#define HideDownloadButton @"YouModHideDownloadButton"
#define HideClipButton @"YouModHideClipButton"
#define HideRemixButton @"YouModHideRemixButton"
#define HideSaveButton @"YouModHideSaveButton"
// Shorts
#define HideShortsLikeButton @"YouModHideShortsLikeButton"
#define HideShortsDisLikeButton @"YouModHideShortsDisLikeButton"
#define HideShortsCommentButton @"YouModHideShortsCommentButton"
#define HideShortsShareButton @"YouModHideShortsShareButton"
#define HideShortsRemixButton @"YouModHideShortsRemixButton"
#define HideShortsMetaButton @"YouModHideShortsMetaButton"
#define HideShortsProducts @"YouModHideShortsProducts"
#define HideShortsRecbar @"YouModHideShortsRecbar"
#define HideShortsCommit @"YouModHideShortsCommit"
#define HideShortsSubscriptButton @"YouModHideShortsSubscriptButton"
#define HideShortsLiveButton @"YouModHideShortsLiveButton"
#define HideShortsLensButton @"YouModHideShortsLensButton"
#define HideShortsTrendsButton @"YouModHideShortsTrendsButton"
#define HideShortsToVideo @"YouModHideShortsToVideo"
#define EnablesShortsQuality @"YouModEnablesShortsQuality"
#define ShowShortsSeekbar @"YouModShowShortsSeekbar"
// Tab bar
#define DefaultTab @"YouModDefaultStartupTab"
#define HideTabIndi @"YouModHideTabIndicators"
#define HideTabLabels @"YouModHideTabLabels"
#define HideHomeTab @"YouModHideHomeTab"
#define HideShortsTab @"YouModHideShortsTab"
#define HideCreateButton @"YouModHideCreateButton"
#define HideSubscriptTab @"YouModHideSubscriptionsTab"
// Miscellaneous
#define BackgroundPlayback @"YouModEnablesBackgroundPlayback"
#define DisablesShortsPiP @"YouModTrytoDisablesShortsPiP"
#define BlockUpgradeDialogs @"YouModBlockUpgradeDialogs"
#define HideAreYouThereDialog @"YouModHideAreYouThereDialog"
#define FixesSlowMiniPlayer @"YouModFixesSlowMiniPlayer"
#define DisablesNewMiniPlayer @"YouModDisablesNewMiniPlayer"
#define DisablesSnackBar @"YouModDisablesSnackBar"
#define HideStartupAni @"YouModHideStartupAnimations"
#define HidePlayInNextQueue @"YouModHidePlayInNextQueue"
#define HideLikeDislikeVotes @"YouModHideLikeDislikeVotes"

#define YT_BUNDLE_ID @"com.google.ios.youtube"
#define YT_NAME @"YouTube"

// Gesture Section Enum
typedef NS_ENUM(NSUInteger, GestureSection) {
    GestureSectionTop,
    GestureSectionBottom,
    GestureSectionInvalid
};

@interface YTITopbarLogoRenderer : NSObject
@property(readonly, nonatomic) YTIIcon *iconImage;
@end

@interface YTRightNavigationButtons (YouMod)
@property (nonatomic, strong) YTQTMButton *notificationButton;
@property (nonatomic, strong) YTQTMButton *searchButton;
@end

@interface YTNavigationBarTitleView : UIView
@end

@interface YTChipCloudCell : UICollectionViewCell
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
@end

@interface YTPlayerViewController (YouMod) <UIGestureRecognizerDelegate>
@property (nonatomic, retain) UIPanGestureRecognizer *YouModPanGesture;
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer;
- (void)YouModAutoFullscreen;
@end

@interface SSOConfiguration : NSObject
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

// Custom perferences logics
@interface YouModPrefsManager : NSObject <UIDocumentPickerDelegate>
+ (instancetype)sharedManager;
- (void)exportYouModSettingsFromVC:(UIViewController *)vc;
- (void)importYouModSettingsFromVC:(UIViewController *)vc;
- (void)restoreYouModDefaults;
@end

// Player Gestures - @bhackel (YTLitePlus)
@interface YTFineScrubberFilmstripView : UIView
@end

@interface YTFineScrubberFilmstripCollectionView : UICollectionView
@end

@interface YTWatchFullscreenViewController : YTMultiSizeViewController
@end

@interface YTPlayerBarController (YouMod)
- (void)didScrub:(UIPanGestureRecognizer *)gestureRecognizer;
- (void)startScrubbing;
- (void)didScrubToPoint:(CGPoint)point;
- (void)endScrubbingForSeekSource:(int)seekSource;
@end

@interface YTMainAppVideoPlayerOverlayViewController (YouMod)
@property (nonatomic, strong, readwrite) YTPlayerBarController *playerBarController;
@end

@interface YTInlinePlayerBarContainerView (YouMod)
@property UIPanGestureRecognizer *scrubGestureRecognizer;
@property (nonatomic, strong, readwrite) YTFineScrubberFilmstripView *fineScrubberFilmstrip;
- (CGFloat)scrubXForScrubRange:(CGFloat)scrubRange;
@end
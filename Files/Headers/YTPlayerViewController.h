#import <UIKit/UIKit.h>
#import "GIMMe.h"
#import "YTPlaybackController.h"
#import "YTPlayerOverlayManager.h"
#import "YTPlayerView.h"
#import "YTPlayerViewControllerUIDelegate.h"
#import "YTSingleVideoController.h"
#import "YTVarispeedSwitchController.h"
#import "YTVideoPlayerOverlayDelegate.h"
#import "MLInnerTubeCaptionTrack.h"
#import "YTIAudioTrack.h"
#import "YTPlayerResponse.h"
#import "SBSegment.h"
#import "YMSBCardItem.h"
#import "YMSBCardViewController.h"
#import "YouModPillView.h"

@interface YTPlayerViewController : UIViewController <YTPlaybackController, YTVideoPlayerOverlayDelegate, YTVarispeedSwitchControllerDelegate>
@property (nonatomic, readonly, assign) BOOL isPlayingAd;
@property (nonatomic, strong, readwrite) NSString *channelID;
@property (nonatomic, strong, readwrite) YTPlayerOverlayManager *overlayManager;
@property (nonatomic, weak, readwrite) id <YTPlayerViewControllerUIDelegate> UIDelegate;
- (GIMMe *)gimme; // Deprecated
- (NSString *)currentVideoID;
- (NSString *)contentVideoID;
- (YTSingleVideoController *)activeVideo;
- (YTVarispeedSwitchController *)varispeedController;
- (CGFloat)currentVideoMediaTime;
- (CGFloat)currentVideoTotalMediaTime;
- (int)playerViewLayout;
- (void)replay;
- (void)replayWithSeekSource:(int)seekSource;
- (void)didPressToggleFullscreen;
- (void)setPlayerViewLayout:(int)layout;
- (void)scrubToTime:(CGFloat)time; // Deprecated
- (void)seekToTime:(CGFloat)time;
- (id)activeVideoPlayerOverlay; // YTMainAppVideoPlayerOverlayViewController || YTInlineMutedPlaybackPlayerOverlayViewController
- (YTPlayerView *)playerView;
- (BOOL)isMDXActive;
- (BOOL)isCurrentVideoVertical;
- (BOOL)isInlinePlaybackActive;
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

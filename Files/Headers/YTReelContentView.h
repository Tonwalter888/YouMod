#import <UIKit/UIKit.h>
#import "YTReelWatchPlaybackOverlayView.h"

@interface YTReelContentView : UIView
@property (nonatomic, assign, readwrite) BOOL alwaysShowShortsProgressBar;
- (void)setEmptyStateVisible:(BOOL)visible;
@property (nonatomic, retain) UILongPressGestureRecognizer *YouModExitShortsOnlyGesture;
@property (nonatomic, readonly, strong) YTReelWatchPlaybackOverlayView *playbackOverlay;
@end
#import <UIKit/UIKit.h>
#import "YTReelWatchPlaybackOverlayView.h"

@interface YTReelContentView : UIView
@property (nonatomic, assign, readwrite) BOOL alwaysShowShortsProgressBar;
- (void)setEmptyStateVisible:(BOOL)visible;
@end

@interface YTReelContentView (YouMod)
@property (nonatomic, retain) UILongPressGestureRecognizer *YouModExitShortsOnlyGesture;
@property (nonatomic, retain) UIPinchGestureRecognizer *YouModPinchGesture;
- (YTReelWatchPlaybackOverlayView *)playbackOverlay;
@end

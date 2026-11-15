#import <UIKit/UIKit.h>

#ifdef LEGACY

#import "YTMainAppPlayerOverlayView.h"

@interface YTMainAppVideoPlayerOverlayView : YTMainAppPlayerOverlayView
@end

#else

#import "YTInlinePlayerBarContainerView.h"
#import "YTMainAppControlsOverlayView.h"
#import "YTFullscreenActionsView.h"
#import "YTQTMButton.h"
#import "YTVideoFreeZoomOverlayView.h"

@interface YTMainAppVideoPlayerOverlayView : UIView
@property (nonatomic, strong, readwrite) YTInlinePlayerBarContainerView *playerBar;
- (YTMainAppControlsOverlayView *)controlsOverlayView;
@end

#endif

@class YTMainAppVideoPlayerOverlayViewController; // forward: the VC header imports this view

@interface YTMainAppVideoPlayerOverlayView (YouMod) <UIGestureRecognizerDelegate>
@property (nonatomic, weak, readwrite) YTMainAppVideoPlayerOverlayViewController *delegate;
@property (nonatomic, strong, readwrite) YTFullscreenActionsView *fullscreenActionsView;
- (YTVideoFreeZoomOverlayView *)videoFreeZoomOverlayView;
- (YTQTMButton *)playbackRouteButton;
- (BOOL)isFullscreen;
@end

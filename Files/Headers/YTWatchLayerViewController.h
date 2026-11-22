#import "YTWatchController.h"

// Minimal declaration for the watch layer VC (auto fullscreen retry hook).
@interface YTWatchLayerViewController : UIViewController
- (id)currentWatchController;
- (void)didExpandWatchFlowWithGestureType:(int)gestureType;
@end

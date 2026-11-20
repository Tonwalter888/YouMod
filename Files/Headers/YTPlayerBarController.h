#import "YTInlinePlayerBarContainerView.h"

@interface YTPlayerBarController : NSObject
@property (nonatomic, strong, readwrite) YTInlinePlayerBarContainerView *playerBar;
@end

@interface YTPlayerBarController (YouMod)
- (void)didScrub:(UIPanGestureRecognizer *)gesture;
@end

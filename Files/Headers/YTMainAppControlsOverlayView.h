#import "YTQTMButton.h"
#import "YTPlayerViewController.h"

@interface YTMainAppControlsOverlayView : UIView
+ (CGFloat)topButtonAdditionalPadding;
@property (nonatomic, assign, readwrite, getter=isOverlayVisible) BOOL overlayVisible;
@property (nonatomic, strong, readwrite) YTPlayerViewController *playerViewController;
- (YTQTMButton *)buttonWithImage:(UIImage *)image accessibilityLabel:(NSString *)accessibilityLabel verticalContentPadding:(CGFloat)verticalContentPadding;
@end

@class YTMainAppVideoPlayerOverlayViewController; // forward: the VC header imports this view

@interface YTMainAppControlsOverlayView (YouMod)
- (YTMainAppVideoPlayerOverlayViewController *)eventsDelegate;
@property (nonatomic, assign, readonly) YTQTMButton *overflowButton;
@end

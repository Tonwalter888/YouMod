@interface YTShortsContentPresenterView : UIView
@end

@interface YTShortsContentPresenterView (YouMod) <UIGestureRecognizerDelegate>
@property (nonatomic, retain) UILongPressGestureRecognizer *YouModExitShortsOnlyGesture;
@property (nonatomic, retain) UIPinchGestureRecognizer *YouModPinchGesture;
- (void)YouModAddPinchGesture;
@end

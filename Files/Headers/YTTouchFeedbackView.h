@interface YTTouchFeedbackView : UIView
@property (nonatomic, assign) BOOL forceCircularTouchFeedback;
- (void)attachToViewBelowSubviews:(UIView *)view;
- (void)startTouchBeganAnimation;
- (void)startTouchEndedAnimationWithCompletion:(void (^)(void))completion;
@end

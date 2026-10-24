@interface YTReelContainerView : UIView
@property (nonatomic, retain) UILongPressGestureRecognizer *YouModExitShortsOnlyGesture;
@property (nonatomic, strong, readwrite) UIView *overlayView;
@property (nonatomic, retain) UIPinchGestureRecognizer *YouModPinchGesture;
@end
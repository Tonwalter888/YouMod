// Shared success, error, and action feedback pill (YouModPill.x).
@interface YouModPillView : UIView
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIButton *actionButton;
@property (nonatomic, strong) UIView *progressOverlay;
@property (nonatomic, strong) UIImageView *infoIconView;
@property (nonatomic, assign) BOOL showsInfoIcon;
@property (nonatomic, copy) void (^onAction)(void);
@property (nonatomic, assign) NSTimeInterval totalDuration;
@property (nonatomic, assign) NSTimeInterval remainingDuration;
@property (nonatomic, assign) BOOL isPaused;
@property (nonatomic, assign) BOOL isHighlightPill;
@property (nonatomic, assign) BOOL isDismissing;
@property (nonatomic, strong) NSDate *backgroundDate;
+ (instancetype)showInView:(UIView *)parentView message:(NSString *)message buttonTitle:(NSString *)buttonTitle action:(void (^)(void))action duration:(NSTimeInterval)duration;
+ (instancetype)showDownloadCompleteDialogInView:(UIView *)parentView message:(NSString *)message saveHandler:(void (^)(void))saveHandler shareHandler:(void (^)(void))shareHandler duration:(NSTimeInterval)duration;
+ (instancetype)showSuccessInView:(UIView *)parentView message:(NSString *)message duration:(NSTimeInterval)duration;
+ (instancetype)showErrorInView:(UIView *)parentView message:(NSString *)message duration:(NSTimeInterval)duration;
+ (NSInteger)nextAnimationSequence;
+ (NSInteger)currentAnimationSequence;
+ (void)dismissExistingPillsInView:(UIView *)parentView completion:(void (^)(void))completion;
- (void)dismiss;
- (void)dismissWithCompletion:(void (^)(void))completion;
- (void)pauseProgress;
- (void)resumeProgress;
@end

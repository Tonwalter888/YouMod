@interface YMDownloadProgressView : UIView
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UIProgressView *progressBar;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, copy) void (^onCancel)(void);
@property (nonatomic, assign) BOOL isDismissing;
+ (instancetype)showInView:(UIView *)parentView message:(NSString *)message cancelAction:(void (^)(void))cancelAction;
- (void)updateProgress:(float)progress title:(NSString *)title subtitle:(NSString *)subtitle;
- (void)dismiss;
- (void)dismissWithCompletion:(void (^)(void))completion;
@end

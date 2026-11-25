#import "Headers.h"

#pragma mark - YMDownloadProgressView

static BOOL gYMProgressUserHidden = NO;

@implementation YMDownloadProgressView

+ (BOOL)userHidden { return gYMProgressUserHidden; }
+ (void)setUserHidden:(BOOL)hidden { gYMProgressUserHidden = hidden; }

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [nc addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
        [nc addObserver:self selector:@selector(appDidEnterBackground) name:UISceneDidEnterBackgroundNotification object:nil];
        [nc addObserver:self selector:@selector(appDidEnterBackground) name:UISceneWillDeactivateNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    [super willMoveToSuperview:newSuperview];
    UIView *oldParent = self.superview;
    if (!newSuperview && oldParent) dispatch_async(dispatch_get_main_queue(), ^{ YMToastRelayout(oldParent); });
}

- (void)appDidEnterBackground {
    [self.layer removeAllAnimations];
    [self removeFromSuperview];
    self.transform = CGAffineTransformIdentity;
}

+ (instancetype)showInView:(UIView *)parentView message:(NSString *)message cancelAction:(void (^)(void))cancelAction {
    YMDownloadProgressView *view = [[YMDownloadProgressView alloc] initWithFrame:CGRectZero];
    view.onCancel = cancelAction;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    // Frosted + light-gray dialog background, matching the download sheet and YM pill.
    YouModApplyFrostedPanelBackgroundToView(view);
    // More grey base on 26 SDK hosts.
    if (YMHostBundleSupportsLiquidGlass()) view.backgroundColor = [UIColor systemGray5Color];
    view.layer.cornerRadius = 16.0;
    view.clipsToBounds = YES;

    // Title label
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = message;
    titleLabel.textColor = UIColor.labelColor;
    titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    view.titleLabel = titleLabel;
    [view addSubview:titleLabel];

    // Subtitle label (speed + size)
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.text = @"";
    subtitleLabel.textColor = UIColor.secondaryLabelColor;
    subtitleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    view.subtitleLabel = subtitleLabel;
    [view addSubview:subtitleLabel];

    // Progress bar
    UIProgressView *progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    progressBar.progress = 0.0;
    progressBar.trackTintColor = [[UIColor labelColor] colorWithAlphaComponent:0.12];
    progressBar.progressTintColor = [YMHelpers accentColor];
    progressBar.translatesAutoresizingMaskIntoConstraints = NO;
    progressBar.layer.cornerRadius = 3.0;
    progressBar.clipsToBounds = YES;
    view.progressBar = progressBar;
    [view addSubview:progressBar];

    // Cancel button
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
    [cancelButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill" withConfiguration:config] forState:UIControlStateNormal];
    cancelButton.tintColor = UIColor.secondaryLabelColor;
    cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [cancelButton addTarget:view action:@selector(cancelButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    view.cancelButton = cancelButton;
    [view addSubview:cancelButton];

    // Internal layout
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:16],
        [titleLabel.topAnchor constraintEqualToAnchor:view.topAnchor constant:12],
        [titleLabel.trailingAnchor constraintEqualToAnchor:cancelButton.leadingAnchor constant:-10],

        [subtitleLabel.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:16],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:3],
        [subtitleLabel.trailingAnchor constraintEqualToAnchor:cancelButton.leadingAnchor constant:-10],

        [progressBar.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:16],
        [progressBar.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-16],
        [progressBar.topAnchor constraintEqualToAnchor:subtitleLabel.bottomAnchor constant:10],
        [progressBar.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-14],
        [progressBar.heightAnchor constraintEqualToConstant:6],

        [cancelButton.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-14],
        [cancelButton.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor],
        [cancelButton.widthAnchor constraintEqualToConstant:32],
        [cancelButton.heightAnchor constraintEqualToConstant:32],
    ]];

    // Swipe down to hide (the download keeps going), tap to open the download queue.
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:view action:@selector(handlePan:)];
    [view addGestureRecognizer:pan];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:view action:@selector(handleTap)];
    [view addGestureRecognizer:tap];

    if (!gYMProgressUserHidden) [view attachToParent:parentView];
    return view;
}

- (void)attachToParent:(UIView *)parentView {
    if (!parentView || self.superview || self.isDismissing) return;
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) return;
    NSLayoutConstraint *maxWidth = [self.widthAnchor constraintLessThanOrEqualToConstant:360];
    NSLayoutConstraint *leadingFallback = [self.leadingAnchor constraintGreaterThanOrEqualToAnchor:parentView.leadingAnchor constant:16];
    NSLayoutConstraint *trailingFallback = [self.trailingAnchor constraintLessThanOrEqualToAnchor:parentView.trailingAnchor constant:-16];
    NSLayoutConstraint *preferredWidth = [self.widthAnchor constraintEqualToAnchor:parentView.widthAnchor constant:-32];
    preferredWidth.priority = UILayoutPriorityDefaultHigh;
    YMToastPresent(parentView, self, YES, @[[self.centerXAnchor constraintEqualToAnchor:parentView.centerXAnchor], maxWidth, leadingFallback, trailingFallback, preferredWidth]);

    self.transform = CGAffineTransformMakeTranslation(0, 80);
    self.alpha = 0;
    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.transform = CGAffineTransformIdentity;
        self.alpha = 1.0;
    } completion:nil];
}

- (void)handleTap {
    Class queueClass = NSClassFromString(@"YMDownloadQueueViewController");
    UIViewController *top = [YMHelpers topViewController:nil];
    if (!top || (queueClass && [top isKindOfClass:queueClass])) return;
    YMDownloadQueuePresent(top);
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if (self.isDismissing) return;
    CGFloat dy = [gesture translationInView:self.superview].y;
    switch (gesture.state) {
        case UIGestureRecognizerStateChanged:
            self.transform = CGAffineTransformMakeTranslation(0, MAX(0, dy));
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            if (dy > 30 || [gesture velocityInView:self.superview].y > 500) {
                gYMProgressUserHidden = YES;
                NSString *hint = LOC(@"DOWNLOAD_PROGRESS_HIDDEN");
                YouModSendToast([hint isEqualToString:@"DOWNLOAD_PROGRESS_HIDDEN"] ? @"Still downloading. See progress in the download queue." : hint);
                self.isDismissing = YES;
                [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
                    self.transform = CGAffineTransformMakeTranslation(0, self.bounds.size.height + 80);
                    self.alpha = 0.0;
                } completion:^(BOOL finished) {
                    [self removeFromSuperview];
                    self.isDismissing = NO;   // detached, not finished: it can come back for the next queue run
                    self.transform = CGAffineTransformIdentity;
                }];
            } else {
                [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
                    self.transform = CGAffineTransformIdentity;
                } completion:nil];
            }
            break;
        }
        default:
            break;
    }
}

- (void)updateProgress:(float)progress title:(NSString *)title subtitle:(NSString *)subtitle {
    if (!self.superview && !gYMProgressUserHidden) [self attachToParent:sbGetNotificationParent()];
    self.titleLabel.text = title;
    self.subtitleLabel.text = subtitle;
    [self.progressBar setProgress:progress animated:YES];
}

- (void)cancelButtonTapped {
    if (self.onCancel) {
        self.onCancel();
        [self dismiss];
    }
}

- (void)dismissWithCompletion:(void (^)(void))completion {
    if (self.isDismissing) {
        if (completion) completion();
        return;
    }
    self.isDismissing = YES;
    if (!self.superview) {
        if (completion) completion();
        return;
    }
    [self.layer removeAllAnimations];
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.transform = CGAffineTransformMakeTranslation(0, 80);
        self.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        if (completion) completion();
    }];
}

- (void)dismiss {
    [self dismissWithCompletion:nil];
}

@end


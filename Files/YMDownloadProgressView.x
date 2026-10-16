#import "Headers.h"

#pragma mark - YMDownloadProgressView

@implementation YMDownloadProgressView

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

- (void)appDidEnterBackground {
    self.isDismissing = YES;
    [self.layer removeAllAnimations];
    self.alpha = 0.0;
    [self removeFromSuperview];
}

+ (instancetype)showInView:(UIView *)parentView message:(NSString *)message cancelAction:(void (^)(void))cancelAction {
    if (!parentView || [UIApplication sharedApplication].applicationState == UIApplicationStateBackground) return nil;

    NSInteger sequence = [YouModPillView nextAnimationSequence];

    YMDownloadProgressView *view = [[YMDownloadProgressView alloc] initWithFrame:CGRectZero];
    view.onCancel = cancelAction;
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    view.layer.cornerRadius = 16.0;
    view.clipsToBounds = YES;
    view.layer.borderWidth = 0.5;
    view.layer.borderColor = [UIColor colorWithWhite:0.25 alpha:1.0].CGColor;

    // Title label
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = message;
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    view.titleLabel = titleLabel;
    [view addSubview:titleLabel];

    // Subtitle label (speed + size)
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.text = @"";
    subtitleLabel.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
    subtitleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    view.subtitleLabel = subtitleLabel;
    [view addSubview:subtitleLabel];

    // Progress bar
    UIProgressView *progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    progressBar.progress = 0.0;
    progressBar.trackTintColor = [UIColor colorWithWhite:0.22 alpha:1.0];
    progressBar.progressTintColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.9 alpha:1.0];
    progressBar.translatesAutoresizingMaskIntoConstraints = NO;
    progressBar.layer.cornerRadius = 3.0;
    progressBar.clipsToBounds = YES;
    view.progressBar = progressBar;
    [view addSubview:progressBar];

    // Cancel button
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
    [cancelButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill" withConfiguration:config] forState:UIControlStateNormal];
    cancelButton.tintColor = [UIColor colorWithWhite:0.45 alpha:1.0];
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

    // Dismiss existing pill if present, then present new progress pill
    [YouModPillView dismissExistingPillsInView:parentView completion:^{
        if (sequence != [YouModPillView currentAnimationSequence]) return;
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) return;

        [parentView addSubview:view];

        // Center horizontally with max width
        NSLayoutConstraint *centerX = [view.centerXAnchor constraintEqualToAnchor:parentView.centerXAnchor];
        NSLayoutConstraint *maxWidth = [view.widthAnchor constraintLessThanOrEqualToConstant:360];
        NSLayoutConstraint *leadingFallback = [view.leadingAnchor constraintGreaterThanOrEqualToAnchor:parentView.leadingAnchor constant:16];
        NSLayoutConstraint *trailingFallback = [view.trailingAnchor constraintLessThanOrEqualToAnchor:parentView.trailingAnchor constant:-16];
        NSLayoutConstraint *preferredWidth = [view.widthAnchor constraintEqualToAnchor:parentView.widthAnchor constant:-32];
        preferredWidth.priority = UILayoutPriorityDefaultHigh;

        [NSLayoutConstraint activateConstraints:@[
            centerX, maxWidth, leadingFallback, trailingFallback, preferredWidth,
            [view.bottomAnchor constraintEqualToAnchor:parentView.safeAreaLayoutGuide.bottomAnchor constant:-12],
        ]];

        // Slide-up animation
        view.transform = CGAffineTransformMakeTranslation(0, 80);
        view.alpha = 0;
        [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
            view.transform = CGAffineTransformIdentity;
            view.alpha = 1.0;
        } completion:nil];
    }];

    return view;
}

- (void)updateProgress:(float)progress title:(NSString *)title subtitle:(NSString *)subtitle {
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


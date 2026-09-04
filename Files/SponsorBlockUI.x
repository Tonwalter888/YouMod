#import "Headers.h"
#import <objc/message.h>

extern BOOL useBackwardIconForButton;

// Range segments render as a filled bar at least this wide so very short segments
// stay visible. Point segments (poi_highlight) have no duration, so they render as
// a fixed-width tick centered on their position via the x-offset.
static const CGFloat SBMarkerMinWidth = 2.0;
static const CGFloat SBPoiMarkerWidth = 3.0;
static const CGFloat SBPoiMarkerXOffset = 1.5;

#pragma mark - SBSkipNotificationView Implementation

static NSInteger sbCurrentPillSequence = 0;

static void YMDismissExistingPillsInView(UIView *parentView, void (^completion)(void)) {
    if (!parentView) {
        if (completion) completion();
        return;
    }
    NSMutableArray<UIView *> *existingPills = [NSMutableArray array];
    for (UIView *sub in [parentView.subviews copy]) {
        if ([sub isKindOfClass:[SBSkipNotificationView class]] || [sub isKindOfClass:[YMDownloadProgressView class]]) {
            [existingPills addObject:sub];
        }
    }

    if (existingPills.count == 0) {
        if (completion) completion();
        return;
    }

    __block NSInteger remaining = existingPills.count;
    for (UIView *pill in existingPills) {
        if ([pill respondsToSelector:@selector(dismissWithCompletion:)]) {
            [(id)pill dismissWithCompletion:^{
                remaining--;
                if (remaining <= 0) {
                    if (completion) completion();
                }
            }];
        } else if ([pill respondsToSelector:@selector(dismiss)]) {
            [(id)pill dismiss];
            remaining--;
            if (remaining <= 0) {
                if (completion) completion();
            }
        } else {
            [pill removeFromSuperview];
            remaining--;
            if (remaining <= 0) {
                if (completion) completion();
            }
        }
    }
}

@implementation SBSkipNotificationView

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
    [self.progressOverlay.layer removeAllAnimations];
    [self.layer removeAllAnimations];
    self.alpha = 0.0;
    [self removeFromSuperview];
}

+ (instancetype)showInView:(UIView *)parentView message:(NSString *)message buttonTitle:(NSString *)buttonTitle action:(void (^)(void))action duration:(NSTimeInterval)duration {
    if (!parentView || [UIApplication sharedApplication].applicationState == UIApplicationStateBackground) return nil;

    NSInteger sequence = ++sbCurrentPillSequence;

    SBSkipNotificationView *view = [[SBSkipNotificationView alloc] initWithFrame:CGRectZero];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.clipsToBounds = YES;
    view.layer.cornerRadius = 22.0;
    view.onAction = action;
    view.totalDuration = duration;
    view.remainingDuration = duration;
    view.isPaused = NO;

    // Base layer (revealed as progress depletes)
    view.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];

    // Progress overlay (shrinks from right to left)
    UIView *progressOverlay = [[UIView alloc] initWithFrame:CGRectZero];
    progressOverlay.translatesAutoresizingMaskIntoConstraints = YES;
    progressOverlay.backgroundColor = [UIColor colorWithWhite:0.18 alpha:1.0];
    progressOverlay.userInteractionEnabled = NO;
    progressOverlay.layer.anchorPoint = CGPointMake(0, 0.5);
    progressOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    view.progressOverlay = progressOverlay;
    [view addSubview:progressOverlay];

    // Message label
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = message;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    label.numberOfLines = 2;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    view.messageLabel = label;
    [view addSubview:label];

    // Icon button (right side)
    BOOL showButton = (buttonTitle != nil || action != nil);
    UIButton *button = nil;

    if (showButton) {
        button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.translatesAutoresizingMaskIntoConstraints = NO;

        NSString *iconName = useBackwardIconForButton ? @"backward.fill" : @"forward.end.fill";
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium];
        UIImage *icon = [UIImage systemImageNamed:iconName withConfiguration:config];
        [button setImage:icon forState:UIControlStateNormal];
        button.tintColor = [UIColor whiteColor];
        button.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
        button.layer.cornerRadius = 16.0;
        button.clipsToBounds = YES;
        [button addTarget:view action:@selector(actionButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        view.actionButton = button;
        [view addSubview:button];
    }

    // Internal layout
    if (showButton) {
        [NSLayoutConstraint activateConstraints:@[
            [label.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:16.0],
            [label.centerYAnchor constraintEqualToAnchor:view.centerYAnchor],
            [label.trailingAnchor constraintEqualToAnchor:button.leadingAnchor constant:-10.0],

            [button.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-8.0],
            [button.centerYAnchor constraintEqualToAnchor:view.centerYAnchor],
            [button.widthAnchor constraintEqualToConstant:32.0],
            [button.heightAnchor constraintEqualToConstant:32.0]
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [label.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:16.0],
            [label.centerYAnchor constraintEqualToAnchor:view.centerYAnchor],
            [label.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-40.0],
        ]];
    }

    // Pan gesture for interactive dismissal
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:view action:@selector(handlePan:)];
    [view addGestureRecognizer:pan];

    // Dismiss existing pill if present, then present new pill
    YMDismissExistingPillsInView(parentView, ^{
        if (sequence != sbCurrentPillSequence) return;
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) return;

        [parentView addSubview:view];

        // Layout: centered horizontally, anchored above tab bar via safe area
        NSLayoutConstraint *maxWidth = [view.widthAnchor constraintLessThanOrEqualToAnchor:parentView.widthAnchor multiplier:0.85];
        [NSLayoutConstraint activateConstraints:@[
            [view.centerXAnchor constraintEqualToAnchor:parentView.centerXAnchor],
            [view.bottomAnchor constraintEqualToAnchor:parentView.safeAreaLayoutGuide.bottomAnchor constant:-60.0],
            [view.heightAnchor constraintEqualToConstant:44.0],
            maxWidth
        ]];

        // Slide up from below
        view.transform = CGAffineTransformMakeTranslation(0, 60);
        view.alpha = 0.0;
        [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            if (finished && duration > 0 && sequence == sbCurrentPillSequence && !view.isDismissing) {
                [view startProgressAnimation];
            }
        }];
    });

    return view;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.progressOverlay.layer.animationKeys.count == 0 || self.isPaused) {
        self.progressOverlay.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
    }
}

- (void)startProgressAnimation {
    if (self.remainingDuration <= 0 || self.isDismissing) return;

    self.progressOverlay.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);

    [UIView animateWithDuration:self.remainingDuration delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.progressOverlay.transform = CGAffineTransformMakeScale(0.001, 1.0);
        self.progressOverlay.alpha = 0.0;
    } completion:^(BOOL finished) {
        if (finished && !self.isPaused && self.superview && !self.isDismissing) {
            [self dismiss];
        }
    }];
}

- (void)pauseProgress {
    if (self.isPaused || self.isDismissing) return;
    self.isPaused = YES;

    CALayer *presentationLayer = self.progressOverlay.layer.presentationLayer;
    CGFloat currentScaleX = 1.0;
    if (presentationLayer) {
        CATransform3D t = presentationLayer.transform;
        currentScaleX = t.m11;
    }

    [self.progressOverlay.layer removeAllAnimations];
    currentScaleX = MAX(0.001, MIN(currentScaleX, 1.0));
    self.progressOverlay.transform = CGAffineTransformMakeScale(currentScaleX, 1.0);
    self.progressOverlay.alpha = currentScaleX;
    self.remainingDuration = self.totalDuration * currentScaleX;
}

- (void)resumeProgress {
    if (!self.isPaused || self.isDismissing) return;
    self.isPaused = NO;

    if (self.remainingDuration <= 0) {
        [self dismiss];
        return;
    }

    [UIView animateWithDuration:self.remainingDuration delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.progressOverlay.transform = CGAffineTransformMakeScale(0.001, 1.0);
        self.progressOverlay.alpha = 0.0;
    } completion:^(BOOL finished) {
        if (finished && !self.isPaused && self.superview && !self.isDismissing) {
            [self dismiss];
        }
    }];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if (self.alpha < 1.0 || self.isDismissing) {
        gesture.enabled = NO;
        gesture.enabled = YES;
        return;
    }

    CGPoint translation = [gesture translationInView:self.superview];
    CGPoint velocity = [gesture velocityInView:self.superview];

    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            [self pauseProgress];
            break;

        case UIGestureRecognizerStateChanged:
            self.transform = CGAffineTransformMakeTranslation(0, translation.y);
            break;

        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            CGFloat distanceThreshold = 30.0;
            CGFloat velocityThreshold = 500.0;
            BOOL shouldDismiss = (fabs(translation.y) > distanceThreshold) || (fabs(velocity.y) > velocityThreshold);

            if (shouldDismiss) {
                CGFloat direction = (translation.y < 0) ? -1.0 : 1.0;
                [self dismissInDirection:direction velocity:fabs(velocity.y)];
            } else {
                // Snap back
                [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.5 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
                    self.transform = CGAffineTransformIdentity;
                } completion:^(BOOL finished) {
                    [self resumeProgress];
                }];
            }
            break;
        }
        default:
            break;
    }
}

- (void)dismissInDirection:(CGFloat)direction velocity:(CGFloat)velocity {
    if (self.isDismissing) return;
    self.isDismissing = YES;
    [self.progressOverlay.layer removeAllAnimations];
    [self.layer removeAllAnimations];
    CGFloat offscreenY = direction < 0 ? -(self.frame.size.height + 80) : (self.frame.size.height + 80);
    CGFloat animDuration = velocity > 500 ? 0.2 : 0.35;

    [UIView animateWithDuration:animDuration delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.transform = CGAffineTransformMakeTranslation(0, offscreenY);
        self.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

- (void)actionButtonTapped {
    if (self.onAction) {
        self.onAction();
    }
    [self dismiss];
}

- (void)dismissWithCompletion:(void (^)(void))completion {
    if (self.isDismissing) {
        if (completion) completion();
        return;
    }
    self.isDismissing = YES;
    [self.progressOverlay.layer removeAllAnimations];
    [self.layer removeAllAnimations];
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.transform = CGAffineTransformMakeTranslation(0, 60);
        self.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        if (completion) completion();
    }];
}

- (void)dismiss {
    [self dismissWithCompletion:nil];
}

+ (instancetype)showSuccessInView:(UIView *)parentView message:(NSString *)message duration:(NSTimeInterval)duration {
    SBSkipNotificationView *view = [self showInView:parentView message:message buttonTitle:nil action:nil duration:duration];
    if (view) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];
        UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"checkmark.circle.fill" withConfiguration:config]];
        iconView.tintColor = [UIColor systemGreenColor];
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [view addSubview:iconView];
        [NSLayoutConstraint activateConstraints:@[
            [iconView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-12.0],
            [iconView.centerYAnchor constraintEqualToAnchor:view.centerYAnchor],
        ]];
    }
    return view;
}

+ (instancetype)showErrorInView:(UIView *)parentView message:(NSString *)message duration:(NSTimeInterval)duration {
    SBSkipNotificationView *view = [self showInView:parentView message:message buttonTitle:nil action:nil duration:duration];
    if (view) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];
        UIImageView *iconView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"xmark.circle.fill" withConfiguration:config]];
        iconView.tintColor = [UIColor systemRedColor];
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [view addSubview:iconView];
        [NSLayoutConstraint activateConstraints:@[
            [iconView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-12.0],
            [iconView.centerYAnchor constraintEqualToAnchor:view.centerYAnchor],
        ]];
    }
    return view;
}

+ (instancetype)showDownloadCompleteDialogInView:(UIView *)parentView message:(NSString *)message saveHandler:(void (^)(void))saveHandler shareHandler:(void (^)(void))shareHandler duration:(NSTimeInterval)duration {
    if (!parentView || [UIApplication sharedApplication].applicationState == UIApplicationStateBackground) return nil;

    NSInteger sequence = ++sbCurrentPillSequence;

    SBSkipNotificationView *view = [[SBSkipNotificationView alloc] initWithFrame:CGRectZero];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.clipsToBounds = YES;
    view.layer.cornerRadius = 22.0;
    view.totalDuration = duration;
    view.remainingDuration = duration;
    view.isPaused = NO;

    // Base layer (revealed as progress depletes)
    view.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];

    // Progress overlay (shrinks from right to left)
    UIView *progressOverlay = [[UIView alloc] initWithFrame:CGRectZero];
    progressOverlay.translatesAutoresizingMaskIntoConstraints = YES;
    progressOverlay.backgroundColor = [UIColor colorWithWhite:0.18 alpha:1.0];
    progressOverlay.userInteractionEnabled = NO;
    progressOverlay.layer.anchorPoint = CGPointMake(0, 0.5);
    progressOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    view.progressOverlay = progressOverlay;
    [view addSubview:progressOverlay];

    // Message label
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = message;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    label.numberOfLines = 1;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    view.messageLabel = label;
    [view addSubview:label];

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightMedium];

    // Save button (left of share button)
    UIButton *saveButton = [UIButton buttonWithType:UIButtonTypeCustom];
    saveButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImage *saveIcon = [UIImage systemImageNamed:@"square.and.arrow.down" withConfiguration:config];
    [saveButton setImage:saveIcon forState:UIControlStateNormal];
    saveButton.tintColor = [UIColor whiteColor];
    saveButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
    saveButton.layer.cornerRadius = 16.0;
    saveButton.clipsToBounds = YES;
    __weak typeof(view) weakView = view;
    [saveButton addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
        if (saveHandler) saveHandler();
        [weakView dismiss];
    }] forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:saveButton];

    // Share button (rightmost) - Using arrowshape.turn.up.right
    UIButton *shareButton = [UIButton buttonWithType:UIButtonTypeCustom];
    shareButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImage *shareIcon = [UIImage systemImageNamed:@"arrowshape.turn.up.right" withConfiguration:config];
    [shareButton setImage:shareIcon forState:UIControlStateNormal];
    shareButton.tintColor = [UIColor whiteColor];
    shareButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
    shareButton.layer.cornerRadius = 16.0;
    shareButton.clipsToBounds = YES;
    [shareButton addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
        if (shareHandler) shareHandler();
        [weakView dismiss];
    }] forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:shareButton];

    // Internal layout
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:view.leadingAnchor constant:16.0],
        [label.centerYAnchor constraintEqualToAnchor:view.centerYAnchor],
        [label.trailingAnchor constraintEqualToAnchor:saveButton.leadingAnchor constant:-10.0],

        [saveButton.trailingAnchor constraintEqualToAnchor:shareButton.leadingAnchor constant:-8.0],
        [saveButton.centerYAnchor constraintEqualToAnchor:view.centerYAnchor],
        [saveButton.widthAnchor constraintEqualToConstant:32.0],
        [saveButton.heightAnchor constraintEqualToConstant:32.0],

        [shareButton.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-8.0],
        [shareButton.centerYAnchor constraintEqualToAnchor:view.centerYAnchor],
        [shareButton.widthAnchor constraintEqualToConstant:32.0],
        [shareButton.heightAnchor constraintEqualToConstant:32.0]
    ]];

    // Pan gesture for interactive dismissal
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:view action:@selector(handlePan:)];
    [view addGestureRecognizer:pan];

    // Dismiss existing pill if present, then present new pill
    YMDismissExistingPillsInView(parentView, ^{
        if (sequence != sbCurrentPillSequence) return;
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) return;

        [parentView addSubview:view];

        // Layout: centered horizontally, anchored above tab bar via safe area
        NSLayoutConstraint *maxWidth = [view.widthAnchor constraintLessThanOrEqualToAnchor:parentView.widthAnchor multiplier:0.88];
        [NSLayoutConstraint activateConstraints:@[
            [view.centerXAnchor constraintEqualToAnchor:parentView.centerXAnchor],
            [view.bottomAnchor constraintEqualToAnchor:parentView.safeAreaLayoutGuide.bottomAnchor constant:-60.0],
            [view.heightAnchor constraintEqualToConstant:44.0],
            maxWidth
        ]];

        // Slide up from below
        view.transform = CGAffineTransformMakeTranslation(0, 60);
        view.alpha = 0.0;
        [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
            view.alpha = 1.0;
            view.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            if (finished && duration > 0 && sequence == sbCurrentPillSequence && !view.isDismissing) {
                [view startProgressAnimation];
            }
        }];
    });

    return view;
}

@end

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

    NSInteger sequence = ++sbCurrentPillSequence;

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
    YMDismissExistingPillsInView(parentView, ^{
        if (sequence != sbCurrentPillSequence) return;
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
    });

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

#pragma mark - Marker Repositioning Hooks

static NSArray<SBSegment *> *sbActivePlayerSegments = nil;

static NSString *const SBSegmentMarkerLayerName = @"SBSegmentMarkerLayer";

// Round a segment marker to match YouTube's own player bar.
//
// The bar is a capsule, and YouTube shapes it with `layer.mask = CAShapeLayer` on the
// decoration view rather than a cornerRadius — a mask composites a layer AND all its
// sublayers, so our markers are already trimmed to the capsule silhouette, caps
// included. That means no per-corner logic is needed: rounding all four corners is
// correct both mid-bar and at the bar's ends, and anything overflowing gets clipped.
//
// The radius is clamped to half the marker's width so a narrow marker
// (SBMarkerMinWidth / SBPoiMarkerWidth) stays a pill instead of collapsing to a dot.
//
// The corner curve is left at CALayer's default (circular), which is what produces a
// stadium shape at radius = height/2 — the bar's silhouette. A continuous curve is the
// wrong tool here: its control points run roughly 1.5x the radius along each edge, so
// on a 2pt-tall bar the two corners' curves overlap and the path degenerates.
static void SBApplyMarkerRounding(CALayer *layer) {
    if (!layer) return;
    CGFloat height = layer.bounds.size.height, width = layer.bounds.size.width;
    if (height <= 0 || width <= 0) return;
    layer.cornerRadius = MIN(height / 2.0, width / 2.0);
}

static BOOL SBGetDecorationViewTimeRange(UIView *view, CGFloat *outStart, CGFloat *outEnd) {
    YTIPlayerBarDecorationModel *model = [view valueForKey:@"_model"];
    YTIPlayerBarItemData *itemData = [model itemData];
    CGFloat start = [itemData startTimeSec];
    CGFloat end = [itemData endTimeSec];
    if (end > start) {
        if (outStart) *outStart = start;
        if (outEnd) *outEnd = end;
        return YES;
    }
    return NO;
}

// Whether a decoration view belongs to the main player's bar rather than the feed's
// inline-muted-playback bar. Only the main player's markers are rounded.
static BOOL SBDecorationViewIsInMainPlayer(UIView *view) {
    UIView *currentView = view.superview;
    while (currentView != nil && currentView.superview != nil && ![currentView isKindOfClass:%c(YTMainAppVideoPlayerOverlayView)]) {
        currentView = currentView.superview;
    }
    if ([currentView isKindOfClass:%c(YTMainAppVideoPlayerOverlayView)]) {
        BOOL isFull = [currentView performSelector:@selector(isFullscreen)];
        return isFull;
    }
    return NO;
}

static void SBRebuildMarkersInDecorationView(UIView *view) {
    if (!view) return;

    for (CALayer *layer in [view.layer.sublayers copy]) {
        if ([layer.name isEqualToString:SBSegmentMarkerLayerName]) {
            [layer removeFromSuperlayer];
        }
    }

    if (!IS_ENABLED(SBEnabled) || !IS_ENABLED(SBButtonKey) || (!IS_ENABLED(SBSegmentsInPlayer) && !IS_ENABLED(SBSegmentsInFeed))) return;

    CGFloat start = 0.0, end = 0.0;
    if (!SBGetDecorationViewTimeRange(view, &start, &end)) return;

    CGFloat viewDuration = end - start;
    CGFloat barWidth = view.bounds.size.width;
    CGFloat barHeight = view.bounds.size.height;
    if (viewDuration <= 0 || barWidth <= 0 || barHeight <= 0) return;

    NSArray<SBSegment *> *segments = sbActivePlayerSegments;
    if (!segments || segments.count == 0) return;

    BOOL isMainPlayer = SBDecorationViewIsInMainPlayer(view);

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    for (SBSegment *segment in segments) {
        SBSegmentAction action = [segment configuredAction];
        if (action == SBSegmentActionDisable) continue;

        BOOL isPoi = [segment.category isEqualToString:@"poi_highlight"];
        if (isPoi) {
            if (segment.startTime >= start && segment.startTime <= end) {
                CGFloat frac = (segment.startTime - start) / viewDuration;
                CGFloat x = MAX(0.0, frac * barWidth - SBPoiMarkerXOffset);
                CGFloat w = SBPoiMarkerWidth;

                CALayer *markerLayer = [CALayer layer];
                markerLayer.name = SBSegmentMarkerLayerName;
                markerLayer.frame = CGRectMake(x, 0, w, barHeight);
                markerLayer.backgroundColor = [segment segmentColor].CGColor;
                markerLayer.masksToBounds = YES;
                if (isMainPlayer) SBApplyMarkerRounding(markerLayer);
                objc_setAssociatedObject(markerLayer, @selector(sbSegmentData), @[@(frac), @(frac), @(YES)], OBJC_ASSOCIATION_RETAIN_NONATOMIC);

                [view.layer addSublayer:markerLayer];
            }
        } else {
            CGFloat overlapStart = MAX((CGFloat)segment.startTime, start);
            CGFloat overlapEnd = MIN((CGFloat)segment.endTime, end);

            if (overlapEnd > overlapStart) {
                CGFloat fracStart = (overlapStart - start) / viewDuration;
                CGFloat fracEnd = (overlapEnd - start) / viewDuration;
                CGFloat x = fracStart * barWidth;
                CGFloat w = (fracEnd - fracStart) * barWidth;
                if (w < SBMarkerMinWidth) w = SBMarkerMinWidth;

                CALayer *markerLayer = [CALayer layer];
                markerLayer.name = SBSegmentMarkerLayerName;
                markerLayer.frame = CGRectMake(x, 0, w, barHeight);
                markerLayer.backgroundColor = [segment segmentColor].CGColor;
                markerLayer.masksToBounds = YES;
                if (isMainPlayer) SBApplyMarkerRounding(markerLayer);
                objc_setAssociatedObject(markerLayer, @selector(sbSegmentData), @[@(fracStart), @(fracEnd), @(NO)], OBJC_ASSOCIATION_RETAIN_NONATOMIC);

                [view.layer addSublayer:markerLayer];
            }
        }
    }

    [CATransaction commit];
}

static void SBRenderMarkersInDecorationView(UIView *view) {
    if (!view) return;
    CGFloat barWidth = view.bounds.size.width;
    CGFloat barHeight = view.bounds.size.height;
    if (barWidth <= 0 || barHeight <= 0) return;

    if (!IS_ENABLED(SBEnabled) || !IS_ENABLED(SBButtonKey) || (!IS_ENABLED(SBSegmentsInPlayer) && !IS_ENABLED(SBSegmentsInFeed))) {
        for (CALayer *layer in [view.layer.sublayers copy]) {
            if ([layer.name isEqualToString:SBSegmentMarkerLayerName]) {
                [layer removeFromSuperlayer];
            }
        }
        return;
    }

    BOOL isMainPlayer = SBDecorationViewIsInMainPlayer(view) && [view respondsToSelector:@selector(enableRoundedCorners)];

    BOOL hasMarkers = NO;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (CALayer *layer in view.layer.sublayers) {
        if ([layer.name isEqualToString:SBSegmentMarkerLayerName]) {
            hasMarkers = YES;
            NSArray *data = objc_getAssociatedObject(layer, @selector(sbSegmentData));
            if (data && data.count >= 3) {
                CGFloat fracStart = [data[0] floatValue];
                CGFloat fracEnd = [data[1] floatValue];
                BOOL isPoi = [data[2] boolValue];

                if (isPoi) {
                    CGFloat x = MAX(0.0, fracStart * barWidth - SBPoiMarkerXOffset);
                    layer.frame = CGRectMake(x, 0, SBPoiMarkerWidth, barHeight);
                } else {
                    CGFloat x = fracStart * barWidth;
                    CGFloat w = MAX(SBMarkerMinWidth, (fracEnd - fracStart) * barWidth);
                    layer.frame = CGRectMake(x, 0, w, barHeight);
                }
                // Re-derive the radius: the bar is 2pt windowed and 4pt fullscreen, and
                // the width changes on every re-layout.
                if (isMainPlayer) SBApplyMarkerRounding(layer);
            }
        }
    }
    [CATransaction commit];

    if (!hasMarkers) {
        SBRebuildMarkersInDecorationView(view);
    }
}

%hook YTPlayerBarProgressDecorationView
- (void)layoutSubviews {
    %orig;
    SBRenderMarkersInDecorationView(self);
}
%new
- (void)sb_updateSegmentMarkers {
    SBRebuildMarkersInDecorationView(self);
}
%end

%hook YTPlayerBarRectangleDecorationView
- (void)layoutSubviews {
    %orig;
    SBRenderMarkersInDecorationView(self);
}
%new
- (void)sb_updateSegmentMarkers {
    SBRebuildMarkersInDecorationView(self);
}
%end

// YTWatchFloatingMiniplayerProgressBarView - miniplayer
%hook YTWatchFloatingMiniplayerProgressBarView
- (void)layoutSubviews {
    %orig;
    CGFloat barWidth = self.bounds.size.width;

    for (UIView *sub in self.superview.subviews) {
        if (sub.tag != SBSegmentMarkerTag) continue;
        NSArray *data = objc_getAssociatedObject(sub, @selector(sbSegmentData));
        if (!data || data.count < 3) continue;

        CGFloat startFrac = [data[0] floatValue];
        CGFloat endFrac = [data[1] floatValue];
        BOOL isPoi = [data[2] boolValue];

        CGFloat x = startFrac * barWidth;
        CGFloat w = (endFrac - startFrac) * barWidth;
        if (isPoi) { w = SBPoiMarkerWidth; x = MAX(0, x - SBPoiMarkerXOffset); }
        else if (w < SBMarkerMinWidth) w = SBMarkerMinWidth;

        sub.frame = CGRectMake(x, self.frame.origin.y, w, self.bounds.size.height);
    }
}
%end

#pragma mark - YTPlayerViewController Hook (Notification Observer)

%group SBObserver
%hook YTPlayerViewController

- (void)viewDidLoad {
    %orig;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SBSegmentsDidLoad" object:self];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sbSegmentsDidLoad:)
                                                 name:@"SBSegmentsDidLoad"
                                               object:self];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SBSegmentsDidLoad" object:self];
    %orig;
}

%new
- (void)sbSegmentsDidLoad:(NSNotification *)notification {
    [self sbRefreshMarkers:notification.userInfo[@"segments"]];
}

// Re-resolves the current player bar view fresh and re-creates segment markers
// on it. Called whenever the player layout might have changed (initial load,
// fullscreen enter/exit, viewport resize) so markers always live on the
// currently-visible bar instead of an old detached one.
%new
- (void)sbRefreshMarkers:(NSArray<SBSegment *> *)segments {
    if (!IS_ENABLED(SBSegmentsInPlayer) && !IS_ENABLED(SBSegmentsInMiniPlayer) && !IS_ENABLED(SBSegmentsInFeed)) return;
    if (!segments) segments = self.sbSegments;

    sbActivePlayerSegments = segments;

    CGFloat totalTime = [self currentVideoTotalMediaTime];
    if (totalTime <= 0) return;
    CGFloat barWidth;
    CGFloat h;
    CGFloat y;
    UIView *mainView = nil;
    UIView *scrubberDot = nil;
    UIView *referenceView = nil;

    if ([self.parentViewController isKindOfClass:%c(YTWatchFloatingMiniplayerViewController)] && IS_ENABLED(SBSegmentsInMiniPlayer)) {
        YTWatchFloatingMiniplayerViewController *miniplayercontroller = (YTWatchFloatingMiniplayerViewController *)self.parentViewController;
        YTWatchFloatingMiniplayerWithPersistentControlsView *controlsview = (YTWatchFloatingMiniplayerWithPersistentControlsView *)miniplayercontroller.view;

        for (UIView *sub in controlsview.subviews) {
            for (UIView *sub2 in sub.subviews) {
                if ([sub2 isKindOfClass:%c(YTWatchFloatingMiniplayerProgressBarView)]) {
                    referenceView = sub2;
                    break;
                }
            }
            if (referenceView) break;
        }

        mainView = referenceView.superview;

        // Remove old markers
        for (UIView *sub in [mainView.subviews copy]) {
            if (sub.tag == SBSegmentMarkerTag) [sub removeFromSuperview];
        }
        if (!segments || segments.count == 0) return;

        barWidth = referenceView.bounds.size.width;
        h = referenceView.bounds.size.height;
        y = referenceView.frame.origin.y;
    } else if ([[self activeVideoPlayerOverlay] isKindOfClass:%c(YTMainAppVideoPlayerOverlayViewController)] && IS_ENABLED(SBSegmentsInPlayer)) {
        YTMainAppVideoPlayerOverlayViewController *overlay = [self activeVideoPlayerOverlay];
        YTPlayerBarController *barController = [overlay playerBarController];
        YTInlinePlayerBarContainerView *containerView = barController.playerBar;
        UIView *playerBar = nil;

        for (UIView *subview in containerView.subviews) {
            if ([subview isKindOfClass:%c(YTModularPlayerBarView)]) {
                playerBar = subview;
                break;
            }
        }
        if (!playerBar) return;

        for (UIView *sub in playerBar.subviews) {
            if ([sub isKindOfClass:%c(YTPlayerBarProgressDecorationView)] ||
                [sub isKindOfClass:%c(YTPlayerBarRectangleDecorationView)]) {
                [(YTPlayerBarProgressDecorationView *)sub sb_updateSegmentMarkers];
            }
        }
        return;
    } else if ([[self activeVideoPlayerOverlay] isKindOfClass:%c(YTInlineMutedPlaybackPlayerOverlayViewController)] && IS_ENABLED(SBSegmentsInFeed)) {
        YTInlineMutedPlaybackPlayerOverlayViewController *viewcon = [self activeVideoPlayerOverlay];
        YTInlineMutedPlaybackPlayerOverlayView *view = (YTInlineMutedPlaybackPlayerOverlayView *)viewcon.view;
        UIView *scrub;
        UIView *playerBar;
        for (UIView *sub in view.subviews) {
            if ([sub isKindOfClass:%c(YTInlineMutedPlaybackScrubberView)]) {
                scrub = sub;
                mainView = sub;
                break;
            }
        }

        if (!segments || segments.count == 0) return;

        for (UIView *sub in scrub.subviews) {
            if ([sub isKindOfClass:%c(YTPlayerBarMarkerView)] && sub.frame.origin.y != 0) {
                playerBar = sub;
            } else if ([sub isKindOfClass:%c(YTModularPlayerBarView)] && sub.frame.origin.y != 0) {
                playerBar = sub;
                mainView = sub;
            } else if ([sub isKindOfClass:%c(YTInlineMutedPlaybackScrubbingSlider)]) {
                if ([sub.accessibilityIdentifier isEqualToString:@"id.player.scrubber.slider"]) {
                    scrubberDot = sub;
                }
            }
            if (playerBar && scrubberDot) break;
        }

        if (!playerBar) return;

        if ([playerBar isKindOfClass:%c(YTModularPlayerBarView)]) {
            for (UIView *sub in playerBar.subviews) {
                if ([sub isKindOfClass:%c(YTPlayerBarProgressDecorationView)] ||
                    [sub isKindOfClass:%c(YTPlayerBarRectangleDecorationView)]) {
                    [(YTPlayerBarProgressDecorationView *)sub sb_updateSegmentMarkers];
                }
            }
            return;
        }

        // Remove old markers
        for (UIView *sub in [mainView.subviews copy]) {
            if (sub.tag == SBSegmentMarkerTag) [sub removeFromSuperview];
        }

        barWidth = playerBar.bounds.size.width;
        h = playerBar.bounds.size.height;
        y = playerBar.frame.origin.y;
    } else {
        return;
    }

    if (!IS_ENABLED(SBButtonKey)) return;

    for (SBSegment *segment in segments) {
        SBSegmentAction action = [segment configuredAction];
        if (action == SBSegmentActionDisable) continue;

        CGFloat startFrac = segment.startTime / totalTime;
        CGFloat endFrac;
        if (segment.endTime > totalTime) {
            endFrac = 1.0;
        } else {
            endFrac = segment.endTime / totalTime;
        }
        CGFloat x = startFrac * barWidth;
        CGFloat w = (endFrac - startFrac) * barWidth;

        // poi_highlight is a point, not a range — give it fixed width
        BOOL isPoi = [segment.category isEqualToString:@"poi_highlight"];
        if (isPoi) {
            w = SBPoiMarkerWidth;
            x = MAX(0, x - SBPoiMarkerXOffset);
        } else {
            if (w < SBMarkerMinWidth) w = SBMarkerMinWidth;
        }

        UIView *marker = [[UIView alloc] initWithFrame:CGRectMake(x, y, w, h)];
        marker.backgroundColor = [segment segmentColor];
        marker.userInteractionEnabled = NO;
        marker.tag = SBSegmentMarkerTag;
        objc_setAssociatedObject(marker, @selector(sbSegmentData), @[@(startFrac), @(endFrac), @(isPoi)], OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        // Insert above the track (main player bar) so the marker paints on it;
        // the dot is re-fronted after the loop. Miniplayer/feed keep dot-relative
        // or top ordering.
        if (referenceView && referenceView.superview == mainView) {
            [mainView insertSubview:marker aboveSubview:referenceView];
        } else if (scrubberDot && scrubberDot.superview == mainView) {
            [mainView insertSubview:marker belowSubview:scrubberDot];
        } else {
            [mainView addSubview:marker];
            [mainView bringSubviewToFront:marker];
        }
    }
    if (scrubberDot) {
        [mainView bringSubviewToFront:scrubberDot];
    }
}

// On fullscreen enter/exit and other layout transitions, YouTube swaps the
// player bar instance. Re-render markers on the current bar (matches
// iSponsorBlock's approach). Deferred to the next runloop so YouTube's own
// layout pass finishes first — otherwise the new bar's bounds.size.width can
// still be 0 and the refresh early-returns without inserting markers.
- (void)setPlayerViewLayout:(NSInteger)layout {
    %orig;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{ 
        [weakSelf sbRefreshMarkers:nil];
        sbUpdateOverlayInsetForPivotBar();
    });
}

- (void)updateViewportSizeProvider {
    %orig;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{ 
        [weakSelf sbRefreshMarkers:nil];
        sbUpdateOverlayInsetForPivotBar();
    });
}

%end
%end

#pragma mark - Constructor

%ctor {
    %init;
    %init(SBObserver);
}
#import "Headers.h"

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
    // Plain pills carry the info icon; the success/error variants opt out
    // below since they add their own status icon.
    view.showsInfoIcon = YES;

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

    // Info icon (trailing side): fills the reserved gap pills leave when
    // there is no action or status icon; hidden in layoutSubviews for the
    // success/error variants that bring their own icon
    UIImageSymbolConfiguration *infoConfig = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightMedium];
    UIImageView *infoIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"info.circle" withConfiguration:infoConfig]];
    infoIcon.tintColor = [UIColor colorWithWhite:1.0 alpha:0.65];
    infoIcon.hidden = YES;
    infoIcon.translatesAutoresizingMaskIntoConstraints = NO;
    view.infoIconView = infoIcon;
    [view addSubview:infoIcon];

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

            [infoIcon.trailingAnchor constraintEqualToAnchor:view.trailingAnchor constant:-12.0],
            [infoIcon.centerYAnchor constraintEqualToAnchor:view.centerYAnchor]
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
    // The icon only has constraints (and reserved space) on button-less
    // pills — never let it surface when an action button is present.
    self.infoIconView.hidden = self.actionButton != nil || !self.showsInfoIcon;
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
    if (self.onAction) self.onAction();
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
        view.showsInfoIcon = NO;
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
        view.showsInfoIcon = NO;
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

static NSString *const SBSegmentMarkerLayerName = @"SBSegmentMarkerLayer";

// Each bar view carries its own segment data as associated objects, stamped by
// its player's sbRefreshMarkers. There is deliberately no process-wide segment
// list: several players exist at once (main player + one per feed cell), and a
// shared list made one player's segments bleed onto another's bar.
static const NSInteger SBMarkerContextPlayer = 1;
static const NSInteger SBMarkerContextFeed = 2;
static const NSInteger SBMarkerContextMiniplayer = 3;

// Master switches for a bar context; the decoration rebuild and the bar hooks
// gate every pass through these so toggling a setting is reflected on the very
// next layout tick.
static BOOL SBMarkersEnabledForContext(NSInteger context) {
    if (!IS_ENABLED(SBEnabled) || !IS_ENABLED(SBButtonKey)) return NO;
    if (context == SBMarkerContextPlayer) return IS_ENABLED(SBSegmentsInPlayer);
    if (context == SBMarkerContextFeed) return IS_ENABLED(SBSegmentsInFeed);
    if (context == SBMarkerContextMiniplayer) return IS_ENABLED(SBSegmentsInMiniPlayer);
    return NO;
}

static void SBApplyMarkerContainerRounding(CALayer *container, CGFloat barHeight) {
    if (!container || barHeight <= 0) return;
    container.masksToBounds = YES;
    container.cornerRadius = barHeight / 2.0;
}

static const NSInteger SBMarkerRoundsLeft = 1;
static const NSInteger SBMarkerRoundsRight = 2;

static void SBApplyMarkerEndRounding(CALayer *markerLayer, NSInteger mode, CGFloat barWidth, CGFloat barHeight) {
    if (!markerLayer || barHeight <= 0 || barWidth <= 0) return;
    if (mode == 0) {
        markerLayer.cornerRadius = 0.0;
        return;
    }
    markerLayer.cornerRadius = MIN(barHeight / 2.0, barWidth / 2.0);
    if ((mode & SBMarkerRoundsLeft) && (mode & SBMarkerRoundsRight)) return;
    markerLayer.maskedCorners = ((mode & SBMarkerRoundsLeft) ? kCALayerMinXMinYCorner | kCALayerMinXMaxYCorner : 0)
                              | ((mode & SBMarkerRoundsRight) ? kCALayerMaxXMinYCorner | kCALayerMaxXMaxYCorner : 0);
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

static BOOL SBDecorationCanApplyRoundedCorners(UIView *view) {
    YTIPlayerBarDecorationModel *model = [view valueForKey:@"_model"];
    if (!model.style.hasRoundedCorners) return NO;
    YTMainAppVideoPlayerOverlayViewController *ovc = (YTMainAppVideoPlayerOverlayViewController *)view._viewControllerForAncestor;
    if (![ovc isKindOfClass:%c(YTMainAppVideoPlayerOverlayViewController)]) return NO;
    return ovc.isFullscreen;
}

static void SBRemoveMarkerContainerFromLayer(CALayer *hostLayer) {
    for (CALayer *layer in [hostLayer.sublayers copy]) {
        if ([layer.name isEqualToString:SBSegmentMarkerLayerName]) {
            [layer removeFromSuperlayer];
        }
    }
}

static CALayer *SBMakeMarkerLayer(SBSegment *segment, CGFloat rangeStart, CGFloat rangeEnd, CGFloat videoStart, CGFloat videoEnd, CGFloat barWidth, CGFloat barHeight) {
    CGFloat viewDuration = rangeEnd - rangeStart;
    BOOL isPoi = [segment.category isEqualToString:@"poi_highlight"];
    CALayer *markerLayer = [CALayer layer];
    markerLayer.masksToBounds = YES;
    markerLayer.backgroundColor = [segment segmentColor].CGColor;

    NSInteger rounding = 0;
    if (isPoi) {
        if (segment.startTime < rangeStart || segment.startTime > rangeEnd) return nil;
        CGFloat frac = (segment.startTime - rangeStart) / viewDuration;
        markerLayer.frame = CGRectMake(MAX(0.0, frac * barWidth - SBPoiMarkerXOffset), 0, SBPoiMarkerWidth, barHeight);
        objc_setAssociatedObject(markerLayer, @selector(sbSegmentData), @[@(frac), @(frac), @(YES), @(rounding)], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        CGFloat overlapStart = MAX((CGFloat)segment.startTime, rangeStart);
        CGFloat overlapEnd = MIN((CGFloat)segment.endTime, rangeEnd);
        if (overlapEnd <= overlapStart) return nil;

        if ((NSInteger)segment.startTime == (NSInteger)videoStart) rounding |= SBMarkerRoundsLeft;
        if ((NSInteger)segment.endTime == (NSInteger)videoEnd) rounding |= SBMarkerRoundsRight;

        CGFloat fracStart = (overlapStart - rangeStart) / viewDuration;
        CGFloat fracEnd = (overlapEnd - rangeStart) / viewDuration;
        markerLayer.frame = CGRectMake(fracStart * barWidth, 0, MAX(SBMarkerMinWidth, (fracEnd - fracStart) * barWidth), barHeight);
        objc_setAssociatedObject(markerLayer, @selector(sbSegmentData), @[@(fracStart), @(fracEnd), @(NO), @(rounding)], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        SBApplyMarkerEndRounding(markerLayer, rounding, markerLayer.bounds.size.width, barHeight);
    }

    return markerLayer;
}

static void SBLayoutMarkerLayers(CALayer *container, CGFloat barWidth, CGFloat barHeight, BOOL rounded) {
    if (!container) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (rounded) SBApplyMarkerContainerRounding(container, barHeight);
    for (CALayer *layer in container.sublayers) {
        NSArray *data = objc_getAssociatedObject(layer, @selector(sbSegmentData));
        if (!data || data.count < 3) continue;
        CGFloat fracStart = [data[0] floatValue];
        CGFloat fracEnd = [data[1] floatValue];
        BOOL isPoi = [data[2] boolValue];
        NSInteger rounding = data.count > 3 ? [data[3] integerValue] : 0;
        CGFloat x, w;
        if (isPoi) {
            x = MAX(0.0, fracStart * barWidth - SBPoiMarkerXOffset);
            w = SBPoiMarkerWidth;
        } else {
            x = fracStart * barWidth;
            w = MAX(SBMarkerMinWidth, (fracEnd - fracStart) * barWidth);
        }
        CGRect target = CGRectMake(x, 0, w, barHeight);
        if (!CGRectEqualToRect(layer.frame, target)) {
            layer.frame = target;
            SBApplyMarkerEndRounding(layer, rounding, w, barHeight);
        }
    }
    [CATransaction commit];
}

static void SBRebuildMarkersInLayer(CALayer *hostLayer, NSArray<SBSegment *> *segments, CGFloat rangeStart, CGFloat rangeEnd, CGFloat videoStart, CGFloat videoEnd) {
    if (!hostLayer) return;
    SBRemoveMarkerContainerFromLayer(hostLayer);
    CGFloat barWidth = hostLayer.bounds.size.width;
    CGFloat barHeight = hostLayer.bounds.size.height;
    if (barWidth <= 0 || barHeight <= 0) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (SBSegment *segment in segments) {
        SBSegmentAction action = [segment configuredAction];
        if (action == SBSegmentActionDisable) continue;
        CALayer *markerLayer = SBMakeMarkerLayer(segment, rangeStart, rangeEnd, videoStart, videoEnd, barWidth, barHeight);
        if (markerLayer) {
            markerLayer.name = SBSegmentMarkerLayerName;
            [hostLayer addSublayer:markerLayer];
        }
    }
    [CATransaction commit];
}

static void SBRebuildMarkersInDecorationView(UIView *view) {
    // Stamps live on the bar view, not on the decoration view: YouTube swaps
    // decoration subviews as the bar changes state, and a fresh view reads the
    // same stamps instead of starting blank until the next refresh.
    UIView *barView = view.superview;
    if (![barView isKindOfClass:%c(YTModularPlayerBarView)]) return;

    NSArray<SBSegment *> *segments = objc_getAssociatedObject(barView, @selector(sbSegmentsForView));
    NSInteger context = [objc_getAssociatedObject(barView, @selector(sbMarkerContextForView)) integerValue];

    // Disabled or segment-less: clearing is the outcome the user asked for.
    if (!SBMarkersEnabledForContext(context) || segments.count == 0) {
        SBRemoveMarkerContainerFromLayer(view.layer);
        return;
    }

    // Transient states (model not ready, mid-layout zero size): keep the old
    // container so nothing blinks; the next tick rebuilds.
    CGFloat start = 0.0, end = 0.0;
    if (!SBGetDecorationViewTimeRange(view, &start, &end)) return;
    CGFloat barHeight = view.bounds.size.height;
    if (view.bounds.size.width <= 0 || barHeight <= 0) return;

    CGFloat videoEnd = [[[view valueForKey:@"_model"] playingState] totalTimeSec];
    CALayer *container = [CALayer layer];
    container.name = SBSegmentMarkerLayerName;
    container.frame = view.bounds;
    if (SBDecorationCanApplyRoundedCorners(view)) SBApplyMarkerContainerRounding(container, barHeight);
    [view.layer addSublayer:container];

    SBRebuildMarkersInLayer(container, segments, start, end, start, videoEnd);
}

%hook YTPlayerBarProgressDecorationView
- (void)layoutSubviews {
    %orig;
    SBRebuildMarkersInDecorationView(self);
}
%end

%hook YTPlayerBarRectangleDecorationView
- (void)layoutSubviews {
    %orig;
    SBRebuildMarkersInDecorationView(self);
}
%end

// Bars without a decoration view (miniplayer, legacy feed slider) carry their
// markers directly on their own layer: layout repositions them, and a disabled
// toggle strips them on the spot.
%hook YTWatchFloatingMiniplayerProgressBarView
- (void)layoutSubviews {
    %orig;
    if (!SBMarkersEnabledForContext(SBMarkerContextMiniplayer)) {
        SBRemoveMarkerContainerFromLayer(self.layer);
        return;
    }
    CGFloat barWidth = self.bounds.size.width, barHeight = self.bounds.size.height;
    if (barWidth <= 0 || barHeight <= 0) return;
    SBLayoutMarkerLayers(self.layer, barWidth, barHeight, NO);
}
%end

%hook YTInlineMutedPlaybackScrubbingSlider
- (void)layoutSubviews {
    %orig;
    if (!SBMarkersEnabledForContext(SBMarkerContextFeed)) {
        SBRemoveMarkerContainerFromLayer(self.layer);
        return;
    }
    CGFloat barWidth = self.bounds.size.width, barHeight = self.bounds.size.height;
    if (barWidth <= 0 || barHeight <= 0) return;
    SBLayoutMarkerLayers(self.layer, barWidth, barHeight, NO);
}
%end

#pragma mark - YTPlayerViewController Hook (Notification Observer)

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
%new
// Stamps each bar with its own segments (associated objects) and rebuilds it
// once; the layout hooks keep the bars correct from there. An empty list is a
// clearing pass — every path still runs, so stale markers never survive a
// video change.
- (void)sbRefreshMarkers:(NSArray<SBSegment *> *)segments {
    if (!IS_ENABLED(SBEnabled) || !IS_ENABLED(SBButtonKey)) return;
    if (!segments) segments = self.sbSegments;

    CGFloat totalTime = [self currentVideoTotalMediaTime];
    if (segments.count > 0 && totalTime <= 0) return;

    if ([self.parentViewController isKindOfClass:%c(YTWatchFloatingMiniplayerViewController)]) {
        if (!IS_ENABLED(SBSegmentsInMiniPlayer)) return;
        UIView *progressView = ((YTWatchFloatingMiniplayerViewController *)self.parentViewController).watchFloatingMiniplayerView.progressBarView;
        SBRebuildMarkersInLayer(progressView.layer, segments, 0.0, totalTime, 0.0, totalTime);
    } else if ([self.activeVideoPlayerOverlay isKindOfClass:%c(YTMainAppVideoPlayerOverlayViewController)]) {
        if (!IS_ENABLED(SBSegmentsInPlayer)) return;
        YTModularPlayerBarView *playerBarView = ((YTMainAppVideoPlayerOverlayViewController *)self.activeVideoPlayerOverlay).playerBarController.playerBar.modularPlayerBar.view;
        objc_setAssociatedObject(playerBarView, @selector(sbSegmentsForView), segments, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(playerBarView, @selector(sbMarkerContextForView), @(SBMarkerContextPlayer), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        for (UIView *sub in playerBarView.subviews) {
            if ([sub isKindOfClass:%c(YTPlayerBarProgressDecorationView)] ||
                [sub isKindOfClass:%c(YTPlayerBarRectangleDecorationView)]) {
                SBRebuildMarkersInDecorationView(sub);
            }
        }
    } else if ([self.activeVideoPlayerOverlay isKindOfClass:%c(YTInlineMutedPlaybackPlayerOverlayViewController)]) {
        if (!IS_ENABLED(SBSegmentsInFeed)) return;
        YTInlineMutedPlaybackPlayerOverlayView *view = (YTInlineMutedPlaybackPlayerOverlayView *)((YTInlineMutedPlaybackPlayerOverlayViewController *)self.activeVideoPlayerOverlay).view;
        YTInlineMutedPlaybackScrubberView *scrubView = view.scrubberView;
        if (scrubView.modularPlayerBarEnabled) {
            YTModularPlayerBarView *modularView = scrubView.modularPlayerBar.view;
            objc_setAssociatedObject(modularView, @selector(sbSegmentsForView), segments, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(modularView, @selector(sbMarkerContextForView), @(SBMarkerContextFeed), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            for (UIView *sub in modularView.subviews) {
                if ([sub isKindOfClass:%c(YTPlayerBarProgressDecorationView)] ||
                    [sub isKindOfClass:%c(YTPlayerBarRectangleDecorationView)]) {
                    SBRebuildMarkersInDecorationView(sub);
                }
            }
        } else {
            SBRebuildMarkersInLayer(scrubView.scrubber.layer, segments, 0.0, totalTime, 0.0, totalTime);
        }
    }
}
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
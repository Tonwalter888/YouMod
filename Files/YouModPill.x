#import "Headers.h"

extern BOOL useBackwardIconForButton;

#pragma mark - YouModPillView Implementation

static NSInteger YouModPillSequence = 0;

@implementation YouModPillView

+ (NSInteger)nextAnimationSequence {
    return ++YouModPillSequence;
}

+ (NSInteger)currentAnimationSequence {
    return YouModPillSequence;
}

+ (void)dismissExistingPillsInView:(UIView *)parentView completion:(void (^)(void))completion {
    if (!parentView) {
        if (completion) completion();
        return;
    }
    NSMutableArray<UIView *> *existingPills = [NSMutableArray array];
    for (UIView *sub in [parentView.subviews copy]) {
        if ([sub isKindOfClass:[YouModPillView class]] || [sub isKindOfClass:[YMDownloadProgressView class]]) {
            [existingPills addObject:sub];
        }
    }

    if (existingPills.count == 0) {
        if (completion) completion();
        return;
    }

    __block NSInteger remaining = existingPills.count;
    void (^didDismiss)(void) = ^{
        remaining--;
        if (remaining <= 0 && completion) completion();
    };
    for (UIView *pill in existingPills) {
        if ([pill isKindOfClass:[YouModPillView class]]) {
            [(YouModPillView *)pill dismissWithCompletion:didDismiss];
        } else if ([pill isKindOfClass:[YMDownloadProgressView class]]) {
            [(YMDownloadProgressView *)pill dismissWithCompletion:didDismiss];
        } else {
            [pill removeFromSuperview];
            didDismiss();
        }
    }
}

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

    NSInteger sequence = [YouModPillView nextAnimationSequence];

    YouModPillView *view = [[YouModPillView alloc] initWithFrame:CGRectZero];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.clipsToBounds = YES;
    view.layer.cornerRadius = 22.0;
    view.onAction = action;
    view.totalDuration = duration;
    view.remainingDuration = duration;
    view.isPaused = NO;
    // Plain pills carry the info icon; success/error variants add their own.
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

    // Info icon (trailing side): fills the reserved gap when there is no action
    // or status icon; hidden in layoutSubviews for success/error variants.
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
    [YouModPillView dismissExistingPillsInView:parentView completion:^{
        if (sequence != [YouModPillView currentAnimationSequence]) return;
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
            if (finished && duration > 0 && sequence == [YouModPillView currentAnimationSequence] && !view.isDismissing) {
                [view startProgressAnimation];
            }
        }];
    }];

    return view;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    // The info icon only has reserved space on button-less pills; hide it
    // whenever an action button is present.
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
    YouModPillView *view = [self showInView:parentView message:message buttonTitle:nil action:nil duration:duration];
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
    YouModPillView *view = [self showInView:parentView message:message buttonTitle:nil action:nil duration:duration];
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

    NSInteger sequence = [YouModPillView nextAnimationSequence];

    YouModPillView *view = [[YouModPillView alloc] initWithFrame:CGRectZero];
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

    // Share button (rightmost)
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
    [YouModPillView dismissExistingPillsInView:parentView completion:^{
        if (sequence != [YouModPillView currentAnimationSequence]) return;
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
            if (finished && duration > 0 && sequence == [YouModPillView currentAnimationSequence] && !view.isDismissing) {
                [view startProgressAnimation];
            }
        }];
    }];

    return view;
}

@end

void YouModShowPill(NSString *message, BOOL success) {
    UIView *parent = sbGetNotificationParent();
    if (success) {
        [YouModPillView showSuccessInView:parent message:message duration:3.0];
    } else {
        [YouModPillView showErrorInView:parent message:message duration:4.0];
    }
}


#import "Headers.h"
#import <objc/message.h>

extern BOOL useBackwardIconForButton;

// Range segments render as a filled bar at least this wide so very short segments
// stay visible. Point segments (poi_highlight) have no duration, so they render as
// a fixed-width tick centered on their position via the x-offset.
static const CGFloat SBMarkerMinWidth = 2.0;
static const CGFloat SBPoiMarkerWidth = 3.0;
static const CGFloat SBPoiMarkerXOffset = 1.5;

// Height of the segment markers drawn on the inline (thumbnail) player bar,
// bottom-aligned so they sit flush with the bottom edge of the bar.
static const CGFloat SBInlineMarkerHeight = 4.0;

#pragma mark - SBSkipNotificationView Implementation

@implementation SBSkipNotificationView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appDidEnterBackground)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appWillEnterForeground)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)appDidEnterBackground {
    if (!self.isPaused) {
        [self pauseProgress];
        self.backgroundDate = [NSDate date];
    }
}

- (void)appWillEnterForeground {
    if (self.backgroundDate) {
        NSTimeInterval timeInBackground = [[NSDate date] timeIntervalSinceDate:self.backgroundDate];
        self.remainingDuration -= timeInBackground;
        self.backgroundDate = nil;
        
        if (self.remainingDuration <= 0) {
            [self removeFromSuperview];
            return;
        } else {
            CGFloat newScaleX = self.remainingDuration / self.totalDuration;
            newScaleX = MAX(0.001, MIN(newScaleX, 1.0));
            self.progressOverlay.transform = CGAffineTransformMakeScale(newScaleX, 1.0);
            self.progressOverlay.alpha = newScaleX;
        }
    }
    [self resumeProgress];
}

+ (instancetype)showInView:(UIView *)parentView message:(NSString *)message buttonTitle:(NSString *)buttonTitle action:(void (^)(void))action duration:(NSTimeInterval)duration {
    if (!parentView) return nil;

    for (UIView *sub in [parentView.subviews copy]) {
        if ([sub isKindOfClass:[SBSkipNotificationView class]]) {
            SBSkipNotificationView *existing = (SBSkipNotificationView *)sub;
            if (existing.isHighlightPill) return nil;
            [existing dismiss];
        }
    }

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

    [parentView addSubview:view];

    // Layout: centered horizontally, anchored above tab bar via safe area
    NSLayoutConstraint *maxWidth = [view.widthAnchor constraintLessThanOrEqualToAnchor:parentView.widthAnchor multiplier:0.85];
    [NSLayoutConstraint activateConstraints:@[
        [view.centerXAnchor constraintEqualToAnchor:parentView.centerXAnchor],
        [view.bottomAnchor constraintEqualToAnchor:parentView.safeAreaLayoutGuide.bottomAnchor constant:-60.0],
        [view.heightAnchor constraintEqualToConstant:44.0],
        maxWidth
    ]];

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

    // Slide up from below
    view.transform = CGAffineTransformMakeTranslation(0, 60);
    view.alpha = 0.0;
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut animations:^{
        view.alpha = 1.0;
        view.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        if (finished && duration > 0) {
            [view startProgressAnimation];
        }
    }];

    return view;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.progressOverlay.layer.animationKeys.count == 0 || self.isPaused) {
        self.progressOverlay.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
    }
}

- (void)startProgressAnimation {
    if (self.remainingDuration <= 0) return;

    self.progressOverlay.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);

    [UIView animateWithDuration:self.remainingDuration delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.progressOverlay.transform = CGAffineTransformMakeScale(0.001, 1.0);
        self.progressOverlay.alpha = 0.0;
    } completion:^(BOOL finished) {
        if (finished && !self.isPaused && self.superview) {
            [self dismiss];
        }
    }];
}

- (void)pauseProgress {
    if (self.isPaused) return;
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
    if (!self.isPaused) return;
    self.isPaused = NO;

    if (self.remainingDuration <= 0) {
        [self dismiss];
        return;
    }

    [UIView animateWithDuration:self.remainingDuration delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.progressOverlay.transform = CGAffineTransformMakeScale(0.001, 1.0);
        self.progressOverlay.alpha = 0.0;
    } completion:^(BOOL finished) {
        if (finished && !self.isPaused && self.superview) {
            [self dismiss];
        }
    }];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    if (self.alpha < 1.0) {
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

- (void)dismiss {
    [self.progressOverlay.layer removeAllAnimations];
    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.transform = CGAffineTransformMakeTranslation(0, 60);
        self.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
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

@end

#pragma mark - YMDownloadProgressView

@implementation YMDownloadProgressView

+ (instancetype)showInView:(UIView *)parentView message:(NSString *)message cancelAction:(void (^)(void))cancelAction {
    if (!parentView) return nil;

    // Dismiss any existing download progress pill
    for (UIView *sub in [parentView.subviews copy]) {
        if ([sub isKindOfClass:[YMDownloadProgressView class]]) {
            [(YMDownloadProgressView *)sub dismiss];
        }
    }

    YMDownloadProgressView *view = [[YMDownloadProgressView alloc] init];
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

    // Layout
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

- (void)dismiss {
    if (!self.superview) return;
    [UIView animateWithDuration:0.25 animations:^{
        self.transform = CGAffineTransformMakeTranslation(0, 80);
        self.alpha = 0;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

@end

#pragma mark - YTSegmentableInlinePlayerBarView Hook (Seek Bar Markers)

%hook YTSegmentableInlinePlayerBarView
%property (nonatomic, strong) NSArray *sbMarkerViews;

- (void)layoutSubviews {
    %orig;
    if (self.sbMarkerViews.count > 0) {
        [self sbRepositionMarkers];
    }
}

%new
- (void)sbRenderSegments:(NSArray<SBSegment *> *)segments {
    [self sbClearSegments];

    CGFloat totalTime = 0;
    @try {
        totalTime = [[self valueForKey:@"totalTime"] floatValue];
    } @catch (NSException *e) { return; }
    if (totalTime <= 0 || segments.count == 0) return;

    CGFloat barWidth = self.bounds.size.width;
    CGFloat barHeight = self.bounds.size.height;
    if (barWidth <= 0) return;

    NSMutableArray *markers = [NSMutableArray array];

    for (SBSegment *segment in segments) {
        SBSegmentAction action = [segment configuredAction];
        if (action == SBSegmentActionDisable) continue;

        CGFloat startFrac = segment.startTime / totalTime;
        CGFloat endFrac = segment.endTime / totalTime;
        CGFloat x = startFrac * barWidth;
        CGFloat w = (endFrac - startFrac) * barWidth;
        if (w < SBMarkerMinWidth) w = SBMarkerMinWidth;

        UIView *marker = [[UIView alloc] initWithFrame:CGRectMake(x, barHeight - SBInlineMarkerHeight, w, SBInlineMarkerHeight)];
        marker.backgroundColor = [segment segmentColor];
        marker.userInteractionEnabled = NO;
        marker.layer.name = [NSString stringWithFormat:@"%f|%f", segment.startTime, segment.endTime];

        [self addSubview:marker];
        [markers addObject:marker];
    }

    self.sbMarkerViews = [markers copy];
}

%new
- (void)sbRepositionMarkers {
    CGFloat totalTime = 0;
    @try {
        totalTime = [[self valueForKey:@"totalTime"] floatValue];
    } @catch (NSException *e) { return; }
    if (totalTime <= 0) return;

    CGFloat barWidth = self.bounds.size.width;
    CGFloat barHeight = self.bounds.size.height;
    if (barWidth <= 0) return;

    for (UIView *marker in self.sbMarkerViews) {
        NSString *name = marker.layer.name;
        NSArray *parts = [name componentsSeparatedByString:@"|"];
        if (parts.count < 2) continue;

        CGFloat startTime = [parts[0] floatValue];
        CGFloat endTime = [parts[1] floatValue];
        CGFloat startFrac = startTime / totalTime;
        CGFloat endFrac = endTime / totalTime;
        CGFloat x = startFrac * barWidth;
        CGFloat w = (endFrac - startFrac) * barWidth;
        if (w < SBMarkerMinWidth) w = SBMarkerMinWidth;

        marker.frame = CGRectMake(x, barHeight - SBInlineMarkerHeight, w, SBInlineMarkerHeight);
    }
}

%new
- (void)sbClearSegments {
    for (UIView *marker in self.sbMarkerViews) {
        [marker removeFromSuperview];
    }
    self.sbMarkerViews = nil;
}

%end

#pragma mark - Marker Repositioning Hooks

// YTModularPlayerBarView - normal player
%hook YTModularPlayerBarView

- (void)layoutSubviews {
    %orig;
    CGFloat barWidth = self.bounds.size.width;
    if (barWidth <= 0) return;

    // Find reference view for Y
    UIView *referenceView = nil;
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:%c(YTPlayerBarRectangleDecorationView)] ||
            [sub isKindOfClass:%c(YTPlayerBarProgressDecorationView)]) {
            referenceView = sub;
            break;
        }
    }

    for (UIView *sub in self.subviews) {
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

        sub.frame = CGRectMake(x, referenceView.frame.origin.y, w, referenceView.frame.size.height);
    }

    // Keep the segment markers above YouTube's decoration views, and the scrubber
    // dot above the markers, so the stack stays track < markers < dot. YouTube
    // rebuilds its own decorations on top of ours on each layout (splitting the
    // progress view per chapter), which would otherwise bury the markers.
    NSArray<UIView *> *subs = self.subviews;
    NSMutableArray<UIView *> *markers = [NSMutableArray array];
    UIView *scrubberDot = nil;
    @try {
        scrubberDot = [self valueForKey:@"_scrubberCircle"];
    } @catch (id ex) {}
    for (UIView *sub in subs) {
        if (sub.tag == SBSegmentMarkerTag) {
            [markers addObject:sub];
        } else if ([sub isKindOfClass:%c(YTPlayerBarScrubberDotDecorationView)]) {
            if (!scrubberDot) scrubberDot = sub;
        }
    }
    if (markers.count == 0) return;

    // Desired top group, front-most last: the markers followed by the dot. Reorder
    // only when the subview tail doesn't already match it, so a settled layout is a
    // no-op and doesn't trigger a fresh layout pass on every runloop cycle.
    NSMutableArray<UIView *> *desiredTail = [markers mutableCopy];
    if (scrubberDot) [desiredTail addObject:scrubberDot];
    BOOL settled = subs.count >= desiredTail.count;
    for (NSUInteger i = 0; settled && i < desiredTail.count; i++) {
        if (subs[subs.count - desiredTail.count + i] != desiredTail[i]) settled = NO;
    }
    if (settled) return;

    for (UIView *marker in markers) [self bringSubviewToFront:marker];
    if (scrubberDot) [self bringSubviewToFront:scrubberDot];
}

%end

// YTWatchFloatingMiniplayerWithPersistentControlsView - miniplayer
%hook YTWatchFloatingMiniplayerWithPersistentControlsView
- (void)layoutSubviews {
    %orig;
    UIView *playerBar;
    UIView *mainView;
    for (UIView *sub in self.subviews) {
        for (UIView *sub2 in sub.subviews) {
            if ([sub2 isKindOfClass:%c(YTWatchFloatingMiniplayerProgressBarView)]) {
                playerBar = sub2;
                break;
            }
        }
        if (playerBar) {
            mainView = sub;
            break;
        }
    }
    if (self.dockHandleStyle == 2) {
        for (UIView *sub in [mainView.subviews copy]) {
            if (sub.tag == SBSegmentMarkerTag) sub.hidden = YES;
        }
        return;
    }
    for (UIView *sub in [mainView.subviews copy]) {
        if (sub.tag == SBSegmentMarkerTag) sub.hidden = NO;
    }
    CGFloat barWidth = playerBar.bounds.size.width;

    for (UIView *sub in mainView.subviews) {
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

        sub.frame = CGRectMake(x, playerBar.frame.origin.y, w, playerBar.bounds.size.height);
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

    CGFloat totalTime = [self currentVideoTotalMediaTime];
    if (totalTime <= 0) return;
    CGFloat barWidth;
    CGFloat h;
    CGFloat y;
    // Explicitly nil so the surface branches can rely on "unassigned == nil"
    // when deciding marker ordering, without depending on ARC zero-init.
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
            if (referenceView) {
                mainView = sub;
                break;
            }
        }
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
        UIView *playerBar;

        for (UIView *subview in containerView.subviews) {
            if ([subview isKindOfClass:%c(YTModularPlayerBarView)]) {
                playerBar = subview;
                mainView = subview;
                break;
            }
        }
        if (!playerBar) return;

        // Remove old markers
        for (UIView *sub in [playerBar.subviews copy]) {
            if (sub.tag == SBSegmentMarkerTag) [sub removeFromSuperview];
        }

        if (!segments || segments.count == 0) return;

        barWidth = playerBar.bounds.size.width;
        if (barWidth <= 0) return;

        @try {
            scrubberDot = [playerBar valueForKey:@"_scrubberCircle"];
        } @catch (id ex) {}
        // Find reference track view for Y position and height
        for (UIView *sub in playerBar.subviews) {
            if ([sub isKindOfClass:%c(YTPlayerBarRectangleDecorationView)]) {
                if (!referenceView) referenceView = sub;
            } else if ([sub isKindOfClass:%c(YTPlayerBarProgressDecorationView)]) {
                if (!referenceView) referenceView = sub;
            } else if ([sub isKindOfClass:%c(YTPlayerBarScrubberDotDecorationView)]) {
                if (!scrubberDot) scrubberDot = sub;
            }
            if (referenceView && scrubberDot) break;
        }
        h = referenceView.bounds.size.height;
        y = referenceView.frame.origin.y;
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

        // Remove old markers
        for (UIView *sub in [mainView.subviews copy]) {
            if (sub.tag == SBSegmentMarkerTag) [sub removeFromSuperview];
        }

        if ([mainView isKindOfClass:%c(YTModularPlayerBarView)]) {
            @try {
                scrubberDot = [mainView valueForKey:@"_scrubberCircle"];
            } @catch (id ex) {}
            // Find reference track view for Y position and height
            for (UIView *sub in mainView.subviews) {
                if ([sub isKindOfClass:%c(YTPlayerBarRectangleDecorationView)]) {
                    if (!referenceView) referenceView = sub;
                } else if ([sub isKindOfClass:%c(YTPlayerBarProgressDecorationView)]) {
                    if (!referenceView) referenceView = sub;
                } else if ([sub isKindOfClass:%c(YTPlayerBarScrubberDotDecorationView)]) {
                    if (!scrubberDot) scrubberDot = sub;
                }
                if (referenceView && scrubberDot) break;
            }
            barWidth = playerBar.bounds.size.width;
            h = referenceView.bounds.size.height;
            y = referenceView.frame.origin.y;
        } else {
            barWidth = playerBar.bounds.size.width;
            h = playerBar.bounds.size.height;
            y = playerBar.frame.origin.y;
        }
    } else {
        return;
    }

    if (!self.sbEnabledForVideo) return;

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
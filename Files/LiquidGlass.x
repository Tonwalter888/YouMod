#import "Headers.h"
#import <objc/message.h>

// System bar-style glass backdrop: a real UIGlassEffect ("liquid glass") on
// iOS 26+, falling back to a system material blur on older versions. The
// backdrop view is created once per view and reused on repeated calls, so
// it's safe to re-apply after theme changes.
static const void *kYMLiquidGlassBackdropKey = &kYMLiquidGlassBackdropKey;

// Resolved dynamically so this compiles against any SDK: UIGlassEffect only
// exists on iOS 26+, so the class lookup itself acts as the availability
// check (no @available needed, which some toolchains can't link).
static UIVisualEffect *YMCreateSystemBarGlassEffect(void) {
    Class glass = NSClassFromString(@"UIGlassEffect");
    SEL selector = NSSelectorFromString(@"effectWithStyle:");
    if (glass && [glass respondsToSelector:selector]) {
        UIVisualEffect *(*createEffect)(id, SEL, NSInteger) = (UIVisualEffect *(*)(id, SEL, NSInteger))objc_msgSend;
        return createEffect(glass, selector, 0); // UIGlassEffectStyleRegular
    }
    return nil;
}

void YouModApplyLiquidGlassBackdropToView(UIView *view, CGFloat cornerRadius) {
    if (!view) return;

    UIVisualEffectView *glassView = objc_getAssociatedObject(view, kYMLiquidGlassBackdropKey);
    if (!glassView) {
        UIVisualEffect *effect = YMCreateSystemBarGlassEffect();
        if (!effect) effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
        glassView = [[UIVisualEffectView alloc] initWithEffect:effect];
        glassView.userInteractionEnabled = NO;
        glassView.isAccessibilityElement = NO;
        glassView.accessibilityElementsHidden = YES;
        glassView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [view insertSubview:glassView atIndex:0];
        objc_setAssociatedObject(view, kYMLiquidGlassBackdropKey, glassView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    glassView.frame = view.bounds;
    view.backgroundColor = UIColor.clearColor;
    view.layer.cornerRadius = cornerRadius;
    view.layer.cornerCurve = kCACornerCurveContinuous;
    view.layer.masksToBounds = YES;
    BOOL dark = view.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *edgeColor = [(dark ? UIColor.whiteColor : UIColor.blackColor) colorWithAlphaComponent:dark ? 0.20 : 0.10];
    view.layer.borderWidth = 0.5;
    view.layer.borderColor = edgeColor.CGColor;
}

void YouModApplyLiquidGlassToView(UIView *view, BOOL wantsBackground) {
    if (wantsBackground && [view respondsToSelector:@selector(tuui_applyFlexibleClearGlassWithShadowBackground)]) [view tuui_applyFlexibleClearGlassWithShadowBackground];
    else if (!wantsBackground && [view respondsToSelector:@selector(tuui_applyFlexibleSmallGlassBackground)]) [view tuui_applyFlexibleSmallGlassBackground];
}

%hook YTChipCloudChipView
- (void)didMoveToWindow {
    %orig;
    YouModApplyLiquidGlassToView(self, YES);
}
%end

%hook YTRightNavigationButtons
- (NSArray <YTQTMButton *> *)visibleButtons {
    NSArray <YTQTMButton *> *orig = %orig;
    if (orig && orig.count > 0) for (YTQTMButton *button in orig) YouModApplyLiquidGlassToView(button, YES);
    return orig;
}
%end

%hook YTEngagementPanelHeaderView
- (void)didMoveToWindow {
    %orig;
    if (self.informationButton != nil) YouModApplyLiquidGlassToView(self.informationButton, YES);
    if (self.sortFilterMenuButton != nil) YouModApplyLiquidGlassToView(self.sortFilterMenuButton, YES);
    if (self.closeButton != nil) YouModApplyLiquidGlassToView(self.closeButton, YES);
    if (self.backButton != nil) YouModApplyLiquidGlassToView(self.backButton, YES);
    if (self.actionButton != nil) YouModApplyLiquidGlassToView(self.actionButton, YES);
    for (UIView *button in self.subviews) {
        if ([button isKindOfClass:%c(YTQTMButton)]) {
            YTIButtonRenderer *renderer = [button valueForKey:@"_buttonRenderer"];
            if (renderer == nil) continue;
            NSString *desc = [renderer description];
            if ([desc containsString:@"FEcommunity_page"] || [desc containsString:@"live_chat_filter_mode_option.eml"]) YouModApplyLiquidGlassToView(button, YES);
        }
    }
}
%end

%hook YTSearchBarView
- (void)didMoveToWindow {
    %orig;
    YouModApplyLiquidGlassToView(self, YES);
}
%end

%hook GSKRedMicButton
- (void)didMoveToWindow {
    %orig;
    YouModApplyLiquidGlassToView(self, NO);
}
%end

%hook YTLeftNavigationButtons
- (YTQTMButton *)backButton {
    YTQTMButton *orig = %orig;
    if (orig) YouModApplyLiquidGlassToView(orig, YES);
    return orig;
}
%end

%hook YTFirstTimeSignInView
- (void)didMoveToWindow {
    %orig;
    @try {
        if (self.chooseAccountButton != nil) YouModApplyLiquidGlassToView(self.chooseAccountButton, YES);
        if (self.alternateAccountButton != nil) YouModApplyLiquidGlassToView(self.alternateAccountButton, YES);
    } @catch (id ex) {}
}
%end

%hook YTBackgroundPromoCell
- (YTQTMButton *)ctaButton {
    YTQTMButton *orig = %orig;
    if (orig) YouModApplyLiquidGlassToView(orig, YES);
    return orig;
}
%end

%hook YTReelHeaderView
- (void)addBackButton:(YTQTMButton *)button toStackView:(UIStackView *)stackView {
    if (button) YouModApplyLiquidGlassToView(button, NO);
    %orig;
}
%end

%hook YTGlobalConfig
- (BOOL)shouldBlockUpgradeDialog { return YES; }
%end

%hook YTVersionUtils
+ (NSString *)appVersionLong {
    NSString *appVersion = %orig;
    if ([appVersion compare:@"20.21.6" options:NSNumericSearch] == NSOrderedAscending) return @"20.21.6";
    return appVersion;
}
+ (NSString *)appVersion {
    NSString *appVersion = %orig;
    if ([appVersion compare:@"20.21.6" options:NSNumericSearch] == NSOrderedAscending) return @"20.21.6";
    return appVersion;
}
%end

static float YMSeekStartValue;

%hook YTInlineMutedPlaybackPlayerOverlayView
%property (nonatomic, retain) UIPanGestureRecognizer *ymSeekPan;

- (void)didMoveToWindow {
    %orig;

    if (self.window && !self.ymSeekPan) {
        self.ymSeekPan =
            [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                    action:@selector(ym_handleSeekPan:)];
        self.ymSeekPan.delegate = (id<UIGestureRecognizerDelegate>)self;
        self.ymSeekPan.cancelsTouchesInView = NO;
        [self addGestureRecognizer:self.ymSeekPan];
    }
}

%new
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
    if (gesture != self.ymSeekPan) return YES;

    CGPoint velocity = [(UIPanGestureRecognizer *)gesture velocityInView:self];
    return fabs(velocity.x) > fabs(velocity.y); // horizontal swipes only
}

%new
- (void)ym_handleSeekPan:(UIPanGestureRecognizer *)pan {
    UISlider *slider = self.scrubberView.scrubber;
    if (!slider) return;

    float duration = slider.maximumValue - slider.minimumValue;
    if (duration <= 0) return;

    if (pan.state == UIGestureRecognizerStateBegan) {
        YMSeekStartValue = slider.value;
        [slider sendActionsForControlEvents:UIControlEventTouchDown];
    }

    UIGestureRecognizerState state = pan.state;
    if (state != UIGestureRecognizerStateChanged &&
        state != UIGestureRecognizerStateEnded &&
        state != UIGestureRecognizerStateCancelled) return;

    CGFloat dx = [pan translationInView:self].x;
    float value = YMSeekStartValue + dx / self.bounds.size.width * duration;
    value = fminf(fmaxf(value, slider.minimumValue), slider.maximumValue);
    slider.value = value;

    if (state == UIGestureRecognizerStateChanged) {
        [slider sendActionsForControlEvents:UIControlEventValueChanged];
    } else if (state == UIGestureRecognizerStateEnded) {
        [slider sendActionsForControlEvents:UIControlEventValueChanged];
        [slider sendActionsForControlEvents:UIControlEventTouchUpInside]; // lets the scrub state machine commit + exit
    } else {
        [slider sendActionsForControlEvents:UIControlEventTouchCancel];
    }
}
%end
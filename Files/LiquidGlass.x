#import "Headers.h"
#import <objc/message.h>

static const void *kYMLiquidGlassBackdropKey = &kYMLiquidGlassBackdropKey;

static UIVisualEffect *YMCreateSystemBarGlassEffect(void) {
    Class glass = %c(UIGlassEffect);
    SEL selector = @selector(effectWithStyle:);
    if (glass && [glass respondsToSelector:selector]) {
        UIVisualEffect *(*createEffect)(id, SEL, NSInteger) = (UIVisualEffect *(*)(id, SEL, NSInteger))objc_msgSend;
        return createEffect(glass, selector, 0); // UIGlassEffectStyleRegular
    }
    return nil;
}

static UIVisualEffectView *YMEnsureGlassBackdrop(UIView *view) {
    UIVisualEffectView *glassView = objc_getAssociatedObject(view, kYMLiquidGlassBackdropKey);
    if (!glassView) {
        UIVisualEffect *effect = YMCreateSystemBarGlassEffect();
        if (!effect) effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
        glassView = [[UIVisualEffectView alloc] initWithEffect:effect];
        glassView.userInteractionEnabled = NO;
        glassView.isAccessibilityElement = NO;
        glassView.accessibilityElementsHidden = YES;
        [view insertSubview:glassView atIndex:0];
        // Flexible: pinned on all sides so the glass stretches with the host while
        // it is dragged or resized — no manual frame syncing needed.
        glassView.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [glassView.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
            [glassView.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
            [glassView.topAnchor constraintEqualToAnchor:view.topAnchor],
            [glassView.bottomAnchor constraintEqualToAnchor:view.bottomAnchor],
        ]];
        objc_setAssociatedObject(view, kYMLiquidGlassBackdropKey, glassView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return glassView;
}

void YouModApplyLiquidGlassBackdropToView(UIView *view, CGFloat cornerRadius) {
    if (!view) return;
    YMEnsureGlassBackdrop(view);
    view.backgroundColor = UIColor.clearColor;
    view.layer.cornerRadius = cornerRadius;
    view.layer.cornerCurve = kCACornerCurveContinuous;
    view.layer.masksToBounds = YES;
    BOOL dark = view.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *edgeColor = [(dark ? UIColor.whiteColor : UIColor.blackColor) colorWithAlphaComponent:dark ? 0.20 : 0.10];
    view.layer.borderWidth = 0.5;
    view.layer.borderColor = edgeColor.CGColor;
}

// Frosted panel background for dialogs: manual glass blur over a light-gray base.
void YouModApplyFrostedPanelBackgroundToView(UIView *view) {
    if (!view) return;
    YMEnsureGlassBackdrop(view);
    view.backgroundColor = [UIColor systemGray6Color];
}

void YouModApplyLiquidGlassToView(UIView *view, BOOL wantsBackground) {
    if (wantsBackground && [view respondsToSelector:@selector(tuui_applyFlexibleClearGlassWithShadowBackground)]) [view tuui_applyFlexibleClearGlassWithShadowBackground];
    else if (!wantsBackground && [view respondsToSelector:@selector(tuui_applyFlexibleSmallGlassBackground)]) [view tuui_applyFlexibleSmallGlassBackground];
}

%hook YTChipCloudChipView
- (void)didMoveToWindow {
    %orig;
    if (self.renderer && [self.renderer.description containsString:@"STYLE_FULL_SCREEN_RELATED"]) return;
    YouModApplyLiquidGlassToView(self, YES);
}
%end

%hook YTRightNavigationButtons
- (void)layoutSubviews {
    %orig;
    YouModApplyLiquidGlassBackdropToView(self, CGRectGetHeight(self.bounds) / 2.0);
}
- (void)setLeadingPadding:(CGFloat)padding { %orig(0); }
- (void)setTailingPadding:(CGFloat)padding { %orig(0); }
%end

%hook YTSearchViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    UIView *voiceView = [self valueForKey:@"_voiceButtonContainerView"];
    if (!voiceView) return;
    for (UIView *sub in voiceView.subviews) {
        if (![sub isKindOfClass:%c(UIButton)]) [sub removeFromSuperview];
        else YouModApplyLiquidGlassToView(sub, YES);
    }
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
    for (NSString *ivar in @[@"_chooseAccountButton", @"_alternateAccountButton"]) {
        YTQTMButton *button = [self valueForKey:ivar];
        if (button != nil) YouModApplyLiquidGlassToView(button, YES);
    }
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

static float YMSeekStartValue;

%hook YTInlineMutedPlaybackPlayerOverlayView
%property (nonatomic, retain) UIPanGestureRecognizer *ymSeekPan;
- (void)didMoveToWindow {
    %orig;
    if (self.window && !self.ymSeekPan) {
        self.ymSeekPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(YouModHandleSeekPan:)];
        self.ymSeekPan.delegate = (id<UIGestureRecognizerDelegate>)self;
        self.ymSeekPan.cancelsTouchesInView = NO;
        [self addGestureRecognizer:self.ymSeekPan];
    }
}
%new
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
    if (gesture != self.ymSeekPan) return YES;
    CGPoint velocity = [(UIPanGestureRecognizer *)gesture velocityInView:self];
    return fabs(velocity.x) > fabs(velocity.y);
}
%new
- (void)YouModHandleSeekPan:(UIPanGestureRecognizer *)gesture {
    UISlider *slider = self.scrubberView.scrubber;
    if (!slider) return;
    float duration = slider.maximumValue - slider.minimumValue;
    if (duration <= 0) return;
    UIGestureRecognizerState state = gesture.state;
    if (state == UIGestureRecognizerStateBegan) {
        YMSeekStartValue = slider.value;
        [slider sendActionsForControlEvents:UIControlEventTouchDown];
    } else if (state != UIGestureRecognizerStateChanged &&
        state != UIGestureRecognizerStateEnded &&
        state != UIGestureRecognizerStateCancelled) return;
    CGFloat dx = [gesture translationInView:self].x;
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
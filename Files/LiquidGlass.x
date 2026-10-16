#import "Headers.h"
#import <objc/message.h>

static const void *kYMPivotBarSystemEffectKey = &kYMPivotBarSystemEffectKey;
static const void *kYMPivotBarSystemEffectViewKey = &kYMPivotBarSystemEffectViewKey;
static const void *kYMPivotBarOriginalBackgroundColorKey = &kYMPivotBarOriginalBackgroundColorKey;
static const void *kYMPivotBarHasOriginalBackgroundColorKey = &kYMPivotBarHasOriginalBackgroundColorKey;

static UIGlassEffect *YMCreateSystemPivotBarGlassEffect() {
    if (@available(iOS 26.0, *)) {
        Class glass = %c(UIGlassEffect);
        SEL selector = @selector(effectWithStyle:);
        if (glass && [glass respondsToSelector:selector]) {
            UIGlassEffect *(*createEffect)(id, SEL, UIGlassEffectStyle) = (UIGlassEffect *(*)(id, SEL, UIGlassEffectStyle))objc_msgSend;
            return createEffect(glass, selector, UIGlassEffectStyleRegular);
        }
    }
    return nil;
}

static UIGlassEffect *YMSystemGlassForPivotBar(YTPivotBarView *pivotBar) {
    UIGlassEffect *effect = objc_getAssociatedObject(pivotBar, kYMPivotBarSystemEffectKey);
    if (!effect) {
        effect = YMCreateSystemPivotBarGlassEffect();
        objc_setAssociatedObject(pivotBar, kYMPivotBarSystemEffectKey, effect, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return effect;
}

static UIVisualEffectView *YMSystemGlassViewForPivotBar(YTPivotBarView *pivotBar) {
    UIVisualEffectView *glassView = objc_getAssociatedObject(pivotBar, kYMPivotBarSystemEffectViewKey);
    if (!glassView) {
        UIGlassEffect *effect = YMSystemGlassForPivotBar(pivotBar);
        if (!effect) return nil;
        glassView = [[UIVisualEffectView alloc] initWithEffect:effect];
        glassView.userInteractionEnabled = NO;
        glassView.isAccessibilityElement = NO;
        glassView.accessibilityElementsHidden = YES;
        glassView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        objc_setAssociatedObject(pivotBar, kYMPivotBarSystemEffectViewKey, glassView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return glassView;
}

static void YMInstallSystemGlassOnPivotBar(YTPivotBarView *pivotBar) {
    if (!pivotBar) return;

    if (INTFORVAL(UseFrostedTabBar) == 2) {
        UIVisualEffectView *glassView = objc_getAssociatedObject(pivotBar, kYMPivotBarSystemEffectViewKey);
        [glassView removeFromSuperview];
        glassView.effect = nil;
        objc_setAssociatedObject(pivotBar, kYMPivotBarSystemEffectViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(pivotBar, kYMPivotBarSystemEffectKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        if ([objc_getAssociatedObject(pivotBar, kYMPivotBarHasOriginalBackgroundColorKey) boolValue]) {
            id originalBackgroundColor = objc_getAssociatedObject(pivotBar, kYMPivotBarOriginalBackgroundColorKey);
            pivotBar.backgroundColor = (originalBackgroundColor == [NSNull null]) ? nil : originalBackgroundColor;
            objc_setAssociatedObject(pivotBar, kYMPivotBarOriginalBackgroundColorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(pivotBar, kYMPivotBarHasOriginalBackgroundColorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return;
    }

    UIGlassEffect *systemEffect = YMSystemGlassForPivotBar(pivotBar);
    if (!systemEffect) return;

    if (![objc_getAssociatedObject(pivotBar, kYMPivotBarHasOriginalBackgroundColorKey) boolValue]) {
        id originalBackgroundColor = pivotBar.backgroundColor ?: [NSNull null];
        objc_setAssociatedObject(pivotBar, kYMPivotBarOriginalBackgroundColorKey, originalBackgroundColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(pivotBar, kYMPivotBarHasOriginalBackgroundColorKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    UIVisualEffectView *glassView = YMSystemGlassViewForPivotBar(pivotBar);
    if (!glassView) return;
    if (glassView.effect != systemEffect) glassView.effect = systemEffect;
    if (glassView.superview != pivotBar) [pivotBar insertSubview:glassView atIndex:0];
    if (!CGRectEqualToRect(glassView.frame, pivotBar.bounds)) glassView.frame = pivotBar.bounds;
    if (![pivotBar.backgroundColor isEqual:[UIColor clearColor]]) pivotBar.backgroundColor = [UIColor clearColor];
}

%hook YTPivotBarView
- (UIGlassEffect *)liquidGlassEffect {
    return YMSystemGlassForPivotBar(self);
}
- (UIGlassEffect *)liquidGlassEffectForPageStyle:(NSInteger)pageStyle {
    return YMSystemGlassForPivotBar(self);
}
- (UIVisualEffectView *)blurView {
    YMInstallSystemGlassOnPivotBar(self);
    return YMSystemGlassViewForPivotBar(self);
}
- (void)setBlurView:(UIVisualEffectView *)blurView {
    UIVisualEffectView *ourBlurView = YMSystemGlassViewForPivotBar(self);
    ourBlurView.effect = YMSystemGlassForPivotBar(self);
    YMInstallSystemGlassOnPivotBar(self);
    %orig(ourBlurView);
}
/*
- (void)layoutSubviews {
    %orig;
    YMInstallSystemGlassOnPivotBar(self);
}
- (void)didMoveToWindow {
    %orig;
    YMInstallSystemGlassOnPivotBar(self);
}
*/
%end

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
    if (self.chooseAccountButton != nil) YouModApplyLiquidGlassToView(self.chooseAccountButton, NO);
    if (self.alternateAccountButton != nil) YouModApplyLiquidGlassToView(self.alternateAccountButton, NO);
}
%end

%hook YTBackgroundPromoCell
- (YTQTMButton *)ctaButton {
    YTQTMButton *orig = %orig;
    if (orig) YouModApplyLiquidGlassToView(orig, NO);
    return orig;
}
%end

%hook YTReelHeaderView
- (void)addBackButton:(YTQTMButton *)button toStackView:(UIStackView *)stackView {
    if (button) YouModApplyLiquidGlassToView(button, NO);
    %orig;
}
%end

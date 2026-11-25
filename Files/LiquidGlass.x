#import "Headers.h"
#import <objc/message.h>

static const void *kYMLiquidGlassBackdropKey = &kYMLiquidGlassBackdropKey;

// sdk check for older yt versions: below 26 there is no Liquid Glass, so
// the same hooks fall back to a flat gray fill instead.
BOOL YMHostBundleSupportsLiquidGlass(void) {
    static BOOL supported = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *platformVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"DTPlatformVersion"];
        supported = platformVersion != nil &&
                    [platformVersion compare:@"26.0" options:NSNumericSearch] != NSOrderedAscending && IS_ENABLED(LiquidGlass);
    });
    return supported;
}

static UIVisualEffect *YMCreateSystemBarGlassEffect(void) {
    Class glass = %c(UIGlassEffect);
    SEL selector = @selector(effectWithStyle:);
    if (glass && [glass respondsToSelector:selector]) {
        UIVisualEffect *(*createEffect)(id, SEL, NSInteger) = (UIVisualEffect *(*)(id, SEL, NSInteger))objc_msgSend;
        return createEffect(glass, selector, 0); // UIGlassEffectStyleRegular
    }
    return nil;
}

// Pre-Liquid-Glass fallback rounding — matches YouTube's search bar (shared constant).
static CGFloat const YMGlassFallbackCornerRadius = YMCornerRadiusSearchBar;

// Flat gray fill that tracks its host's rounded corners. Hosts usually pin
// their cornerRadius after the backdrop is installed and don't clip subviews,
// so a plain square fill would poke past the rounding and override it.
@implementation YMGlassBackdropView
- (void)layoutSubviews {
    [super layoutSubviews];
    CALayer *hostLayer = self.superview.layer;
    if (!hostLayer) return;
    if (self.layer.cornerRadius != hostLayer.cornerRadius) self.layer.cornerRadius = hostLayer.cornerRadius;
    if (self.layer.cornerCurve != hostLayer.cornerCurve) self.layer.cornerCurve = hostLayer.cornerCurve;
}
@end

static UIView *YMEnsureGlassBackdrop(UIView *view) {
    UIView *backdrop = objc_getAssociatedObject(view, kYMLiquidGlassBackdropKey);
    if (!backdrop) {
        if (YMHostBundleSupportsLiquidGlass()) {
            UIVisualEffect *effect = YMCreateSystemBarGlassEffect();
            if (!effect) effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
            UIVisualEffectView *glassView = [[UIVisualEffectView alloc] initWithEffect:effect];
            glassView.userInteractionEnabled = NO;
            glassView.isAccessibilityElement = NO;
            glassView.accessibilityElementsHidden = YES;
            backdrop = glassView;
        } else {
            // Pre-Liquid-Glass host: flat gray fill — the same dynamic gray the
            // settings / download-library search fields use — instead of
            // YouTube's frosted glass blur.
            YMGlassBackdropView *fill = [YMGlassBackdropView new];
            fill.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
                return (trait.userInterfaceStyle == UIUserInterfaceStyleDark) ? [UIColor secondarySystemBackgroundColor] : [UIColor systemGray5Color];
            }];
            // Hosts that already carry their rounding (e.g. the SB pill) get it
            // immediately; pins applied later are picked up in layoutSubviews.
            fill.layer.cornerRadius = view.layer.cornerRadius;
            backdrop = fill;
            backdrop.userInteractionEnabled = NO;
            backdrop.isAccessibilityElement = NO;
            backdrop.accessibilityElementsHidden = YES;
        }
        [view insertSubview:backdrop atIndex:0];
        // Flexible: pinned on all sides so the glass stretches with the host while
        // it is dragged or resized — no manual frame syncing needed.
        backdrop.translatesAutoresizingMaskIntoConstraints = NO;
        [NSLayoutConstraint activateConstraints:@[
            [backdrop.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
            [backdrop.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
            [backdrop.topAnchor constraintEqualToAnchor:view.topAnchor],
            [backdrop.bottomAnchor constraintEqualToAnchor:view.bottomAnchor],
        ]];
        objc_setAssociatedObject(view, kYMLiquidGlassBackdropKey, backdrop, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return backdrop;
}

// Panel background for dialogs: glass blur over a light-gray base on iOS 26
// SDK hosts; flat gray (search-field gray) on pre-26 ones.
void YouModApplyFrostedPanelBackgroundToView(UIView *view) {
    if (!view) return;
    YMEnsureGlassBackdrop(view);
    view.backgroundColor = [UIColor systemGray6Color];
}

void YouModApplyLiquidGlassToView(UIView *view, BOOL wantsBackground) {
    if (!view) return;
    BOOL glassHost = YMHostBundleSupportsLiquidGlass();
    if (glassHost) {
        view.layer.cornerRadius = CGRectGetHeight(view.bounds) / 2.0;
    } else if (view.layer.cornerRadius == 0) {
        // Pre-Liquid-Glass host: round the flat gray fill like YouTube's search
        // bar instead of a capsule. Views that pin their own radius (the library
        // type pills, panels) keep it.
        view.layer.cornerRadius = YMGlassFallbackCornerRadius;
    }
    if ([view isKindOfClass:%c(YTChipCloudChipView)]) [view setValue:nil forKey:@"_touchFeedbackView"];
    else if ([view isKindOfClass:%c(YTLightweightQTMButton)]) {
        [view setValue:nil forKey:@"_touchFeedbackView"];
        for (UIView *sub in view.subviews) {
            if ([sub isKindOfClass:%c(YTTouchFeedbackView)]) {
                [sub removeFromSuperview];
                break;
            }
        }
        for (UIGestureRecognizer *ges in view.gestureRecognizers) {
            if ([ges isKindOfClass:%c(YTTouchFeedbackGestureRecognizer)]) {
                @try {
                    [[ges valueForKey:@"_controller"] setValue:nil forKey:@"_touchFeedbackView"];
                } @catch (id ex) {}
                break;
            }
        }
        ((YTLightweightQTMButton *)view).flatButtonHasOpaqueBackground = NO;
        @try {
            ((YTLightweightQTMButton *)view).disableTouchResponse = YES;
        } @catch (id ex2) {}
    }
    if (glassHost) {
        if (wantsBackground && [view respondsToSelector:@selector(tuui_applyFlexibleClearGlassWithShadowBackground)]) [view tuui_applyFlexibleClearGlassWithShadowBackground];
        else if (!wantsBackground && [view respondsToSelector:@selector(tuui_applyFlexibleSmallGlassBackground)]) [view tuui_applyFlexibleSmallGlassBackground];
    } else if (wantsBackground) {
        // Pre-Liquid-Glass host: YTFrostedGlassView backdrop instead of tuui_* glass.
        YMEnsureGlassBackdrop(view);
    }
}

%group Glass
%hook YTChipCloudChipView
- (void)didMoveToWindow {
    %orig;
    if (self.renderer && [self.renderer.description containsString:@"STYLE_FULL_SCREEN_RELATED"]) return;
    YouModApplyLiquidGlassToView(self, YES);
}
%end

%hook YTRightNavigationButtons
- (NSArray <YTQTMButton *> *)visibleButtons {
    NSArray <YTQTMButton *> *buttons = %orig;
    YouModApplyLiquidGlassToView(self, YES);
    for (YTQTMButton *button in buttons) {
        [button setValue:nil forKey:@"_touchFeedbackView"];
        for (UIView *sub in button.subviews) {
            if ([sub isKindOfClass:%c(YTTouchFeedbackView)]) {
                [sub removeFromSuperview];
                break;
            }
        }
        for (UIGestureRecognizer *ges in button.gestureRecognizers) {
            if ([ges isKindOfClass:%c(YTTouchFeedbackGestureRecognizer)]) {
                @try {
                    [[ges valueForKey:@"_controller"] setValue:nil forKey:@"_touchFeedbackView"];
                } @catch (id ex) {}
                break;
            }
        }
        ((YTLightweightQTMButton *)button).flatButtonHasOpaqueBackground = NO;
        @try {
            ((YTLightweightQTMButton *)button).disableTouchResponse = YES;
        } @catch (id ex2) {}
    }
    return buttons;
}
- (void)setLeadingPadding:(CGFloat)padding { %orig(0); }
- (void)setTailingPadding:(CGFloat)padding { %orig(0); }
%end

%hook YTSearchViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    UIView *voiceView = [self valueForKey:@"_voiceButtonContainerView"];
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

%hook YTInlineSignInChannelCell
- (void)didMoveToWindow {
    %orig;
    YTQTMButton *button = [self valueForKey:@"_editChannelButton"];
    if (button) YouModApplyLiquidGlassToView(button, YES);
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
%end

%ctor {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        LiquidGlass: @YES
    }];
    %init;
    if (YMHostBundleSupportsLiquidGlass()) %init(Glass);
}

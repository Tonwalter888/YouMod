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

// Native UITabBar overlay for the pivot bar — real iOS 26 Liquid Glass.
// YouTube's bar chrome stays in the hierarchy (hidden) behind it; taps call
// selectItemWithPivotIdentifier: so startup-tab and Download-library logic
// in Tabbar.x still runs unchanged.

static YMPivotGlassTabBar *gGlassDelegate;
static UITabBar *gTabBar;
static __weak UIView *gHostBar;
static __weak YTPivotBarViewController *gPivotVC;
static NSMutableArray<YTIPivotBarSupportedRenderers *> *gPivotItems;
static NSMutableArray<NSString *> *gPivotIDs;
static NSString *gSelectedPivotID;
static const void *kYMGlassMenuKey = &kYMGlassMenuKey;

@implementation YMPivotGlassTabBar

+ (BOOL)isActive {
    static BOOL active = NO;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        // The OS draws glass tab bars from 26; the host SDK check keeps older
        // YouTube builds on the plain bar — same gate as LiquidGlass.x.
        active = YMHostBundleSupportsLiquidGlass() &&
                 [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){26, 0, 0}];
    });
    return active;
}

+ (void)setPivotBarViewController:(YTPivotBarViewController *)vc {
    gPivotVC = vc;
}

// pivotID -> YouTube's hidden item view (source of the real tab icons).
+ (NSDictionary<NSString *, YTPivotBarItemView *> *)itemViewsByPivotID {
    NSMutableDictionary *views = [NSMutableDictionary dictionary];
    for (YTPivotBarItemView *itemView in [(id<YMPivotBarViewProto>)gHostBar itemViews]) {
        NSString *pid = [itemView pivotIdentifier];
        if (pid) views[pid] = itemView;
    }
    return views;
}

+ (NSString *)titleForItem:(YTIPivotBarSupportedRenderers *)item {
    if (IS_ENABLED(HideTabLabels)) return nil;
    YTIStringRun *run = item.pivotBarItemRenderer.title.runsArray.firstObject;
    // nil = icon-only item (centered); an empty title offsets the content.
    return run.text.length > 0 ? run.text : nil;
}

// Tab icon: YouTube's own glyph from the hidden item view.
+ (UIImage *)iconForItemView:(YTPivotBarItemView *)itemView {
    // Account avatar: YT's button image carries the selected ring and gets
    // flattened to a black silhouette — draw the raw avatar as a colored circle.
    UIImage *avatar = [self avatarForItemView:itemView];
    if (avatar) return avatar;
    return [itemView navigationButtonImageView].image;
}

// Ringless avatar, circle-cropped to the sibling icons' size, keeping its colors.
+ (UIImage *)avatarForItemView:(YTPivotBarItemView *)itemView {
    UIImageView *avatarView = [itemView valueForKey:@"_avatarImageView"]; // ivar _avatarImageView
    UIImage *image = avatarView.image;
    if (!image) return nil;
    CGFloat side = [itemView navigationButtonImageView].image.size.width ?: 28;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(side, side)];
    UIImage *rounded = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, side, side)] addClip];
        [image drawInRect:CGRectMake(0, 0, side, side)];
    }];
    return [rounded imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

// YouTube's own bar chrome (blur, separator, items) — the UITabBar replaces it.
+ (void)hideChrome {
    for (UIView *sub in gHostBar.subviews) {
        if (sub != gTabBar) sub.hidden = YES;
    }
    gHostBar.backgroundColor = [UIColor clearColor];
}

+ (void)rebuild {
    UIView *barView = gHostBar;
    YTIPivotBarRenderer *renderer = [(id<YMPivotBarViewProto>)barView renderer];
    if (!barView || !renderer) return;
    NSArray<YTIPivotBarSupportedRenderers *> *items = [renderer itemsArray];
    NSDictionary<NSString *, YTPivotBarItemView *> *views = [self itemViewsByPivotID];
    NSMutableArray<UITabBarItem *> *tabItems = [NSMutableArray arrayWithCapacity:items.count];
    gPivotItems = [NSMutableArray arrayWithCapacity:items.count];
    gPivotIDs = [NSMutableArray arrayWithCapacity:items.count];
    for (YTIPivotBarSupportedRenderers *item in items) {
        NSString *pid = YMPivotIDOfItem(item);
        if (!pid) continue;
        UITabBarItem *tabItem = [[UITabBarItem alloc] initWithTitle:[self titleForItem:item]
                                                              image:[self iconForItemView:views[pid]]
                                                               tag:0];
        tabItem.accessibilityIdentifier = pid;
        [tabItems addObject:tabItem];
        [gPivotItems addObject:item];
        [gPivotIDs addObject:pid];
    }
    gTabBar.items = tabItems;
    [self hideChrome];
    [self attachContextMenu];
}

+ (void)attachToBarView:(YTPivotBarView *)barView {
    if (![self isActive] || !barView) return;
    if (!gGlassDelegate) gGlassDelegate = [YMPivotGlassTabBar new];
    if (!gTabBar) {
        // Stock UIKit drawing = iOS 26 Liquid Glass (the clear-glass capsule sits on
        // the selected item). White icon only on that item; the others stay the
        // default outlined look.
        gTabBar = [[UITabBar alloc] initWithFrame:barView.bounds];
        gTabBar.delegate = gGlassDelegate;
        gTabBar.tintColor = [UIColor labelColor];
        UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
        [appearance configureWithDefaultBackground];
        appearance.stackedLayoutAppearance.selected.iconColor = [UIColor whiteColor];
        appearance.inlineLayoutAppearance.selected.iconColor = [UIColor whiteColor];
        appearance.compactInlineLayoutAppearance.selected.iconColor = [UIColor whiteColor];
        // Equal-width items (iOS 26 sizes them by content otherwise).
        appearance.stackedItemPositioning = UITabBarItemPositioningFill;
        gTabBar.standardAppearance = appearance;
        gTabBar.scrollEdgeAppearance = appearance;
        gTabBar.itemPositioning = UITabBarItemPositioningFill;
        gTabBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    if (gTabBar.superview != barView) {
        [gTabBar removeFromSuperview];
        [barView addSubview:gTabBar];
    }
    gHostBar = barView;
    gTabBar.frame = barView.bounds;
    [self rebuild];
}

+ (void)refreshIcons {
    if (!gTabBar || !gHostBar) return;
    NSDictionary<NSString *, YTPivotBarItemView *> *views = [self itemViewsByPivotID];
    NSUInteger count = MIN(gTabBar.items.count, gPivotIDs.count);
    for (NSUInteger i = 0; i < count; i++) {
        UIImage *image = [self iconForItemView:views[gPivotIDs[i]]];
        if (image) gTabBar.items[i].image = image;
    }
    [self hideChrome];
    [self attachContextMenu];
}

// The long-press menu (Manage Tabs, …) lives on YouTube's first item view, which
// the glass tab bar hides and covers — forward the bar's long-press to that menu.
+ (void)attachContextMenu {
    if (!gTabBar || !gHostBar || objc_getAssociatedObject(gTabBar, &kYMGlassMenuKey)) return;
    UIContextMenuInteraction *interaction = [[UIContextMenuInteraction alloc] initWithDelegate:gGlassDelegate];
    [gTabBar addInteraction:interaction];
    objc_setAssociatedObject(gTabBar, &kYMGlassMenuKey, interaction, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location {
    // First item slot only, like the hidden item view interaction.
    NSUInteger count = MAX(gTabBar.items.count, (NSUInteger)1);
    if (location.x > CGRectGetWidth(gTabBar.bounds) / count) return nil;
    YTPivotBarItemView *firstItem = [(id<YMPivotBarViewProto>)gHostBar itemViews].firstObject;
    return [firstItem contextMenuInteraction:interaction configurationForMenuAtLocation:location];
}

+ (void)selectPivotIdentifier:(NSString *)pivotID {
    if (pivotID) gSelectedPivotID = [pivotID copy];
    if (!gTabBar || !pivotID) return;
    NSUInteger index = [gPivotIDs indexOfObject:pivotID];
    if (index == NSNotFound || index >= gTabBar.items.count) return;
    gTabBar.selectedItem = gTabBar.items[index];
}

+ (void)setBadgeCount:(id)count forPivotIdentifier:(NSString *)pivotID {
    if (!gTabBar) return;
    NSUInteger index = [gPivotIDs indexOfObject:pivotID];
    if (index == NSNotFound || index >= gTabBar.items.count) return;
    long long value = [count longLongValue];
    gTabBar.items[index].badgeValue = value > 0 ? [NSString stringWithFormat:@"%lld", value] : nil;
}

- (void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
    NSUInteger index = [tabBar.items indexOfObject:item];
    if (index == NSNotFound || index >= gPivotIDs.count) return;
    YTPivotBarViewController *vc = gPivotVC;
    if (!vc) return;
    // The real tap path, not selectItemWithPivotIdentifier: — that one treats
    // every tab as a browse request and wedges on tabs without a destination
    // (Create/FEuploads), after which no tab switches any more.
    YTIPivotBarSupportedRenderers *rendererItem = gPivotItems[index];
    YTIPivotBarIconOnlyItemRenderer *iconOnly = rendererItem.pivotBarIconOnlyItemRenderer;
    if (iconOnly.pivotIdentifier.length > 0) {
        if (YMShowLibraryForItem(vc, iconOnly)) return;
        [vc didTapItemWithIconOnlyItemRenderer:iconOnly badgeNavigationCommand:nil interactionLoggingClientData:nil];
    } else {
        YTIPivotBarItemRenderer *renderer = rendererItem.pivotBarItemRenderer;
        if (YMShowLibraryForItem(vc, renderer)) return;
        [vc didTapItemWithRenderer:renderer];
    }
}

@end

%hook YTPivotBarView
- (void)selectItemWithPivotIdentifier:(id)identifier {
    %orig;
    [YMPivotGlassTabBar selectPivotIdentifier:identifier];
}
- (void)setUnseenCount:(id)count pivotIdentifier:(id)identifier {
    %orig;
    [YMPivotGlassTabBar setBadgeCount:count forPivotIdentifier:identifier];
}
- (void)setShouldShowTopDivider:(BOOL)arg { %orig(NO); }
%end

%hook YTPivotBarViewController
- (void)updateViewsWithSelectedPivotIdentifier:(id)pivotIdentifier {
    %orig;
    [YMPivotGlassTabBar selectPivotIdentifier:pivotIdentifier];
}
%end

%hook YTPivotBarItemView
- (void)setSelected:(BOOL)selected {
    %orig;
    if (selected) [YMPivotGlassTabBar selectPivotIdentifier:[self pivotIdentifier]];
    [YMPivotGlassTabBar refreshIcons]; // YouTube swaps outlined/filled art on selection
}
- (void)setupIconsAndTitles {
    %orig;
    [YMPivotGlassTabBar refreshIcons];
}
- (void)updateTintColorForIconsAndTitles {
    %orig;
    [YMPivotGlassTabBar refreshIcons];
}
- (void)updateAvatarView {
    %orig;
    [YMPivotGlassTabBar refreshIcons];
}
- (void)imageViewDidLoad:(id)load {
    %orig;
    [YMPivotGlassTabBar refreshIcons];
}
%end

%hook YTColdConfig
- (BOOL)mainAppCoreClientIosEnablePositionedFloatyBars { return NO; }
%end
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
%new(B@:@)
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
    if (gesture != self.ymSeekPan) return YES;
    CGPoint velocity = [(UIPanGestureRecognizer *)gesture velocityInView:self];
    return fabs(velocity.x) > fabs(velocity.y);
}
%new(v@:@)
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

%ctor {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        LiquidGlass: @YES
    }];
    %init;
    if (YMHostBundleSupportsLiquidGlass()) %init(Glass);
}

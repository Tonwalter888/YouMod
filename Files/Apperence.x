#import "Headers.h"

static const void *kOLEDKey = &kOLEDKey;

%group OLEDTheme
%hook YTColor
+ (UIColor *)black0 { return [UIColor blackColor]; }
+ (UIColor *)black1 { return [UIColor blackColor]; }
+ (UIColor *)black2 { return [UIColor blackColor]; }
+ (UIColor *)black3 { return [UIColor blackColor]; }
+ (UIColor *)black4 { return [UIColor blackColor]; }
%end

%hook YTCommonColorPalette
- (UIColor *)baseBackground { return self.pageStyle == 1 ? [UIColor blackColor] : %orig; }
- (UIColor *)brandBackgroundSolid { return self.pageStyle == 1 ? [UIColor blackColor] : %orig; }
- (UIColor *)brandBackgroundPrimary { return self.pageStyle == 1 ? [UIColor blackColor] : %orig; }
- (UIColor *)brandBackgroundSecondary { return self.pageStyle == 1 ? [UIColor blackColor] : %orig; }
- (UIColor *)raisedBackground { return self.pageStyle == 1 ? [UIColor blackColor] : %orig; }
- (UIColor *)staticBrandBlack { return self.pageStyle == 1 ? [UIColor blackColor] : %orig; }
- (UIColor *)generalBackgroundA { return self.pageStyle == 1 ? [UIColor blackColor] : %orig; }
%end

%hook YTInnerTubeCollectionViewController
- (UIColor *)backgroundColor:(NSInteger)pageStyle { return pageStyle == 1 ? [UIColor blackColor] : %orig; }
%end

void YouModApplyOLEDToDisplayView(_ASDisplayView *view, NSString *iden) {
    if (!IS_ENABLED(OLEDTheme)) return;
    NSSet *blackViews = [NSSet setWithObjects:
        @"id.elements.components.comment_composer",
        @"id.subs.subscriptions_channel_bar",
        @"eml.vwc",
        @"eml.cvr",
        @"PAmedia_hub_device_picker.engagement_panel_header", nil
    ];  
    if ([blackViews containsObject:iden]) {
        view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(view) ? [UIColor blackColor] : [UIColor clearColor];
        }];
        return;
    } else if ([iden isEqualToString:@"id.elements.components.filter_chip_bar"]) {
        UIColor *dynamicColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(view) ? [UIColor blackColor] : [UIColor clearColor];
        }];
        view.backgroundColor = dynamicColor;
        view.superview.backgroundColor = dynamicColor;
        return;
    }  
    UIViewController *controller = view._viewControllerForAncestor;
    if ([controller isKindOfClass:%c(YTActionSheetDialogViewController)] || [controller isKindOfClass:%c(YTBottomSheetController)]) {
        if ([view.superview.accessibilityIdentifier isEqualToString:@"eml.animated_subscribe_button"]) return;
        view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(view) ? [UIColor blackColor] : [UIColor clearColor];
        }];
    } else if ([iden isEqualToString:@"eml.live_chat_text_message"] && [controller isKindOfClass:%c(YCHAsyncLiveChatCollectionViewController)]) {
        YCHAsyncLiveChatCollectionViewController *con = (YCHAsyncLiveChatCollectionViewController *)controller;
        if ([con.view isKindOfClass:%c(YCHAsyncLiveChatImmersiveCollectionView)]) return;
        view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(view) ? [UIColor blackColor] : [UIColor whiteColor];
        }];
    }
}

void YouModApplyOLEDCollectionView(ASCollectionView *self) {
    if (!IS_ENABLED(OLEDTheme)) return;
    NSString *iden = self.accessibilityIdentifier;
    NSSet *blackViews = [NSSet setWithObjects:
        @"eml.chip_bar_collection",
        @"subs_channel_bar.collection", nil
    ];  
    if ([blackViews containsObject:iden]) {
        self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
        }];
    }
}

%hook YTContextualWrapView
- (void)didMoveToWindow {
    %orig;
    if (objc_getAssociatedObject(self, kOLEDKey)) return;
    UIView *sup = self.superview;
    if ([sup isKindOfClass:%c(YTContextualSheetView)]) {
        self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(self) ? [UIColor blackColor] : [UIColor whiteColor];
        }];
    }
    objc_setAssociatedObject(self, kOLEDKey, @YES, OBJC_ASSOCIATION_ASSIGN);
}
%end

%hook YTDialogContainerScrollView
- (void)didMoveToWindow {
    %orig;
    if (objc_getAssociatedObject(self, kOLEDKey)) return;
    self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return isDarkMode(self) ? [UIColor blackColor] : [UIColor whiteColor];
    }];
    objc_setAssociatedObject(self, kOLEDKey, @YES, OBJC_ASSOCIATION_ASSIGN);
}
%end

%hook MDCInkView
- (void)didMoveToWindow {
    %orig;
    if (objc_getAssociatedObject(self, kOLEDKey)) return;
    if ([self.superview isKindOfClass:%c(GOODialogActionMDCButton)]) {
        UIViewController *controller = self._viewControllerForAncestor;
        if ([controller isKindOfClass:%c(YTBottomSheetController)] || [controller isKindOfClass:%c(GOOModalWindowViewController)]) return;
        self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
        }];
    }
    objc_setAssociatedObject(self, kOLEDKey, @YES, OBJC_ASSOCIATION_ASSIGN);
}
%end

%hook YTRiveStartupAnimationViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    UIView *mainView = self.view;
    if (objc_getAssociatedObject(mainView, kOLEDKey)) return;
    mainView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return isDarkMode(mainView) ? [UIColor blackColor] : [UIColor whiteColor];
    }];
    objc_setAssociatedObject(mainView, kOLEDKey, @YES, OBJC_ASSOCIATION_ASSIGN);
}
%end

%hook YTStartupAnimationViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    UIView *mainView = self.view;
    if (objc_getAssociatedObject(mainView, kOLEDKey)) return;
    mainView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return isDarkMode(mainView) ? [UIColor blackColor] : [UIColor whiteColor];
    }];
    objc_setAssociatedObject(mainView, kOLEDKey, @YES, OBJC_ASSOCIATION_ASSIGN);
}
%end

%hook YTEngagementPanelView
- (void)setFooterView:(UIView *)view {
    %orig;
    if (view) {
        UIView *sub = view.subviews.firstObject;
        if (objc_getAssociatedObject(sub, kOLEDKey)) return;
        sub.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(sub) ? [UIColor blackColor] : [UIColor clearColor];
        }];
        objc_setAssociatedObject(sub, kOLEDKey, @YES, OBJC_ASSOCIATION_ASSIGN);
    }
}
%end
%end

%group OLEDKeyboard
%hook UIKeyboard
- (void)displayLayer:(id)arg1 {
    %orig;
    if (objc_getAssociatedObject(self, kOLEDKey)) return;
    self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
    }];
    objc_setAssociatedObject(self, kOLEDKey, @YES, OBJC_ASSOCIATION_ASSIGN);
}
%end

%hook UIPredictionViewController
- (id)_currentTextSuggestions {
    UIKeyboard *keyboard = [%c(UIKeyboard) activeKeyboard];
    UIView *mainView = self.view;
    if (objc_getAssociatedObject(mainView, kOLEDKey)) return %orig;
    UIColor *dynamicColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return isDarkMode(mainView) ? [UIColor blackColor] : [UIColor clearColor];
    }];
    [mainView setBackgroundColor:dynamicColor];
    keyboard.backgroundColor = dynamicColor;
    objc_setAssociatedObject(mainView, kOLEDKey, @YES, OBJC_ASSOCIATION_ASSIGN);
    return %orig;
}
%end

%hook UIKeyboardDockView
- (void)layoutSubviews {
    %orig;
    if (objc_getAssociatedObject(self, kOLEDKey)) return;
    self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
    }];
    objc_setAssociatedObject(self, kOLEDKey, @YES, OBJC_ASSOCIATION_ASSIGN);
}
%end

// Since we can't hook a private framework class from UIKit, we check the class name through the nearest available from UIKit class
%hook UIInputView
- (void)layoutSubviews {
    %orig;
    if (objc_getAssociatedObject(self, kOLEDKey)) return;
    if ([self isKindOfClass:NSClassFromString(@"TUIEmojiSearchInputView")] || [self isKindOfClass:NSClassFromString(@"_SFAutoFillInputView")]) {
        self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
        }];
    }
    objc_setAssociatedObject(self, kOLEDKey, @YES, OBJC_ASSOCIATION_ASSIGN);
}
%end

%hook UIKBVisualEffectView
- (void)layoutSubviews {
    %orig;
    if (isDarkMode(self)) {
        self.backgroundEffects = nil;
        self.backgroundColor = [UIColor blackColor];
    } else {
        self.backgroundColor = [UIColor clearColor];
    }
}
%end
%end

%ctor {
    if (IS_ENABLED(OLEDTheme)) {
        %init(OLEDTheme);
    }
    if (IS_ENABLED(OLEDKeyboard)) {
        %init(OLEDKeyboard);
    }
}

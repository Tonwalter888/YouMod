#import "Headers.h"

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
    UIViewController *controller = view._viewControllerForAncestor;
    if ([controller isKindOfClass:%c(YTRelatedVideosCollectionViewController)]) return;
    NSSet *blackViews = [NSSet setWithObjects:
        @"id.elements.components.comment_composer",
        @"id.subs.subscriptions_channel_bar",
        @"eml.cvr",
        @"eml.vwc",
        @"intro_dialog",
        @"PAmedia_hub_device_picker.engagement_panel_header", nil
    ];  
    if ([blackViews containsObject:iden]) {
        view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(view) ? [UIColor blackColor] : [UIColor clearColor];
        }];
    } else if ([iden isEqualToString:@"id.elements.components.filter_chip_bar"]) {
        UIColor *dynamicColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(view) ? [UIColor blackColor] : [UIColor clearColor];
        }];
        view.backgroundColor = dynamicColor;
        view.superview.backgroundColor = dynamicColor;
    } else if ([controller isKindOfClass:%c(YTActionSheetDialogViewController)] || [controller isKindOfClass:%c(YTBottomSheetController)]) {
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
    } else {
        ELMNodeController *nodeCon = view.keepalive_node.nodeController;
        NSString *desc = nil;
        @try {
            desc = [[[nodeCon performSelector:@selector(parent)] performSelector:@selector(owningComponent)] description];
        } @catch (id ex) {}
        if (desc != nil && ([desc containsString:@"live_chat_buy_flow_panel_header.eml"] 
            || [desc containsString:@"missing_content_view.eml"])) {
            view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
                return isDarkMode(view) ? [UIColor blackColor] : [UIColor clearColor];
            }];
        } else {
            desc = nil;
            @try {
                desc = [[[[nodeCon performSelector:@selector(parent)] performSelector:@selector(parent)] performSelector:@selector(owningComponent)] description];
            } @catch (id ex) {
                return;
            }
            if (desc != nil && [desc containsString:@"macro_markers_list_item.eml"]) {
                view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
                    return isDarkMode(view) ? [UIColor blackColor] : [UIColor clearColor];
                }];
            }
        }
    }
}

void YouModApplyOLEDCollectionView(ASCollectionView *view, NSString *iden) {
    if (!IS_ENABLED(OLEDTheme) || ![iden isEqualToString:@"eml.chip_bar_collection"]) return;
    view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return isDarkMode(view) ? [UIColor blackColor] : [UIColor clearColor];
    }];
}

%hook YTContextualWrapView
- (void)setBackgroundColor:(UIColor *)color {
    color = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return isDarkMode(self) ? [UIColor blackColor] : [UIColor whiteColor];
    }];
    %orig(color);
}
%end

%hook YTDialogContainerScrollView
- (void)setBackgroundColor:(UIColor *)color {
    color = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return isDarkMode(self) ? [UIColor blackColor] : [UIColor whiteColor];
    }];
    %orig(color);
}
%end

%hook GOODialogView
- (void)setBackgroundColor:(UIColor *)color {
    color = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return isDarkMode(self) ? [UIColor blackColor] : [UIColor whiteColor];
    }];
    %orig(color);
}
%end

%hook GOODialogContentView
- (void)didMoveToWindow {
    %orig;
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:%c(YTELMView)]) {
            UIView *view = sub.subviews[0];
            view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
                return isDarkMode(view) ? [UIColor blackColor] : [UIColor whiteColor];
            }];
            break;
        }
    }
}
%end

%hook MDCInkView
- (void)didMoveToWindow {
    %orig;
    if (![self.superview isKindOfClass:%c(GOODialogActionMDCButton)]) return;
    UIViewController *controller = self._viewControllerForAncestor;
    if ([controller isKindOfClass:%c(YTBottomSheetController)] || [controller isKindOfClass:%c(GOOModalWindowViewController)]) return;
    self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
    }];
}
%end

%hook YTStartupAnimationViewController
- (void)viewWillAppear:(BOOL)animated {
    UIView *mainView = self.view;
    mainView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return isDarkMode(mainView) ? [UIColor blackColor] : [UIColor whiteColor];
    }];
    %orig;
}
%end

%hook YTEngagementPanelView
- (void)setFooterView:(UIView *)view {
    %orig;
    if (!view) return;
    UIView *sub = view.subviews.firstObject;
    sub.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return isDarkMode(sub) ? [UIColor blackColor] : [UIColor clearColor];
    }];
}
%end
%end

%group OLEDKeyboard
%hook UIKeyboard
- (void)displayLayer:(id)arg1 {
    %orig;
    self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
    }];
}
%end

%hook UIPredictionViewController
- (id)_currentTextSuggestions {
    UIKeyboard *keyboard = [%c(UIKeyboard) activeKeyboard];
    UIView *mainView = self.view;
    UIColor *dynamicColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return isDarkMode(mainView) ? [UIColor blackColor] : [UIColor clearColor];
    }];
    [mainView setBackgroundColor:dynamicColor];
    keyboard.backgroundColor = dynamicColor;
    return %orig;
}
%end

// Janky OLED keyboard hack
// blame @ZomkaDEV for this
%hook UIKeyboardDockView
- (void)layoutSubviews {
    %orig;
    if (!isDarkMode(self)) return;

    // Pre-iOS 26 and iOS 26+ keyboards are styled differently
    __block CGFloat top = CGFLOAT_MAX, btnH = 0;
    NSMutableArray *vq = [NSMutableArray arrayWithObject:self];
    while (vq.count) {
        UIView *v = vq.firstObject; [vq removeObjectAtIndex:0];
        for (UIView *c in v.subviews) [vq addObject:c];
        if ([v isKindOfClass:NSClassFromString(@"UIKeyboardDockItemButton")]) {
            CGRect r = [v convertRect:v.bounds toView:self];
            top = MIN(top, CGRectGetMinY(r));
            btnH = MAX(btnH, r.size.height);
        }
    }
    if (btnH <= 0 || self.bounds.size.height <= btnH * 2.5) {
        self.backgroundColor = [UIColor blackColor];
        return;
    }

    __weak UIView *weakSelf = self;
    void (^hideBackdrop)(void) = ^{
        UIView *me = weakSelf; if (!me) return;
        CALayer *root = me.window ? me.window.layer : me.layer; if (!root) return;
        Class backdrop = NSClassFromString(@"CABackdropLayer"); if (!backdrop) return;
        NSMutableArray *q = [NSMutableArray arrayWithObject:root];
        while (q.count) {
            CALayer *l = q.firstObject; [q removeObjectAtIndex:0];
            for (CALayer *sub in l.sublayers) [q addObject:sub];
            if ([l isKindOfClass:backdrop]) l.hidden = YES;
        }
    };
    hideBackdrop();
    dispatch_async(dispatch_get_main_queue(), hideBackdrop);

    if (top == CGFLOAT_MAX) return;
    UIView *strip = [self viewWithTag:0x0DEC];
    if (!strip) {
        strip = [[UIView alloc] init];
        strip.tag = 0x0DEC;
        strip.backgroundColor = [UIColor blackColor];
        strip.userInteractionEnabled = NO;
        [self insertSubview:strip atIndex:0];
    }
    strip.frame = CGRectMake(0, top, self.bounds.size.width, self.bounds.size.height - top);
}
%end

// Private class can't be hooked directly; detect it by name via its UIKit base class.
%hook UIInputView
- (void)layoutSubviews {
    %orig;
    if (![self isKindOfClass:NSClassFromString(@"TUIEmojiSearchInputView")] && ![self isKindOfClass:NSClassFromString(@"_SFAutoFillInputView")]) return;
    self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
    }];
}
%end

%hook UIKBInputBackdropView
- (void)layoutSubviews {
    %orig;
    self.hidden = isDarkMode(self);
}
%end

%hook UIKBVisualEffectView
- (void)layoutSubviews {
    %orig;
    if (isDarkMode(self)) {
        self.backgroundEffects = nil;
        self.backgroundColor = [UIColor blackColor];
        self.hidden = NO;
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

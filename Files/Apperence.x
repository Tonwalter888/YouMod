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

%hook _ASDisplayView
- (void)layoutSubviews {
    %orig;
    NSSet *blackViews = [NSSet setWithObjects:
        @"id.elements.components.comment_composer",
        @"id.subs.subscriptions_channel_bar",
        @"PAmedia_hub_device_picker.engagement_panel_header", nil
    ];  
    if ([blackViews containsObject:self.accessibilityIdentifier]) {
        self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
        }];
        return;
    }     
    UIViewController *controller = self._viewControllerForAncestor;
    if ([controller isKindOfClass:%c(YTActionSheetDialogViewController)] || [controller isKindOfClass:%c(YTBottomSheetController)]) {
        if ([self.superview.accessibilityIdentifier isEqualToString:@"eml.animated_subscribe_button"]) return;
        self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
        }];
        return;
    } else if ([self.accessibilityIdentifier isEqualToString:@"eml.live_chat_text_message"] && [controller isKindOfClass:%c(YCHAsyncLiveChatCollectionViewController)]) {
        YCHAsyncLiveChatCollectionViewController *con = (YCHAsyncLiveChatCollectionViewController *)controller;
        if ([con.view isKindOfClass:%c(YCHAsyncLiveChatImmersiveCollectionView)]) return;
        self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(self) ? [UIColor blackColor] : [UIColor whiteColor];
        }];
        return;
    } else if ([controller isKindOfClass:%c(YTELMViewController)]) {
        YTELMViewController *con = (YTELMViewController *)controller;
        YTIElementRenderer *renderer = [con valueForKey:@"_renderer"];
        NSString *desc = [renderer description];
        if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.text_field"] && [desc containsString:@"timeline_search_input_form_id"] && [desc containsString:@"search_input.eml"]) {
            self.superview.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
                return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
            }];
        } else if ([desc containsString:@"transcript_panel.eml"]) {
            self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
                return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
            }];
        }
        return;
    } else if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.filter_chip_bar"]) {
        UIColor *dynamicColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
        }];
        self.backgroundColor = dynamicColor;
        self.superview.backgroundColor = dynamicColor;
        return;
    }
}
%end

%hook ASCollectionView
- (void)layoutSubviews {
    %orig;
    NSSet *blackViews = [NSSet setWithObjects:
        @"eml.chip_bar_collection",
        @"subs_channel_bar.collection", nil
    ];  
    if ([blackViews containsObject:self.accessibilityIdentifier]) {
        self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
        }];
    }
    if ([self.accessibilityIdentifier isEqualToString:@"subs_channel_bar.collection"]) {
        self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
        }];
    }
    if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.more_drawer_collection"]) {
        self.superview.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(self) ? [UIColor blackColor] : [UIColor whiteColor];
        }];
    }
}
%end

%hook YTContextualWrapView
- (void)layoutSubviews {
    %orig;
    UIView *sup = self.superview;
    if ([sup isKindOfClass:%c(YTContextualSheetView)]) {
        self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(self) ? [UIColor blackColor] : [UIColor whiteColor];
        }];
    }
}
%end

%hook ASScrollView
- (void)layoutSubviews {
    %orig;
    ASDisplayNode *node = self.scrollNode;
    if (node) {
        for (UIView *child in node.yogaChildren) {
            NSString *desc = [child description];
            if ([desc containsString:@"id.elements.components.report_form_reason_select_page.container"] || [desc containsString:@"id.elements.components.report_form_sign_in_page.container"]) {
                self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
                    return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
                }];
                break;
            }
        }
    } 
}
%end

%hook MDCInkView
- (void)layoutSubviews {
    %orig;
    if ([self.superview isKindOfClass:%c(GOODialogActionMDCButton)]) {
        UIViewController *controller = self._viewControllerForAncestor;
        if ([controller isKindOfClass:%c(YTBottomSheetController)] || [controller isKindOfClass:%c(GOOModalWindowViewController)]) return;
        self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
        }];
    }
}
%end

%hook YTStartupAnimationViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    UIView *mainView = self.view;
    mainView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return isDarkMode(mainView) ? [UIColor blackColor] : [UIColor whiteColor];
    }];
}
%end

%hook YTEngagementPanelView
- (void)setFooterView:(UIView *)view {
    %orig;
    if (view) {
        UIView *sub = view.subviews.firstObject;
        sub.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
        }];
    }
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

%hook UIKeyboardDockView
- (void)layoutSubviews {
    %orig;
    self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
    }];
}
%end

// Since we can't hook a private framework class from UIKit, we check the class name through the nearest available from UIKit class
%hook UIInputView
- (void)layoutSubviews {
    %orig;
    if ([self isKindOfClass:NSClassFromString(@"TUIEmojiSearchInputView")] || [self isKindOfClass:NSClassFromString(@"_SFAutoFillInputView")]) {
        self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
        }];
    }
}
%end

%hook UIKBVisualEffectView
- (void)layoutSubviews {
    %orig;
    if (isDarkMode(self)) {
        self.backgroundEffects = nil;
    }
    self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
    }];
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
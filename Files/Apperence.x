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

%hook UITableViewCell
- (void)_layoutSystemBackgroundView {
    %orig;
    UIView *systemBackgroundView = [self valueForKey:@"_systemBackgroundView"];
    NSString *backgroundViewKey = class_getInstanceVariable(systemBackgroundView.class, "_colorView") ? @"_colorView" : @"_backgroundView";
    ((UIView *)[systemBackgroundView valueForKey:backgroundViewKey]).backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return isDarkMode(self) ? [UIColor blackColor] : [UIColor whiteColor];
    }];
}
- (void)_layoutSystemBackgroundView:(BOOL)arg1 {
    %orig;
    ((UIView *)[[self valueForKey:@"_systemBackgroundView"] valueForKey:@"_colorView"]).backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return isDarkMode(self) ? [UIColor blackColor] : [UIColor whiteColor];
    }];
}
%end

%hook _ASDisplayView
- (void)didMoveToWindow {
    %orig;
    NSSet *blackViews = [NSSet setWithObjects:
        @"id.elements.components.comment_composer",
        // @"eml.cvr",
        @"id.subs.subscriptions_channel_bar",
        @"PAmedia_hub_device_picker.engagement_panel_header", nil
        // @"eml.vwc", nil
    ];  
    if ([blackViews containsObject:self.accessibilityIdentifier]) {
        self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
        }];
        return;
    }     
    // Action dialog
    UIResponder *responder = self.nextResponder;
    while (responder != nil) {
        if ([responder isKindOfClass:%c(YTActionSheetDialogViewController)] || [responder isKindOfClass:%c(YTBottomSheetController)]) {
            if ([self.superview.accessibilityIdentifier isEqualToString:@"eml.animated_subscribe_button"]) break;
            self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
                return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
            }];
            break;
        } else if ([self.accessibilityIdentifier isEqualToString:@"eml.live_chat_text_message"] && [responder isKindOfClass:%c(YCHAsyncLiveChatCollectionViewController)]) {
            YCHAsyncLiveChatCollectionViewController *con = (YCHAsyncLiveChatCollectionViewController *)responder;
            if ([con.view isKindOfClass:%c(YCHAsyncLiveChatImmersiveCollectionView)]) break;
            self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
                return isDarkMode(self) ? [UIColor blackColor] : [UIColor whiteColor];
            }];
            break;
        } else if ([responder isKindOfClass:%c(YTELMViewController)]) {
            YTELMViewController *con = (YTELMViewController *)responder;
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
            break;
        }
        responder = responder.nextResponder;
    }
    if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.filter_chip_bar"]) {
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
- (void)didMoveToWindow {
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
- (void)didMoveToWindow {
    %orig;
    UIView *sup = self.superview;
    if ([sup isKindOfClass:%c(YTContextualSheetView)]) {
        self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(self) ? [UIColor blackColor] : [UIColor whiteColor];
        }];
    }
}
%end

%hook YTEngagementPanelView
- (void)didMoveToWindow {
    %orig;
    UIView *foot = self.footerView;
    if (foot) {
        UIView *sub = foot.subviews.firstObject;
        sub.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
        }];
    }
}
%end

%hook MDCInkView
- (void)didMoveToWindow {
    %orig;
    UIView *sup = self.superview;
    if ([sup isKindOfClass:%c(YTMenuItemMDCButton)] || [sup isKindOfClass:%c(GOODialogActionMDCButton)]) {
        self.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
        }];
    }
}
%end

%hook YTStartupAnimationViewController
- (void)viewDidLoad {
    %orig;
    UIView *mainView = self.view;
    mainView.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        return isDarkMode(mainView) ? [UIColor blackColor] : [UIColor whiteColor];
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
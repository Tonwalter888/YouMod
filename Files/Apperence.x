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
    if (isDarkMode(self)) {
        ((UIView *)[systemBackgroundView valueForKey:backgroundViewKey]).backgroundColor = [UIColor blackColor];
    } else {
        ((UIView *)[systemBackgroundView valueForKey:backgroundViewKey]).backgroundColor = [UIColor whiteColor];
    }
}
- (void)_layoutSystemBackgroundView:(BOOL)arg1 {
    %orig;
    if (isDarkMode(self)) {
        ((UIView *)[[self valueForKey:@"_systemBackgroundView"] valueForKey:@"_colorView"]).backgroundColor = [UIColor blackColor];
    } else {
        ((UIView *)[[self valueForKey:@"_systemBackgroundView"] valueForKey:@"_colorView"]).backgroundColor = [UIColor whiteColor];
    }
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self setNeedsLayout];
    }
}
%end

%hook _ASDisplayView
- (void)layoutSubviews {
    %orig;
    NSSet *blackViews = [NSSet setWithObjects:
        @"id.elements.components.comment_composer",
        // @"eml.cvr",
        @"id.subs.subscriptions_channel_bar",
        @"PAmedia_hub_device_picker.engagement_panel_header", nil
        // @"eml.vwc", nil
    ];  
    if (isDarkMode(self)) {
         if ([blackViews containsObject:self.accessibilityIdentifier]) {
            self.backgroundColor = [UIColor blackColor];
            return;
        }
        // Action dialog
        UIResponder *responder = self.nextResponder;
        while (responder != nil) {
            if ([responder isKindOfClass:%c(YTActionSheetDialogViewController)] || [responder isKindOfClass:%c(YTBottomSheetController)]) {
                if ([self.superview.accessibilityIdentifier isEqualToString:@"eml.animated_subscribe_button"]) break;
                self.backgroundColor = [UIColor blackColor];
                break;
            } else if ([self.accessibilityIdentifier isEqualToString:@"eml.live_chat_text_message"] && [responder isKindOfClass:%c(YCHAsyncLiveChatCollectionViewController)]) {
                YCHAsyncLiveChatCollectionViewController *con = (YCHAsyncLiveChatCollectionViewController *)responder;
                if ([con.view isKindOfClass:%c(YCHAsyncLiveChatImmersiveCollectionView)]) break;
                self.backgroundColor = [UIColor blackColor];
                break;
            } else if ([responder isKindOfClass:%c(YTELMViewController)]) {
                YTELMViewController *con = (YTELMViewController *)responder;
                YTIElementRenderer *renderer = [con valueForKey:@"_renderer"];
                NSString *desc = [renderer description];
                if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.text_field"] && [desc containsString:@"timeline_search_input_form_id"] && [desc containsString:@"search_input.eml"]) {
                    self.superview.backgroundColor = [UIColor blackColor];
                } else if ([desc containsString:@"transcript_panel.eml"]) {
                    self.backgroundColor = [UIColor blackColor];
                }
                break;
            }
            responder = responder.nextResponder;
        }
        if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.filter_chip_bar"]) {
            self.backgroundColor = [UIColor blackColor];
            self.superview.backgroundColor = [UIColor blackColor];
            return;
        }
    } else {
        if ([blackViews containsObject:self.accessibilityIdentifier]) {
            self.backgroundColor = [UIColor clearColor];
            return;
        }     
        // Action dialog
        UIResponder *responder = self.nextResponder;
        while (responder != nil) {
            if ([responder isKindOfClass:%c(YTActionSheetDialogViewController)] || [responder isKindOfClass:%c(YTBottomSheetController)]) {
                if ([self.superview.accessibilityIdentifier isEqualToString:@"eml.animated_subscribe_button"]) break;
                self.backgroundColor = [UIColor clearColor];
                break;
            } else if ([self.accessibilityIdentifier isEqualToString:@"eml.live_chat_text_message"] && [responder isKindOfClass:%c(YCHAsyncLiveChatCollectionViewController)]) {
                YCHAsyncLiveChatCollectionViewController *con = (YCHAsyncLiveChatCollectionViewController *)responder;
                if ([con.view isKindOfClass:%c(YCHAsyncLiveChatImmersiveCollectionView)]) break;
                self.backgroundColor = [UIColor whiteColor];
                break;
            } else if ([responder isKindOfClass:%c(YTELMViewController)]) {
                YTELMViewController *con = (YTELMViewController *)responder;
                YTIElementRenderer *renderer = [con valueForKey:@"_renderer"];
                NSString *desc = [renderer description];
                if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.text_field"] && [desc containsString:@"timeline_search_input_form_id"] && [desc containsString:@"search_input.eml"]) {
                    self.superview.backgroundColor = [UIColor clearColor];
                } else if ([desc containsString:@"transcript_panel.eml"]) {
                    self.backgroundColor = [UIColor clearColor];
                }
                break;
            }
            responder = responder.nextResponder;
        }
        if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.filter_chip_bar"]) {
            self.backgroundColor = [UIColor clearColor];
            self.superview.backgroundColor = [UIColor clearColor];
            return;
        }
    }
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self setNeedsLayout];
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
    if (isDarkMode(self)) {
        if ([blackViews containsObject:self.accessibilityIdentifier]) self.backgroundColor = [UIColor blackColor];
        if ([self.accessibilityIdentifier isEqualToString:@"subs_channel_bar.collection"]) self.backgroundColor = [UIColor blackColor];
        if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.more_drawer_collection"]) self.superview.backgroundColor = [UIColor blackColor];
    } else {
        if ([blackViews containsObject:self.accessibilityIdentifier]) self.backgroundColor = [UIColor clearColor];
        if ([self.accessibilityIdentifier isEqualToString:@"subs_channel_bar.collection"]) self.backgroundColor = [UIColor clearColor];
        if ([self.accessibilityIdentifier isEqualToString:@"id.elements.components.more_drawer_collection"]) self.superview.backgroundColor = [UIColor whiteColor];
    }
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self setNeedsLayout];
    }
}
%end

%hook YTContextualSheetView
- (void)layoutSubviews {
    %orig;
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:%c(YTContextualWrapView)]) {
            if (isDarkMode(self)) {
                subview.backgroundColor = [UIColor blackColor];
            } else {
                subview.backgroundColor = [UIColor whiteColor];
            }
            break;
        }
    }
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self setNeedsLayout];
    }
}
%end

%hook YTEngagementPanelView
- (void)layoutSubviews {
    %orig;
    UIView *foot = self.footerView;
    if (foot) {
        UIView *sub = foot.subviews.firstObject;
        if (isDarkMode(self)) {
            sub.backgroundColor = [UIColor blackColor];
        } else {
            sub.backgroundColor = [UIColor clearColor];
        }
    }
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self setNeedsLayout];
    }
}
%end

%hook YTMenuItemMDCButton
- (void)layoutSubviews {
    %orig;
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:%c(MDCInkView)]) {
            if (isDarkMode(self)) {
                sub.backgroundColor = [UIColor blackColor];
            } else {
                sub.backgroundColor = [UIColor clearColor];
            }
            break;
        }
    }
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self setNeedsLayout];
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
    self.backgroundColor = isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self setNeedsLayout];
    }
}
%end

%hook UIPredictionViewController
- (id)_currentTextSuggestions {
    UIKeyboard *keyboard = [%c(UIKeyboard) activeKeyboard];
    if (isDarkMode(keyboard)) {
        [self.view setBackgroundColor:[UIColor blackColor]];
        keyboard.backgroundColor = [UIColor blackColor];
    } else {
        [self.view setBackgroundColor:[UIColor clearColor]];
        keyboard.backgroundColor = [UIColor clearColor];
    }
    return %orig;
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self.view setNeedsLayout];
    }
}
%end

%hook UIKeyboardDockView
- (void)layoutSubviews {
    %orig;
    self.backgroundColor = isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self setNeedsLayout];
    }
}
%end

// Since we can't hook a private framework class from UIKit, we check the class name through the nearest available from UIKit class
%hook UIInputView
- (void)layoutSubviews {
    %orig;
    if ([self isKindOfClass:NSClassFromString(@"TUIEmojiSearchInputView")] // Emoji searching panel
     || [self isKindOfClass:NSClassFromString(@"_SFAutoFillInputView")]) { // Autofill password
        self.backgroundColor = isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
    }
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self setNeedsLayout];
    }
}
%end

%hook UIKBVisualEffectView
- (void)layoutSubviews {
    %orig;
    if (isDarkMode(self)) {
        self.backgroundEffects = nil;
        self.backgroundColor = [UIColor blackColor];
    }
}
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
        [self setNeedsLayout];
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

#import "Headers.h"

static int localPageStyle;

// OLEDKeyboard (https://github.com/dayanch96/OledKeyboard)
static BOOL isDarkMode(UIView *view) {
    if ([view respondsToSelector:@selector(_mapkit_isDarkModeEnabled)]) {
        return view._mapkit_isDarkModeEnabled;
    }
    return view._viewControllerForAncestor.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
}

// OLED theme (uYouEnhanced)
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
- (NSInteger)pageStyle {
    int value = %orig;
    localPageStyle = value;
    return value;
}
%end

%hook YTInnerTubeCollectionViewController
- (UIColor *)backgroundColor:(NSInteger)pageStyle { return pageStyle == 1 ? [UIColor blackColor] : %orig; }
%end

%hook _ASDisplayView
- (void)didMoveToWindow {
    %orig;
    NSSet *blackViews = [NSSet setWithObjects:
        @"id.subs.subscriptions_channel_bar",
        @"eml.live_chat_text_message", nil
    ];  
    if (localPageStyle == 1) {
        if ([blackViews containsObject:self.accessibilityIdentifier]) self.backgroundColor = [UIColor blackColor]; 
        // Action dialog
        UIResponder *responder = self.nextResponder;
        while (responder != nil) {
            if ([responder isKindOfClass:%c(YTActionSheetDialogViewController)] || [responder isKindOfClass:%c(YTBottomSheetController)]) {
                self.backgroundColor = [UIColor blackColor];
                break;
            }
            responder = responder.nextResponder;
        }
    } else {
        if ([blackViews containsObject:self.accessibilityIdentifier]) self.backgroundColor = [UIColor clearColor]; 
        // Action dialog
        UIResponder *responder = self.nextResponder;
        while (responder != nil) {
            if ([responder isKindOfClass:%c(YTActionSheetDialogViewController)] || [responder isKindOfClass:%c(YTBottomSheetController)]) {
                self.backgroundColor = [UIColor clearColor];
                break;
            }
            responder = responder.nextResponder;
        }
    }
}
- (void)layoutSubviews {
    %orig;
    NSSet *blackViews = [NSSet setWithObjects:
        @"id.subs.subscriptions_channel_bar",
        @"eml.live_chat_text_message", nil
    ];  
    if (localPageStyle == 1) {
        if ([blackViews containsObject:self.accessibilityIdentifier]) self.backgroundColor = [UIColor blackColor]; 
        // Action dialog
        UIResponder *responder = self.nextResponder;
        while (responder != nil) {
            if ([responder isKindOfClass:%c(YTActionSheetDialogViewController)] || [responder isKindOfClass:%c(YTBottomSheetController)]) {
                self.backgroundColor = [UIColor blackColor];
                break;
            }
            responder = responder.nextResponder;
        }
    } else {
        if ([blackViews containsObject:self.accessibilityIdentifier]) self.backgroundColor = [UIColor clearColor]; 
        // Action dialog
        UIResponder *responder = self.nextResponder;
        while (responder != nil) {
            if ([responder isKindOfClass:%c(YTActionSheetDialogViewController)] || [responder isKindOfClass:%c(YTBottomSheetController)]) {
                self.backgroundColor = [UIColor clearColor];
                break;
            }
            responder = responder.nextResponder;
        }
    }
}
%end

%hook ASCollectionView
- (void)didMoveToWindow {
    %orig;
    if (localPageStyle == 1) {
        if ([self.accessibilityIdentifier isEqualToString:@"subs_channel_bar.collection"]) self.backgroundColor = [UIColor blackColor];
        // Subbars
        UIResponder *responder = self.nextResponder;
        while (responder != nil) {
            if ([responder isKindOfClass:%c(YTMySubsFilterHeaderViewController)]) {
                YTMySubsFilterHeaderViewController *controller = (YTMySubsFilterHeaderViewController *)responder;
                YTIMySubsFilterHeaderRenderer *renderer = [controller valueForKey:@"_renderer"];
                NSString *description = [renderer description];
                if ([description containsString:@"subscriptions_chip_bar.eml"] || [description containsString:@"channel_list_page_sort_chip"]) {
                    self.backgroundColor = [UIColor blackColor];
                    break;
                }
            } else if ([responder isKindOfClass:%c(YTELMViewController)]) {
                YTELMViewController *controller = (YTELMViewController *)responder;
                YTIElementRenderer *renderer = controller.renderer;
                NSString *description = [renderer description];
                if ([description containsString:@"chip_bar.eml"]) {
                    self.backgroundColor = [UIColor blackColor];
                    break;
                }
            }
            responder = responder.nextResponder;
        }
    } else {
        if ([self.accessibilityIdentifier isEqualToString:@"subs_channel_bar.collection"]) self.backgroundColor = [UIColor clearColor];
        // Subbars
        UIResponder *responder = self.nextResponder;
        while (responder != nil) {
            if ([responder isKindOfClass:%c(YTMySubsFilterHeaderViewController)]) {
                YTMySubsFilterHeaderViewController *controller = (YTMySubsFilterHeaderViewController *)responder;
                YTIMySubsFilterHeaderRenderer *renderer = [controller valueForKey:@"_renderer"];
                NSString *description = [renderer description];
                if ([description containsString:@"subscriptions_chip_bar.eml"] || [description containsString:@"channel_list_page_sort_chip"]) {
                    self.backgroundColor = [UIColor clearColor];
                    break;
                }
            } else if ([responder isKindOfClass:%c(YTELMViewController)]) {
                YTELMViewController *controller = (YTELMViewController *)responder;
                YTIElementRenderer *renderer = controller.renderer;
                NSString *description = [renderer description];
                if ([description containsString:@"chip_bar.eml"]) {
                    self.backgroundColor = [UIColor clearColor];
                    break;
                }
            }
            responder = responder.nextResponder;
        }
    }
}
- (void)layoutSubviews {
    %orig;
    if (localPageStyle == 1) {
        if ([self.accessibilityIdentifier isEqualToString:@"subs_channel_bar.collection"]) self.backgroundColor = [UIColor blackColor];
        // Subbars
        UIResponder *responder = self.nextResponder;
        while (responder != nil) {
            if ([responder isKindOfClass:%c(YTMySubsFilterHeaderViewController)]) {
                YTMySubsFilterHeaderViewController *controller = (YTMySubsFilterHeaderViewController *)responder;
                YTIMySubsFilterHeaderRenderer *renderer = [controller valueForKey:@"_renderer"];
                NSString *description = [renderer description];
                if ([description containsString:@"subscriptions_chip_bar.eml"] || [description containsString:@"channel_list_page_sort_chip"]) {
                    self.backgroundColor = [UIColor blackColor];
                    break;
                }
            } else if ([responder isKindOfClass:%c(YTELMViewController)]) {
                YTELMViewController *controller = (YTELMViewController *)responder;
                YTIElementRenderer *renderer = controller.renderer;
                NSString *description = [renderer description];
                if ([description containsString:@"chip_bar.eml"]) {
                    self.backgroundColor = [UIColor blackColor];
                    break;
                }
            }
            responder = responder.nextResponder;
        }
    } else {
        if ([self.accessibilityIdentifier isEqualToString:@"subs_channel_bar.collection"]) self.backgroundColor = [UIColor clearColor];
        // Subbars
        UIResponder *responder = self.nextResponder;
        while (responder != nil) {
            if ([responder isKindOfClass:%c(YTMySubsFilterHeaderViewController)]) {
                YTMySubsFilterHeaderViewController *controller = (YTMySubsFilterHeaderViewController *)responder;
                YTIMySubsFilterHeaderRenderer *renderer = [controller valueForKey:@"_renderer"];
                NSString *description = [renderer description];
                if ([description containsString:@"subscriptions_chip_bar.eml"] || [description containsString:@"channel_list_page_sort_chip"]) {
                    self.backgroundColor = [UIColor clearColor];
                    break;
                }
            } else if ([responder isKindOfClass:%c(YTELMViewController)]) {
                YTELMViewController *controller = (YTELMViewController *)responder;
                YTIElementRenderer *renderer = controller.renderer;
                NSString *description = [renderer description];
                if ([description containsString:@"chip_bar.eml"]) {
                    self.backgroundColor = [UIColor clearColor];
                    break;
                }
            }
            responder = responder.nextResponder;
        }
    }
}
%end

%hook YTContextualSheetView
- (void)layoutSubviews {
    %orig;
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:%c(YTContextualWrapView)]) {
            if (localPageStyle == 1) {
                subview.backgroundColor = [UIColor blackColor];
            } else {
                subview.backgroundColor = [UIColor whiteColor];
            }
            break;
        }
    }
}
%end

%hook YTEngagementPanelHeaderView
- (void)layoutSubviews {
    %orig;
    YTEngagementPanelIdentifier *identifier = self.engagementPanelIdentifier;
    if ([identifier.tag isEqualToString:@"PAmodern_transcript_view"]) return;
    if (localPageStyle == 1) {
        self.backgroundColor = [UIColor blackColor];
    } else {
        self.backgroundColor = [UIColor clearColor];
    }
}
%end
%end

%group OLEDKeyboard
%hook UIKeyboard
- (void)displayLayer:(id)arg1 {
    %orig;
    self.backgroundColor = isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
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
%end

%hook UIKeyboardDockView
- (void)layoutSubviews {
    %orig;
    self.backgroundColor = isDarkMode(self) ? [UIColor blackColor] : [UIColor clearColor];
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
%end

%hook UIKBVisualEffectView
- (void)layoutSubviews {
    %orig;
    if (isDarkMode(self)) {
        self.backgroundEffects = nil;
        self.backgroundColor = [UIColor blackColor];
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
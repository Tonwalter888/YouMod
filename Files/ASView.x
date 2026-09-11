#import "Headers.h"

static const void *YouModASViewKey = &YouModASViewKey;

%hook _ASDisplayView
- (void)didMoveToWindow {
    %orig;
    if (objc_getAssociatedObject(self, YouModASViewKey)) return;
    NSString *iden = self.accessibilityIdentifier;
    YouModApplyOLEDToDisplayView(self, iden);
    YouModConfigureDownloadButton(self, iden);
    YouModSetupDownloadGestures(self, iden);
    YouModFilterAdsDisplayView(self, iden);
    YouModFilterChannelButtons(self, iden); // Maybe I will improve this
    YouModFilterNonScrollableVideoButtons(self, iden);
    YouModFilterVideoButtons(self, iden);
    YouModFilterShortsDisplayView(self, iden);
    YouModRemoveShortsPausedButtons(self, iden);
    objc_setAssociatedObject(self, YouModASViewKey, @YES, OBJC_ASSOCIATION_ASSIGN);
}
%new
- (void)YouModHandleCommentLongPress:(UILongPressGestureRecognizer *)sender {
    YouModHandleCommentLongPressAction(self, sender);
}
%new
- (void)YouModHandlePostLongPress:(UILongPressGestureRecognizer *)sender {
    YouModHandlePostLongPressAction(self, sender);
}
%new
- (void)YouModDownloadButtonTapped:(UITapGestureRecognizer *)sender {
    YouModHandleDownloadButtonAction(self, sender);
}
%end

%hook ASCollectionView
- (void)didMoveToWindow {
    %orig;
    if (objc_getAssociatedObject(self, YouModASViewKey)) return;
    NSString *iden = self.accessibilityIdentifier;
    YouModApplyOLEDCollectionView(self, iden);
    objc_setAssociatedObject(self, YouModASViewKey, @YES, OBJC_ASSOCIATION_ASSIGN);
}
%end

%hook YTELMViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (objc_getAssociatedObject(self, YouModASViewKey)) return;
    NSString *desc = [[self valueForKey:@"_renderer"] description];
    if ([desc containsString:@"more_drawer.eml"]) {
        YouModRemoveDrawerAds(self);
        if (IS_ENABLED(OLEDTheme)) {
            self.view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
                return isDarkMode(self.view) ? [UIColor blackColor] : [UIColor whiteColor];
            }];
        }
    } else if (IS_ENABLED(OLEDTheme) && ([desc containsString:@"report_form_reason_select_page.eml"] || [desc containsString:@"report_form_sign_in_page.eml"] || [desc containsString:@"transcript_panel.eml"])) {
        self.view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(self.view) ? [UIColor blackColor] : [UIColor clearColor];
        }];
    } else if (IS_ENABLED(OLEDTheme) && [desc containsString:@"timeline_search_input_form_id"] && [desc containsString:@"search_input.eml"]) {
        self.view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(self.view) ? [UIColor blackColor] : [UIColor whiteColor];
        }];
    } else if (IS_ENABLED(OLEDTheme) && [desc containsString:@"subs_channel_bar.eml"]) {
        UIView *sub = self.view.subviews[0];
        sub.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(sub) ? [UIColor blackColor] : [UIColor clearColor];
        }];
    } else if ([desc containsString:@"quick_actions.eml"]) {
        YouModRemoveFullscreenActionsButtons(self);
    }
    objc_setAssociatedObject(self, YouModASViewKey, @YES, OBJC_ASSOCIATION_ASSIGN);
}
%end

%hook YCHAsyncLiveChatCollectionViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    NSLog(@"[WaterDev] viewWillAppear LiveChat got called");
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSLog(@"[WaterDev] viewDidAppear LiveChat got called");
}
%end
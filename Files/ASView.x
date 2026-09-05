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
    YouModFilterChannelButtons(self, iden); // Will improve this
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
    YouModApplyOLEDCollectionView(self);
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
    } else if (IS_ENABLED(OLEDTheme) && ([desc containsString:@"report_form_reason_select_page.eml"] || [desc containsString:@"report_form_sign_in_page.eml"] || [desc containsString:@"transcript_panel.eml"] || ([desc containsString:@"timeline_search_input_form_id"] && [desc containsString:@"search_input.eml"]))) {
        self.view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(self.view) ? [UIColor blackColor] : [UIColor clearColor];
        }];
    }
    objc_setAssociatedObject(self, YouModASViewKey, @YES, OBJC_ASSOCIATION_ASSIGN);
}
%end

%hook YTInlinePlayerBarContainerView
- (void)updateCurrentTimeTitleLabel {
    NSLog(@"[WaterDev] updateTime called");
    %orig;
}
%end
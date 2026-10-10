#import "Headers.h"

static const void *kASViewKey = &kASViewKey;

%hook _ASDisplayView
%property (nonatomic, assign) _ASDisplayView *currentDownloadButton;
- (void)didMoveToWindow {
    %orig;
    // YouModFilterVideoButtons(self, iden); not rn, im having a headache with this shi. no matter what i do, it just doesnt work well.
    if (objc_getAssociatedObject(self, kASViewKey)) return;
    NSString *iden = self.accessibilityIdentifier;
    YouModApplyOLEDToDisplayView(self, iden);
    YouModConfigureDownloadButton(self, iden);
    YouModSetupDownloadGestures(self, iden);
    if (IS_ENABLED(RemoveAds)) YouModFilterAdsDisplayView(self, iden);
    YouModFilterShortsDisplayView(self, iden);
    YouModRemoveShortsPausedButtons(self, iden);
    if (iden.length > 0) objc_setAssociatedObject(self, kASViewKey, @YES, OBJC_ASSOCIATION_ASSIGN);
}
%new
- (void)YouModHandleCommentLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;
    YouModHandleCommentLongPressAction(self);
}
%new
- (void)YouModHandlePostLongPress:(UILongPressGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateBegan) return;
    YouModHandlePostLongPressAction(self);
}
%new
- (void)YouModDownloadButtonTapped:(UITapGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateEnded) return;
    YouModHandleDownloadButtonAction(self);
}
%new
- (void)YouModHandleNewDownloadButtonTapped:(UITapGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateEnded) return;
    YTDefaultSheetController *sheetController = [self.currentDownloadButton._viewControllerForAncestor valueForKey:@"_delegate"];
    _ASDisplayView *moreButton = [sheetController valueForKey:@"_sourceView"];
    [sheetController dismissViewControllerAnimated:YES completion:^{
        YouModHandleDownloadButtonAction(moreButton);
    }];
}
%end

%hook ASCollectionView
- (void)didMoveToWindow {
    %orig;
    if (objc_getAssociatedObject(self, kASViewKey)) return;
    YouModApplyOLEDCollectionView(self, self.accessibilityIdentifier);
    objc_setAssociatedObject(self, kASViewKey, @YES, OBJC_ASSOCIATION_ASSIGN);
}
%end

%hook YTELMViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (objc_getAssociatedObject(self, kASViewKey)) return;
    NSString *desc = [[self valueForKey:@"_renderer"] description];
    if (IS_ENABLED(HideWaterMark) && [desc containsString:@"featured_channel_watermark_overlay.eml"]) {
        self.view.hidden = YES;
    } else if ([desc containsString:@"more_drawer.eml"]) {
        if (IS_ENABLED(RemoveAds)) YouModRemoveDrawerAds(self);
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
    } else if (IS_ENABLED(OLEDTheme) && [desc containsString:@"subscriptions_channel_bar.eml"]) {
        UIView *sub = self.view.subviews[0];
        sub.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
            return isDarkMode(sub) ? [UIColor blackColor] : [UIColor clearColor];
        }];
    } else if ([desc containsString:@"quick_actions.eml"]) {
        YouModRemoveFullscreenActionsButtons(self);
    }
    objc_setAssociatedObject(self, kASViewKey, @YES, OBJC_ASSOCIATION_ASSIGN);
}
%end

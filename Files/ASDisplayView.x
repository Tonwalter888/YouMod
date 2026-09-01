#import "Headers.h"

static const void *kYouModASDisplayViewHandledKey = &kYouModASDisplayViewHandledKey;

%hook _ASDisplayView

- (void)didMoveToWindow {
    %orig;
    if (objc_getAssociatedObject(self, kYouModASDisplayViewHandledKey)) return;

    YouModApplyOLEDToDisplayView(self);

    YouModConfigureDownloadButton(self);

    NSString *iden = self.accessibilityIdentifier;
    if (iden && iden.length > 0) {
        YouModSetupDownloadGestures(self, iden);
        YouModFilterAdsDisplayView(self, iden);
        YouModFilterChannelButtons(self, iden);
        YouModFilterVideoButtons(self, iden);
        YouModFilterShortsDisplayView(self, iden);
    }

    objc_setAssociatedObject(self, kYouModASDisplayViewHandledKey, @YES, OBJC_ASSOCIATION_ASSIGN);
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

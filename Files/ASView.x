#import "Headers.h"

static const void *YouModASViewKey = &YouModASViewKey;

%hook _ASDisplayView

- (void)didMoveToWindow {
    %orig;
    if (objc_getAssociatedObject(self, YouModASViewKey)) return;

    YouModApplyOLEDToDisplayView(self);

    YouModConfigureDownloadButton(self);

    NSString *iden = self.accessibilityIdentifier;
    YouModSetupDownloadGestures(self, iden);
    YouModFilterAdsDisplayView(self, iden);
    YouModFilterChannelButtons(self, iden);
    YouModFilterVideoButtons(self, iden);
    YouModFilterShortsDisplayView(self, iden);

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

%hook ASScrollView
- (void)didMoveToWindow {
    %orig;
    if (objc_getAssociatedObject(self, YouModASViewKey)) return;
    ASDisplayNode *node = self.scrollNode;
    YouModApplyOLEDScrollView(self, node);
    objc_setAssociatedObject(self, YouModASViewKey, @YES, OBJC_ASSOCIATION_ASSIGN);
}
%end

%hook ASCollectionView
- (void)didMoveToWindow {
    %orig;
    if (objc_getAssociatedObject(self, YouModASViewKey)) return;
    YouModAppleOLEDCollectionView(self);
    YouModRemoveDrawerAds(self);
    objc_setAssociatedObject(self, YouModASViewKey, @YES, OBJC_ASSOCIATION_ASSIGN);
}
%end
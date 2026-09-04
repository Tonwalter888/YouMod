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
    YouModFilterChannelButtons(self, iden);
    YouModFilterVideoButtons(self, iden); // I want to improve this
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

%hook YTPageHeaderViewController
- (void)viewDidAppear:(BOOL)animated {
    NSLog(@"[WaterDev] viewDidAppear PageHeaderView got called");
    %orig;
}
%end

%hook YTPageHeaderView
- (void)layoutSubviews {
    NSLog(@"[WaterDev] layoutSubviews PageHeaderView got called");
    %orig;
}
- (void)didMoveToWindow {
    NSLog(@"[WaterDev] didMoveToWindow PageHeaderView got called");
    %orig;
}
%end

%hook YTWatchNextResultsViewController
- (void)viewDidAppear:(BOOL)animated {
    NSLog(@"[WaterDev] viewDidAppear watchnext got called");
    %orig;
}
%end
@interface YTPivotBarViewController : UIViewController
- (void)selectItemWithPivotIdentifier:(id)pivotIndentifier;
- (void)selectItemWithPivotBarItem:(id)item;
- (void)selectItemWithPivotRenderer:(id)item;
- (void)cacheCurrentViewControllers;
- (void)updateViewsWithSelectedPivotIdentifier:(id)pivotIdentifier;
- (void)didTapItemWithRenderer:(id)renderer;
- (void)didTapItemWithIconOnlyItemRenderer:(id)renderer badgeNavigationCommand:(id)command interactionLoggingClientData:(id)data;
- (id)delegate;
- (void)YouModReloadTabBar:(id)arg;
@end

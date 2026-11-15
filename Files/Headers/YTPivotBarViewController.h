@interface YTPivotBarViewController : UIViewController
- (void)selectItemWithPivotIdentifier:(id)pivotIndentifier;
- (void)selectItemWithPivotBarItem:(id)item;
- (void)selectItemWithPivotRenderer:(id)item;
- (void)cacheCurrentViewControllers;
- (void)updateViewsWithSelectedPivotIdentifier:(id)pivotIdentifier;
- (id)delegate;
- (void)YouModReloadTabBar:(id)arg;
@end

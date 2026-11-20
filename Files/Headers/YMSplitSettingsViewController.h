// YMSplitSettingsViewController — iPad two-pane YouMod settings page (sidebar + detail) inside the modal settings navigation created by YMPresentSettingsPage (YMSplitSettings.x).
#import "YMSettingsItem.h"
#import "YMSubSettingsViewController.h"

@interface YMSplitSettingsViewController : UIViewController <UINavigationControllerDelegate>
- (NSArray<YMSettingsItem *> *)sidebarItems;
- (void)setSidebarItems:(NSArray<YMSettingsItem *> *)items;
- (YMSubSettingsViewController *)sidebarVC;
- (void)setSidebarVC:(YMSubSettingsViewController *)vc;
- (YMSubSettingsViewController *)resultsVC;
- (void)setResultsVC:(YMSubSettingsViewController *)vc;
- (UINavigationController *)detailNav;
- (void)setDetailNav:(UINavigationController *)nav;
- (UIViewController *)groupRootVC;
- (void)setGroupRootVC:(UIViewController *)vc;
- (UIView *)detailContainer;
- (void)setDetailContainer:(UIView *)view;
- (NSString *)currentTitle;
- (void)setCurrentTitle:(NSString *)title;
- (NSArray<YMSettingsItem *> *)currentItems;
- (void)setCurrentItems:(NSArray<YMSettingsItem *> *)items;
- (NSInteger)currentKind;
- (void)setCurrentKind:(NSInteger)kind;
- (NSString *)searchQuery;
- (void)setSearchQuery:(NSString *)query;
- (UIView *)sidebarPane;
- (void)setSidebarPane:(UIView *)view;
- (UIView *)detailPane;
- (void)setDetailPane:(UIView *)view;
- (UIView *)separatorView;
- (void)setSeparatorView:(UIView *)view;
@end

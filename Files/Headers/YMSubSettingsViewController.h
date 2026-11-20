#import "YMSearchRow.h"
#import "YMSettingsItem.h"

#pragma mark - YMSubSettingsViewController (YouModSettings.x)

// Called when a row (or search result) that opens a group page is tapped.
// Return YES to suppress the default push (iPad split view routes the group into
// its detail pane instead).
typedef BOOL (^YMGroupSelectionHandler)(NSString *title, NSArray<YMSettingsItem *> *items, NSInteger kind);

// Reusable UIKit-based sub-page for YouMod settings sections. A plain
// UIViewController living inside the modal settings navigation created by
// YMPresentSettingsPage.
@interface YMSubSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>
- (UITableView *)tableView;
- (void)setTableView:(UITableView *)tv;
- (UISearchBar *)searchBar;
- (void)setSearchBar:(UISearchBar *)sb;
- (NSString *)navTitle;
- (void)setNavTitle:(NSString *)t;
- (NSArray<YMSettingsItem *> *)items;
- (void)setItems:(NSArray<YMSettingsItem *> *)items;
- (UIColor *)ymTextColor;
- (UIColor *)ymSecondaryColor;
- (UITableViewCell *)cellForItem:(YMSettingsItem *)item tableView:(UITableView *)tableView;
- (UITableViewCell *)navCellForItem:(YMSettingsItem *)item tableView:(UITableView *)tableView;
- (void)updateSearchBarTheme;

// Global search (home page): the search bar covers every registered settings group
// instead of just this page's own rows.
- (BOOL)globalSearch;
- (void)setGlobalSearch:(BOOL)global;
- (NSArray<YMSearchRow *> *)globalSearchIndex;
- (NSArray<YMSearchRow *> *)filteredSearchRows;
- (void)setFilteredSearchRows:(NSArray<YMSearchRow *> *)rows;
// Refilters the global index for the current pageFilter text.
- (void)updateGlobalSearchResults;
// YES = per-page search bar filtering this page's own rows. Subclasses can override.
- (BOOL)usesPageSearch;
// YES = no search bar (external/driven search, e.g. the iPad split-view results pane).
- (BOOL)hideSearchBar;
- (void)setHideSearchBar:(BOOL)hide;
// Active filter text (nil/empty = not filtering).
- (NSString *)pageFilter;
- (void)setPageFilter:(NSString *)filter;
// Rows currently shown (visible items, or matches while filtering).
- (NSArray<YMSettingsItem *> *)displayedItems;
- (void)updateDisplayedItemsAnimated:(BOOL)animated;
// YES = thin version footer below the rows (set before pushing; home page only).
- (BOOL)showsVersionFooter;
- (void)setShowsVersionFooter:(BOOL)shows;
- (UIView *)ymVersionFooterView;

// iPad split-view hooks (nil on regular pages).
// Group rows routed here instead of pushed when it returns YES.
- (YMGroupSelectionHandler)groupHandler;
- (void)setGroupHandler:(YMGroupSelectionHandler)handler;
// Per-page search bar text changes routed here instead of filtering this page's
// rows (the iPad sidebar drives the detail pane's global search with them).
- (void (^)(NSString *text))searchTextHandler;
- (void)setSearchTextHandler:(void (^)(NSString *text))handler;
// Title of the nav row currently shown in a detail pane (draws the grey
// selection highlight in the iPad sidebar; nil = no highlight).
- (NSString *)selectedGroupTitle;
- (void)setSelectedGroupTitle:(NSString *)title;
// YES for the embedded sidebar page of the iPad split settings — its nav rows
// show the #2885FF touch feedback instead of the system selection flash.
- (BOOL)ymIsSplitSidebar;
- (void)setYmIsSplitSidebar:(BOOL)sidebar;
@end

// SponsorBlock settings page (matches YTLite's SponsorBlock UI). Uses associated
// objects for its state (see the accessors in SponsorBlockSettings.x).
@interface SBSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UIColorPickerViewControllerDelegate, UISearchBarDelegate>
- (UITableView *)tableView;
- (void)setTableView:(UITableView *)tv;
- (UISearchBar *)searchBar;
- (void)setSearchBar:(UISearchBar *)sb;
- (NSString *)activeColorKey;
- (void)setActiveColorKey:(NSString *)key;
- (NSIndexPath *)activeColorIndexPath;
- (void)setActiveColorIndexPath:(NSIndexPath *)ip;
- (UIColor *)sbTextColor;
- (UIColor *)sbSecondaryTextColor;
- (void)updateSearchBarTheme;
// Cell builders, also reused by the global settings search (sbSearchRows).
- (UITableViewCell *)toggleCellForRow:(NSInteger)row tableView:(UITableView *)tableView;
- (UITableViewCell *)sliderCellForRow:(NSInteger)row tableView:(UITableView *)tableView;
- (UITableViewCell *)actionCellForCategory:(NSString *)category name:(NSString *)catName tableView:(UITableView *)tableView;
- (UITableViewCell *)colorCellForCategory:(NSString *)category name:(NSString *)catName tableView:(UITableView *)tableView;
@end

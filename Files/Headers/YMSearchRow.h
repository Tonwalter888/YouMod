#pragma mark - Settings Search

// One row in the global settings-search results: renders its own cell (makeCell)
// and optionally handles its own tap (onSelect, with a reload block). searchText
// is what the query matches against (title + description).
@interface YMSearchRow : NSObject
@property (nonatomic, copy) NSString *searchText;
@property (nonatomic, copy) UITableViewCell *(^makeCell)(UITableView *tableView);
@property (nonatomic, assign) CGFloat cellHeight; // 0 = UITableViewAutomaticDimension
@property (nonatomic, copy) void (^onSelect)(UIViewController *presenter, void (^reload)(void));
@end

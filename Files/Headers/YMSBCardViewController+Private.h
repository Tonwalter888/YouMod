#import "YMSBCardViewController.h"

// Private state for YMSBCardViewController (implemented in SponsorBlockMenu.x).
@interface YMSBCardViewController () <UISearchBarDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) NSArray<YMSBCardItem *> *allItems;
@property (nonatomic, copy) NSString *searchText;
@property (nonatomic, assign) BOOL sbUsesSubmitColors;
@end

#import "YMSBCardItem.h"

@interface YMSBCardViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, copy) NSString *cardTitle;
@property (nonatomic, copy) NSString *message;        // informational label row on top
@property (nonatomic, copy) NSString *emptyText;      // centered text shown while items is empty
@property (nonatomic, strong) UITextField *textField; // optional editable field row on top
@property (nonatomic, strong) UISearchBar *searchBar; // optional search bar; filters items by title/subtitle
@property (nonatomic, strong) NSArray<YMSBCardItem *> *items;
@property (nonatomic, assign) BOOL swipeToDelete;
@property (nonatomic, copy) void (^onDeleteItem)(YMSBCardViewController *card, YMSBCardItem *item);
- (void)reloadItems;
- (void)dismissCard;
+ (UINavigationController *)presentCard:(YMSBCardViewController *)card;
+ (void)presentCardInEngagementPanel:(YMSBCardViewController *)card fromResponder:(id)responder; // YouTube engagement panel
@end

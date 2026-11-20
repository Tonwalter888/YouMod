@interface YouModLanguagePickerViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate>
@property (nonatomic, copy) NSString *selectedLangCode;
@property (nonatomic, copy) NSArray<NSString *> *titles;
@property (nonatomic, copy) NSArray<NSString *> *codes;
@property (nonatomic, copy) void (^onSelectLanguage)(NSString *code, NSString *title);
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *containerView;
@end

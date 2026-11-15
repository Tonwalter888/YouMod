// Form-sheet card dialog (UIModalPresentationFormSheet + UINavigationController)
// for segment voting, whitelist and user-ID editing. Rows are plain table items;
// swipeToDelete + onDeleteItem add swipe-left delete, searchBar filters rows.
@class YMSBCardViewController;
@interface YMSBCardItem : NSObject
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, strong) UIColor *tintColor;
@property (nonatomic, copy) NSString *identifier; // e.g. channelID on whitelist rows
@property (nonatomic, strong) UIView *accessoryView; // optional trailing controls
@property (nonatomic, copy) void (^handler)(YMSBCardViewController *card);
+ (instancetype)itemWithImage:(UIImage *)image title:(NSString *)title subtitle:(NSString *)subtitle tintColor:(UIColor *)tint handler:(void (^)(YMSBCardViewController *card))handler;
@end

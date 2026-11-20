// Delegate for a colour picker opened from a search result: writes the colour and reloads
// the search table (the stock flow reloads an SB-table index path that doesn't exist there).
@interface SBSearchColorDelegate : NSObject <UIColorPickerViewControllerDelegate>
@property (nonatomic, copy) NSString *colorKey;
@property (nonatomic, copy) void (^reload)(void);
@end

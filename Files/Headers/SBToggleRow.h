// One toggle row: the defaults key it controls plus its localized title/description
// keys (single source for the toggle section's row count, cells and writes).
@interface SBToggleRow : NSObject
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *titleKey;
@property (nonatomic, copy) NSString *descKey;
@end

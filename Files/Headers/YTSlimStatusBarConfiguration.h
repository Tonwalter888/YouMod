// Sleep timer - For newer YT versions (starting with YT 21.40)
@interface YTSlimStatusBarConfiguration : NSObject
@property (nonatomic, readwrite, copy) NSString *text;
@property (nonatomic, readwrite, strong) UIImage *icon;
@property (nonatomic, readwrite, assign) BOOL animated;
+ (id)configurationWithText:(NSString *)text style:(NSInteger)style;
// 21.41 or newer
@property (nonatomic, readwrite, strong) UIColor *backgroundColor;
@property (nonatomic, readwrite, strong) UIColor *textColor;
@end

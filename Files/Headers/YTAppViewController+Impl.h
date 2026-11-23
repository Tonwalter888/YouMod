#import "YTMultiSizeViewController.h"

// 20.x and earlier use the pre-split YTAppViewController; 21.x+ uses
// YTAppViewControllerImpl (same API).
@interface YTAppViewController : YTMultiSizeViewController
- (NSInteger)pageStyle;
@end

@interface YTAppViewControllerImpl : YTMultiSizeViewController
- (NSInteger)pageStyle;
@end

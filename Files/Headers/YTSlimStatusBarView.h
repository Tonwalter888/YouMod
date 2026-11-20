#import "YTSlimStatusBarConfiguration.h"

// For older YTs
@interface YTSlimStatusBarView : UIView
- (void)updateAppearanceToSleepTimerActiveWithText:(NSString *)text;
// new one
- (void)updateWithConfiguration:(YTSlimStatusBarConfiguration *)config;
@end

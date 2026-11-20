#import "GPBMessage.h"
#import "YTIFormattedString.h"

@interface YTIVideoWithContextRenderer : GPBMessage
- (YTIFormattedString *)title;
- (BOOL)hasUntranslatedTitle;
- (YTIFormattedString *)untranslatedTitle;
@end

#import "YTReelContentModel.h"
#import "YTIElementRenderer.h"
#import "YTIReelNonVideoContentRenderer.h"

@interface YTReelNonVideoContentModel : YTReelContentModel
- (YTIReelNonVideoContentRenderer *)renderer;
- (YTIElementRenderer *)elementRenderer;
@end

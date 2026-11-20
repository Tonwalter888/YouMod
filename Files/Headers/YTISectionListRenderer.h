#import "YTISectionListSupportedRenderers.h"

@interface YTISectionListRenderer : GPBMessage
@property (nonatomic, strong, readwrite) NSMutableArray <YTISectionListSupportedRenderers *> *contentsArray;
- (NSArray *)sectionRenderers;
@end

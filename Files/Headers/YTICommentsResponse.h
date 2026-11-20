#import "GPBMessage.h"

@interface YTICommentsResponse : GPBMessage
@property (nonatomic, strong, readwrite) GPBMessage *contents;
- (NSArray *)sectionRenderers;
@end
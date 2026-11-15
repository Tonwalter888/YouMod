#import "YTIInsertItemSectionContentOperation.h"
#import "YTIReplaceSectionOperation.h"

@interface YTISectionListMutationOperation : GPBMessage
@property (nonatomic, strong, readwrite) YTIInsertItemSectionContentOperation *insertItemSectionContent;
@property (nonatomic, strong, readwrite) YTIReplaceSectionOperation *replaceSection;
@end
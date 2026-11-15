#import "GPBMessage.h"
#import "YTIEngagementPanelSectionListHeaderSupportedRenderers.h"

@interface YTIEngagementPanelSectionListRenderer : GPBMessage
@property (nonatomic, copy) NSString *panelIdentifier;
@property (nonatomic, strong) YTIEngagementPanelSectionListHeaderSupportedRenderers *header;
@property (nonatomic, assign) int32_t supportedOrientations;
@property (nonatomic, assign) BOOL allowReplace;
@end

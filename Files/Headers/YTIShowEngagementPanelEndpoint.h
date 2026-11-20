#import "GPBExtensionDescriptor.h"
#import "YTIEngagementPanelIdentifier.h"
#import "YTIEngagementPanelSupportedRenderers.h"

@interface YTIShowEngagementPanelEndpoint : GPBMessage
@property (nonatomic, strong, readwrite) YTIEngagementPanelIdentifier *identifier;
@property (nonatomic, copy, readwrite) NSString *panelIdentifier;
+ (GPBExtensionDescriptor *)showEngagementPanelEndpoint;
@end

@interface YTIShowEngagementPanelEndpoint (YouMod)
@property (nonatomic, strong) YTIEngagementPanelSupportedRenderers *engagementPanel;
@end

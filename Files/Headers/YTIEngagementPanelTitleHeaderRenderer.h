#import "GPBMessage.h"
#import "YMSBCardViewController.h"
#import "YTIFormattedString.h"

// Engagement panel pieces hosting YMSBCardViewController (SponsorBlockMenu.x).
// Protobuf fields resolve at runtime — declarations only.
@interface YTIEngagementPanelTitleHeaderRenderer : GPBMessage
@property (nonatomic, strong) YTIFormattedString *title;
@end

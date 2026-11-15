#import "GPBMessage.h"

@interface YTIBrowseRequest : GPBMessage
+ (NSString *)browseIDForExploreTab;
+ (NSString *)browseIDForAccountTab;
+ (NSString *)browseIDForActivityTab;
+ (NSString *)browseIDForHomeTab;
+ (NSString *)browseIDForLibraryTab;
+ (NSString *)browseIDForTrendingTab;
+ (NSString *)browseIDForSubscriptionsTab;
+ (NSString *)browseIDForWhatToWatch;
@end

@interface YTIBrowseRequest (YouMod)
+ (NSString *)browseIDForGamingDestination;
+ (NSString *)browseIDForSportsDestination;
+ (NSString *)browseIDForNotificationsInbox;
+ (NSString *)browseIDForHistory;
+ (NSString *)browseIDForWhatToWatch;
+ (NSString *)browseIDForSubscriptionsTab;
+ (NSString *)browseIDForLibraryTab;
+ (NSString *)browseIDForLearningDestination;
@end

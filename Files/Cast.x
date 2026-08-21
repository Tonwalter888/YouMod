// Original from YTKACE (https://github.com/itzzace/ytkace/blob/main/Tweak/Features/Compatibility/CastCompatibility.mm)
#import "Headers.h"

@interface GCKDiscoveryManager : NSObject
- (void)startDiscovery;
@end

@interface GCKCastContext : NSObject
+ (instancetype)sharedInstance;
@property (nonatomic, readonly) GCKDiscoveryManager *discoveryManager;
@end

%hook MDXRoutePresentationController
- (BOOL)hasSufficientLocalNetworkPermissions { return YES; }
%end

%hook MDXLocalNetworkPermissions
- (NSInteger)lastKnownPermissionsStatus { return 1; }
- (BOOL)isAuthorized { return YES; }
%end

%hook MDXLocalStorage
- (NSInteger)localNetworkPermissionsStatus { return 1; }
%end

%hook CADPLocalNetworkPermissionInfo
- (BOOL)isLocalNetworkPermissionAllowed { return YES; }
- (BOOL)wasLocalNetworkPermissionAllowed { return YES; }
- (BOOL)shouldPresentLocalNetworkAccessPermissionDialog { return NO; }
%end

%hook MDXPermissionsController
- (void)showLocalNetworkPermissionsRequiredPageWithCompletion:(void (^)(BOOL))completion {
    GCKCastContext *context = [%c(GCKCastContext) sharedInstance];
    GCKDiscoveryManager *manager = context.discoveryManager;
    [manager startDiscovery];
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(YES);
        });
    }
}
%end

%hook YTBAMediaHubUiDeviceItemsResult
- (BOOL)shouldShowLocalNetworkPermissionPrompt { return NO; }
%end
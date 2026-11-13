#import "Headers.h"

// Auto clear cache
%hook YTAppDelegate
%new
- (void)YouModAutoClearCache {
    NSString *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    [[NSFileManager defaultManager] removeItemAtPath:cachePath error:nil];
}
- (BOOL)application:(id)application didFinishLaunchingWithOptions:(id)launchOptions {
    if (IS_ENABLED(AutoClearCache)) {
        // Clear cache on app launch
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self YouModAutoClearCache];
        });
    }
    return %orig;
}
%end

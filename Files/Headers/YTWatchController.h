#import "YTPlayerViewControllerUIDelegate.h"
#import "YTWatchPlaybackController.h"
#import "YTWatchTransition.h"

@interface YTWatchController : NSObject <YTPlayerViewControllerUIDelegate>
@property (nonatomic, strong, readwrite) YTWatchPlaybackController *watchPlaybackController;
@property (nonatomic, readonly) YTWatchTransition *watchTransition;
- (void)watchPlaybackController:(id)controller didLoadPlayerWithPlaybackData:(id)data;
- (void)showFullScreen;
- (void)showSmallScreen;
- (void)reloadStartPlayback:(BOOL)startPlayback;
@end

@interface YTWatchController (YouMod)
- (void)reload;
@end

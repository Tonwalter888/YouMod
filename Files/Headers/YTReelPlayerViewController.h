#import "YTPlayerViewController.h"
#import "YTReelContentView.h"

@interface YTReelPlayerViewController : UIViewController
@property (nonatomic, strong, readwrite) YTPlayerViewController *player;
- (YTReelContentView *)contentView;
- (YTSingleVideoController *)currentVideo;
- (NSString *)videoId;
@end

@interface YTReelPlayerViewController (YouMod)
- (void)reelContentViewRequestsAdvanceToNextVideo:(id)arg;
- (void)reelContentViewRequestsPlayPauseToggle:(id)arg;
- (id)audioTrackController;
- (void)YouModAutoAudioTrack:(YTPlayerViewController *)pv;
@end

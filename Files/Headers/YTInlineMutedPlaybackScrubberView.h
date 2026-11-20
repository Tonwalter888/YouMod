#import "YTInlineMutedPlaybackScrubbingSlider.h"
#import "YTModularPlayerBarController.h"

@interface YTInlineMutedPlaybackScrubberView : UIView
- (YTInlineMutedPlaybackScrubbingSlider *)scrubber;
- (BOOL)modularPlayerBarEnabled;
- (YTModularPlayerBarController *)modularPlayerBar;
@end

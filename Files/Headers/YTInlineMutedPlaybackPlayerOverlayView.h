#import "YTInlineMutedPlaybackScrubberView.h"

@interface YTInlineMutedPlaybackPlayerOverlayView : UIView
@property (nonatomic, retain) UIPanGestureRecognizer *ymSeekPan;
- (YTInlineMutedPlaybackScrubberView *)scrubberView;
@end

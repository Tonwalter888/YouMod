#import "YTIAudioTrack.h"

// 20.x and earlier: the audio track switch controller predates the 21.x
// Impl split; same API (verified against YouTube 20.21.6).
@interface YTAudioTrackSwitchController : NSObject
- (void)setActiveVideo:(id)video;
- (void)switchToAudioTrack:(YTIAudioTrack *)track source:(NSInteger)source;
@end

@interface YTAudioTrackSwitchController (YouMod)
@property (nonatomic, assign) BOOL ymAutoTrackApplied;
@end

// 21.x+
@interface YTAudioTrackSwitchControllerImpl : NSObject
- (void)setActiveVideo:(id)video;
- (void)switchToAudioTrack:(YTIAudioTrack *)track source:(NSInteger)source;
@end

@interface YTAudioTrackSwitchControllerImpl (YouMod)
@property (nonatomic, assign) BOOL ymAutoTrackApplied;
@end

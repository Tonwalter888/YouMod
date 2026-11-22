// Inline muted playback state controllers. 21.x+ uses the ...Impl class;
// 20.x and earlier use the pre-split YTInlineMutedPlaybackStateController
// (same API, verified against YouTube 20.21.6).
@interface YTInlineMutedPlaybackStateControllerImpl : NSObject
- (BOOL)inlinePlaybackUnmutedAtStart;
- (void)setInlinePlaybackUnmutedAtStart:(BOOL)start;
- (void)didTurnOnAudioForVideoId:(NSString *)videoID;
- (void)didTurnOffAudioForVideoId:(NSString *)videoID;
@end

@interface YTInlineMutedPlaybackStateController : NSObject
- (BOOL)inlinePlaybackUnmutedAtStart;
- (void)setInlinePlaybackUnmutedAtStart:(BOOL)start;
- (void)didTurnOnAudioForVideoId:(NSString *)videoID;
- (void)didTurnOffAudioForVideoId:(NSString *)videoID;
@end

#import "Headers.h"

// mostly i dont understand this btw

// =======================
//    FORCE HLS STREAM
// =======================

// The player-stack gate (checked by MLPlayerPoolImpl canQueuePlayerPlayVideo /
// acquirePlayerForVideo when choosing HAM/DASH vs MLAVPlayer) reads these two
// getters from MLStreamingData. Reporting NO while HLS data exists routes
// playback to MLAVPlayer, whose MLStreamSelector then prefers MLHLSStreamSelector
// (HLS is checked before progressive). Falls back to normal behavior when the
// video has no HLS manifest.

%hook MLStreamingData
- (BOOL)hasSupportedAudioDASHStreams { return [self hasHLSData] ? NO : %orig; }
- (BOOL)hasSupportedVideoDASHStreams { return [self hasHLSData] ? NO : %orig; }
%end

%ctor {
    if (!IS_ENABLED(FixPlaybackIssues)) return;
    %init;
}
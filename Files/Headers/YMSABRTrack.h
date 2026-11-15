#import "YMSABRFormat.h"

// YMSABRTrack — accumulates one track's media, keyed by ITAG (init and media
// segments arrive under different headerIds). Written to `fileURL`.

@interface YMSABRTrack : NSObject
@property (nonatomic, strong) YMSABRFormat *format;
@property (nonatomic, strong) NSURL *fileURL;
@property (nonatomic, strong) NSFileHandle *handle;
@property (nonatomic, assign) uint64_t downloadedMs;   // real total downloaded duration (sum of segment durations)
@property (nonatomic, assign) uint64_t lastSequence;   // highest segment index written
// Per-round window of NEW segments (the buffered_range we report is a delta
// window, not a cumulative 0..N range).
@property (nonatomic, assign) uint64_t roundStartMs;
@property (nonatomic, assign) uint64_t roundDurationMs;
@property (nonatomic, assign) uint64_t roundFirstSeq;
@property (nonatomic, assign) uint64_t roundLastSeq;
@property (nonatomic, assign) BOOL roundHasMedia;
@property (nonatomic, assign) uint64_t endSegment;     // from FORMAT_INIT (0 = unknown)
@property (nonatomic, assign) uint64_t endTimeMs;      // from FORMAT_INIT (0 = unknown)
@property (nonatomic, assign) BOOL initWritten;
@property (nonatomic, assign) BOOL complete;
@property (nonatomic, assign) unsigned long long bytesWritten;
@end

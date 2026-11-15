#import "YTIFormatStream.h"
#import "YMSABRFormat.h"
#import "YMSABRMediaHeader.h"
#import "YMSABRTrack.h"

// YMSABRHelpers — SABR wire-format helpers (SABRDownload.x): UMP + protobuf
// parse/encode and the download-engine support functions.

@interface YMSABRHelpers : NSObject
// Serial queue guarding all shared engine state; capture hooks and network
// completions hop here before touching shared state.
+ (dispatch_queue_t)queue;

// UMP varint: leading 1-bits of the first byte give total byte count (1..5).
// Returns bytes consumed (0 on truncated input).
+ (NSUInteger)readUMPVarint:(const uint8_t *)b length:(NSUInteger)len position:(NSUInteger)pos out:(uint64_t *)out;
// Parse a UMP stream, calling handler per part (type, payload). MEDIA payloads
// still include the leading headerId varint. Returns bytes consumed.
+ (NSUInteger)parseUMP:(NSData *)data handler:(void (^)(uint64_t type, const uint8_t *payload, NSUInteger size))handler;

// Read a base-128 protobuf varint. Returns bytes consumed (0 on malformed input).
+ (NSUInteger)readProtoVarint:(const uint8_t *)b length:(NSUInteger)len position:(NSUInteger)pos out:(uint64_t *)out;
+ (void)appendProtoVarint:(NSMutableData *)d value:(uint64_t)v;
+ (void)appendVarintField:(NSMutableData *)d field:(uint64_t)field value:(uint64_t)v;
+ (void)appendBytesField:(NSMutableData *)d field:(uint64_t)field bytes:(NSData *)bytes;
// Walk ONE level of a protobuf message: handler gets (field number, wire type,
// whole-field span, payload span) and returns NO to stop early. YES only if the
// buffer parsed cleanly end-to-end.
+ (BOOL)iterateTopLevel:(NSData *)data handler:(BOOL (^)(uint64_t field, int wire, NSUInteger fieldStart, NSUInteger fieldEnd, NSUInteger payloadStart, NSUInteger payloadLen))handler;
// Read one varint field's value from a message (first match). Returns whether found.
+ (BOOL)readVarintField:(NSData *)msg field:(uint64_t)field out:(uint64_t *)out;
// Copy `msg` with varint `field` set to `value` (replaced in place, or appended
// if absent). Other fields are copied byte-for-byte.
+ (NSData *)setVarintField:(NSData *)msg field:(uint64_t)field value:(uint64_t)value;

// Parse a FormatId message → {itag, lastModified, xtags}.
+ (YMSABRFormat *)parseFormatId:(NSData *)fmt;
// Resolve a download target for `itag` from the available-format list (#5.#1.#6).
// `wantXtags` names one variant exactly (the picked soundtrack); nil/empty = no
// preference → first match, upgraded to an xtags-bearing entry.
+ (YMSABRFormat *)resolveFormat:(NSData *)body itag:(uint64_t)itag wantXtags:(NSData *)wantXtags;
// Encode FormatId { #1 itag, #2 lastModified, #3 xtags }. xtags is always
// emitted (empty if none) — matches YTKACE / the real client.
+ (NSData *)encodeFormatId:(YMSABRFormat *)fmt;
// Encode a BufferedRange with the REAL extent just received: segments
// [startSeg..endSeg] over [startMs, startMs+durationMs).
+ (NSData *)encodeBufferedRange:(YMSABRFormat *)fmt startSeg:(uint64_t)startSeg endSeg:(uint64_t)endSeg startMs:(uint64_t)startMs durationMs:(uint64_t)durationMs;

// Convert a TimeRange tick count to milliseconds (rounded).
+ (uint64_t)ticksToMs:(uint64_t)ticks timescale:(uint64_t)timescale;
// Decode MEDIA_HEADER (UMP part 20): maps a headerId to a format + segment.
+ (YMSABRMediaHeader *)decodeMediaHeader:(const uint8_t *)payload size:(NSUInteger)size;
// FORMAT_INITIALIZATION_METADATA (part 42): the authoritative end-of-track marker.
+ (void)decodeFormatInit:(const uint8_t *)payload size:(NSUInteger)size itag:(uint64_t *)itag endSeg:(uint64_t *)endSeg endTimeMs:(uint64_t *)endTimeMs;

// The URL's expire= query value (0 when absent).
+ (NSTimeInterval)expireFromURL:(NSURL *)url;
// Build one request body targeting `videoFmt` + `audioFmt`: #16/#17 preferred
// formats, #2/#3 echoed state, #1.#28 + #4 player_time_ms; #1/#5/#19 verbatim.
// `bufferedRanges` / `selectedFormats` are pre-encoded submessages.
+ (NSData *)buildRequestBody:(NSData *)orig videoFmt:(YMSABRFormat *)videoFmt audioFmt:(YMSABRFormat *)audioFmt
               playerTimeMs:(uint64_t)playerTimeMs bufferedRanges:(NSArray<NSData *> *)bufferedRanges
             selectedFormats:(NSArray<NSData *> *)selectedFormats;
// One network round-trip: POST `body` to the captured signed URL, return the raw
// UMP response. Called on the serial queue.
+ (void)postOnce:(NSURL *)url body:(NSData *)body completion:(void (^)(NSData *data, NSHTTPURLResponse *http, NSError *err))completion;
// Parse one UMP response, routing media to its track by itag; reports
// redirect/reload via out-params.
+ (void)ingestResponse:(NSData *)data tracks:(NSDictionary<NSNumber *, YMSABRTrack *> *)tracks
           redirectURL:(NSString **)redirectURL reload:(BOOL *)reload;
// A track is complete at its last segment (authoritative), or when its real
// downloaded duration reaches the total (backup check).
+ (BOOL)trackDone:(YMSABRTrack *)track;
// Fresh unique temp file per track (per download).
+ (YMSABRTrack *)makeTrack:(YMSABRFormat *)fmt extension:(NSString *)ext;
// Orchestrator: download the video + audio itags together until each track
// reaches its last segment, then `completion(videoURL, audioURL, err)` on the
// main queue. videoItag == 0 = audio-only (videoURL is nil).
+ (void)runDownloadVideoItag:(uint64_t)videoItag audioItag:(uint64_t)audioItag audioXtags:(NSData *)audioXtags
                    progress:(void (^)(float fraction, unsigned long long bytesDownloaded, BOOL isAudio))progress
                  completion:(void (^)(NSURL *videoURL, NSURL *audioURL, NSString *err))completion;
// The picked format's xtags from a format stream (nil = none / no preference).
+ (NSData *)xtagsForStream:(YTIFormatStream *)stream;
@end

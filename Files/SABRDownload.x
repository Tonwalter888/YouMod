// Reworked on-device downloader with SABR

#import "Headers.h"

#define SABR_ENABLED() 1

#pragma mark - UMP parser

// UMP part type IDs (LuanRT/googlevideo ump_part_id.proto).
typedef NS_ENUM(NSInteger, SABRPartType) {
    SABRPartMediaHeader      = 20,
    SABRPartMedia            = 21,
    SABRPartMediaEnd         = 22,
    SABRPartNextRequestPolicy = 35,
    SABRPartFormatInit       = 42, // FORMAT_INITIALIZATION_METADATA
    SABRPartRedirect         = 43, // SABR_REDIRECT (new URL)
    SABRPartError            = 44, // SABR_ERROR
    SABRPartReload           = 46, // RELOAD_PLAYER_RESPONSE
    SABRPartContextUpdate    = 57, // SABR_CONTEXT_UPDATE
    SABRPartStreamProtection = 58, // STREAM_PROTECTION_STATUS
};

// SABR_REDIRECT (part 43) payload: #1 = the replacement videoplayback URL (string).
static const uint64_t kSABRRedirectURL = 1;

#pragma mark - SABR protobuf field map

// VideoPlaybackAbrRequest top-level fields.
static const uint64_t kSABRReqClientAbrState  = 1;  // keep verbatim; only #28 player_time overridden
static const uint64_t kSABRReqSelectedFormats = 2;  // "initialized" echo list (empty until init metadata arrives)
static const uint64_t kSABRReqBufferedRanges  = 3;  // what we already hold (drives advancement)
static const uint64_t kSABRReqPlayerTimeMs    = 4;  // top-level player time
static const uint64_t kSABRReqUstreamerConfig = 5;  // ustreamer/policy blob; also carries the available-format list
static const uint64_t kSABRReqPreferredAudio  = 16; // preferred_audio_format_ids — the AUDIO download target
static const uint64_t kSABRReqPreferredVideo  = 17; // preferred_video_format_ids — the VIDEO download target
// (#19 streamer_context is kept verbatim via the copy-everything-else path.)

static const uint64_t kSABRAbrStatePlayerTimeMs = 28; // ClientAbrState.player_time_ms

// #5 -> #1 -> #6 repeated FormatId = the full available-format list (source of lastModified + xtags).
static const uint64_t kSABRAvailInner = 1; // #5.#1
static const uint64_t kSABRAvailList  = 6; // #5.#1.#6 repeated FormatId

// FormatId { #1 itag, #2 last_modified, #3 xtags }.
static const uint64_t kSABRFmtItag    = 1;
static const uint64_t kSABRFmtLastMod = 2;
static const uint64_t kSABRFmtXtags   = 3;

// BufferedRange { #1 formatId, #2 start_time_ms, #3 duration_ms, #4 start_segment_index,
//                 #5 end_segment_index, #6 TimeRange } ; TimeRange { #1 start, #2 duration, #3 timescale }.
static const uint64_t kSABRBufFormatId   = 1;
static const uint64_t kSABRBufStartMs     = 2;
static const uint64_t kSABRBufDurationMs  = 3;
static const uint64_t kSABRBufStartSeg    = 4;
static const uint64_t kSABRBufEndSeg      = 5;
static const uint64_t kSABRBufTimeRange   = 6;
static const uint64_t kSABRTimeRangeStart = 1;
static const uint64_t kSABRTimeRangeDur   = 2;
static const uint64_t kSABRTimeRangeScale = 3;
static const uint64_t kSABRMsPerSecond    = 1000; // ms timebase (also the timescale we emit)

// MediaHeader (UMP part 20) fields. On 21.29+ start/duration come from the
// #15 TimeRange instead of scalars #11/#12.
static const uint64_t kSABRHdrHeaderId      = 1;
static const uint64_t kSABRHdrItag          = 3;
static const uint64_t kSABRHdrIsInit        = 8;
static const uint64_t kSABRHdrSequence      = 9;
static const uint64_t kSABRHdrStartMs       = 11; // segment start (ms), scalar — when present
static const uint64_t kSABRHdrDurationMs    = 12; // segment duration (ms), scalar — when present
static const uint64_t kSABRHdrFormatId      = 13; // fallback FormatId (has itag/xtags)
static const uint64_t kSABRHdrContentLength = 14;
static const uint64_t kSABRHdrTimeRange     = 15; // TimeRange { startTicks, durationTicks, timescale }
static const uint64_t kSABRTRStartTicks     = 1;
static const uint64_t kSABRTRDurationTicks  = 2;
static const uint64_t kSABRTRTimescale      = 3;

// FormatInitializationMetadata (UMP part 42): a track's total length.
// #1 = video_id string, #2 = FormatId.
static const uint64_t kSABRInitFormatId     = 2; // FormatId { itag, lastModified, xtags }
static const uint64_t kSABRInitEndTimeMs    = 3; // total duration ms
static const uint64_t kSABRInitEndSegment   = 4; // last segment index

// Cap on request round-trips per download (safety backstop, never hit in practice).
static const int kSABRMaxRequests = 400;
// Bail after this many consecutive rounds with no new media (a run of
// policy-only rounds means the download is genuinely stuck).
static const int kSABRMaxEmptyRounds = 4;
static const int kSABRMaxResyncs = 1;

#pragma mark - Protobuf helpers (base-128 varint; distinct from the UMP varint above)

// Protobuf wire types (low 3 bits of a field key).
static const int kProtoWireVarint          = 0;
static const int kProtoWire64Bit           = 1;
static const int kProtoWireLengthDelimited = 2;
static const int kProtoWire32Bit           = 5;

#pragma mark - Available formats (#5) → {lastModified, xtags} for a chosen itag

@implementation YMSABRFormat @end

#pragma mark - Response part decoders (MEDIA_HEADER / FORMAT_INIT)

@implementation YMSABRMediaHeader @end

#pragma mark - Per-track download state

@implementation YMSABRTrack @end

#pragma mark - Capture layer (permanent): the app's live signed videoplayback request

// Captured request material: tracks the MOST-RECENT videoplayback request (the
// current video), so switching videos re-captures the new one. Touched only on
// the serial queue.
static NSURL *gCapURL;
static NSData *gCapPlainBody;      // pre-Brotli body (from -HTTPBody)
static NSDictionary *gCapHeaders;
static NSTimeInterval gCapExpire;  // from the URL's expire= param
static BOOL gSABRCancel;           // aborts the active download loop (touched on the serial queue)

%hook HAMDataLoadRequest
- (NSURLRequest *)buildURLRequest {
    NSURLRequest *r = %orig;
    if (!SABR_ENABLED()) return r;
    @try {
        NSString *host = r.URL.host ?: @""; NSString *path = r.URL.path ?: @"";
        if ([host containsString:@"googlevideo"] && [path containsString:@"videoplayback"] &&
            [r.HTTPMethod isEqualToString:@"POST"]) {
            id me = self;
            NSData *plain = nil; @try { plain = [me HTTPBody]; } @catch (id ex) {}
            NSURL *url = r.URL;
            NSData *plainCopy = [plain copy];
            NSMutableDictionary *hdrs = [r.allHTTPHeaderFields mutableCopy] ?: [NSMutableDictionary dictionary];
            dispatch_async([YMSABRHelpers queue], ^{
                // Most-recent-wins so switching videos captures the new request.
                gCapURL = url; gCapPlainBody = plainCopy; gCapHeaders = hdrs; gCapExpire = [YMSABRHelpers expireFromURL:url];
            });
        }
    } @catch (id ex) {}
    return r;
}
%end

#pragma mark - Fresh request builder (no captured body: built from a resolved player response)

@interface YMSABRSessionState : NSObject
@property (nonatomic, strong) NSData *cookie;                                    // NextRequestPolicy.playback_cookie
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSData *> *contexts; // SABR_CONTEXT_UPDATE: type -> value
@property (nonatomic, assign) uint64_t backoffMs;
@property (nonatomic, assign) uint64_t protectionStatus;                         // STREAM_PROTECTION_STATUS #1
@property (nonatomic, copy) NSString *reloadToken;                               // RELOAD_PLAYER_RESPONSE #1.#1
@end
@implementation YMSABRSessionState
- (instancetype)init { if ((self = [super init])) _contexts = [NSMutableDictionary dictionary]; return self; }
@end

static NSData *SABRBytesField(NSData *msg, uint64_t field) {
    __block NSData *out = nil;
    [YMSABRHelpers iterateTopLevel:msg handler:^BOOL(uint64_t f, int w, NSUInteger fs, NSUInteger fe, NSUInteger ps, NSUInteger pl) {
        if (f == field && w == kProtoWireLengthDelimited) { out = [msg subdataWithRange:NSMakeRange(ps, pl)]; return NO; }
        return YES;
    }];
    return out;
}

static void SABRAppendFloatField(NSMutableData *d, uint64_t field, float v) {
    [YMSABRHelpers appendProtoVarint:d value:(field << 3) | kProtoWire32Bit];
    [d appendBytes:&v length:4];
}

static id SABRFindPlayerData(id obj, int depth) {
    if (!obj || depth > 6) return nil;
    @try { if ([obj valueForKey:@"streamingData"]) return obj; } @catch (id ex) {}
    for (NSString *name in @[@"playerData", @"playerResponse", @"playbackData", @"contentPlayerResponse", @"response", @"video"]) {
        id child = nil; @try { child = [obj valueForKey:name]; } @catch (id ex) {}
        id found = SABRFindPlayerData(child, depth + 1);
        if (found) return found;
    }
    return nil;
}

static BOOL SABRExtractSession(id response, NSString **urlOut, NSData **configOut) {
    id data = SABRFindPlayerData(response, 0) ?: response;
    @try {
        id streaming = [data valueForKey:@"streamingData"];
        id common = [[data valueForKey:@"playerConfig"] valueForKey:@"mediaCommonConfig"];
        id cfg = [[common valueForKey:@"mediaUstreamerRequestConfig"] valueForKey:@"videoPlaybackUstreamerConfig"];
        id url = [streaming valueForKey:@"serverAbrStreamingURL"];
        if ([cfg isKindOfClass:NSData.class] && [cfg length] && [url isKindOfClass:NSString.class] && [url length]) {
            *urlOut = url; *configOut = cfg; return YES;
        }
    } @catch (id ex) {}
    return NO;
}

static YMSABRFormat *SABRFormatFromStream(YTIFormatStream *stream) {
    YMSABRFormat *f = [YMSABRFormat new]; f.xtags = [NSData data];
    if (!stream) return f;
    f.itag = (uint64_t)[stream itag];
    @try { f.lastModified = [[stream valueForKey:@"lastModified"] unsignedLongLongValue]; } @catch (id ex) {}
    NSData *x = [YMSABRHelpers xtagsForStream:stream];
    if (x.length) f.xtags = x;
    f.found = f.itag != 0 && f.lastModified != 0;
    return f;
}

static id gSABRFreshResponse;
static NSData *gSABRPinnedBody;
static NSDictionary *gSABRPinnedHeaders;

static YTIFormatStream *SABRFindStream(id response, uint64_t itag, NSData *wantXtags) {
    id data = SABRFindPlayerData(response, 0) ?: response;
    NSArray *list = nil;
    @try { list = [[data valueForKey:@"streamingData"] valueForKey:@"adaptiveFormatsArray"]; } @catch (id ex) {}
    YTIFormatStream *best = nil;
    for (YTIFormatStream *st in list) {
        if ((uint64_t)[st itag] != itag) continue;
        NSData *x = [YMSABRHelpers xtagsForStream:st];
        if (wantXtags.length) { if ([x isEqualToData:wantXtags]) return st; continue; }
        if (!best || ([YMSABRHelpers xtagsForStream:best].length == 0 && x.length > 0)) best = st;
    }
    return best;
}

static NSString *SABRVideoIDFromResponse(id response) {
    id data = SABRFindPlayerData(response, 0) ?: response;
    @try { id v = [[data valueForKey:@"videoDetails"] valueForKey:@"videoId"]; if ([v isKindOfClass:NSString.class]) return v; } @catch (id ex) {}
    return nil;
}

static NSURL *SABRURLWithRequestNumber(NSString *base, int rn) {
    NSURLComponents *c = [NSURLComponents componentsWithString:base];
    NSMutableArray *items = [NSMutableArray array];
    for (NSURLQueryItem *i in c.queryItems ?: @[]) if (![i.name isEqualToString:@"rn"]) [items addObject:i];
    [items addObject:[NSURLQueryItem queryItemWithName:@"rn" value:[NSString stringWithFormat:@"%d", rn]]];
    c.queryItems = items;
    return c.URL;
}

static NSData *SABRBuildClientInfo(void) {
    NSMutableData *d = [NSMutableData data];
    UIDevice *dev = UIDevice.currentDevice;
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    CGSize pts = UIScreen.mainScreen.bounds.size;
    void (^str)(uint64_t, NSString *) = ^(uint64_t f, NSString *v) { if (v.length) [YMSABRHelpers appendBytesField:d field:f bytes:[v dataUsingEncoding:NSUTF8StringEncoding]]; };
    str(12, @"Apple");
    str(13, dev.model ?: @"iOS");
    [YMSABRHelpers appendVarintField:d field:16 value:5];
    str(17, info[@"CFBundleShortVersionString"] ?: @"21.28.3");
    str(18, @"IOS");
    str(19, dev.systemVersion ?: @"16.0");
    str(21, NSLocale.preferredLanguages.firstObject ?: @"en-US");
    str(22, NSLocale.currentLocale.countryCode ?: @"US");
    [YMSABRHelpers appendVarintField:d field:37 value:(uint64_t)llround(pts.width)];
    [YMSABRHelpers appendVarintField:d field:38 value:(uint64_t)llround(pts.height)];
    [YMSABRHelpers appendVarintField:d field:41 value:(uint64_t)llround(UIScreen.mainScreen.scale)];
    [YMSABRHelpers appendVarintField:d field:46 value:dev.userInterfaceIdiom == UIUserInterfaceIdiomPad ? 2 : 1];
    str(80, NSTimeZone.localTimeZone.name ?: @"UTC");
    return d;
}

static NSData *SABRBuildFreshBody(NSData *ustreamerConfig, NSData *poToken, NSData *playbackCookie,
                                  YMSABRFormat *videoFmt, YMSABRFormat *audioFmt, uint64_t resolution,
                                  uint64_t playerTimeMs, NSArray<NSData *> *bufferedRanges, NSArray<NSData *> *selectedFormats,
                                  NSDictionary<NSNumber *, NSData *> *contexts) {
    resolution = MAX(resolution, 360);
    NSMutableData *state = [NSMutableData data];
    [YMSABRHelpers appendVarintField:state field:16 value:resolution];
    [YMSABRHelpers appendVarintField:state field:21 value:resolution];
    [YMSABRHelpers appendVarintField:state field:22 value:0];
    [YMSABRHelpers appendVarintField:state field:kSABRAbrStatePlayerTimeMs value:playerTimeMs];
    [YMSABRHelpers appendVarintField:state field:34 value:1];
    SABRAppendFloatField(state, 35, 1.0f);
    [YMSABRHelpers appendVarintField:state field:40 value:0];   // track mode 0 = audio + video
    [YMSABRHelpers appendVarintField:state field:46 value:0];

    NSMutableData *ctx = [NSMutableData data];
    [YMSABRHelpers appendBytesField:ctx field:1 bytes:SABRBuildClientInfo()];
    if (poToken.length) [YMSABRHelpers appendBytesField:ctx field:2 bytes:poToken];
    if (playbackCookie.length) [YMSABRHelpers appendBytesField:ctx field:3 bytes:playbackCookie];
    for (NSNumber *type in contexts) {
        NSMutableData *item = [NSMutableData data];
        [YMSABRHelpers appendVarintField:item field:1 value:type.unsignedLongLongValue];
        [YMSABRHelpers appendBytesField:item field:2 bytes:contexts[type]];
        [YMSABRHelpers appendBytesField:ctx field:5 bytes:item];
    }

    NSMutableData *req = [NSMutableData data];
    [YMSABRHelpers appendBytesField:req field:kSABRReqClientAbrState bytes:state];
    for (NSData *sel in selectedFormats) [YMSABRHelpers appendBytesField:req field:kSABRReqSelectedFormats bytes:sel];
    for (NSData *br in bufferedRanges)   [YMSABRHelpers appendBytesField:req field:kSABRReqBufferedRanges bytes:br];
    [YMSABRHelpers appendBytesField:req field:kSABRReqUstreamerConfig bytes:ustreamerConfig];
    if (audioFmt) [YMSABRHelpers appendBytesField:req field:kSABRReqPreferredAudio bytes:[YMSABRHelpers encodeFormatId:audioFmt]];
    if (videoFmt) [YMSABRHelpers appendBytesField:req field:kSABRReqPreferredVideo bytes:[YMSABRHelpers encodeFormatId:videoFmt]];
    [YMSABRHelpers appendBytesField:req field:19 bytes:ctx];
    return req;
}

static NSData *SABRDropFields(NSData *msg, NSArray<NSNumber *> *drop) {
    const uint8_t *b = (const uint8_t *)msg.bytes;
    NSMutableData *out = [NSMutableData data];
    BOOL ok = [YMSABRHelpers iterateTopLevel:msg handler:^BOOL(uint64_t f, int w, NSUInteger fs, NSUInteger fe, NSUInteger ps, NSUInteger pl) {
        if (![drop containsObject:@(f)]) [out appendBytes:b + fs length:fe - fs];
        return YES;
    }];
    return ok ? out : [msg copy];
}

// Replay a request body the app itself sent (any video's), for example when session expires
static NSData *SABRBuildNativeBody(NSData *native, NSData *ustreamerConfig, NSData *playbackCookie,
                                   YMSABRFormat *videoFmt, YMSABRFormat *audioFmt, uint64_t resolution,
                                   uint64_t playerTimeMs, NSArray<NSData *> *bufferedRanges, NSArray<NSData *> *selectedFormats,
                                   NSDictionary<NSNumber *, NSData *> *contexts) {
    NSData *nativeState = SABRBytesField(native, kSABRReqClientAbrState);
    NSData *nativeCtx = SABRBytesField(native, 19);
    if (!nativeState.length || !nativeCtx.length) return nil;
    NSData *state = [YMSABRHelpers setVarintField:nativeState field:16 value:MAX(resolution, 360)];
    state = [YMSABRHelpers setVarintField:state field:kSABRAbrStatePlayerTimeMs value:playerTimeMs];
    state = [YMSABRHelpers setVarintField:state field:40 value:0];   // track mode 0 = audio + video

    NSMutableData *ctx = [NSMutableData dataWithData:SABRDropFields(nativeCtx, @[@3, @5])];
    if (playbackCookie.length) [YMSABRHelpers appendBytesField:ctx field:3 bytes:playbackCookie];
    for (NSNumber *type in contexts) {
        NSMutableData *item = [NSMutableData data];
        [YMSABRHelpers appendVarintField:item field:1 value:type.unsignedLongLongValue];
        [YMSABRHelpers appendBytesField:item field:2 bytes:contexts[type]];
        [YMSABRHelpers appendBytesField:ctx field:5 bytes:item];
    }

    NSMutableData *req = [NSMutableData dataWithData:SABRDropFields(native, @[@1, @2, @3, @4, @5, @16, @17, @19])];
    [YMSABRHelpers appendBytesField:req field:kSABRReqClientAbrState bytes:state];
    for (NSData *sel in selectedFormats) [YMSABRHelpers appendBytesField:req field:kSABRReqSelectedFormats bytes:sel];
    for (NSData *br in bufferedRanges)   [YMSABRHelpers appendBytesField:req field:kSABRReqBufferedRanges bytes:br];
    [YMSABRHelpers appendBytesField:req field:kSABRReqUstreamerConfig bytes:ustreamerConfig];
    if (audioFmt) [YMSABRHelpers appendBytesField:req field:kSABRReqPreferredAudio bytes:[YMSABRHelpers encodeFormatId:audioFmt]];
    if (videoFmt) [YMSABRHelpers appendBytesField:req field:kSABRReqPreferredVideo bytes:[YMSABRHelpers encodeFormatId:videoFmt]];
    [YMSABRHelpers appendBytesField:req field:19 bytes:ctx];
    return req;
}

@implementation YMSABRHelpers

// Serial queue guarding all shared engine state; capture hooks and network
// completions hop here before touching shared state.
+ (dispatch_queue_t)queue {
    static dispatch_queue_t q; static dispatch_once_t o;
    dispatch_once(&o, ^{ q = dispatch_queue_create("youmod.sabr", DISPATCH_QUEUE_SERIAL); });
    return q;
}

// UMP varint: leading 1-bits of the first byte give total byte count (1..5).
+ (NSUInteger)readUMPVarint:(const uint8_t *)b length:(NSUInteger)len position:(NSUInteger)pos out:(uint64_t *)out {
    if (pos >= len) return 0;
    uint8_t pfx = b[pos]; int size = 1;
    if (pfx >= 0xF0) size = 5; else if (pfx >= 0xE0) size = 4; else if (pfx >= 0xC0) size = 3; else if (pfx >= 0x80) size = 2;
    if (pos + size > len) return 0;
    uint64_t r = 0; int sh = 0;
    if (size != 5) { sh = 8 - size; r = pfx & ((1u << sh) - 1); }
    for (int i = 1; i < size; i++) { r |= ((uint64_t)b[pos + i]) << sh; sh += 8; }
    *out = r; return (NSUInteger)size;
}

// Parse a UMP stream, calling `handler` per part (type, payload). Returns bytes
// consumed. MEDIA payloads still include the leading headerId varint.
+ (NSUInteger)parseUMP:(NSData *)data handler:(void (^)(uint64_t type, const uint8_t *payload, NSUInteger size))handler {
    const uint8_t *b = (const uint8_t *)data.bytes; NSUInteger len = data.length, pos = 0;
    while (pos < len) {
        uint64_t type = 0, size = 0;
        NSUInteger c1 = [YMSABRHelpers readUMPVarint:b length:len position:pos out:&type]; if (!c1) break; pos += c1;
        NSUInteger c2 = [YMSABRHelpers readUMPVarint:b length:len position:pos out:&size]; if (!c2) break; pos += c2;
        if (pos + size > len) break;
        if (handler) handler(type, b + pos, (NSUInteger)size);
        pos += (NSUInteger)size;
    }
    return pos;
}

// Read a base-128 varint. Returns bytes consumed (0 on malformed/truncated input).
+ (NSUInteger)readProtoVarint:(const uint8_t *)b length:(NSUInteger)len position:(NSUInteger)pos out:(uint64_t *)out {
    uint64_t v = 0; int sh = 0; NSUInteger start = pos;
    while (pos < len) {
        uint8_t by = b[pos++];
        v |= ((uint64_t)(by & 0x7f)) << sh;
        if (!(by & 0x80)) { if (out) *out = v; return pos - start; }
        sh += 7; if (sh >= 64) return 0;
    }
    return 0;
}

+ (void)appendProtoVarint:(NSMutableData *)d value:(uint64_t)v {
    uint8_t buf[10]; int n = 0;
    do { uint8_t by = v & 0x7f; v >>= 7; if (v) by |= 0x80; buf[n++] = by; } while (v);
    [d appendBytes:buf length:n];
}

+ (void)appendVarintField:(NSMutableData *)d field:(uint64_t)field value:(uint64_t)v {
    [YMSABRHelpers appendProtoVarint:d value:((field << 3) | 0)]; [YMSABRHelpers appendProtoVarint:d value:v];
}

+ (void)appendBytesField:(NSMutableData *)d field:(uint64_t)field bytes:(NSData *)bytes {
    [YMSABRHelpers appendProtoVarint:d value:((field << 3) | 2)]; [YMSABRHelpers appendProtoVarint:d value:bytes.length]; [d appendData:bytes];
}

// Walk ONE level of a protobuf message: handler gets (field number, wire type,
// whole-field span, payload span) and returns NO to stop early. YES only if the
// buffer parsed cleanly end-to-end.
+ (BOOL)iterateTopLevel:(NSData *)data handler:(BOOL (^)(uint64_t field, int wire, NSUInteger fieldStart, NSUInteger fieldEnd, NSUInteger payloadStart, NSUInteger payloadLen))handler {
    const uint8_t *b = (const uint8_t *)data.bytes; NSUInteger len = data.length, pos = 0;
    while (pos < len) {
        NSUInteger fieldStart = pos;
        uint64_t key = 0; NSUInteger kc = [YMSABRHelpers readProtoVarint:b length:len position:pos out:&key]; if (!kc) return NO; pos += kc;
        uint64_t field = key >> 3; int wire = key & 0x7;
        NSUInteger payloadStart = pos, payloadLen = 0;
        if (wire == kProtoWireVarint) { uint64_t v; NSUInteger c = [YMSABRHelpers readProtoVarint:b length:len position:pos out:&v]; if (!c) return NO; payloadLen = c; pos += c; }
        else if (wire == kProtoWire64Bit) { if (pos + 8 > len) return NO; payloadLen = 8; pos += 8; }
        else if (wire == kProtoWireLengthDelimited) { uint64_t l; NSUInteger c = [YMSABRHelpers readProtoVarint:b length:len position:pos out:&l]; if (!c || pos + c + l > len) return NO; payloadStart = pos + c; payloadLen = (NSUInteger)l; pos += c + l; }
        else if (wire == kProtoWire32Bit) { if (pos + 4 > len) return NO; payloadLen = 4; pos += 4; }
        else return NO;
        if (handler && !handler(field, wire, fieldStart, pos, payloadStart, payloadLen)) return YES;
    }
    return YES;
}

// Read one varint field's value from a message (first match). Returns whether found.
+ (BOOL)readVarintField:(NSData *)msg field:(uint64_t)field out:(uint64_t *)out {
    const uint8_t *b = (const uint8_t *)msg.bytes; NSUInteger len = msg.length;
    __block BOOL got = NO; __block uint64_t val = 0;
    [YMSABRHelpers iterateTopLevel:msg handler:^BOOL(uint64_t f, int w, NSUInteger fs, NSUInteger fe, NSUInteger ps, NSUInteger pl) {
        if (f == field && w == kProtoWireVarint) { uint64_t v = 0; if ([YMSABRHelpers readProtoVarint:b length:len position:ps out:&v]) { val = v; got = YES; return NO; } }
        return YES;
    }];
    if (got && out) *out = val;
    return got;
}

// Copy `msg` with varint `field` set to `value` (replaced in place, or appended
// if absent). Other fields are copied byte-for-byte.
+ (NSData *)setVarintField:(NSData *)msg field:(uint64_t)field value:(uint64_t)value {
    const uint8_t *b = (const uint8_t *)msg.bytes;
    NSMutableData *out = [NSMutableData data];
    __block BOOL replaced = NO;
    BOOL ok = [YMSABRHelpers iterateTopLevel:msg handler:^BOOL(uint64_t f, int w, NSUInteger fs, NSUInteger fe, NSUInteger ps, NSUInteger pl) {
        if (f == field && w == kProtoWireVarint) { [YMSABRHelpers appendVarintField:out field:field value:value]; replaced = YES; }
        else [out appendBytes:b + fs length:fe - fs];
        return YES;
    }];
    if (!ok) return [msg copy]; // don't corrupt a body we can't parse
    if (!replaced) [YMSABRHelpers appendVarintField:out field:field value:value];
    return out;
}

// Parse a FormatId message → {itag, lastModified, xtags}.
+ (YMSABRFormat *)parseFormatId:(NSData *)fmt {
    YMSABRFormat *r = [YMSABRFormat new]; r.xtags = [NSData data];
    const uint8_t *b = (const uint8_t *)fmt.bytes; NSUInteger len = fmt.length;
    [YMSABRHelpers iterateTopLevel:fmt handler:^BOOL(uint64_t f, int w, NSUInteger fs, NSUInteger fe, NSUInteger ps, NSUInteger pl) {
        if (f == kSABRFmtItag && w == kProtoWireVarint)    { uint64_t v = 0; if ([YMSABRHelpers readProtoVarint:b length:len position:ps out:&v]) r.itag = v; }
        else if (f == kSABRFmtLastMod && w == kProtoWireVarint) { uint64_t v = 0; if ([YMSABRHelpers readProtoVarint:b length:len position:ps out:&v]) r.lastModified = v; }
        else if (f == kSABRFmtXtags && w == kProtoWireLengthDelimited)   { r.xtags = [fmt subdataWithRange:NSMakeRange(ps, pl)]; }
        return YES;
    }];
    return r;
}

// Resolve a download target for `itag` from the available-format list (#5.#1.#6).
// Itags can repeat as plain + xtags-tagged variants (soundtrack/DRC live in
// xtags); `wantXtags` picks one variant exactly (nil/empty = first match,
// upgraded to an xtags-bearing entry). The triple is copied as one so server
// matching lines up.
+ (YMSABRFormat *)resolveFormat:(NSData *)body itag:(uint64_t)itag wantXtags:(NSData *)wantXtags {
    YMSABRFormat *result = [YMSABRFormat new];
    BOOL exact = wantXtags.length > 0;
    [YMSABRHelpers iterateTopLevel:body handler:^BOOL(uint64_t f5, int w5, NSUInteger fs, NSUInteger fe, NSUInteger ps5, NSUInteger pl5) {
        if (f5 != kSABRReqUstreamerConfig || w5 != kProtoWireLengthDelimited) return YES;
        NSData *avail = [body subdataWithRange:NSMakeRange(ps5, pl5)];
        [YMSABRHelpers iterateTopLevel:avail handler:^BOOL(uint64_t f1, int w1, NSUInteger fs1, NSUInteger fe1, NSUInteger ps1, NSUInteger pl1) {
            if (f1 != kSABRAvailInner || w1 != kProtoWireLengthDelimited) return YES;
            NSData *inner = [avail subdataWithRange:NSMakeRange(ps1, pl1)];
            [YMSABRHelpers iterateTopLevel:inner handler:^BOOL(uint64_t f6, int w6, NSUInteger fs6, NSUInteger fe6, NSUInteger ps6, NSUInteger pl6) {
                if (f6 != kSABRAvailList || w6 != kProtoWireLengthDelimited) return YES;
                YMSABRFormat *fmt = [YMSABRHelpers parseFormatId:[inner subdataWithRange:NSMakeRange(ps6, pl6)]];
                if (fmt.itag != itag) return YES;
                BOOL take;
                if (exact) {
                    take = !result.found && [fmt.xtags isEqualToData:wantXtags];
                } else {
                    // Keep the first match, but upgrade to an entry that carries xtags.
                    take = !result.found || (result.xtags.length == 0 && fmt.xtags.length > 0);
                }
                if (take) {
                    result.itag = fmt.itag; result.lastModified = fmt.lastModified;
                    result.xtags = fmt.xtags; result.found = YES;
                }
                return YES;
            }];
            return YES;
        }];
        return NO; // only the first #5
    }];
    return result;
}

// Encode FormatId { #1 itag, #2 lastModified, #3 xtags }. xtags is always
// emitted (empty if none) — matches YTKACE / the real client.
+ (NSData *)encodeFormatId:(YMSABRFormat *)fmt {
    NSMutableData *d = [NSMutableData data];
    [YMSABRHelpers appendVarintField:d field:kSABRFmtItag value:fmt.itag];
    [YMSABRHelpers appendVarintField:d field:kSABRFmtLastMod value:fmt.lastModified];
    [YMSABRHelpers appendBytesField:d field:kSABRFmtXtags bytes:fmt.xtags ?: [NSData data]];
    return d;
}

// Encode a BufferedRange with the REAL extent just received: segments
// [startSeg..endSeg] over [startMs, startMs+durationMs). Overstating it makes the
// server think the track is fully buffered and stop sending its remaining segments.
+ (NSData *)encodeBufferedRange:(YMSABRFormat *)fmt startSeg:(uint64_t)startSeg endSeg:(uint64_t)endSeg startMs:(uint64_t)startMs durationMs:(uint64_t)durationMs {
    NSMutableData *tr = [NSMutableData data];
    [YMSABRHelpers appendVarintField:tr field:kSABRTimeRangeStart value:startMs];
    [YMSABRHelpers appendVarintField:tr field:kSABRTimeRangeDur value:durationMs];
    [YMSABRHelpers appendVarintField:tr field:kSABRTimeRangeScale value:kSABRMsPerSecond];

    NSMutableData *br = [NSMutableData data];
    [YMSABRHelpers appendBytesField:br field:kSABRBufFormatId bytes:[YMSABRHelpers encodeFormatId:fmt]];
    [YMSABRHelpers appendVarintField:br field:kSABRBufStartMs value:startMs];
    [YMSABRHelpers appendVarintField:br field:kSABRBufDurationMs value:durationMs];
    [YMSABRHelpers appendVarintField:br field:kSABRBufStartSeg value:startSeg];
    [YMSABRHelpers appendVarintField:br field:kSABRBufEndSeg value:endSeg];
    [YMSABRHelpers appendBytesField:br field:kSABRBufTimeRange bytes:tr];
    return br;
}

// Convert a TimeRange tick count to milliseconds (rounded).
+ (uint64_t)ticksToMs:(uint64_t)ticks timescale:(uint64_t)timescale {
    if (timescale == 0) return 0;
    return (uint64_t)(((double)ticks / (double)timescale) * (double)kSABRMsPerSecond + 0.5);
}

// Decode MEDIA_HEADER (UMP part 20): maps a headerId to a format + segment.
+ (YMSABRMediaHeader *)decodeMediaHeader:(const uint8_t *)payload size:(NSUInteger)size {
    NSData *msg = [NSData dataWithBytesNoCopy:(void *)payload length:size freeWhenDone:NO];
    YMSABRMediaHeader *h = [YMSABRMediaHeader new];
    const uint8_t *b = (const uint8_t *)msg.bytes; NSUInteger len = msg.length;
    [YMSABRHelpers iterateTopLevel:msg handler:^BOOL(uint64_t f, int w, NSUInteger fs, NSUInteger fe, NSUInteger ps, NSUInteger pl) {
        if (f == kSABRHdrHeaderId && w == kProtoWireVarint)         { uint64_t v=0; if ([YMSABRHelpers readProtoVarint:b length:len position:ps out:&v]) h.headerId = v; }
        else if (f == kSABRHdrItag && w == kProtoWireVarint)        { uint64_t v=0; if ([YMSABRHelpers readProtoVarint:b length:len position:ps out:&v]) h.itag = v; }
        else if (f == kSABRHdrIsInit && w == kProtoWireVarint)      { uint64_t v=0; if ([YMSABRHelpers readProtoVarint:b length:len position:ps out:&v]) h.isInit = (v != 0); }
        else if (f == kSABRHdrSequence && w == kProtoWireVarint)    { uint64_t v=0; if ([YMSABRHelpers readProtoVarint:b length:len position:ps out:&v]) h.sequence = v; }
        else if (f == kSABRHdrStartMs && w == kProtoWireVarint)     { uint64_t v=0; if ([YMSABRHelpers readProtoVarint:b length:len position:ps out:&v]) h.startMs = v; }
        else if (f == kSABRHdrDurationMs && w == kProtoWireVarint)  { uint64_t v=0; if ([YMSABRHelpers readProtoVarint:b length:len position:ps out:&v]) h.durationMs = v; }
        else if (f == kSABRHdrContentLength && w == kProtoWireVarint){ uint64_t v=0; if ([YMSABRHelpers readProtoVarint:b length:len position:ps out:&v]) h.contentLength = v; }
        else if (f == kSABRHdrFormatId && w == kProtoWireLengthDelimited && h.itag == 0) { // fallback itag from nested FormatId
            YMSABRFormat *fmt = [YMSABRHelpers parseFormatId:[msg subdataWithRange:NSMakeRange(ps, pl)]];
            if (fmt.itag) h.itag = fmt.itag;
        }
        else if (f == kSABRHdrTimeRange && w == kProtoWireLengthDelimited) { // TimeRange — the start/duration source on 21.29
            NSData *tr = [msg subdataWithRange:NSMakeRange(ps, pl)];
            uint64_t startTicks = 0, durTicks = 0, timescale = 0;
            [YMSABRHelpers readVarintField:tr field:kSABRTRStartTicks out:&startTicks];
            [YMSABRHelpers readVarintField:tr field:kSABRTRDurationTicks out:&durTicks];
            [YMSABRHelpers readVarintField:tr field:kSABRTRTimescale out:&timescale];
            if (timescale > 0) {
                if (h.durationMs == 0 && durTicks) h.durationMs = [YMSABRHelpers ticksToMs:durTicks timescale:timescale];
                if (h.startMs == 0 && startTicks)  h.startMs   = [YMSABRHelpers ticksToMs:startTicks timescale:timescale];
            }
        }
        return YES;
    }];
    return h;
}

// FORMAT_INITIALIZATION_METADATA (part 42): the authoritative end-of-track marker.
+ (void)decodeFormatInit:(const uint8_t *)payload size:(NSUInteger)size itag:(uint64_t *)itag endSeg:(uint64_t *)endSeg endTimeMs:(uint64_t *)endTimeMs {
    NSData *msg = [NSData dataWithBytesNoCopy:(void *)payload length:size freeWhenDone:NO];
    const uint8_t *b = (const uint8_t *)msg.bytes; NSUInteger len = msg.length;
    __block uint64_t it = 0;
    [YMSABRHelpers iterateTopLevel:msg handler:^BOOL(uint64_t f, int w, NSUInteger fs, NSUInteger fe, NSUInteger ps, NSUInteger pl) {
        if (f == kSABRInitFormatId && w == kProtoWireLengthDelimited)          { YMSABRFormat *fmt = [YMSABRHelpers parseFormatId:[msg subdataWithRange:NSMakeRange(ps, pl)]]; if (fmt.itag) it = fmt.itag; }
        else if (f == kSABRInitEndSegment && w == kProtoWireVarint)   { uint64_t v=0; if ([YMSABRHelpers readProtoVarint:b length:len position:ps out:&v] && endSeg) *endSeg = v; }
        else if (f == kSABRInitEndTimeMs && w == kProtoWireVarint)    { uint64_t v=0; if ([YMSABRHelpers readProtoVarint:b length:len position:ps out:&v] && endTimeMs) *endTimeMs = v; }
        return YES;
    }];
    if (itag) *itag = it;
}

// The URL's expire= query value (0 when absent).
+ (NSTimeInterval)expireFromURL:(NSURL *)url {
    for (NSURLQueryItem *item in [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO].queryItems)
        if ([item.name isEqualToString:@"expire"]) return item.value.doubleValue;
    return 0;
}

#pragma mark - Request builder

// Build one request body targeting `videoFmt` + `audioFmt`:
//   #16/#17 = preferred audio/video FormatId (the download targets, every request)
//   #2 = "initialized" echo list · #3 = buffered ranges we hold (empty = from start)
//   #1.#28 + #4 = player_time_ms (advances the stream)
//   #1 / #5 / #19 kept byte-for-byte (auth/session/config stay intact)
// `bufferedRanges` / `selectedFormats` are pre-encoded submessages (nil/empty on
// the first request).
+ (NSData *)buildRequestBody:(NSData *)orig videoFmt:(YMSABRFormat *)videoFmt audioFmt:(YMSABRFormat *)audioFmt
               playerTimeMs:(uint64_t)playerTimeMs bufferedRanges:(NSArray<NSData *> *)bufferedRanges
             selectedFormats:(NSArray<NSData *> *)selectedFormats {
    const uint8_t *b = (const uint8_t *)orig.bytes;
    NSMutableData *out = [NSMutableData data];
    BOOL parsed = [YMSABRHelpers iterateTopLevel:orig handler:^BOOL(uint64_t field, int wire, NSUInteger fs, NSUInteger fe, NSUInteger ps, NSUInteger pl) {
        // Drop the fields we rebuild; copy everything else verbatim.
        if (field == kSABRReqSelectedFormats || field == kSABRReqBufferedRanges ||
            field == kSABRReqPreferredAudio || field == kSABRReqPreferredVideo ||
            field == kSABRReqPlayerTimeMs) return YES;
        if (field == kSABRReqClientAbrState && wire == 2) {
            // Override player_time_ms (#28) inside the ClientAbrState, keep the rest.
            NSData *state = [YMSABRHelpers setVarintField:[orig subdataWithRange:NSMakeRange(ps, pl)] field:kSABRAbrStatePlayerTimeMs value:playerTimeMs];
            [YMSABRHelpers appendBytesField:out field:kSABRReqClientAbrState bytes:state];
            return YES;
        }
        [out appendBytes:b + fs length:fe - fs];
        return YES;
    }];
    if (!parsed) return nil;

    [YMSABRHelpers appendVarintField:out field:kSABRReqPlayerTimeMs value:playerTimeMs];
    if (audioFmt) [YMSABRHelpers appendBytesField:out field:kSABRReqPreferredAudio bytes:[YMSABRHelpers encodeFormatId:audioFmt]];
    if (videoFmt) [YMSABRHelpers appendBytesField:out field:kSABRReqPreferredVideo bytes:[YMSABRHelpers encodeFormatId:videoFmt]];
    for (NSData *sel in selectedFormats) [YMSABRHelpers appendBytesField:out field:kSABRReqSelectedFormats bytes:sel];
    for (NSData *br in bufferedRanges)    [YMSABRHelpers appendBytesField:out field:kSABRReqBufferedRanges bytes:br];
    return out;
}

#pragma mark - Download engine (permanent)

// One network round-trip: POST `body` to the captured signed URL, return the raw
// UMP response. Called on the serial queue; the completion must hop back before
// touching shared state.
+ (void)postOnce:(NSURL *)url body:(NSData *)body headers:(NSDictionary *)headers completion:(void (^)(NSData *data, NSHTTPURLResponse *http, NSError *err))completion {
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    req.HTTPBody = body;
    [headers enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSString *v, BOOL *stop) {
        if ([k caseInsensitiveCompare:@"Content-Encoding"] == NSOrderedSame) return; // no Brotli
        if ([k caseInsensitiveCompare:@"Content-Length"] == NSOrderedSame) return;   // session sets it
        [req setValue:v forHTTPHeaderField:k];
    }];
    if (![req valueForHTTPHeaderField:@"Content-Type"]) [req setValue:@"application/x-protobuf" forHTTPHeaderField:@"Content-Type"];
    NSURLSession *s = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration ephemeralSessionConfiguration]];
    [[s dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        completion(data, [resp isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)resp : nil, err);
    }] resume];
}

// Parse one UMP response, routing media to its track by itag. Writes init (once)
// + media segments, updates lastSequence / duration / per-round window and
// FORMAT_INIT markers, and reports redirect/reload via out-params.
+ (void)ingestResponse:(NSData *)data tracks:(NSDictionary<NSNumber *, YMSABRTrack *> *)tracks
           redirectURL:(NSString **)redirectURL reload:(BOOL *)reload session:(YMSABRSessionState *)ss {
    NSMutableDictionary<NSNumber *, YMSABRMediaHeader *> *headers = [NSMutableDictionary dictionary]; // headerId -> header
    __block NSString *redirect = nil; __block BOOL sawReload = NO;

    // Reset each track's per-round window; it's rebuilt from the real headers below.
    for (NSNumber *itag in tracks) {
        YMSABRTrack *t = tracks[itag];
        t.roundHasMedia = NO; t.roundStartMs = 0; t.roundDurationMs = 0; t.roundFirstSeq = 0; t.roundLastSeq = 0;
    }

    [YMSABRHelpers parseUMP:data handler:^(uint64_t type, const uint8_t *payload, NSUInteger size) {
        if (type == SABRPartMediaHeader) {
            YMSABRMediaHeader *h = [YMSABRHelpers decodeMediaHeader:payload size:size];
            headers[@(h.headerId)] = h;
        } else if (type == SABRPartMedia && size > 0) {
            uint64_t hid = 0; NSUInteger hc = [YMSABRHelpers readUMPVarint:payload length:size position:0 out:&hid];
            if (hc == 0 || hc > size) return;
            YMSABRMediaHeader *h = headers[@(hid)];
            YMSABRTrack *track = h ? tracks[@(h.itag)] : nil;
            if (!track) return; // media for a format we're not collecting
            if (h.isInit) {
                if (!track.initWritten) { [track.handle writeData:[NSData dataWithBytes:payload + hc length:size - hc]]; track.bytesWritten += size - hc; track.initWritten = YES; }
                return;
            }
            // A segment can arrive more than once (different headerId); only
            // sequences past the high-water mark are new — duplicates corrupt the stream.
            if (h.sequence <= track.lastSequence) return;
            [track.handle writeData:[NSData dataWithBytes:payload + hc length:size - hc]];
            track.bytesWritten += size - hc;
        } else if (type == SABRPartMediaEnd && size > 0) {
            YMSABRMediaHeader *h = headers[@(payload[0])];
            YMSABRTrack *track = h ? tracks[@(h.itag)] : nil;
            if (!track || h.isInit) return;
            if (h.sequence <= track.lastSequence) return; // duplicate segment: don't double-count
            if (!track.firstSequence) { track.firstSequence = h.sequence; track.firstStartMs = h.startMs; }
            track.lastSequence = h.sequence;
            track.downloadedMs += h.durationMs;           // real total from #15-derived duration
            // Extend this round's contiguous window with the segment's real timing.
            if (!track.roundHasMedia) { track.roundHasMedia = YES; track.roundStartMs = h.startMs; track.roundFirstSeq = h.sequence; }
            track.roundDurationMs += h.durationMs;
            track.roundLastSeq = h.sequence;
        } else if (type == SABRPartFormatInit) {
            uint64_t it = 0, endSeg = 0, endMs = 0;
            [YMSABRHelpers decodeFormatInit:payload size:size itag:&it endSeg:&endSeg endTimeMs:&endMs];
            YMSABRTrack *track = tracks[@(it)];
            if (track) { if (endSeg) track.endSegment = endSeg; if (endMs) track.endTimeMs = endMs; }
        } else if (type == SABRPartRedirect) {
            NSData *msg = [NSData dataWithBytesNoCopy:(void *)payload length:size freeWhenDone:NO];
            [YMSABRHelpers iterateTopLevel:msg handler:^BOOL(uint64_t f, int w, NSUInteger fs, NSUInteger fe, NSUInteger ps, NSUInteger pl) {
                // -copy detaches from the transient no-copy payload.
                if (f == kSABRRedirectURL && w == kProtoWireLengthDelimited) redirect = [[[NSString alloc] initWithData:[msg subdataWithRange:NSMakeRange(ps, pl)] encoding:NSUTF8StringEncoding] copy];
                return NO;
            }];
        } else if (type == SABRPartReload) {
            sawReload = YES;
            if (ss) {
                NSData *msg = [NSData dataWithBytes:payload length:size];
                NSData *tok = SABRBytesField(SABRBytesField(msg, 1) ?: [NSData data], 1);
                if (tok.length) ss.reloadToken = [[NSString alloc] initWithData:tok encoding:NSUTF8StringEncoding];
            }
        } else if (ss && type == SABRPartNextRequestPolicy) {
            NSData *msg = [NSData dataWithBytes:payload length:size];
            uint64_t backoff = 0; if ([YMSABRHelpers readVarintField:msg field:4 out:&backoff]) ss.backoffMs = backoff;
            NSData *cookie = SABRBytesField(msg, 7); if (cookie.length) ss.cookie = cookie;
        } else if (ss && type == SABRPartContextUpdate) {
            NSData *msg = [NSData dataWithBytes:payload length:size];
            uint64_t ctype = 0, send = 0, policy = 0;
            [YMSABRHelpers readVarintField:msg field:1 out:&ctype]; [YMSABRHelpers readVarintField:msg field:4 out:&send]; [YMSABRHelpers readVarintField:msg field:5 out:&policy];
            NSData *value = SABRBytesField(msg, 3);
            if (ctype && value.length && send && (policy != 2 || !ss.contexts[@(ctype)])) ss.contexts[@(ctype)] = value;
        } else if (ss && type == SABRPartStreamProtection) {
            NSData *msg = [NSData dataWithBytes:payload length:size];
            uint64_t st = 0; if ([YMSABRHelpers readVarintField:msg field:1 out:&st]) ss.protectionStatus = st;
        }
    }];

    if (redirectURL) *redirectURL = redirect;
    if (reload) *reload = sawReload;
}

// A track is complete at its last segment (authoritative), or when its real
// downloaded duration reaches the total (backup check).
+ (BOOL)trackDone:(YMSABRTrack *)track {
    if (!track.endSegment && !track.endTimeMs) return NO;        // no markers yet → not done
    if (track.endSegment && track.lastSequence >= track.endSegment) return YES;
    if (track.endTimeMs && track.downloadedMs + 500 >= track.endTimeMs) return YES;
    return NO;
}

// Fresh unique temp file per track (per download, so stale or concurrent runs
// can't collide).
+ (YMSABRTrack *)makeTrack:(YMSABRFormat *)fmt extension:(NSString *)ext {
    NSString *name = [NSString stringWithFormat:@"sabr_%llu_%@.%@", fmt.itag, [NSUUID UUID].UUIDString, ext];
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
    YMSABRTrack *t = [YMSABRTrack new];
    t.format = fmt;
    t.fileURL = [NSURL fileURLWithPath:path];
    t.handle = [NSFileHandle fileHandleForWritingAtPath:path];
    return t;
}

// Orchestrator: download the video + audio itags together (both requested every
// round; media routed per itag) until each track reaches its last segment, then
// `completion(videoURL, audioURL, err)` on the main queue. videoItag == 0 =
// audio-only (videoURL is nil).
+ (void)runDownloadVideoItag:(uint64_t)videoItag audioItag:(uint64_t)audioItag audioXtags:(NSData *)audioXtags
                    progress:(void (^)(float fraction, unsigned long long bytesDownloaded, BOOL isAudio))progress
                  completion:(void (^)(NSURL *videoURL, NSURL *audioURL, NSString *err))completion {
    dispatch_async([YMSABRHelpers queue], ^{
        void (^failEarly)(NSString *) = ^(NSString *msg) { dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, nil, msg); }); };
        id freshResponse = gSABRFreshResponse;
        BOOL pinned = freshResponse != nil && gSABRPinnedBody.length > 0;
        NSData *capBody = pinned ? gSABRPinnedBody : gCapPlainBody;
        NSDictionary *capHeaders = pinned ? gSABRPinnedHeaders : [gCapHeaders copy];
        BOOL fresh = freshResponse != nil;
        BOOL wantVideo = videoItag != 0;
        __block NSString *sessionURL = nil;   // fresh: serverAbrStreamingURL, may be replaced by redirect/reload
        __block NSData *sessionConfig = nil;  // fresh: ustreamer config
        NSString *videoID = nil;
        uint64_t resolution = 0;
        YMSABRFormat *videoFmt = nil, *audioFmt = nil;

        if (fresh) {
            if (!SABRExtractSession(freshResponse, &sessionURL, &sessionConfig)) { failEarly(@"YouTube did not provide SABR session data."); return; }
            videoID = SABRVideoIDFromResponse(freshResponse);
            YTIFormatStream *vs = wantVideo ? SABRFindStream(freshResponse, videoItag, nil) : nil;
            YTIFormatStream *as = SABRFindStream(freshResponse, audioItag, audioXtags);
            videoFmt = wantVideo ? SABRFormatFromStream(vs) : nil;
            audioFmt = SABRFormatFromStream(as);
            resolution = vs ? (uint64_t)MAX([vs height], 0) : 0;
        } else {
            if (!gCapURL || !capBody.length) { failEarly(@"No request captured yet — play the video for a few seconds first."); return; }
            videoFmt = wantVideo ? [YMSABRHelpers resolveFormat:capBody itag:videoItag wantXtags:nil] : nil;
            audioFmt = [YMSABRHelpers resolveFormat:capBody itag:audioItag wantXtags:audioXtags];
        }
        // A requested soundtrack missing from the available-format list must fail,
        // not fall back (fallback would serve the wrong language).
        if (!audioFmt.found && audioXtags.length > 0) { failEarly(@"That soundtrack isn't available to download for this video."); return; }
        if ((wantVideo && !videoFmt.found) || !audioFmt.found) {
            NSString *videoState = !wantVideo ? @"n/a" : (videoFmt.found ? @"ok" : @"missing");
            failEarly([NSString stringWithFormat:@"format not available (video %llu:%@, audio %llu:%@)", videoItag, videoState, audioItag, audioFmt.found?@"ok":@"missing"]);
            return;
        }
        __block NSData *poToken = fresh ? [YMPlayerResolver poTokenForVideoID:videoID] : nil;
        YMSABRSessionState *ss = fresh ? [YMSABRSessionState new] : nil;

        gSABRCancel = NO;
        YMSABRTrack *videoTrack = wantVideo ? [YMSABRHelpers makeTrack:videoFmt extension:@"mp4"] : nil;
        YMSABRTrack *audioTrack = [YMSABRHelpers makeTrack:audioFmt extension:@"m4a"];
        // Ordered [video?, audio]; `mainTrack` (video when present, else audio)
        // drives player_time, matching the reference.
        NSArray<YMSABRTrack *> *trackList = wantVideo ? @[videoTrack, audioTrack] : @[audioTrack];
        YMSABRTrack *mainTrack = trackList.firstObject;
        NSMutableDictionary<NSNumber *, YMSABRTrack *> *tracks = [NSMutableDictionary dictionary];
        for (YMSABRTrack *t in trackList) tracks[@(t.format.itag)] = t;

        __block int requestCount = 0;
        __block int emptyRounds = 0;   // consecutive rounds with no new media (SABR may send policy-only rounds)
        __block int reloadCount = 0;
        __block BOOL finished = NO;
        __block int resyncs = 0;        // consecutive new sessions without progress
        __block int rnBase = 0;         // requestCount when the current session started
        __block BOOL reportHeld = NO;   // next request reports everything already written
        __block NSURL *currentURL = fresh ? nil : gCapURL;
        // Recursive loop across async callbacks: hold the block in a heap box and
        // recurse through it (a direct capture is an ARC retain-cycle error);
        // `finish` empties the box to free the loop.
        NSMutableArray *box = [NSMutableArray arrayWithObject:[NSNull null]];
        void (^callRound)(void) = ^{ id r = box.firstObject; if (r && r != [NSNull null]) ((void (^)(void))r)(); };
        void (^finish)(NSString *) = ^(NSString *err) {
            if (finished) return;   // idempotent: never double-close / double-complete
            finished = YES;
            [box removeAllObjects];
            for (YMSABRTrack *t in trackList) [t.handle closeFile];
            if (err) { // failed/cancelled → don't leave partial files behind
                for (YMSABRTrack *t in trackList) [[NSFileManager defaultManager] removeItemAtURL:t.fileURL error:nil];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (err) completion(nil, nil, err);
                else completion(videoTrack.fileURL, audioTrack.fileURL, nil);
            });
        };
        BOOL (^resync)(NSString *) = ^BOOL(NSString *why) {
            if (!fresh || !videoID.length || resyncs >= kSABRMaxResyncs) return NO;
            resyncs++;
            [YMPlayerResolver appendLog:[NSString stringWithFormat:@"SABR resync %d for %@ at video seq %llu / audio seq %llu: %@", resyncs, videoID, videoTrack.lastSequence, audioTrack.lastSequence, why]];
            [YMPlayerResolver refreshVideoID:videoID completion:^(id response, NSError *rerr) {
                dispatch_async([YMSABRHelpers queue], ^{
                    if (finished) return;
                    NSString *u = nil; NSData *c = nil;
                    if (!response || !SABRExtractSession(response, &u, &c)) { finish(why); return; }
                    sessionURL = u; sessionConfig = c;
                    ss.cookie = nil; [ss.contexts removeAllObjects];
                    ss.protectionStatus = 0; ss.backoffMs = 0;
                    poToken = [YMPlayerResolver poTokenForVideoID:videoID] ?: poToken;
                    rnBase = requestCount; emptyRounds = 0; reportHeld = YES;
                    callRound();
                });
            }];
            return YES;
        };
        void (^fail)(NSString *) = ^(NSString *why) { if (!resync(why)) finish(why); };
        void (^round)(void) = ^{
            if (gSABRCancel) { finish(@"cancelled"); return; }
            if (requestCount++ >= kSABRMaxRequests) { finish(@"exceeded request cap"); return; }

            // Each requested format stays in #16/#17 for the whole session; a
            // finished track is silenced by its buffered_ranges. Removing it from
            // #16/#17 would change the request shape and stall the other track.
            NSMutableArray<NSData *> *buffered = [NSMutableArray array];
            NSMutableArray<NSData *> *selected = [NSMutableArray array];
            // Report each track's REAL per-round delta window (start/duration/
            // first/last from #15 time_range), never player_time — overstating
            // buffered extent makes the server stop sending tail segments.
            for (YMSABRTrack *t in trackList) {
                if (reportHeld) {
                    if (t.firstSequence) [buffered addObject:[YMSABRHelpers encodeBufferedRange:t.format startSeg:t.firstSequence endSeg:t.lastSequence startMs:t.firstStartMs durationMs:t.downloadedMs]];
                } else if (t.roundHasMedia) {
                    [buffered addObject:[YMSABRHelpers encodeBufferedRange:t.format startSeg:t.roundFirstSeq endSeg:t.roundLastSeq startMs:t.roundStartMs durationMs:t.roundDurationMs]];
                }
                if (t.lastSequence > 0) [selected addObject:[YMSABRHelpers encodeFormatId:t.format]];
            }
            reportHeld = NO;
            // Drive player_time off the main track's real downloaded total (video
            // when present, else audio) so the playhead pulls segments forward.
            uint64_t driveTime = mainTrack.downloadedMs;
            NSData *body; NSURL *url;
            if (fresh) {
                body = pinned
                    ? SABRBuildNativeBody(capBody, sessionConfig, ss.cookie, videoFmt, audioFmt, resolution, driveTime, buffered, selected, ss.contexts)
                    : nil;
                if (!body) body = SABRBuildFreshBody(sessionConfig, poToken, ss.cookie, videoFmt, audioFmt, resolution, driveTime, buffered, selected, ss.contexts);
                url = SABRURLWithRequestNumber(sessionURL, requestCount - 1 - rnBase);
            } else {
                body = [YMSABRHelpers buildRequestBody:capBody videoFmt:videoFmt audioFmt:audioFmt playerTimeMs:driveTime bufferedRanges:buffered selectedFormats:selected];
                url = currentURL;
            }
            if (!body || !url) { finish(@"failed to build request body"); return; }

            [YMSABRHelpers postOnce:url body:body headers:capHeaders completion:^(NSData *data, NSHTTPURLResponse *http, NSError *err) {
                dispatch_async([YMSABRHelpers queue], ^{
                    if (err || !http) { fail([NSString stringWithFormat:@"network error: %@", err.localizedDescription ?: @"no response"]); return; }
                    if (http.statusCode != 200 || !data.length) { fail([NSString stringWithFormat:@"HTTP %ld (%lu bytes)", (long)http.statusCode, (unsigned long)data.length]); return; }

                    NSMutableDictionary<NSNumber *, NSNumber *> *beforeSeq = [NSMutableDictionary dictionary];
                    for (YMSABRTrack *t in trackList) beforeSeq[@(t.format.itag)] = @(t.lastSequence);
                    NSString *redirect = nil; BOOL reload = NO;
                    [YMSABRHelpers ingestResponse:data tracks:tracks redirectURL:&redirect reload:&reload session:ss];

                    if (reload) {
                        if (!fresh) { finish(@"Session expired! Replay the video and try again"); return; }
                        if (reloadCount >= 3 || !ss.reloadToken.length) { fail(@"Session expired and could not be refreshed!"); return; }
                        reloadCount++;
                        NSString *reloadToken = ss.reloadToken; ss.reloadToken = nil;
                        [YMPlayerResolver reloadVideoID:videoID token:reloadToken completion:^(id response, NSError *rerr) {
                            dispatch_async([YMSABRHelpers queue], ^{
                                NSString *u = nil; NSData *c = nil;
                                if (finished) return;
                                if (!response || !SABRExtractSession(response, &u, &c)) { fail(@"Session expired and could not be refreshed!"); return; }
                                sessionURL = u; sessionConfig = c;
                                ss.cookie = nil; [ss.contexts removeAllObjects];
                                callRound();
                            });
                        }];
                        return;
                    }
                    if (redirect.length) { if (fresh) sessionURL = redirect; else currentURL = [NSURL URLWithString:redirect] ?: currentURL; }

                    BOOL allDone = YES; float fracSum = 0; unsigned long long bytesTotal = 0;
                    for (YMSABRTrack *t in trackList) {
                        t.complete = [YMSABRHelpers trackDone:t];
                        if (!t.complete) allDone = NO;
                        fracSum += t.endTimeMs ? MIN(1.0f, (float)t.downloadedMs / (float)t.endTimeMs) : 0;
                        bytesTotal += t.bytesWritten;
                    }
                    BOOL isAudio = (videoTrack != nil && videoTrack.complete && audioTrack != nil && !audioTrack.complete);
                    if (progress) progress(fracSum / (float)trackList.count, bytesTotal, isAudio);
                    if (allDone) { finish(nil); return; }
                    // Stall guard keys off SEQUENCE advancement, not bytes (a
                    // stuck request still returns the same segment). Bail after
                    // several consecutive rounds where no incomplete track advanced.
                    BOOL advanced = NO;
                    for (YMSABRTrack *t in trackList)
                        if (!t.complete && t.lastSequence > beforeSeq[@(t.format.itag)].unsignedLongLongValue) advanced = YES;
                    // Attestation / stream-protection failure: status 3+ is always fatal,
                    // status 2 with nothing delivered means the stream is being withheld.
                    if (fresh && (ss.protectionStatus >= 3 || (ss.protectionStatus == 2 && !advanced))) {
                        fail([NSString stringWithFormat:@"YouTube requires stream authorization (status %llu)", ss.protectionStatus]); return;
                    }
                    emptyRounds = advanced ? 0 : (emptyRounds + 1);
                    if (advanced) resyncs = 0;
                    if (emptyRounds >= kSABRMaxEmptyRounds) { fail(@"No forward progress for several rounds! (If on A17 or below, get YTUHD and enable VP9/AV1!)"); return; }
                    uint64_t backoff = fresh ? MIN(ss.backoffMs, 5000) : 0;
                    if (backoff) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(backoff * NSEC_PER_MSEC)), [YMSABRHelpers queue], ^{ callRound(); });
                    else callRound();
                });
            }];
        };
        box[0] = round;
        round();
    });
}

// Soundtrack identity on the wire: the picked format's xtags (same value the
// FormatId carries); nil = no preference. The accessor's type isn't contractual
// (private protobuf class), so both NSData and NSString are read.
+ (NSData *)xtagsForStream:(YTIFormatStream *)stream {
    if (!stream) return nil;
    NSData *xtags = nil;
    @try {
        if ([stream respondsToSelector:@selector(xtags)]) {
            id value = [stream xtags];
            if ([value isKindOfClass:NSString.class])    xtags = [value dataUsingEncoding:NSUTF8StringEncoding];
            else if ([value isKindOfClass:NSData.class]) xtags = value;
        }
    } @catch (id ex) {}
    return xtags.length ? xtags : nil;
}
@end

#pragma mark - Public entry (called from Download.x)

// Download the chosen mp4 video + m4a audio itags on-device via SABR into two
// elementary files for the caller's muxer. `progress` (0..1) and `completion` are
// always delivered on the main queue.
@implementation YMSABR
+ (void)downloadVideoItag:(int)videoItag audioItag:(int)audioItag audioStream:(YTIFormatStream *)audioStream
                 progress:(void (^)(float fraction, unsigned long long bytesDownloaded, BOOL isAudio))progress
               completion:(void (^)(NSURL *videoURL, NSURL *audioURL, NSString *err))completion {
    [YMSABRHelpers runDownloadVideoItag:(uint64_t)videoItag audioItag:(uint64_t)audioItag audioXtags:[YMSABRHelpers xtagsForStream:audioStream]
        progress:^(float f, unsigned long long bytes, BOOL isAudio) { if (progress) dispatch_async(dispatch_get_main_queue(), ^{ progress(f, bytes, isAudio); }); }
        completion:completion]; // completion is already delivered on the main queue
}
+ (void)downloadAudioItag:(int)audioItag audioStream:(YTIFormatStream *)audioStream
                 progress:(void (^)(float fraction, unsigned long long bytesDownloaded))progress
               completion:(void (^)(NSURL *audioURL, NSString *err))completion {
    // videoItag 0 → audio-only; deliver just the audio file.
    [YMSABRHelpers runDownloadVideoItag:0 audioItag:(uint64_t)audioItag audioXtags:[YMSABRHelpers xtagsForStream:audioStream]
        progress:^(float f, unsigned long long bytes, BOOL isAudio) { if (progress) dispatch_async(dispatch_get_main_queue(), ^{ progress(f, bytes); }); }
        completion:^(NSURL *videoURL, NSURL *audioURL, NSString *err) { completion(audioURL, err); }];
}
+ (void)useResolvedResponse:(id)response capture:(NSDictionary *)capture {
    NSData *body = capture[@"body"];
    NSDictionary *headers = capture[@"headers"];
    dispatch_async([YMSABRHelpers queue], ^{
        gSABRFreshResponse = response;
        gSABRPinnedBody = response ? body : nil;
        gSABRPinnedHeaders = response ? headers : nil;
    });
}
+ (void)currentCapture:(void (^)(NSDictionary *capture))completion {
    dispatch_async([YMSABRHelpers queue], ^{
        NSDictionary *capture = (gCapPlainBody.length && gCapHeaders) ? @{@"body": gCapPlainBody, @"headers": [gCapHeaders copy]} : nil;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(capture); });
    });
}
+ (void)cancelCurrent {
    dispatch_async([YMSABRHelpers queue], ^{ gSABRCancel = YES; }); // loop aborts at its next round
}
@end

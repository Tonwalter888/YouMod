// Resolves a player response for any video ID, without the video playing.
//
// The app's player service is hooked at runtime (class_addMethod / method_setImplementation)
// so the saved original IMPs can be called directly. Every real playback request is kept as
// a template; a copy retargeted to the wanted videoId goes through the app's own
// YTPlayerService, which signs and sends it like a normal playback.

#import "Headers.h"
#import <objc/message.h>
#import <objc/runtime.h>

#pragma mark - Logging

// The device log doesn't reliably reach a debugger, so lines are also kept in memory
// (+recentLog) for the queue to show.
static NSMutableArray<NSString *> *gLogLines;

static void YMResolveLogf(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static void YMResolveLogf(NSString *format, ...) {
    va_list args; va_start(args, format);
    NSString *line = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"[YouMod] resolve: %@", line);
    static NSDateFormatter *formatter;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ formatter = [NSDateFormatter new]; formatter.dateFormat = @"HH:mm:ss.SSS"; gLogLines = [NSMutableArray array]; });
    @synchronized (gLogLines) {
        [gLogLines addObject:[NSString stringWithFormat:@"%@ %@", [formatter stringFromDate:NSDate.date], line]];
        if (gLogLines.count > 60) [gLogLines removeObjectAtIndex:0];
    }
}
#define YMResolveLog(fmt, ...) YMResolveLogf(fmt, ##__VA_ARGS__)

static NSError *YMResolveError(NSInteger code, NSString *message) {
    return [NSError errorWithDomain:@"YMPlayerResolve" code:code userInfo:@{NSLocalizedDescriptionKey: message}];
}

#pragma mark - Runtime hook installer

static BOOL YMInstallInstanceHook(NSString *className, NSString *selectorName, IMP replacement, IMP *originalStorage) {
    Class cls = NSClassFromString(className);
    if (cls == Nil) return NO;
    SEL selector = NSSelectorFromString(selectorName);
    Method method = class_getInstanceMethod(cls, selector);
    if (method == NULL) return NO;

    static NSMutableSet<NSString *> *installed;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ installed = [NSMutableSet set]; });
    NSString *key = [NSString stringWithFormat:@"%@|%@", className, selectorName];
    @synchronized (installed) {
        if ([installed containsObject:key]) return YES;
        IMP original = method_getImplementation(method);
        if (!class_addMethod(cls, selector, replacement, method_getTypeEncoding(method))) {
            Method direct = class_getInstanceMethod(cls, selector);
            if (direct == NULL) return NO;
            method_setImplementation(direct, replacement);
        }
        if (originalStorage) *originalStorage = original;
        [installed addObject:key];
        return YES;
    }
}

#pragma mark - KVC helpers (the request classes are private protobuf types)

static id YMGetValue(id object, NSArray<NSString *> *keys) {
    if (object == nil) return nil;
    for (NSString *key in keys) {
        SEL selector = NSSelectorFromString(key);
        if ([object respondsToSelector:selector]) {
            id value = ((id (*)(id, SEL))objc_msgSend)(object, selector);
            if (value != nil) return value;
        }
        @try {
            id value = [object valueForKey:key];
            if (value != nil) return value;
        } @catch (__unused NSException *exception) {}
    }
    return nil;
}

static BOOL YMSetValue(id object, NSString *key, id value) {
    if (object == nil || key.length == 0) return NO;
    if ([value isKindOfClass:NSNumber.class]) {   // scalar setters (int/BOOL) need unboxing, which KVC does
        @try { [object setValue:value forKey:key]; return YES; } @catch (__unused NSException *exception) { return NO; }
    }
    SEL setter = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:", [[key substringToIndex:1] uppercaseString], [key substringFromIndex:1]]);
    if ([object respondsToSelector:setter]) {
        ((void (*)(id, SEL, id))objc_msgSend)(object, setter, value);
        return YES;
    }
    @try {
        [object setValue:value forKey:key];
        return YES;
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

static id YMCopyObject(id object) {
    return [object respondsToSelector:@selector(copyWithZone:)] ? [object copy] : object;
}

static NSString *YMRequestVideoID(id request) {
    id value = YMGetValue(request, @[@"videoId", @"videoID", @"videoIdString"]);
    return [value isKindOfClass:NSString.class] ? value : nil;
}

static NSString *YMResponseVideoID(id response) {
    if (response == nil) return nil;
    id details = YMGetValue(response, @[@"videoDetails"]) ?: YMGetValue(YMGetValue(response, @[@"playerData"]), @[@"videoDetails"]);
    id value = YMGetValue(details != nil ? details : response, @[@"videoId", @"videoID", @"videoIdString"]);
    return [value isKindOfClass:NSString.class] ? value : nil;
}

#pragma mark - Captured state

static IMP gOrigMakePlayerRequest, gOrigMakePlaybackRequest, gOrigMakePrefetch;
static IMP gOrigFactory, gOrigFactoryExtended, gOrigServiceInit;
static IMP gOrigContextShort, gOrigContextMedium, gOrigContextLong;
static IMP gOrigMint, gOrigSetPoToken;

// All guarded by @synchronized (YMPlayerResolver.class).
static id gLastService;
static id gLastRequest;
static id gLastPlaybackRequest;
static id gLastContext;                                   // InnerTube context, to build a request when none was seen
static NSMutableDictionary<NSString *, NSArray *> *gRequests;   // videoID -> @[service, request]
static NSMutableSet<NSString *> *gResolvingIDs;           // our own requests; never taken as templates
static NSMutableDictionary<NSString *, id> *gResponses;   // videoID -> player response
static NSMutableArray<NSString *> *gResponseOrder;
static NSMutableDictionary<NSString *, NSData *> *gPoTokens;
static NSData *gLastPoToken;
static NSMutableDictionary<NSString *, NSNumber *> *gCaptureCounts;

static void YMEnsureState(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gRequests = [NSMutableDictionary dictionary];
        gResolvingIDs = [NSMutableSet set];
        gResponses = [NSMutableDictionary dictionary];
        gResponseOrder = [NSMutableArray array];
        gPoTokens = [NSMutableDictionary dictionary];
        gCaptureCounts = [NSMutableDictionary dictionary];
    });
}

#pragma mark - Template persistence (survives relaunch)

static NSURL *YMRequestSeedURL(void) {
    NSURL *dir = [[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject URLByAppendingPathComponent:@"YouMod" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return [dir URLByAppendingPathComponent:@"player-request.pb"];
}

static void YMPersistRequest(id request) {
    static NSTimeInterval lastWrite;
    NSTimeInterval now = NSDate.date.timeIntervalSinceReferenceDate;
    if (now - lastWrite < 60.0 || ![request respondsToSelector:NSSelectorFromString(@"data")]) return;
    NSData *encoded = ((id (*)(id, SEL))objc_msgSend)(request, NSSelectorFromString(@"data"));
    if (![encoded isKindOfClass:NSData.class] || encoded.length == 0) return;
    lastWrite = now;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{ [encoded writeToURL:YMRequestSeedURL() atomically:YES]; });
}

static void YMRestoreRequest(void) {
    YMEnsureState();
    @synchronized (YMPlayerResolver.class) { if (gLastRequest != nil) return; }
    NSData *encoded = [NSData dataWithContentsOfURL:YMRequestSeedURL()];
    Class cls = NSClassFromString(@"YTIPlayerRequest");
    SEL parse = NSSelectorFromString(@"parseFromData:error:");
    if (encoded.length == 0 || cls == Nil || ![cls respondsToSelector:parse]) return;
    NSError *error = nil;
    id restored = ((id (*)(id, SEL, id, NSError **))objc_msgSend)(cls, parse, encoded, &error);
    if (restored == nil) { YMResolveLog(@"restore failed %@", error.localizedDescription ?: @"unknown"); return; }
    @synchronized (YMPlayerResolver.class) { if (gLastRequest == nil) gLastRequest = restored; }
    YMResolveLog(@"restored player request bytes=%lu", (unsigned long)encoded.length);
}

#pragma mark - Capture

static BOOL YMIsResolving(NSString *videoID) {
    return videoID.length && [gResolvingIDs containsObject:videoID];
}

static void YMCount(NSString *source) {
    gCaptureCounts[source] = @(gCaptureCounts[source].integerValue + 1);
}

// A request reached the service: keep the service, and the request as the template.
static void YMCaptureService(id receiver, id request, NSString *source) {
    YMEnsureState();
    NSString *videoID = YMRequestVideoID(request);
    id copy = YMCopyObject(request);
    BOOL stored = NO;
    @synchronized (YMPlayerResolver.class) {
        YMCount(source);
        if (receiver) gLastService = receiver;
        if (!YMIsResolving(videoID)) {
            gLastRequest = copy;
            if (videoID.length && receiver) gRequests[videoID] = @[receiver, copy ?: request];
            stored = YES;
        }
    }
    if (stored) YMPersistRequest(copy ?: request);
    static NSUInteger logged;
    if (logged++ < 12) YMResolveLog(@"capture via %@ video=%@ service=%d class=%@", source, videoID ?: @"-", receiver != nil, NSStringFromClass([request class]));
}

// The factory sees the real YTIPlayerRequest for every playback.
static void YMCaptureFactory(id request) {
    YMEnsureState();
    NSString *videoID = YMRequestVideoID(request);
    BOOL ours;
    @synchronized (YMPlayerResolver.class) { ours = YMIsResolving(videoID); }
    if (ours) YMResolveLog(@"factory reached for our request video=%@", videoID);
    id copy = YMCopyObject(request);
    BOOL stored = NO;
    @synchronized (YMPlayerResolver.class) {
        YMCount(@"factory");
        if (!YMIsResolving(videoID)) {
            gLastRequest = copy;
            if (videoID.length && gLastService) gRequests[videoID] = @[gLastService, YMCopyObject(request)];
            stored = YES;
        }
    }
    if (stored) YMPersistRequest(copy);
}

static void YMCacheResponse(id response) {
    NSString *videoID = YMResponseVideoID(response);
    if (videoID.length == 0) return;
    @synchronized (YMPlayerResolver.class) {
        if (!gResponses[videoID]) [gResponseOrder addObject:videoID];
        gResponses[videoID] = response;
        while (gResponseOrder.count > 16) {
            [gResponses removeObjectForKey:gResponseOrder.firstObject];
            [gResponseOrder removeObjectAtIndex:0];
        }
    }
}

static void YMDropCachedResponse(NSString *videoID) {
    if (videoID.length == 0) return;
    YMEnsureState();
    @synchronized (YMPlayerResolver.class) { [gResponses removeObjectForKey:videoID]; [gResponseOrder removeObject:videoID]; }
}

#pragma mark - Hook bodies

static id YMObservedResponseBlock(id responseBlock) {
    if (responseBlock == nil) return nil;
    void (^original)(id, void *) = responseBlock;
    return [^(id playerResponse, void *cacheContext) {
        YMCacheResponse(playerResponse);
        original(playerResponse, cacheContext);
    } copy];
}

static void YMMakePlayerRequest(id receiver, SEL selector, id request, id responseBlock, id errorBlock) {
    YMCaptureService(receiver, request, @"makePlayerRequest");
    if (gOrigMakePlayerRequest)
        ((void (*)(id, SEL, id, id, id))gOrigMakePlayerRequest)(receiver, selector, request, YMObservedResponseBlock(responseBlock), errorBlock);
}

static id YMMakePlaybackRequest(id receiver, SEL selector, id request, id responseBlock, id errorBlock) {
    YMCaptureService(receiver, request, @"makePlaybackRequest");
    @synchronized (YMPlayerResolver.class) { gLastPlaybackRequest = YMCopyObject(request); }
    return gOrigMakePlaybackRequest
        ? ((id (*)(id, SEL, id, id, id))gOrigMakePlaybackRequest)(receiver, selector, request, YMObservedResponseBlock(responseBlock), errorBlock)
        : nil;
}

static void YMMakePrefetchPlayerRequest(id receiver, SEL selector, id request, id responseBlock, id errorBlock) {
    YMCaptureService(receiver, request, @"makePrefetch");
    if (gOrigMakePrefetch)
        ((void (*)(id, SEL, id, id, id))gOrigMakePrefetch)(receiver, selector, request, responseBlock, errorBlock);
}

static id YMFactoryRequest(id receiver, SEL selector, id request, id properties) {
    id result = gOrigFactory ? ((id (*)(id, SEL, id, id))gOrigFactory)(receiver, selector, request, properties) : nil;
    YMCaptureFactory(request);
    return result;
}

static id YMFactoryRequestExtended(id receiver, SEL selector, id request, id properties, BOOL relaxation, id cacheToken, BOOL skipCache) {
    id result = gOrigFactoryExtended
        ? ((id (*)(id, SEL, id, id, BOOL, id, BOOL))gOrigFactoryExtended)(receiver, selector, request, properties, relaxation, cacheToken, skipCache)
        : nil;
    YMCaptureFactory(request);
    return result;
}

static id YMPlayerServiceInit(id receiver, SEL selector) {
    id result = gOrigServiceInit ? ((id (*)(id, SEL))gOrigServiceInit)(receiver, selector) : receiver;
    if (result) {
        YMEnsureState();
        @synchronized (YMPlayerResolver.class) { if (gLastService == nil) gLastService = result; }
    }
    return result;
}

static void YMCaptureContext(id context) {
    if (context == nil) return;
    @synchronized (YMPlayerResolver.class) { gLastContext = context; }
}

static id YMContextShort(id receiver, SEL selector, id pageID, BOOL incognito, int criticality, id tracking, BOOL sendIdentifier, long long serviceType) {
    id result = gOrigContextShort
        ? ((id (*)(id, SEL, id, BOOL, int, id, BOOL, long long))gOrigContextShort)(receiver, selector, pageID, incognito, criticality, tracking, sendIdentifier, serviceType)
        : nil;
    YMCaptureContext(result);
    return result;
}

static id YMContextMedium(id receiver, SEL selector, id pageID, BOOL incognito, int criticality, id tracking, BOOL sendIdentifier, id nonce, id jars, id attestation, long long serviceType) {
    id result = gOrigContextMedium
        ? ((id (*)(id, SEL, id, BOOL, int, id, BOOL, id, id, id, long long))gOrigContextMedium)(receiver, selector, pageID, incognito, criticality, tracking, sendIdentifier, nonce, jars, attestation, serviceType)
        : nil;
    YMCaptureContext(result);
    return result;
}

static id YMContextLong(id receiver, SEL selector, id pageID, BOOL incognito, int criticality, id tracking, BOOL sendIdentifier, id nonce, id jars, id attestation, id reauth, long long serviceType, BOOL isPrefetch) {
    id result = gOrigContextLong
        ? ((id (*)(id, SEL, id, BOOL, int, id, BOOL, id, id, id, id, long long, BOOL))gOrigContextLong)(receiver, selector, pageID, incognito, criticality, tracking, sendIdentifier, nonce, jars, attestation, reauth, serviceType, isPrefetch)
        : nil;
    YMCaptureContext(result);
    return result;
}

#pragma mark - PO token capture

// Tokens arrive as NSData (raw or base64 text) or as a wrapper with -poToken.
static NSData *YMDecodePoToken(id token) {
    if ([token isKindOfClass:NSString.class]) {
        NSMutableString *b64 = [[(NSString *)token stringByReplacingOccurrencesOfString:@"-" withString:@"+"] stringByReplacingOccurrencesOfString:@"_" withString:@"/"].mutableCopy;
        while (b64.length % 4) [b64 appendString:@"="];
        return [[NSData alloc] initWithBase64EncodedString:b64 options:0];
    }
    if ([token isKindOfClass:NSData.class]) {
        NSData *raw = token;
        NSString *text = [[NSString alloc] initWithData:raw encoding:NSUTF8StringEncoding];
        if (text.length) {
            NSCharacterSet *bad = [[NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_=+/"] invertedSet];
            if ([text rangeOfCharacterFromSet:bad].location == NSNotFound) {
                NSData *decoded = YMDecodePoToken(text);
                if (decoded.length) return decoded;
            }
        }
        return raw;
    }
    if (token && [token respondsToSelector:NSSelectorFromString(@"poToken")]) {
        id inner = YMGetValue(token, @[@"poToken"]);
        if (inner && inner != token) return YMDecodePoToken(inner);
    }
    return nil;
}

static void YMStorePoToken(id token, NSString *videoID) {
    NSData *data = YMDecodePoToken(token);
    if (!data.length) return;
    YMEnsureState();
    @synchronized (YMPlayerResolver.class) {
        gLastPoToken = [data copy];
        if (videoID.length) {
            gPoTokens[videoID] = gLastPoToken;
            while (gPoTokens.count > 32) [gPoTokens removeObjectForKey:gPoTokens.allKeys.firstObject];
        }
    }
    YMResolveLog(@"potoken video=%@ bytes=%lu", videoID ?: @"-", (unsigned long)data.length);
}

static id YMMintWithVideoID(id receiver, SEL selector, id videoID) {
    id result = gOrigMint ? ((id (*)(id, SEL, id))gOrigMint)(receiver, selector, videoID) : nil;
    YMStorePoToken(result, [videoID isKindOfClass:NSString.class] ? videoID : nil);
    return result;
}

static void YMSetPoToken(id receiver, SEL selector, NSData *token) {
    if (gOrigSetPoToken) ((void (*)(id, SEL, id))gOrigSetPoToken)(receiver, selector, token);
    YMStorePoToken(token, nil);
}

#pragma mark - Hook installation

// These classes can load after the tweak does, so retry until they all exist.
static NSInteger gHookAttempts;

static void YMInstallPlayerHooks(void) {
    YMEnsureState();
    BOOL init = YMInstallInstanceHook(@"YTPlayerService", @"init", (IMP)YMPlayerServiceInit, &gOrigServiceInit);
    YMInstallInstanceHook(@"YTAccountScopedInnerTubeContextFactory",
        @"contextWithPageID:isIncognitoActive:criticality:clickTrackingInfo:sendDeviceIdentifier:serviceType:",
        (IMP)YMContextShort, &gOrigContextShort);
    YMInstallInstanceHook(@"YTAccountScopedInnerTubeContextFactory",
        @"contextWithPageID:isIncognitoActive:criticality:clickTrackingInfo:sendDeviceIdentifier:clientScreenNonce:consistencyTokenJars:attestationResponseData:serviceType:",
        (IMP)YMContextMedium, &gOrigContextMedium);
    YMInstallInstanceHook(@"YTAccountScopedInnerTubeContextFactory",
        @"contextWithPageID:isIncognitoActive:criticality:clickTrackingInfo:sendDeviceIdentifier:clientScreenNonce:consistencyTokenJars:attestationResponseData:reauthProofToken:serviceType:isPrefetch:",
        (IMP)YMContextLong, &gOrigContextLong);
    BOOL service = YMInstallInstanceHook(@"YTPlayerService", @"makePlayerRequest:responseBlock:errorBlock:", (IMP)YMMakePlayerRequest, &gOrigMakePlayerRequest);
    BOOL playback = YMInstallInstanceHook(@"YTPlayerService", @"makePlaybackRequest:responseBlock:errorBlock:", (IMP)YMMakePlaybackRequest, &gOrigMakePlaybackRequest);
    BOOL prefetch = YMInstallInstanceHook(@"YTPlayerService", @"makePrefetchPlayerRequest:responseBlock:errorBlock:", (IMP)YMMakePrefetchPlayerRequest, &gOrigMakePrefetch);
    BOOL factory = YMInstallInstanceHook(@"YTPlayerRequestFactoryImpl", @"requestForPlayerWithPlayerRequest:URLRequestProperties:", (IMP)YMFactoryRequest, &gOrigFactory);
    BOOL extended = YMInstallInstanceHook(@"YTPlayerRequestFactoryImpl",
        @"requestForPlayerWithPlayerRequest:URLRequestProperties:enablePlayerResponseCacheKeyRelaxation:playerResponseCacheToken:skipInnertubeCacheLookup:",
        (IMP)YMFactoryRequestExtended, &gOrigFactoryExtended);
    BOOL mint = YMInstallInstanceHook(@"YTProofOfOriginTokenManager", @"mintWithVideoID:", (IMP)YMMintWithVideoID, &gOrigMint);
    BOOL poToken = YMInstallInstanceHook(@"YTIServiceIntegrityDimensions", @"setPoToken:", (IMP)YMSetPoToken, &gOrigSetPoToken);

    if (init && service && playback && prefetch && factory && extended && mint && poToken) {
        YMResolveLog(@"player path hooked");
        return;
    }
    if (++gHookAttempts >= 30) {
        YMResolveLog(@"player path unavailable init=%d service=%d playback=%d prefetch=%d factory=%d extended=%d mint=%d poToken=%d",
                     init, service, playback, prefetch, factory, extended, mint, poToken);
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{ YMInstallPlayerHooks(); });
}

%ctor {
    YMInstallPlayerHooks();
    YMRestoreRequest();
}

#pragma mark - Public entry

// The app plays through makePlaybackRequest, which takes a YTPlaybackRequest wrapping the
// proto request. Build one around `request`, reusing the last real playback request's
// properties with a fresh YTCPN.
static id YMWrapInPlaybackRequest(id request, id playbackRequest) {
    if (playbackRequest == nil || gOrigMakePlaybackRequest == NULL) return nil;
    Class playbackClass = NSClassFromString(@"YTPlaybackRequest");
    SEL initializer = NSSelectorFromString(@"initWithProtoRequest:URLRequestProperties:CPN:QOEController:latencyLogger:streamingWatchEnabled:enablePlayerResponseCacheKeyRelaxation:playerResponseCacheToken:streamingWatchHandlers:");
    id allocated = [playbackClass alloc];
    if (![allocated respondsToSelector:initializer]) return nil;
    // The app reads -[YTCPN value] from this; a plain string crashes it. -init makes a fresh nonce.
    id cpn = [NSClassFromString(@"YTCPN") new];
    if (cpn == nil) return nil;
    BOOL streaming = ((BOOL (*)(id, SEL))objc_msgSend)(playbackRequest, NSSelectorFromString(@"streamingWatchEnabled"));
    BOOL relaxation = ((BOOL (*)(id, SEL))objc_msgSend)(playbackRequest, NSSelectorFromString(@"enablePlayerResponseCacheKeyRelaxation"));
    return ((id (*)(id, SEL, id, id, id, id, id, BOOL, BOOL, id, id))objc_msgSend)(
        allocated, initializer, request,
        YMGetValue(playbackRequest, @[@"URLRequestProperties"]),
        cpn,
        YMGetValue(playbackRequest, @[@"QOEController"]),
        YMGetValue(playbackRequest, @[@"latencyLogger"]),
        streaming, relaxation,
        YMGetValue(playbackRequest, @[@"playerResponseCacheToken"]),
        YMGetValue(playbackRequest, @[@"streamingWatchHandlers"]));
}

@implementation YMPlayerResolver

+ (void)appendLog:(NSString *)line { YMResolveLogf(@"%@", line); }

+ (NSString *)recentLog {
    YMResolveLogf(@"recentLog read");
    @synchronized (gLogLines) { return [gLogLines componentsJoinedByString:@"\n"]; }
}

+ (BOOL)templateReady {
    YMRestoreRequest();
    @synchronized (YMPlayerResolver.class) {
        if (gLastRequest == nil) return NO;
        if (gLastService != nil) return YES;
    }
    return NSClassFromString(@"YTPlayerService") != Nil;
}

+ (NSData *)poTokenForVideoID:(NSString *)videoID {
    YMEnsureState();
    @synchronized (YMPlayerResolver.class) { return (videoID.length ? gPoTokens[videoID] : nil) ?: gLastPoToken; }
}

// A copy of `source` aimed at `videoID`, with playlist/page context from the template's video removed.
static id YMRetargetedRequest(id source, NSString *videoID) {
    id request = YMCopyObject(source);
    if (!YMSetValue(request, @"videoId", videoID)) return nil;
    YMSetValue(request, @"playlistId", @"");
    YMSetValue(request, @"params", @"");
    YMSetValue(request, @"playlistIndex", @0);
    id contentPlayback = YMGetValue(YMGetValue(request, @[@"playbackContext"]), @[@"contentPlaybackContext"]);
    YMSetValue(contentPlayback, @"currentUrl", @"");
    YMSetValue(contentPlayback, @"referer", @"");
    // -[YTPlayerService makePlayerRequest:…] silently does nothing for a prefetch request (no
    // factory call, no callbacks). The template is often one the app made to prefetch the next video.
    id requestInfo = YMGetValue(YMGetValue(request, @[@"context"]), @[@"request"]);
    BOOL wasPrefetch = NO;
    @try { wasPrefetch = [[requestInfo valueForKey:@"isPrefetch"] boolValue]; } @catch (__unused NSException *exception) {}
    if (wasPrefetch) YMSetValue(requestInfo, @"isPrefetch", @NO);
    YMResolveLog(@"retargeted video=%@ templatePrefetch=%d", videoID, wasPrefetch);
    return request;
}

// The service to use: the app's own when seen, otherwise a fresh instance.
static id YMServiceForResolve(void) {
    id service;
    @synchronized (YMPlayerResolver.class) { service = gLastService; }
    if (service) return service;
    Class cls = NSClassFromString(@"YTPlayerService");
    if (cls == Nil) return nil;
    @try { service = [[cls alloc] init]; } @catch (__unused NSException *exception) { service = nil; }
    YMResolveLog(@"constructed player service=%d", service != nil);
    if (service) @synchronized (YMPlayerResolver.class) { if (gLastService == nil) gLastService = service; }
    return service;
}

+ (void)resolveVideoID:(NSString *)videoID completion:(void (^)(id, NSError *))completion {
    YMEnsureState();
    // Delivered once: the service's answer and the timeout race.
    __block BOOL delivered = NO;
    NSObject *deliverLock = [NSObject new];
    void (^done)(id, NSError *) = ^(id response, NSError *error) {
        @synchronized (deliverLock) { if (delivered) return; delivered = YES; }
        dispatch_async(dispatch_get_main_queue(), ^{ completion(response, error); });
    };
    if (videoID.length == 0) { done(nil, YMResolveError(1, @"No video identifier.")); return; }

    YMRestoreRequest();
    id cached, service, source;
    @synchronized (YMPlayerResolver.class) {
        cached = gResponses[videoID];
        NSArray *pair = gRequests[videoID];
        service = pair.count > 1 ? pair[0] : gLastService;
        source = pair.count > 1 ? pair[1] : gLastRequest;
    }
    if (cached) { YMResolveLog(@"cached video=%@", videoID); done(cached, nil); return; }
    if (service == nil) service = YMServiceForResolve();
    if (source == nil) {
        id context;
        @synchronized (YMPlayerResolver.class) { context = gLastContext; }
        id built = context ? [NSClassFromString(@"YTIPlayerRequest") new] : nil;
        if (built && YMSetValue(built, @"context", YMCopyObject(context))) source = built;
    }
    if (service == nil || source == nil || gOrigMakePlayerRequest == NULL) {
        done(nil, YMResolveError(2, [NSString stringWithFormat:@"No player request template (service=%d request=%d hooked=%d).", service != nil, source != nil, gOrigMakePlayerRequest != NULL]));
        return;
    }
    id request = YMRetargetedRequest(source, videoID);
    if (request == nil) { done(nil, YMResolveError(3, @"YouTube's player request could not be retargeted.")); return; }

    @synchronized (YMPlayerResolver.class) { [gResolvingIDs addObject:videoID]; }
    YMResolveLog(@"request video=%@", videoID);
    [self sendPlayerRequest:request service:service videoID:videoID usePlaybackRoute:NO done:done];
    // The service can drop a request without answering; don't leave the caller waiting.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 25 * NSEC_PER_SEC), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @synchronized (deliverLock) { if (delivered) return; }
        NSString *diag;
        @synchronized (YMPlayerResolver.class) {
            diag = [NSString stringWithFormat:@"svc=%@ req=%@ caps=%@", NSStringFromClass([service class]), NSStringFromClass([source class]), gCaptureCounts];
            [gResolvingIDs removeObject:videoID];
        }
        YMResolveLog(@"timeout video=%@ %@", videoID, diag);
        done(nil, YMResolveError(8, [NSString stringWithFormat:@"YouTube didn't answer in time (%@)", diag]));
    });
}

// Sends `request` through the saved original makePlayerRequest (or the playback route).
+ (void)sendPlayerRequest:(id)request service:(id)service videoID:(NSString *)videoID usePlaybackRoute:(BOOL)playbackRoute done:(void (^)(id, NSError *))done {
    dispatch_async(dispatch_get_main_queue(), ^{
        YMResolveLog(@"sending video=%@ route=%@", videoID, playbackRoute ? @"playback" : @"player");
        void (^onResponse)(id, id) = ^(id response, __unused id cacheContext) {
            @synchronized (YMPlayerResolver.class) { [gResolvingIDs removeObject:videoID]; }
            id streaming = YMGetValue(response, @[@"streamingData"]) ?: YMGetValue(YMGetValue(response, @[@"playerData"]), @[@"streamingData"]);
            YMResolveLog(@"response video=%@ resolved=%@ streaming=%d", videoID, YMResponseVideoID(response) ?: @"none", streaming != nil);
            if (response == nil) { done(nil, YMResolveError(4, @"Empty player response.")); return; }
            YMCacheResponse(response);
            done(response, nil);
        };
        void (^onError)(NSError *) = ^(NSError *error) {
            @synchronized (YMPlayerResolver.class) { [gResolvingIDs removeObject:videoID]; }
            YMResolveLog(@"error video=%@ %@", videoID, error.localizedDescription ?: @"unknown");
            done(nil, error ?: YMResolveError(5, @"Player request failed."));
        };
        if (playbackRoute && gOrigMakePlaybackRequest) {
            id ret = ((id (*)(id, SEL, id, id, id))gOrigMakePlaybackRequest)(service, NSSelectorFromString(@"makePlaybackRequest:responseBlock:errorBlock:"), request, onResponse, onError);
            YMResolveLog(@"makePlaybackRequest returned %@ for video=%@", ret ? NSStringFromClass([ret class]) : @"nil", videoID);
        } else {
            ((void (*)(id, SEL, id, id, id))gOrigMakePlayerRequest)(service, NSSelectorFromString(@"makePlayerRequest:responseBlock:errorBlock:"), request, onResponse, onError);
        }
    });
}

+ (void)refreshVideoID:(NSString *)videoID completion:(void (^)(id, NSError *))completion {
    YMDropCachedResponse(videoID);
    [self resolveVideoID:videoID completion:completion];
}

// Answers a SABR RELOAD: the token rides in playbackContext.reloadPlaybackContext.reloadPlaybackParams.
+ (void)reloadVideoID:(NSString *)videoID token:(NSString *)token completion:(void (^)(id, NSError *))completion {
    YMEnsureState();
    YMDropCachedResponse(videoID);
    void (^fail)(NSInteger, NSString *) = ^(NSInteger code, NSString *message) {
        NSError *error = YMResolveError(code, message);
        dispatch_async(dispatch_get_main_queue(), ^{ completion(nil, error); });
    };
    id service, source, playbackRequest;
    @synchronized (YMPlayerResolver.class) {
        NSArray *pair = videoID.length ? gRequests[videoID] : nil;
        service = pair.count > 1 ? pair[0] : gLastService;
        source = pair.count > 1 ? pair[1] : gLastRequest;
        playbackRequest = gLastPlaybackRequest;
    }
    if ((gOrigMakePlayerRequest == NULL && gOrigMakePlaybackRequest == NULL) || service == nil || source == nil || token.length == 0) {
        fail(1, @"No matching YouTube player request is available."); return;
    }
    id request = videoID.length ? YMRetargetedRequest(source, videoID) : YMCopyObject(source);
    id playback = YMCopyObject(YMGetValue(request, @[@"playbackContext"]));
    if (playback == nil) playback = [NSClassFromString(@"YTIPlaybackContext") new];
    id params = [NSClassFromString(@"YTIReloadPlaybackParams") new];
    id reload = [NSClassFromString(@"YTIReloadPlaybackContext") new];
    if (!(YMSetValue(params, @"token", token) && YMSetValue(reload, @"reloadPlaybackParams", params) &&
          YMSetValue(playback, @"reloadPlaybackContext", reload) && YMSetValue(request, @"playbackContext", playback))) {
        fail(2, @"YouTube's reload request could not be configured."); return;
    }
    id routed = YMWrapInPlaybackRequest(request, playbackRequest);
    YMResolveLog(@"reload video=%@ token=%lu route=%@", videoID ?: @"unknown", (unsigned long)token.length, routed ? @"playback" : @"player");
    NSString *key = videoID ?: @"";
    if (key.length) @synchronized (YMPlayerResolver.class) { [gResolvingIDs addObject:key]; }
    __block BOOL delivered = NO;
    NSObject *deliverLock = [NSObject new];
    void (^done)(id, NSError *) = ^(id response, NSError *error) {
        @synchronized (deliverLock) { if (delivered) return; delivered = YES; }
        dispatch_async(dispatch_get_main_queue(), ^{ completion(response, error); });
    };
    [self sendPlayerRequest:routed ?: request service:service videoID:key usePlaybackRoute:routed != nil done:done];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 25 * NSEC_PER_SEC), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @synchronized (deliverLock) { if (delivered) return; }
        if (key.length) @synchronized (YMPlayerResolver.class) { [gResolvingIDs removeObject:key]; }
        done(nil, YMResolveError(8, @"YouTube didn't answer the reload in time."));
    });
}

@end

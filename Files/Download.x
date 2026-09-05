#import "Headers.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <math.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <stdarg.h>
#import <stdlib.h>

@interface YouModMenuItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, strong) UIImage *iconImage;
@property (nonatomic, copy) void (^handler)(void);
+ (instancetype)itemWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(UIImage *)icon handler:(void (^)(void))handler;
@end

@implementation YouModMenuItem
+ (instancetype)itemWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(UIImage *)icon handler:(void (^)(void))handler {
    YouModMenuItem *item = [YouModMenuItem new];
    item.title = title;
    item.subtitle = subtitle;
    item.iconImage = icon;
    item.handler = handler;
    return item;
}
@end

@interface YouModMediaFormat : NSObject
@property (nonatomic, strong) YTIFormatStream *source;
@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, copy) NSString *qualityLabel;
@property (nonatomic, copy) NSString *mimeType;
@property (nonatomic, copy) NSString *idp;
@property (nonatomic, assign) NSInteger contentLength;
@property (nonatomic, assign) NSUInteger durationMs;
@property (nonatomic, assign) int fps;
@property (nonatomic, assign) int itag;
@property (nonatomic, assign) int resolution;
@property (nonatomic, assign) BOOL video;
@property (nonatomic, assign) BOOL audioIsDefault;
@end

@implementation YouModMediaFormat
@end

typedef void (^YouModFileDownloadCompletion)(NSURL *fileURL, NSError *error);
typedef void (^YouModMergeCompletion)(BOOL success, NSError *error);
typedef void (^YouModRangeDownloadProgress)(unsigned long long completedBytes);

@interface YouModDownloadChunk : NSObject
@property (nonatomic, assign) unsigned long long offset;
@property (nonatomic, assign) unsigned long long length;
@property (nonatomic, assign) NSUInteger attempts;
@end

@implementation YouModDownloadChunk
@end

@interface YouModRangeDownloader : NSObject
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSURL *destinationURL;
@property (nonatomic, copy) NSDictionary *httpHeaders;
@property (nonatomic, assign) unsigned long long expectedBytes;
@property (nonatomic, copy) YouModRangeDownloadProgress progress;
@property (nonatomic, copy) YouModFileDownloadCompletion completion;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (nonatomic, strong) NSMutableArray <YouModDownloadChunk *> *pendingChunks;
@property (nonatomic, strong) NSMutableSet <NSURLSessionDataTask *> *tasks;
@property (nonatomic, strong) dispatch_queue_t stateQueue;
@property (nonatomic, strong) dispatch_queue_t fileQueue;
@property (nonatomic, assign) NSUInteger activeTaskCount;
@property (nonatomic, assign) NSUInteger totalChunkCount;
@property (nonatomic, assign) unsigned long long completedBytes;
@property (nonatomic, assign) BOOL cancelled;
@property (nonatomic, assign) BOOL finished;
- (instancetype)initWithURL:(NSURL *)url destinationURL:(NSURL *)destinationURL expectedBytes:(unsigned long long)expectedBytes headers:(NSDictionary *)headers progress:(YouModRangeDownloadProgress)progress completion:(YouModFileDownloadCompletion)completion;
- (void)start;
- (void)cancel;
@end

@interface YouModDownloadCoordinator : NSObject <NSURLSessionDownloadDelegate>
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSessionDownloadTask *task;
@property (nonatomic, strong) NSURLSessionDataTask *metadataTask;
@property (nonatomic, strong) YouModRangeDownloader *rangeDownloader;
@property (nonatomic, strong) AVAssetExportSession *exporter;
@property (nonatomic, strong) YMDownloadProgressView *progressPill;
@property (nonatomic, weak) UIViewController *presenter;
@property (nonatomic, copy) YouModFileDownloadCompletion fileCompletion;
@property (nonatomic, strong) NSURL *destinationURL;
@property (nonatomic, strong) NSURL *videoTempURL;
@property (nonatomic, strong) NSURL *audioTempURL;
@property (nonatomic, assign) unsigned long long completedBytes;
@property (nonatomic, assign) unsigned long long totalBytes;
@property (nonatomic, assign) unsigned long long currentBytes;
@property (nonatomic, assign) unsigned long long currentExpectedBytes;
@property (nonatomic, assign) BOOL currentResolvedSizeAddedToTotal;
@property (nonatomic, assign) BOOL active;
@property (nonatomic, assign) BOOL finishedCurrentFile;
@property (nonatomic, assign) BOOL cancelled;
@property (nonatomic, copy) NSString *baseProgressTitle;
@property (nonatomic, assign) NSTimeInterval downloadStartTime;
@property (nonatomic, copy) void (^downloadCompletionBlock)(NSURL *localURL, NSString *errorMsg);
+ (instancetype)sharedCoordinator;
- (void)startVideoDownloadWithVideoFormat:(YouModMediaFormat *)videoFormat audioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID;
- (void)startAudioDownloadWithAudioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID;
- (void)startDirectVideoDownloadWithVideoFormat:(YouModMediaFormat *)videoFormat audioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID;
- (void)startDirectAudioDownloadWithAudioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID;
- (void)trimAudioToHalfLengthAtURL:(NSURL *)inputURL toURL:(NSURL *)outputURL completion:(void (^)(NSError *error))completion;
- (void)mergeVideoURL:(NSURL *)videoURL audioURL:(NSURL *)audioURL fileName:(NSString *)fileName outputExtension:(NSString *)outputExtension durationMs:(unsigned long long)durationMs presenter:(UIViewController *)presenter;
- (void)mergeVideoWithAVFoundationVideoURL:(NSURL *)videoURL audioURL:(NSURL *)audioURL outputURL:(NSURL *)outputURL durationMs:(unsigned long long)durationMs presenter:(UIViewController *)presenter fallbackError:(NSError *)fallbackError;
@end

static const unsigned long long YouModFastDownloadMinimumBytes = 256ULL * 1024ULL;
static const unsigned long long YouModFastDownloadChunkBytes = 4ULL * 1024ULL * 1024ULL;
static const NSUInteger YouModFastDownloadConcurrency = 8;
static const NSUInteger YouModFastDownloadMaxAttempts = 3;

static BOOL YouModHTTPHeadersContainField(NSDictionary *headers, NSString *field) {
    for (id key in headers) {
        if ([key isKindOfClass:NSString.class] && [(NSString *)key caseInsensitiveCompare:field] == NSOrderedSame)
            return YES;
    }
    return NO;
}

static NSString *YouModYouTubeCookiesString(void) {
    NSMutableArray *cookieStrings = [NSMutableArray array];
    for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
        if ([cookie.domain containsString:@"youtube.com"]) {
            [cookieStrings addObject:[NSString stringWithFormat:@"%@=%@", cookie.name, cookie.value]];
        }
    }
    return [cookieStrings componentsJoinedByString:@"; "];
}

static NSString *YouModNativeUserAgent(void) {
    NSString *device = isPad() ? @"iPad" : @"iPhone";
    return [NSString stringWithFormat:@"com.google.ios.youtube/21.26.4 (%@; CPU OS 18_7 like Mac OS X)", device];
}

static void YouModApplyDownloadHeaders(NSMutableURLRequest *request, NSDictionary *headers) {
    for (id key in headers) {
        id value = headers[key];
        if ([key isKindOfClass:NSString.class] && [value isKindOfClass:NSString.class])
            [request setValue:value forHTTPHeaderField:key];
    }
    if (!YouModHTTPHeadersContainField(headers, @"User-Agent"))
        [request setValue:YouModNativeUserAgent() forHTTPHeaderField:@"User-Agent"];
    if (!YouModHTTPHeadersContainField(headers, @"Origin"))
        [request setValue:@"https://www.youtube.com" forHTTPHeaderField:@"Origin"];
    if (!YouModHTTPHeadersContainField(headers, @"Referer"))
        [request setValue:@"https://www.youtube.com/" forHTTPHeaderField:@"Referer"];
    if (!YouModHTTPHeadersContainField(headers, @"Cookie")) {
        NSString *cookies = YouModYouTubeCookiesString();
        if (cookies.length > 0) [request setValue:cookies forHTTPHeaderField:@"Cookie"];
    }
    extern NSString *YouModGlobalAuthHeader;
    if (YouModGlobalAuthHeader && !YouModHTTPHeadersContainField(headers, @"Authorization")) {
        [request setValue:YouModGlobalAuthHeader forHTTPHeaderField:@"Authorization"];
    }
    [request setValue:@"identity" forHTTPHeaderField:@"Accept-Encoding"];
}

@implementation YouModRangeDownloader

- (instancetype)initWithURL:(NSURL *)url destinationURL:(NSURL *)destinationURL expectedBytes:(unsigned long long)expectedBytes headers:(NSDictionary *)headers progress:(YouModRangeDownloadProgress)progress completion:(YouModFileDownloadCompletion)completion {
    self = [super init];
    if (self) {
        _url = url;
        _destinationURL = destinationURL;
        _httpHeaders = [headers copy];
        _expectedBytes = expectedBytes;
        _progress = [progress copy];
        _completion = [completion copy];
        _pendingChunks = [NSMutableArray array];
        _tasks = [NSMutableSet set];
        _stateQueue = dispatch_queue_create("com.youmod.download.range.state", DISPATCH_QUEUE_SERIAL);
        _fileQueue = dispatch_queue_create("com.youmod.download.range.file", DISPATCH_QUEUE_SERIAL);

        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.HTTPMaximumConnectionsPerHost = YouModFastDownloadConcurrency;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        configuration.timeoutIntervalForResource = 300;
        NSMutableDictionary *additionalHeaders = [NSMutableDictionary dictionary];
        for (id key in headers) {
            id value = headers[key];
            if ([key isKindOfClass:NSString.class] && [value isKindOfClass:NSString.class])
                additionalHeaders[key] = value;
        }
        if (!YouModHTTPHeadersContainField(additionalHeaders, @"User-Agent"))
            additionalHeaders[@"User-Agent"] = YouModNativeUserAgent();
        if (!YouModHTTPHeadersContainField(additionalHeaders, @"Origin"))
            additionalHeaders[@"Origin"] = @"https://www.youtube.com";
        if (!YouModHTTPHeadersContainField(additionalHeaders, @"Referer"))
            additionalHeaders[@"Referer"] = @"https://www.youtube.com/";
        if (!YouModHTTPHeadersContainField(additionalHeaders, @"Cookie")) {
            NSString *cookies = YouModYouTubeCookiesString();
            if (cookies.length > 0) additionalHeaders[@"Cookie"] = cookies;
        }
        extern NSString *YouModGlobalAuthHeader;
        if (YouModGlobalAuthHeader && !YouModHTTPHeadersContainField(additionalHeaders, @"Authorization")) {
            additionalHeaders[@"Authorization"] = YouModGlobalAuthHeader;
        }
        additionalHeaders[@"Accept-Encoding"] = @"identity";
        configuration.HTTPAdditionalHeaders = additionalHeaders;
        _session = [NSURLSession sessionWithConfiguration:configuration];
    }
    return self;
}

- (NSError *)errorWithCode:(NSInteger)code message:(NSString *)message {
    return [NSError errorWithDomain:@"YouMod" code:code userInfo:@{NSLocalizedDescriptionKey: message ?: @"Download failed"}];
}

- (BOOL)prepareDestinationWithError:(NSError **)error {
    [NSFileManager.defaultManager removeItemAtURL:self.destinationURL error:nil];
    if (![NSFileManager.defaultManager createFileAtPath:self.destinationURL.path contents:nil attributes:nil]) {
        if (error) *error = [self errorWithCode:20 message:@"Cannot create file"];
        return NO;
    }

    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.destinationURL.path];
    if (!self.fileHandle) {
        if (error) *error = [self errorWithCode:21 message:@"Cannot open file"];
        return NO;
    }

    @try {
        [self.fileHandle truncateFileAtOffset:self.expectedBytes];
    } @catch (NSException *exception) {
        if (error) *error = [self errorWithCode:22 message:exception.reason ?: @"Cannot allocate file"];
        return NO;
    }
    return YES;
}

- (void)start {
    dispatch_async(self.stateQueue, ^{
        if (self.expectedBytes == 0) {
            [self finishWithErrorLocked:[self errorWithCode:23 message:@"Unknown stream size"]];
            return;
        }

        NSError *error = nil;
        if (![self prepareDestinationWithError:&error]) {
            [self finishWithErrorLocked:error];
            return;
        }

        unsigned long long chunkSize = self.expectedBytes / 100ULL;
        if (chunkSize < 256ULL * 1024ULL) chunkSize = 256ULL * 1024ULL;
        if (chunkSize > YouModFastDownloadChunkBytes) chunkSize = YouModFastDownloadChunkBytes;

        for (unsigned long long offset = 0; offset < self.expectedBytes; offset += chunkSize) {
            YouModDownloadChunk *chunk = [YouModDownloadChunk new];
            chunk.offset = offset;
            unsigned long long remaining = self.expectedBytes - offset;
            chunk.length = remaining < chunkSize ? remaining : chunkSize;
            [self.pendingChunks addObject:chunk];
        }
        self.totalChunkCount = self.pendingChunks.count;
        [self scheduleChunksLocked];
    });
}

- (void)cancel {
    dispatch_async(self.stateQueue, ^{
        if (self.finished) return;
        self.cancelled = YES;
        self.finished = YES;
        for (NSURLSessionDataTask *task in self.tasks) [task cancel];
        [self.tasks removeAllObjects];
        [self.session invalidateAndCancel];
        dispatch_async(self.fileQueue, ^{
            @try {
                [self.fileHandle closeFile];
            } @catch (__unused NSException *exception) {
            }
            [NSFileManager.defaultManager removeItemAtURL:self.destinationURL error:nil];
        });
    });
}

- (void)scheduleChunksLocked {
    if (self.finished || self.cancelled) return;
    while (self.activeTaskCount < YouModFastDownloadConcurrency && self.pendingChunks.count > 0) {
        YouModDownloadChunk *chunk = self.pendingChunks.firstObject;
        [self.pendingChunks removeObjectAtIndex:0];
        [self startChunkLocked:chunk];
    }

    if (self.activeTaskCount == 0 && self.pendingChunks.count == 0) {
        [self finishSuccessfullyLocked];
    }
}

- (void)startChunkLocked:(YouModDownloadChunk *)chunk {
    unsigned long long end = chunk.offset + chunk.length - 1;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60.0];
    YouModApplyDownloadHeaders(request, self.httpHeaders);
    [request setValue:[NSString stringWithFormat:@"bytes=%llu-%llu", chunk.offset, end] forHTTPHeaderField:@"Range"];

    __weak typeof(self) weakSelf = self;
    __block NSURLSessionDataTask *task = nil;
    task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self completeChunk:chunk task:task data:data response:response error:error];
    }];
    [self.tasks addObject:task];
    self.activeTaskCount++;
    [task resume];
}

- (NSError *)validationErrorForChunk:(YouModDownloadChunk *)chunk data:(NSData *)data response:(NSURLResponse *)response error:(NSError *)error {
    if (error) return error;

    NSHTTPURLResponse *httpResponse = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
    NSInteger statusCode = httpResponse.statusCode;
    BOOL statusOK = statusCode == 206 || (self.totalChunkCount == 1 && statusCode == 200);
    if (httpResponse && !statusOK)
        return [self errorWithCode:24 message:@"Range request rejected by server"];

    if (data.length != chunk.length)
        return [self errorWithCode:25 message:@"Incomplete chunk"];

    return nil;
}

- (void)completeChunk:(YouModDownloadChunk *)chunk task:(NSURLSessionDataTask *)task data:(NSData *)data response:(NSURLResponse *)response error:(NSError *)error {
    dispatch_async(self.stateQueue, ^{
        if (self.activeTaskCount > 0) self.activeTaskCount--;
        if (task) [self.tasks removeObject:task];
        if (self.finished || self.cancelled) return;

        NSError *validationError = [self validationErrorForChunk:chunk data:data response:response error:error];
        if (validationError) {
            if (validationError.code == 24) {
                [self finishWithErrorLocked:validationError];
                return;
            }
            if (chunk.attempts + 1 < YouModFastDownloadMaxAttempts) {
                chunk.attempts++;
                [self.pendingChunks insertObject:chunk atIndex:0];
                [self scheduleChunksLocked];
            } else {
                [self finishWithErrorLocked:validationError];
            }
            return;
        }

        NSData *chunkData = [data copy];
        dispatch_async(self.fileQueue, ^{
            NSError *writeError = nil;
            @try {
                [self.fileHandle seekToFileOffset:chunk.offset];
                [self.fileHandle writeData:chunkData];
            } @catch (NSException *exception) {
                writeError = [self errorWithCode:26 message:exception.reason ?: @"Write failed"];
            }

            dispatch_async(self.stateQueue, ^{
                if (self.finished || self.cancelled) return;
                if (writeError) {
                    [self finishWithErrorLocked:writeError];
                    return;
                }

                self.completedBytes += chunkData.length;
                if (self.progress) {
                    unsigned long long completed = self.completedBytes;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.progress(completed);
                    });
                }
                [self scheduleChunksLocked];
            });
        });
    });
}

- (void)finishSuccessfullyLocked {
    if (self.finished) return;
    self.finished = YES;
    [self.session finishTasksAndInvalidate];
    dispatch_async(self.fileQueue, ^{
        @try {
            [self.fileHandle closeFile];
        } @catch (__unused NSException *exception) {
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.completion) self.completion(self.destinationURL, nil);
        });
    });
}

- (void)finishWithErrorLocked:(NSError *)error {
    if (self.finished) return;
    self.finished = YES;
    for (NSURLSessionDataTask *task in self.tasks) [task cancel];
    [self.tasks removeAllObjects];
    [self.session invalidateAndCancel];
    dispatch_async(self.fileQueue, ^{
        @try {
            [self.fileHandle closeFile];
        } @catch (__unused NSException *exception) {
        }
        [NSFileManager.defaultManager removeItemAtURL:self.destinationURL error:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.completion) self.completion(nil, error ?: [self errorWithCode:27 message:@"Download failed"]);
        });
    });
}

@end

YTPlayerViewController *YouModCurrentPlayerViewController = nil;

static void YouModSendToast(NSString *message) {
    UIView *parent = sbGetNotificationParent();
    [SBSkipNotificationView showInView:parent message:message buttonTitle:nil action:nil duration:3.0];
}

static void YouModSendSuccess(NSString *message) {
    UIView *parent = sbGetNotificationParent();
    [SBSkipNotificationView showSuccessInView:parent message:message duration:3.0];
}

static void YouModSendError(NSString *message) {
    UIView *parent = sbGetNotificationParent();
    [SBSkipNotificationView showErrorInView:parent message:message duration:4.0];
}

static NSString *YouModByteCount(unsigned long long bytes) {
    if (bytes == 0) return nil;
    NSByteCountFormatter *formatter = [NSByteCountFormatter new];
    formatter.countStyle = NSByteCountFormatterCountStyleFile;
    return [formatter stringFromByteCount:(long long)bytes];
}

static NSString *YouModURLStringBypassingThrottle(NSString *urlString) {
    if (urlString.length == 0) return urlString;
    NSURLComponents *components = [NSURLComponents componentsWithString:urlString];
    if (components) {
        NSMutableArray *queryItems = [components.queryItems mutableCopy] ?: [NSMutableArray array];
        NSMutableArray *filtered = [NSMutableArray array];
        for (NSURLQueryItem *item in queryItems) {
            if (![item.name isEqualToString:@"n"])
                [filtered addObject:item];
        }
        BOOL hasRateBypass = NO;
        for (NSURLQueryItem *item in filtered) {
            if ([item.name isEqualToString:@"ratebypass"]) { hasRateBypass = YES; break; }
        }
        if (!hasRateBypass)
            [filtered addObject:[NSURLQueryItem queryItemWithName:@"ratebypass" value:@"yes"]];
        components.queryItems = filtered;
        NSString *result = components.string;
        if (result.length > 0) return result;
    }
    return urlString;
}

static NSString *YouModURLStringWithCPN(NSString *urlString) {
    if (urlString.length == 0) return urlString;
    urlString = YouModURLStringBypassingThrottle(urlString);
    if ([urlString containsString:@"cpn="]) return urlString;
    NSString *cpn = [%c(YTDataUtils) generateClientSideNonce];
    NSString *separator = [urlString containsString:@"?"] ? @"&" : @"?";
    return [NSString stringWithFormat:@"%@%@cpn=%@", urlString, separator, cpn];
}

static NSString *YouModSanitizedFileName(NSString *name) {
    if (name.length == 0) return @"YouTube Video";
    NSMutableCharacterSet *invalid = [NSMutableCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>:"];
    [invalid formUnionWithCharacterSet:NSCharacterSet.newlineCharacterSet];
    NSArray *parts = [name componentsSeparatedByCharactersInSet:invalid];
    NSString *clean = [[parts componentsJoinedByString:@" "] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    while ([clean containsString:@"  "]) clean = [clean stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    if (clean.length > 120) clean = [clean substringToIndex:120];
    return clean.length ? clean : @"YouTube Video";
}

static NSURL *YouModDownloadsDirectoryURL(void) {
    NSURL *documentsURL = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *downloadsURL = [documentsURL URLByAppendingPathComponent:@"YouMod_Downloads" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:downloadsURL withIntermediateDirectories:YES attributes:nil error:nil];
    return downloadsURL;
}

static NSURL *YouModUniqueFileURL(NSString *fileName, NSString *extension) {
    NSString *safeName = YouModSanitizedFileName(fileName);
    NSURL *directoryURL = YouModDownloadsDirectoryURL();
    NSURL *candidate = [directoryURL URLByAppendingPathComponent:[safeName stringByAppendingPathExtension:extension]];
    NSUInteger index = 2;
    while ([NSFileManager.defaultManager fileExistsAtPath:candidate.path]) {
        NSString *indexed = [NSString stringWithFormat:@"%@ %lu", safeName, (unsigned long)index++];
        candidate = [directoryURL URLByAppendingPathComponent:[indexed stringByAppendingPathExtension:extension]];
    }
    return candidate;
}

static NSURL *YouModTemporaryFileURL(NSString *extension) {
    NSString *name = [[NSUUID UUID].UUIDString stringByAppendingPathExtension:extension];
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
}

static unsigned long long YouModDurationMsForURL(NSURL *url) {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    if (!CMTIME_IS_NUMERIC(asset.duration) || !CMTIME_IS_VALID(asset.duration)) return 0;
    Float64 seconds = CMTimeGetSeconds(asset.duration);
    if (!isfinite(seconds) || seconds <= 0.0) return 0;
    return (unsigned long long)llround(seconds * 1000.0);
}

static BOOL YouModCMTimeIsUsable(CMTime time) {
    if (!CMTIME_IS_VALID(time) || !CMTIME_IS_NUMERIC(time) || CMTIME_IS_INDEFINITE(time)) return NO;
    Float64 seconds = CMTimeGetSeconds(time);
    return isfinite(seconds) && seconds > 0.0;
}

static CMTime YouModMinUsableDuration(CMTime first, CMTime second) {
    BOOL firstOK = YouModCMTimeIsUsable(first);
    BOOL secondOK = YouModCMTimeIsUsable(second);
    if (firstOK && secondOK) return CMTIME_COMPARE_INLINE(first, <, second) ? first : second;
    if (firstOK) return first;
    if (secondOK) return second;
    return kCMTimeInvalid;
}

static CMTime YouModExportDuration(AVAsset *videoAsset, AVAsset *audioAsset, unsigned long long expectedDurationMs) {
    CMTime duration = kCMTimeInvalid;
    if (expectedDurationMs > 0)
        duration = CMTimeMakeWithSeconds((double)expectedDurationMs / 1000.0, 600);

    CMTime videoDuration = YouModMinUsableDuration(videoAsset.duration, [[videoAsset tracksWithMediaType:AVMediaTypeVideo] firstObject].timeRange.duration);
    CMTime audioDuration = audioAsset ? YouModMinUsableDuration(audioAsset.duration, [[audioAsset tracksWithMediaType:AVMediaTypeAudio] firstObject].timeRange.duration) : kCMTimeInvalid;
    CMTime mediaDuration = audioAsset ? YouModMinUsableDuration(videoDuration, audioDuration) : videoDuration;

    if (!YouModCMTimeIsUsable(duration)) return mediaDuration;
    if (YouModCMTimeIsUsable(mediaDuration) && CMTIME_COMPARE_INLINE(duration, >, mediaDuration))
        return mediaDuration;
    return duration;
}

static BOOL YouModPathExtensionIsPhotosVideo(NSString *extension) {
    NSString *lower = extension.lowercaseString;
    return [@[@"mp4"] containsObject:lower];
}

static NSString *YouModMimeDetail(NSString *mimeType) {
    NSString *lower = mimeType.lowercaseString;
    if ([lower containsString:@"mp4"]) return @"MP4";
    return mimeType;
}

static NSString *YouModFileExtensionForFormat(YouModMediaFormat *format) {
    NSString *lower = format.mimeType.lowercaseString;
    if ([lower containsString:@"mp4a"]) return @"m4a";
    if ([lower containsString:@"mp4"]) return @"mp4";
    return nil;
}

static BOOL YouModFormatLooksMP4Family(YouModMediaFormat *format) {
    NSString *mime = format.mimeType.lowercaseString;
    NSString *extension = YouModFileExtensionForFormat(format);
    return [mime containsString:@"mp4"] || [mime containsString:@"mp4a"] || [@[@"mp4", @"mp4a"] containsObject:extension];
}

static NSString *YouModMergedVideoOutputExtension(YouModMediaFormat *videoFormat, YouModMediaFormat *audioFormat) {
    if (YouModFormatLooksMP4Family(videoFormat) && YouModFormatLooksMP4Family(audioFormat)) return @"mp4";
    return nil;
}

static BOOL YouModVideoFileCanUseAVFoundation(NSURL *fileURL) {
    return YouModPathExtensionIsPhotosVideo(fileURL.pathExtension);
}

static BOOL YouModVideoFileCanSaveToPhotos(NSURL *fileURL) {
    return YouModPathExtensionIsPhotosVideo(fileURL.pathExtension);
}

static NSString *YouModFormatSubtitle(YouModMediaFormat *format, BOOL video) {
    if (video) {
        NSMutableArray *parts = [NSMutableArray array];
        NSString *detail = YouModMimeDetail(format.mimeType);
        if (detail.length) [parts addObject:detail];
        NSString *size = YouModByteCount(format.contentLength);
        if (size.length) [parts addObject:size];
        return [parts componentsJoinedByString:@" - "];
    }
    NSString *cut = [[format.idp componentsSeparatedByString:@"."] firstObject];
    return cut;
}

static YTIPlayerResponse *YouModPlayerDataForPlayer(YTPlayerViewController *player) {
    YTPlayerResponse *response;
    if ([player respondsToSelector:@selector(contentPlayerResponse)]) {
        response = player.contentPlayerResponse;
    } else {
        response = player.playerResponse;
    }
    YTIPlayerResponse *playerData = response.playerData;
    return playerData;
}

static NSArray *YouModCaptionTracksForPlayer(YTPlayerViewController *player) {
    YTIPlayerResponse *playerData = YouModPlayerDataForPlayer(player);
    YTICaptionsSupportedRenderers *captions = playerData.captions;
    YTIPlayerCaptionsTrackListRenderer *tracklistRenderer = captions.playerCaptionsTracklistRenderer;
    NSArray *tracks = tracklistRenderer.captionTracksArray;
    if (tracks.count > 0) return tracks;
    return nil;
}

static YTIVideoDetails *YouModVideoDetailsForPlayer(YTPlayerViewController *player) {
    YTIPlayerResponse *ires = YouModPlayerDataForPlayer(player);
    return ires.videoDetails;
}

static NSString *YouModAuthorForPlayer(YTPlayerViewController *player) {
    YTIVideoDetails *details = YouModVideoDetailsForPlayer(player);
    return details.author;
}

static NSString *YouModTitleForPlayer(YTPlayerViewController *player) {
    YTIVideoDetails *details = YouModVideoDetailsForPlayer(player);
    return details.title;
}

static NSString *YouModDescriptionForPlayer(YTPlayerViewController *player) {
    YTIVideoDetails *details = YouModVideoDetailsForPlayer(player);
    return details.shortDescription;
}

static NSArray *YouModAdaptiveFormatObjectsForPlayer(YTPlayerViewController *player) {
    YTIPlayerResponse *playerData = YouModPlayerDataForPlayer(player);
    YTIStreamingData *streamingData = playerData.streamingData;
    return streamingData.adaptiveFormatsArray;
}

static YouModMediaFormat *YouModMediaFormatFromStream(YTIFormatStream *stream, BOOL video) {
    NSString *url = stream.URL;
    NSString *mimeType = stream.mimeType;
    NSString *lowerMime = mimeType.lowercaseString;
    BOOL typeMatches = video ? ([lowerMime containsString:@"video/"]) : ([lowerMime containsString:@"audio/"]);
    if (!typeMatches) return nil;

    BOOL mimeLooksMP4 = [lowerMime containsString:@"mp4"] && ([lowerMime containsString:@"avc1"] || ([lowerMime containsString:@"mp4a"] && stream.itag == 140));
    if (mimeType.length && !mimeLooksMP4) return nil;

    YouModMediaFormat *format = [YouModMediaFormat new];
    format.source = stream;
    format.video = video;
    format.urlString = YouModURLStringWithCPN(url);
    format.mimeType = mimeType;
    int height = stream.height;
    if (video && height > 1080) return nil;
    format.resolution = height;
    format.fps = stream.fps;
    format.qualityLabel = stream.qualityLabel;
    if ([stream.qualityLabel hasSuffix:@"HDR"]) return nil;
    if (!video) {
        YTIAudioTrack *audio = stream.audioTrack;
        NSString *audioidp = audio.id_p;
        if (audio.hasId_p) {
            if (INTFORVAL(AudioPreferIndex) == 1 && ![audioidp hasSuffix:@".4"]) return nil;
            if (INTFORVAL(AudioPreferIndex) == 2 && ![audioidp hasPrefix:@"en"]) return nil;
            format.qualityLabel = audio.displayName;
            format.idp = audioidp;
            format.audioIsDefault = audio.audioIsDefault;
        } else if (audio && audio.displayName.length > 0) {
            format.qualityLabel = audio.displayName;
            format.audioIsDefault = audio.audioIsDefault;
        }
    }
    format.contentLength = stream.contentLength;
    format.durationMs = stream.approxDurationMs;
    format.itag = stream.itag;
    return format;
}

static NSArray <YouModMediaFormat *> *YouModFormatsForPlayer(YTPlayerViewController *player, BOOL video) {
    NSMutableArray *formats = [NSMutableArray array];
    for (YTIFormatStream *stream in YouModAdaptiveFormatObjectsForPlayer(player)) {
        YouModMediaFormat *format = YouModMediaFormatFromStream(stream, video);
        if (format) [formats addObject:format];
    }

    if (formats.count == 0) return @[];

    if (video) {
        [formats sortUsingComparator:^NSComparisonResult(YouModMediaFormat *left, YouModMediaFormat *right) {
            NSInteger leftRes = left.resolution;
            NSInteger rightRes = right.resolution;
            if (leftRes != rightRes) return leftRes > rightRes ? NSOrderedAscending : NSOrderedDescending;
            NSInteger leftFPS = left.fps;
            NSInteger rightFPS = right.fps;
            if (leftFPS != rightFPS) return leftFPS > rightFPS ? NSOrderedAscending : NSOrderedDescending;

            BOOL leftMP4 = YouModFormatLooksMP4Family(left);
            BOOL rightMP4 = YouModFormatLooksMP4Family(right);
            if (leftMP4 != rightMP4) return leftMP4 ? NSOrderedAscending : NSOrderedDescending;

            if (left.contentLength != right.contentLength)
                return left.contentLength > right.contentLength ? NSOrderedAscending : NSOrderedDescending;
            return NSOrderedSame;
        }];

        NSMutableArray *unique = [NSMutableArray array];
        NSMutableSet *seen = [NSMutableSet set];
        for (YouModMediaFormat *format in formats) {
            NSInteger fps = format.fps;
            NSString *key = [NSString stringWithFormat:@"%@-%ld-%@", format.qualityLabel, (long)fps, YouModMimeDetail(format.mimeType)];
            if ([seen containsObject:key]) continue;
            [seen addObject:key];
            [unique addObject:format];
        }
        return unique.copy;
    } else {
        BOOL hasExplicitTracks = NO;
        for (YouModMediaFormat *format in formats) {
            if (format.idp.length > 0 || format.qualityLabel.length > 0) {
                hasExplicitTracks = YES;
                break;
            }
        }

        [formats sortUsingComparator:^NSComparisonResult(YouModMediaFormat *left, YouModMediaFormat *right) {
            if (left.audioIsDefault != right.audioIsDefault) return left.audioIsDefault ? NSOrderedAscending : NSOrderedDescending;

            BOOL leftOrig = [left.idp hasSuffix:@".4"];
            BOOL rightOrig = [right.idp hasSuffix:@".4"];
            if (leftOrig != rightOrig) return leftOrig ? NSOrderedAscending : NSOrderedDescending;

            BOOL leftHasIdp = left.idp.length > 0;
            BOOL rightHasIdp = right.idp.length > 0;
            if (leftHasIdp != rightHasIdp) return leftHasIdp ? NSOrderedAscending : NSOrderedDescending;

            NSComparisonResult byName = [(left.qualityLabel ?: @"") localizedCaseInsensitiveCompare:(right.qualityLabel ?: @"")];
            if (byName != NSOrderedSame) return byName;

            BOOL leftMP4 = YouModFormatLooksMP4Family(left);
            BOOL rightMP4 = YouModFormatLooksMP4Family(right);
            if (leftMP4 != rightMP4) return leftMP4 ? NSOrderedAscending : NSOrderedDescending;

            if (left.contentLength != right.contentLength)
                return left.contentLength > right.contentLength ? NSOrderedAscending : NSOrderedDescending;
            return NSOrderedSame;
        }];

        if (!hasExplicitTracks) {
            return formats.count > 0 ? @[formats.firstObject] : @[];
        }

        NSMutableArray *unique = [NSMutableArray array];
        NSMutableSet *seenLang = [NSMutableSet set];
        NSMutableSet *seenTitle = [NSMutableSet set];

        for (YouModMediaFormat *format in formats) {
            if (format.idp.length == 0 && format.qualityLabel.length == 0) continue;

            NSString *langCode = format.idp.length ? [[format.idp componentsSeparatedByString:@"."] firstObject].lowercaseString : nil;
            NSString *cleanTitle = [format.qualityLabel.lowercaseString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            NSString *baseTitle = cleanTitle;
            for (NSString *suffix in @[@" (original)", @" [original]", @" (default)", @" [default]"]) {
                if ([baseTitle hasSuffix:suffix]) {
                    baseTitle = [baseTitle substringToIndex:baseTitle.length - suffix.length];
                    break;
                }
            }

            if (langCode.length > 0 && [seenLang containsObject:langCode]) continue;
            if (baseTitle.length > 0 && [seenTitle containsObject:baseTitle]) continue;

            if (langCode.length > 0) [seenLang addObject:langCode];
            if (baseTitle.length > 0) [seenTitle addObject:baseTitle];

            [unique addObject:format];
        }

        if (unique.count == 0 && formats.count > 0) {
            [unique addObject:formats.firstObject];
        }

        return unique.copy;
    }
}

static NSURL *YouModThumbnailURL(YTPlayerViewController *player) {
    if (!player) return nil;
    YTIVideoDetails *details = YouModVideoDetailsForPlayer(player);
    YTIThumbnailDetails *thumbmain = details.thumbnail;
    YTIThumbnailDetails_Thumbnail *bestThumbnail = nil;
    NSUInteger maxPixels = 0;
    
    for (YTIThumbnailDetails_Thumbnail *thumb in thumbmain.thumbnailsArray) {
        NSUInteger pixels = (NSUInteger)thumb.width * (NSUInteger)thumb.height;
        if (pixels > maxPixels) {
            maxPixels = pixels;
            bestThumbnail = thumb;
        }
    }

    return [NSURL URLWithString:bestThumbnail.URL];
}

static void YouModRequestPhotoAccess(void (^completion)(BOOL granted)) {
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus status) {
        completion(status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited);
    }];
}

static void YouModSaveVideoToPhotos(NSURL *fileURL, UIViewController *presenter, void (^completion)(BOOL success, NSError *error)) {
    YouModRequestPhotoAccess(^(BOOL granted) {
        if (!granted) {
            NSError *error = [NSError errorWithDomain:@"YouMod" code:1 userInfo:@{NSLocalizedDescriptionKey: @"Photos access denied"}];
            completion(NO, error);
            return;
        }
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetCreationRequest creationRequestForAssetFromVideoAtFileURL:fileURL];
        } completionHandler:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(success, error);
            });
        }];
    });
}

static void YouModShareItem(id item, UIViewController *presenter) {
    if (!item || !presenter) return;
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[item] applicationActivities:nil];
    YouModConfigureSharePopover(activity, presenter.view);
    [presenter presentViewController:activity animated:YES completion:nil];
}

static void YouModShareFile(NSURL *fileURL, UIViewController *presenter) {
    YouModShareItem(fileURL, presenter);
}

static NSInteger YouModGetPostDownloadAction(void) {
    return INTFORVAL(PostDownloadAction);
}

static void YouModHandlePostDownloadFile(NSURL *fileURL, BOOL isVideo, UIViewController *presenter) {
    if (!fileURL) return;
    NSInteger action = YouModGetPostDownloadAction();

    if (action == PostDownloadActionSaveToPhotos) {
        if (isVideo && YouModVideoFileCanSaveToPhotos(fileURL)) {
            YouModSaveVideoToPhotos(fileURL, presenter, ^(BOOL success, NSError *error) {
                if (success) {
                    YouModSendSuccess(LOC(@"SAVED_TO_PHOTOS"));
                } else {
                    YouModSendError(error.localizedDescription ?: LOC(@"CANNOT_SAVE_TO_PHOTOS"));
                    YouModShareFile(fileURL, presenter);
                }
            });
        } else {
            YouModSendSuccess(LOC(@"DOWNLOAD_COMPLETED"));
            YouModShareFile(fileURL, presenter);
        }
    } else if (action == PostDownloadActionShare) {
        YouModSendSuccess(LOC(@"DOWNLOAD_COMPLETED"));
        YouModShareFile(fileURL, presenter);
    } else if (action == PostDownloadActionAsk) {
        UIView *parent = sbGetNotificationParent();
        [SBSkipNotificationView showDownloadCompleteDialogInView:parent
                                                        message:LOC(@"DOWNLOAD_COMPLETED")
                                                    saveHandler:^{
            if (isVideo && YouModVideoFileCanSaveToPhotos(fileURL)) {
                YouModSaveVideoToPhotos(fileURL, presenter, ^(BOOL success, NSError *error) {
                    if (success) {
                        YouModSendSuccess(LOC(@"SAVED_TO_PHOTOS"));
                    } else {
                        YouModSendError(error.localizedDescription ?: LOC(@"CANNOT_SAVE_TO_PHOTOS"));
                        YouModShareFile(fileURL, presenter);
                    }
                });
            } else {
                YouModSendSuccess(LOC(@"DOWNLOAD_COMPLETED"));
                YouModShareFile(fileURL, presenter);
            }
        } shareHandler:^{
            YouModShareFile(fileURL, presenter);
        } duration:8.0];
    }
}

static void YouModHandlePostDownloadImage(UIImage *image, UIViewController *presenter) {
    if (!image) return;
    NSInteger action = YouModGetPostDownloadAction();

    if (action == PostDownloadActionSaveToPhotos) {
        YouModRequestPhotoAccess(^(BOOL granted) {
            if (!granted) {
                YouModSendError(LOC(@"PHOTO_ACCESS_DENINED"));
                return;
            }
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromImage:image];
            } completionHandler:^(BOOL success, NSError *saveError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) {
                        YouModSendSuccess(LOC(@"SAVED_TO_PHOTOS"));
                    } else {
                        YouModSendError(saveError.localizedDescription ?: LOC(@"SAVE_FAILED"));
                        YouModShareItem(image, presenter);
                    }
                });
            }];
        });
    } else if (action == PostDownloadActionShare) {
        YouModSendSuccess(LOC(@"DOWNLOAD_COMPLETED"));
        YouModShareItem(image, presenter);
    } else if (action == PostDownloadActionAsk) {
        UIView *parent = sbGetNotificationParent();
        [SBSkipNotificationView showDownloadCompleteDialogInView:parent
                                                        message:LOC(@"DOWNLOAD_COMPLETED")
                                                    saveHandler:^{
            YouModRequestPhotoAccess(^(BOOL granted) {
                if (!granted) {
                    YouModSendError(LOC(@"PHOTO_ACCESS_DENINED"));
                    return;
                }
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                } completionHandler:^(BOOL success, NSError *saveError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (success) {
                            YouModSendSuccess(LOC(@"SAVED_TO_PHOTOS"));
                        } else {
                            YouModSendError(saveError.localizedDescription ?: LOC(@"SAVE_FAILED"));
                        }
                    });
                }];
            });
        } shareHandler:^{
            YouModShareItem(image, presenter);
        } duration:8.0];
    }
}

static id parentResponder = nil;

static void YouModPresentMenu(YTPlayerViewController *player, NSArray <YouModMenuItem *> *items, UIViewController *presenter, UIView *sender) {
    YTDefaultSheetController *sheet = [%c(YTDefaultSheetController) sheetControllerWithParentResponder:parentResponder];
    for (YouModMenuItem *item in items) {
        YTActionSheetAction *action;
        if (item.subtitle == nil) {
            action = [%c(YTActionSheetAction) actionWithTitle:item.title iconImage:item.iconImage style:0 handler:^(__unused YTActionSheetAction *action) {
                item.handler();
            }];
        } else {
            action = [%c(YTActionSheetAction) actionWithTitle:item.title subtitle:item.subtitle iconImage:item.iconImage handler:^(__unused YTActionSheetAction *action) {
                item.handler();
            }];
        }
        [sheet addAction:action];
    }
    if (player && player != nil) {
        [sheet addHeaderWithTitle:YouModAuthorForPlayer(player) subtitle:YouModTitleForPlayer(player)];
    }
    if (sender) {
        [sheet presentFromView:sender animated:YES completion:nil];
    } else {
        [sheet presentFromViewController:presenter animated:YES completion:nil];
    }
}

@implementation YouModDownloadCoordinator

+ (instancetype)sharedCoordinator {
    static YouModDownloadCoordinator *coordinator;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        coordinator = [YouModDownloadCoordinator new];
    });
    return coordinator;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configuration.HTTPAdditionalHeaders = @{
            @"User-Agent": @"Mozilla/5.0",
            @"Origin": @"https://www.youtube.com",
            @"Referer": @"https://www.youtube.com/",
        };
        configuration.HTTPMaximumConnectionsPerHost = YouModFastDownloadConcurrency;
        configuration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        configuration.timeoutIntervalForResource = 300;
        _session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    }
    return self;
}

- (void)showProgressWithTitle:(NSString *)title presenter:(UIViewController *)presenter {
    self.presenter = presenter;
    self.baseProgressTitle = title;
    self.downloadStartTime = [NSDate timeIntervalSinceReferenceDate];

    UIView *pillParent = sbGetNotificationParent();
    __weak typeof(self) weakSelf = self;
    self.progressPill = [YMDownloadProgressView showInView:pillParent
        message:[NSString stringWithFormat:@"%@ - 0%%", title]
        cancelAction:^{
            [weakSelf cancelWithMessage:LOC(@"DOWNLOAD_CANCELLED")];
        }];
}

- (void)updateProgressTitle:(NSString *)title progress:(float)progress {
    NSString *displayTitle = [NSString stringWithFormat:@"%@ - %ld%%", title, (long)lrintf(progress * 100.0f)];
    [self.progressPill updateProgress:progress title:displayTitle subtitle:nil];
}

// SABR progress with a speed + size subtitle. When the total is known (the formats'
// contentLength, in self.totalBytes) the percentage and subtitle track downloaded/total
// like the direct/server path; otherwise they fall back to the segment fraction + a
// downloaded-so-far figure. Reuses the "X.X MB/s · Y.Y MB" style.
- (void)updateSABRProgressTitle:(NSString *)title progress:(float)progress bytesDownloaded:(unsigned long long)bytesDownloaded {
    NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - self.downloadStartTime;
    double downloadedMB = (double)bytesDownloaded / 1048576.0;
    double speedMBps = elapsed > 0 ? (downloadedMB / elapsed) : 0;

    NSString *subtitle;
    if (self.totalBytes > 0) {
        // Real percentage from bytes; subtitle shows downloaded / total.
        progress = fminf(fmaxf((float)bytesDownloaded / (float)self.totalBytes, 0.0f), 1.0f);
        double totalMB = (double)self.totalBytes / 1048576.0;
        subtitle = [NSString stringWithFormat:@"%.1f MB/s · %.1f / %.1f MB", speedMBps, downloadedMB, totalMB];
    } else {
        // Total unknown → segment-fraction % + downloaded-so-far.
        subtitle = [NSString stringWithFormat:@"%.1f MB/s · %.1f MB", speedMBps, downloadedMB];
    }

    NSString *displayTitle = [NSString stringWithFormat:@"%@ - %ld%%", title, (long)lrintf(progress * 100.0f)];
    [self.progressPill updateProgress:progress title:displayTitle subtitle:subtitle];
}

- (void)cancelWithMessage:(NSString *)message {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self cancelWithMessage:message];
        });
        return;
    }

    [self.task cancel];
    [self.metadataTask cancel];
    [self.rangeDownloader cancel];
    [self.exporter cancelExport];
    [YMSABR cancelCurrent];
    
    self.task = nil;
    self.metadataTask = nil;
    self.rangeDownloader = nil;
    self.exporter = nil;
    self.fileCompletion = nil;
    self.downloadCompletionBlock = nil;
    
    self.active = NO;
    self.cancelled = YES;
    if (self.progressPill) { [self.progressPill dismiss]; self.progressPill = nil; }
    [self cleanupTemporaryFiles];
    if (message.length) YouModSendError(message);
}

- (void)cleanupTemporaryFiles {
    if (self.videoTempURL) [NSFileManager.defaultManager removeItemAtURL:self.videoTempURL error:nil];
    if (self.audioTempURL) [NSFileManager.defaultManager removeItemAtURL:self.audioTempURL error:nil];
    if (self.destinationURL) [NSFileManager.defaultManager removeItemAtURL:self.destinationURL error:nil];
    self.videoTempURL = nil;
    self.audioTempURL = nil;
    self.destinationURL = nil;
}

- (void)downloadURL:(NSURL *)url toURL:(NSURL *)destinationURL expectedBytes:(unsigned long long)expectedBytes headers:(NSDictionary *)headers completion:(YouModFileDownloadCompletion)completion {
    self.currentResolvedSizeAddedToTotal = NO;
    self.currentExpectedBytes = expectedBytes;
    self.currentBytes = 0;
    if (expectedBytes == 0) {
        __weak typeof(self) weakSelf = self;
        [self resolveExpectedBytesForURL:url headers:headers completion:^(unsigned long long bytes) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.cancelled) return;
            if (bytes > 0) [self adjustCurrentExpectedBytesIfNeeded:bytes];
            [self beginDownloadURL:url toURL:destinationURL expectedBytes:bytes headers:headers allowFast:YES completion:completion];
        }];
        return;
    }
    [self beginDownloadURL:url toURL:destinationURL expectedBytes:expectedBytes headers:headers allowFast:YES completion:completion];
}

- (void)beginDownloadURL:(NSURL *)url toURL:(NSURL *)destinationURL expectedBytes:(unsigned long long)expectedBytes headers:(NSDictionary *)headers allowFast:(BOOL)allowFast completion:(YouModFileDownloadCompletion)completion {
    self.destinationURL = destinationURL;
    self.currentExpectedBytes = expectedBytes;
    self.currentBytes = 0;
    self.finishedCurrentFile = NO;
    self.fileCompletion = completion;
    [NSFileManager.defaultManager removeItemAtURL:destinationURL error:nil];

    if (self.cancelled) {
        if (completion) completion(nil, [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:@{NSLocalizedDescriptionKey: LOC(@"DOWNLOAD_CANCELLED")}]);
        return;
    }

    if (allowFast && expectedBytes == 0) allowFast = NO;

    if (allowFast && expectedBytes >= YouModFastDownloadMinimumBytes) {
        __weak typeof(self) weakSelf = self;
        self.rangeDownloader = [[YouModRangeDownloader alloc] initWithURL:url destinationURL:destinationURL expectedBytes:expectedBytes headers:headers progress:^(unsigned long long completedBytes) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.cancelled) return;
            self.currentBytes = completedBytes;
            [self updateDownloadProgressWithCurrentBytes:completedBytes expectedBytes:expectedBytes];
        } completion:^(NSURL *fileURL, NSError *error) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.cancelled) return;
            self.rangeDownloader = nil;
            if (error) {
                [self beginDownloadURL:url toURL:destinationURL expectedBytes:expectedBytes headers:headers allowFast:NO completion:completion];
                return;
            }
            if (completion) completion(fileURL, nil);
        }];
        [self.rangeDownloader start];
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60.0];
    YouModApplyDownloadHeaders(request, headers);
    self.task = [self.session downloadTaskWithRequest:request];
    [self.task resume];
}

- (void)resolveExpectedBytesForURL:(NSURL *)url headers:(NSDictionary *)headers completion:(void (^)(unsigned long long bytes))completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15.0];
    request.HTTPMethod = @"HEAD";
    YouModApplyDownloadHeaders(request, headers);

    __weak typeof(self) weakSelf = self;
    self.metadataTask = [NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(__unused NSData *data, NSURLResponse *response, __unused NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;

        unsigned long long bytes = 0;
        if (response.expectedContentLength > 0) {
            bytes = (unsigned long long)response.expectedContentLength;
        } else if ([response isKindOfClass:NSHTTPURLResponse.class]) {
            id header = ((NSHTTPURLResponse *)response).allHeaderFields[@"Content-Length"];
            if ([header respondsToSelector:@selector(unsignedLongLongValue)])
                bytes = [header unsignedLongLongValue];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self.metadataTask = nil;
            completion(bytes);
        });
    }];
    [self.metadataTask resume];
}

- (void)updateDownloadProgressWithCurrentBytes:(unsigned long long)currentBytes expectedBytes:(unsigned long long)expectedBytes {
    unsigned long long total = self.totalBytes ?: expectedBytes;
    float progress = total ? (float)(self.completedBytes + currentBytes) / (float)total : 0.0f;
    progress = fminf(fmaxf(progress, 0.0f), 1.0f);

    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval elapsed = now - self.downloadStartTime;
    double speedMBps = 0;
    if (elapsed > 0) {
        speedMBps = ((double)(self.completedBytes + currentBytes) / 1048576.0) / elapsed;
    }
    double totalMB = (double)total / 1048576.0;

    NSString *title = [NSString stringWithFormat:@"%@ - %ld%%", self.baseProgressTitle ?: @"Downloading", (long)lrintf(progress * 100.0f)];
    NSString *subtitle;
    if (total > 0) {
        subtitle = [NSString stringWithFormat:@"%.1f MB/s · %.1f MB", speedMBps, totalMB];
    } else {
        subtitle = [NSString stringWithFormat:@"%.1f MB/s", speedMBps];
    }
    [self.progressPill updateProgress:progress title:title subtitle:subtitle];
}

- (void)adjustCurrentExpectedBytesIfNeeded:(unsigned long long)newExpectedBytes {
    unsigned long long oldExpectedBytes = self.currentExpectedBytes;
    if (newExpectedBytes <= oldExpectedBytes) return;

    self.currentExpectedBytes = newExpectedBytes;
    if (oldExpectedBytes > 0) {
        self.totalBytes += newExpectedBytes - oldExpectedBytes;
    } else if (!self.currentResolvedSizeAddedToTotal) {
        self.totalBytes += newExpectedBytes;
        self.currentResolvedSizeAddedToTotal = YES;
    }
}

- (void)startVideoDownloadWithVideoFormat:(YouModMediaFormat *)videoFormat audioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID {
    if (self.active) {
        YouModSendToast(LOC(@"ALREADY_DOWNLOADING"));
        return;
    }
    [self startDirectVideoDownloadWithVideoFormat:videoFormat audioFormat:audioFormat fileName:fileName presenter:presenter videoID:vidID];
}

- (void)startDirectVideoDownloadWithVideoFormat:(YouModMediaFormat *)videoFormat audioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID {
    [self cleanupTemporaryFiles];
    // On-device SABR path. Checked first: on modern YouTube the format URLs are empty
    // (media flows via SABR), so the URL check below would otherwise abort.
    if (INTFORVAL(DownloadMethod) == DownloadMethodOnDevice) {
        [self startSABRVideoDownloadWithVideoFormat:videoFormat audioFormat:audioFormat fileName:fileName presenter:presenter];
        return;
    }
    NSURL *videoURL = [NSURL URLWithString:videoFormat.urlString];
    NSURL *audioURL = [NSURL URLWithString:audioFormat.urlString];
    if (!videoURL || !audioURL) {
        YouModSendError(LOC(@"NO_STREAM_URL"));
        return;
    }

    self.active = YES;
    self.cancelled = NO;
    self.completedBytes = 0;
    self.totalBytes = videoFormat.contentLength + audioFormat.contentLength;
    self.videoTempURL = YouModTemporaryFileURL(YouModFileExtensionForFormat(videoFormat));
    self.audioTempURL = YouModTemporaryFileURL(YouModFileExtensionForFormat(audioFormat));
    NSString *outputExtension = YouModMergedVideoOutputExtension(videoFormat, audioFormat);
    if (INTFORVAL(DownloadMethod) == DownloadMethodServer) {
        NSString *resolutionStr = [NSString stringWithFormat:@"%d", videoFormat.itag];
        [self triggerSilentDownloadWithQuality:resolutionStr isAudio:NO videoID:vidID presenter:presenter];
        return;
    }
    [self showProgressWithTitle:LOC(@"DOWNLOADING_VIDEO") presenter:presenter];

    __weak typeof(self) weakSelf = self;
    [self downloadURL:videoURL toURL:self.videoTempURL expectedBytes:videoFormat.contentLength headers:nil completion:^(NSURL *videoFileURL, NSError *videoError) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.cancelled) return;
        if (videoError) {
            [self failWithError:videoError ?: [NSError errorWithDomain:@"YouMod" code:2 userInfo:@{NSLocalizedDescriptionKey: @"Video download failed"}]];
            return;
        }

        self.completedBytes += MAX(videoFormat.contentLength, self.currentBytes);
        [self updateProgressTitle:LOC(@"DOWNLOADING_AUDIO") progress:(self.totalBytes ? (float)self.completedBytes / (float)self.totalBytes : 0.5f)];
        [self downloadURL:audioURL toURL:self.audioTempURL expectedBytes:audioFormat.contentLength headers:nil completion:^(NSURL *audioFileURL, NSError *audioError) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.cancelled) return;
            if (audioError) {
                [self failWithError:audioError ?: [NSError errorWithDomain:@"YouMod" code:3 userInfo:@{NSLocalizedDescriptionKey: @"Audio download failed"}]];
                return;
            }
            unsigned long long durationMs = videoFormat.durationMs ?: audioFormat.durationMs;
            [self mergeVideoURL:videoFileURL audioURL:audioFileURL fileName:fileName outputExtension:outputExtension durationMs:durationMs presenter:presenter];
        }];
    }];
}

// On-device SABR download: fetch the chosen mp4 video + m4a audio itags via the SABR
// engine (which captures/replays the app's own signed request), then hand the two
// elementary files to the existing muxer. Additive — the direct/server paths above
// are untouched.
- (void)startSABRVideoDownloadWithVideoFormat:(YouModMediaFormat *)videoFormat audioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter {
    self.active = YES;
    self.cancelled = NO;
    self.completedBytes = 0;
    // Known total from the formats' contentLength (present even on 21.29 where the
    // stream URL is empty) → the pill can show a real % + total size. 0 if unknown.
    self.totalBytes = videoFormat.contentLength + audioFormat.contentLength;
    [self showProgressWithTitle:LOC(@"DOWNLOADING_VIDEO") presenter:presenter];

    unsigned long long durationMs = videoFormat.durationMs ?: audioFormat.durationMs;
    __weak typeof(self) weakSelf = self;
    [YMSABR downloadVideoItag:videoFormat.itag audioItag:audioFormat.itag audioStream:audioFormat.source
        progress:^(float fraction, unsigned long long bytesDownloaded, BOOL isAudio) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.cancelled) return;
            NSString *title = isAudio ? LOC(@"DOWNLOADING_AUDIO") : LOC(@"DOWNLOADING_VIDEO");
            [self updateSABRProgressTitle:title progress:fraction bytesDownloaded:bytesDownloaded];
        }
        completion:^(NSURL *videoURL, NSURL *audioURL, NSString *err) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.cancelled) return;
            if (err || !videoURL || !audioURL) {
                [self failWithError:[NSError errorWithDomain:@"YouMod" code:20 userInfo:@{NSLocalizedDescriptionKey: err ?: LOC(@"DOWNLOAD_FAILED")}]];
                return;
            }
            self.videoTempURL = videoURL; // so cleanupTemporaryFiles removes them afterwards
            self.audioTempURL = audioURL;
            [self mergeVideoURL:videoURL audioURL:audioURL fileName:fileName outputExtension:@"mp4" durationMs:durationMs presenter:presenter];
        }];
}

// On-device SABR audio-only download: fetch the chosen m4a audio itag via SABR, then
// remux the fragmented-mp4 track into a clean .m4a with AVFoundation (passthrough, no
// re-encode). No half-length trim: SABR delivers a properly segmented, complete track.
- (void)startSABRAudioDownloadWithAudioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter {
    self.active = YES;
    self.cancelled = NO;
    self.completedBytes = 0;
    // Known total from the format's contentLength (see video path). 0 if unknown.
    self.totalBytes = audioFormat.contentLength;
    [self showProgressWithTitle:LOC(@"DOWNLOADING_AUDIO") presenter:presenter];

    NSURL *finalURL = YouModUniqueFileURL(fileName, @"m4a");
    __weak typeof(self) weakSelf = self;
    [YMSABR downloadAudioItag:audioFormat.itag audioStream:audioFormat.source
        progress:^(float fraction, unsigned long long bytesDownloaded) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.cancelled) return;
            [self updateSABRProgressTitle:LOC(@"DOWNLOADING_AUDIO") progress:fraction bytesDownloaded:bytesDownloaded];
        }
        completion:^(NSURL *audioURL, NSString *err) {
            __strong typeof(weakSelf) self = weakSelf;
            if (!self || self.cancelled) return;
            if (err || !audioURL) {
                [self failWithError:[NSError errorWithDomain:@"YouMod" code:21 userInfo:@{NSLocalizedDescriptionKey: err ?: LOC(@"DOWNLOAD_FAILED")}]];
                return;
            }
            self.audioTempURL = audioURL; // so cleanupTemporaryFiles removes it afterwards
            [self exportSABRAudioURL:audioURL toURL:finalURL presenter:presenter];
        }];
}

// Remux a SABR audio track (fragmented mp4) to a clean m4a container, full length.
- (void)exportSABRAudioURL:(NSURL *)audioURL toURL:(NSURL *)outputURL presenter:(UIViewController *)presenter {
    [self updateProgressTitle:LOC(@"FINA_VIDEO") progress:0.985f];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:audioURL options:nil];
    AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:asset presetName:AVAssetExportPresetAppleM4A];
    if (!exportSession) {
        [self failWithError:[NSError errorWithDomain:@"YouMod" code:22 userInfo:@{NSLocalizedDescriptionKey: LOC(@"DOWNLOAD_FAILED")}]];
        return;
    }
    exportSession.outputURL = outputURL;
    exportSession.outputFileType = AVFileTypeAppleM4A;
    self.exporter = exportSession;

    __weak typeof(self) weakSelf = self;
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.exporter = nil;
            if (self.cancelled || exportSession.status == AVAssetExportSessionStatusCancelled) return;
            if (exportSession.status == AVAssetExportSessionStatusCompleted) {
                [self completeWithFileURL:outputURL isVideo:NO presenter:presenter];
            } else {
                [self failWithError:exportSession.error ?: [NSError errorWithDomain:@"YouMod" code:23 userInfo:@{NSLocalizedDescriptionKey: LOC(@"DOWNLOAD_FAILED")}]];
            }
        });
    }];
}

- (void)startAudioDownloadWithAudioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID {
    if (self.active) {
        YouModSendToast(LOC(@"ALREADY_DOWNLOADING"));
        return;
    }
    [self startDirectAudioDownloadWithAudioFormat:audioFormat fileName:fileName presenter:presenter videoID:vidID];
}

- (void)startDirectAudioDownloadWithAudioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID {
    [self cleanupTemporaryFiles];
    // On-device SABR path. Checked first: on modern YouTube the format URLs are empty
    // (media flows via SABR), so the URL check below would otherwise abort.
    if (INTFORVAL(DownloadMethod) == DownloadMethodOnDevice) {
        [self startSABRAudioDownloadWithAudioFormat:audioFormat fileName:fileName presenter:presenter];
        return;
    }
    NSURL *audioURL = [NSURL URLWithString:audioFormat.urlString];
    if (!audioURL) {
        YouModSendError(LOC(@"NO_AUDIO_URL"));
        return;
    }

    self.active = YES;
    self.cancelled = NO;
    self.completedBytes = 0;
    self.totalBytes = audioFormat.contentLength;

    NSURL *finalURL = YouModUniqueFileURL(fileName, @"m4a");
    NSString *tempFileName = [NSString stringWithFormat:@"Temp_%@", fileName];
    NSURL *downloadURL = YouModUniqueFileURL(tempFileName, @"m4a");
    self.audioTempURL = downloadURL;
    if (INTFORVAL(DownloadMethod) == DownloadMethodServer) {
        [self triggerSilentDownloadWithQuality:nil isAudio:YES videoID:vidID presenter:presenter];
        return;
    }
    
    [self showProgressWithTitle:LOC(@"DOWNLOADING_AUDIO") presenter:presenter];
    __weak typeof(self) weakSelf = self;
    
    [self downloadURL:audioURL toURL:downloadURL expectedBytes:audioFormat.contentLength headers:nil completion:^(NSURL *fileURL, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || self.cancelled) {
            [[NSFileManager defaultManager] removeItemAtURL:downloadURL error:nil];
            return;
        }
        if (error) {
            [[NSFileManager defaultManager] removeItemAtURL:downloadURL error:nil];
            [self failWithError:error ?: [NSError errorWithDomain:@"YouMod" code:4 userInfo:@{NSLocalizedDescriptionKey: @"Audio download failed"}]];
            return;
        }
        
        [self trimAudioToHalfLengthAtURL:fileURL toURL:finalURL completion:^(NSError *trimError) {
            [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
            if (self.cancelled) return;
            if (trimError) {
                [self failWithError:trimError];
                return;
            }
            [self completeWithFileURL:finalURL isVideo:NO presenter:presenter];
        }];
    }];
}

- (void)trimAudioToHalfLengthAtURL:(NSURL *)inputURL toURL:(NSURL *)outputURL completion:(void (^)(NSError *error))completion {
    [self updateProgressTitle:LOC(@"TRIMMING_AUDIO") progress:0.985f];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:inputURL options:nil];

    [asset loadValuesAsynchronouslyForKeys:@[@"duration"] completionHandler:^{
        NSError *error = nil;
        AVKeyValueStatus status = [asset statusOfValueForKey:@"duration" error:&error];
        if (status != AVKeyValueStatusLoaded) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(error ?: [NSError errorWithDomain:@"YouMod" code:5 userInfo:@{NSLocalizedDescriptionKey: @"Failed to load audio duration"}]);
            });
            return;
        }
        
        CMTime totalDuration = asset.duration;
        CMTime halfDuration = CMTimeMultiplyByFloat64(totalDuration, 0.5);
        CMTimeRange exportTimeRange = CMTimeRangeMake(kCMTimeZero, halfDuration);
        
        AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:asset presetName:AVAssetExportPresetAppleM4A];
        if (!exportSession) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion([NSError errorWithDomain:@"YouMod" code:6 userInfo:@{NSLocalizedDescriptionKey: @"Failed to create export session"}]);
            });
            return;
        }
        
        exportSession.outputURL = outputURL;
        exportSession.outputFileType = AVFileTypeAppleM4A;
        exportSession.timeRange = exportTimeRange;
        
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                if (exportSession.status == AVAssetExportSessionStatusCompleted) {
                    completion(nil);
                } else {
                    completion(exportSession.error ?: [NSError errorWithDomain:@"YouMod" code:7 userInfo:@{NSLocalizedDescriptionKey: @"Audio trim export failed"}]);
                }
            });
        }];
    }];
}

- (void)mergeVideoURL:(NSURL *)videoURL audioURL:(NSURL *)audioURL fileName:(NSString *)fileName outputExtension:(NSString *)outputExtension durationMs:(unsigned long long)durationMs presenter:(UIViewController *)presenter {
    [self updateProgressTitle:LOC(@"MERGING_VID") progress:0.985f];
    NSURL *outputURL = YouModUniqueFileURL(fileName, outputExtension.length ? outputExtension : @"mp4");
    if (durationMs == 0) durationMs = YouModDurationMsForURL(videoURL);

    if (YouModVideoFileCanUseAVFoundation(outputURL)) {
        [self mergeVideoWithAVFoundationVideoURL:videoURL audioURL:audioURL outputURL:outputURL durationMs:durationMs presenter:presenter fallbackError:nil];
    } else {
        [self failWithError:[NSError errorWithDomain:@"YouMod" code:16 userInfo:@{NSLocalizedDescriptionKey: @"Cannot download audio from this stream"}]];
    }
}

- (void)mergeVideoWithAVFoundationVideoURL:(NSURL *)videoURL audioURL:(NSURL *)audioURL outputURL:(NSURL *)outputURL durationMs:(unsigned long long)durationMs presenter:(UIViewController *)presenter fallbackError:(NSError *)fallbackError {
    [self updateProgressTitle:fallbackError ? LOC(@"MERGING_VID_FALLBACK") : LOC(@"MERGING_VID") progress:0.985f];
    AVURLAsset *videoAsset = [AVURLAsset URLAssetWithURL:videoURL options:nil];
    AVURLAsset *audioAsset = [AVURLAsset URLAssetWithURL:audioURL options:nil];
    AVMutableComposition *composition = [AVMutableComposition composition];

    AVAssetTrack *videoTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    AVAssetTrack *audioTrack = [[audioAsset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    if (!videoTrack || !audioTrack) {
        [self failWithError:fallbackError ?: [NSError errorWithDomain:@"YouMod" code:5 userInfo:@{NSLocalizedDescriptionKey: @"Merge failed"}]];
        return;
    }

    CMTime duration = YouModExportDuration(videoAsset, audioAsset, durationMs);
    if (!YouModCMTimeIsUsable(duration)) {
        [self failWithError:fallbackError ?: [NSError errorWithDomain:@"YouMod" code:9 userInfo:@{NSLocalizedDescriptionKey: @"Cannot determine duration"}]];
        return;
    }
    NSError *insertError = nil;
    AVMutableCompositionTrack *compositionVideo = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionVideo insertTimeRange:CMTimeRangeMake(kCMTimeZero, duration) ofTrack:videoTrack atTime:kCMTimeZero error:&insertError];
    compositionVideo.preferredTransform = videoTrack.preferredTransform;
    if (insertError) {
        [self failWithError:insertError];
        return;
    }

    AVMutableCompositionTrack *compositionAudio = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    CMTime audioDuration = YouModMinUsableDuration(duration, audioTrack.timeRange.duration);
    [compositionAudio insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioDuration) ofTrack:audioTrack atTime:kCMTimeZero error:&insertError];
    if (insertError) {
        [self failWithError:insertError];
        return;
    }

    AVAssetExportSession *exporter = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetPassthrough];
    exporter.outputURL = outputURL;
    exporter.outputFileType = AVFileTypeMPEG4;
    exporter.shouldOptimizeForNetworkUse = YES;
    self.exporter = exporter;

    __weak typeof(self) weakSelf = self;
    [exporter exportAsynchronouslyWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            self.exporter = nil;
            if (self.cancelled || exporter.status == AVAssetExportSessionStatusCancelled) return;
            if (exporter.status == AVAssetExportSessionStatusCompleted) {
                [self completeWithFileURL:outputURL isVideo:YES presenter:presenter];
            } else {
                [self failWithError:exporter.error ?: [NSError errorWithDomain:@"YouMod" code:6 userInfo:@{NSLocalizedDescriptionKey: @"Merge failed"}]];
            }
        });
    }];
}

- (void)completeWithFileURL:(NSURL *)fileURL isVideo:(BOOL)isVideo presenter:(UIViewController *)presenter {
    if (self.cancelled) return;
    self.active = NO;
    [self updateProgressTitle:LOC(@"DOWNLOAD_COMPLETED") progress:1.0f];
    if (self.progressPill) { [self.progressPill dismiss]; self.progressPill = nil; }

    YouModHandlePostDownloadFile(fileURL, isVideo, presenter);
}

- (void)failWithError:(NSError *)error {
    if (self.cancelled) return;
    self.active = NO;
    if (self.progressPill) { [self.progressPill dismiss]; self.progressPill = nil; }
    [self cleanupTemporaryFiles];
    YouModSendError(error.localizedDescription ?: LOC(@"DOWNLOAD_FAILED"));
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    self.currentBytes = (unsigned long long)MAX(totalBytesWritten, 0);
    if (totalBytesExpectedToWrite > 0)
        [self adjustCurrentExpectedBytesIfNeeded:(unsigned long long)totalBytesExpectedToWrite];
    if (self.currentBytes > self.currentExpectedBytes)
        [self adjustCurrentExpectedBytesIfNeeded:self.currentBytes];
    [self updateDownloadProgressWithCurrentBytes:self.currentBytes expectedBytes:self.currentExpectedBytes];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    if (self.cancelled) return;
    self.finishedCurrentFile = YES;
    
    NSURL *destURL = self.destinationURL;
    
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtURL:destURL error:nil];
    [[NSFileManager defaultManager] moveItemAtURL:location toURL:destURL error:&error];
    
    if (self.downloadCompletionBlock) {
        self.downloadCompletionBlock(error ? nil : destURL, error ? error.localizedDescription : nil);
        self.downloadCompletionBlock = nil;
    } else if (self.fileCompletion) {
        self.fileCompletion(error ? nil : destURL, error);
        self.fileCompletion = nil;
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error && !self.finishedCurrentFile) {
        if (self.downloadCompletionBlock) {
            self.downloadCompletionBlock(nil, error.localizedDescription);
            self.downloadCompletionBlock = nil;
        } else if (self.fileCompletion) {
            self.fileCompletion(nil, error);
            self.fileCompletion = nil;
        }
    }    
    // We intentionally don't invalidate the shared session here if it's reused.
}

- (NSString *)serverEndpoint {
    if (INTFORVAL(DownloadServerIndex) == 0) {
        return @"https://appropriatenet2928.tail6a9ca7.ts.net/"; // Europe (@AppropriateNet2928)
    } else if (INTFORVAL(DownloadServerIndex) == 1) {
        return @"https://waterserver.freeddns.org/"; // Thailand - Asia (@Tonwalter888)
    }
    return @"";
}

- (void)triggerSilentDownloadWithQuality:(NSString *)quality isAudio:(BOOL)isAudio videoID:(NSString *)vidID presenter:(UIViewController *)presenter {
    __weak typeof(self) weakSelf = self;
    [self requestDownloadForVideoId:vidID isAudio:isAudio quality:quality presenter:presenter completion:^(NSURL *localURL, NSString *errorMsg) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.cancelled) return;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!strongSelf || strongSelf.cancelled) return;
            if (!localURL) { 
                [strongSelf cancelWithMessage:errorMsg];
                return; 
            }
            [strongSelf completeWithFileURL:localURL isVideo:!isAudio presenter:presenter];
        });
    }];
}

- (void)requestDownloadForVideoId:(NSString *)vId isAudio:(BOOL)isAudio quality:(NSString *)quality presenter:(UIViewController *)presenter completion:(void (^)(NSURL *localURL, NSString *errorMsg))completionBlock {
    [self showProgressWithTitle:LOC(@"CONNECTING_TO_SERVER") presenter:presenter];
    NSString *watchURL = [NSString stringWithFormat:@"https://www.youtube.com/watch?v=%@", vId];
    [self startYTDMDownloadWithWatchURL:watchURL format:isAudio ? @"audio" : @"video" formatId:quality presenter:presenter completion:completionBlock];
}

- (void)startYTDMDownloadWithWatchURL:(NSString *)watchURL format:(NSString *)format formatId:(NSString *)formatId presenter:(UIViewController *)presenter completion:(void (^)(NSURL *localURL, NSString *errorMsg))completionBlock {
    if (!self || self.cancelled) return;
    NSString *urlStr = [[self serverEndpoint] stringByAppendingString:@"/api/download"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSMutableDictionary *payload = [@{@"url": watchURL, @"format": format} mutableCopy];
    if (formatId) payload[@"format_id"] = formatId;
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!self || self.cancelled) return;
        if (error || !data) { completionBlock(nil, @"Server unreachable."); return; }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        
        if (json[@"job_id"]) {
            BOOL isAudioDl = [format isEqualToString:@"audio"];
            [self pollJobStatus:json[@"job_id"] isAudio:isAudioDl presenter:presenter completion:completionBlock];
        }
        else {
            completionBlock(nil, json[@"error"] ?: @"Job init failed.");
        }
    }] resume];
}

- (void)pollJobStatus:(NSString *)jobId isAudio:(BOOL)isAudio presenter:(UIViewController *)presenter completion:(void (^)(NSURL *localURL, NSString *errorMsg))completionBlock {
    if (!self || self.cancelled) return;
    
    NSString *urlStr = [NSString stringWithFormat:@"%@/api/status/%@", [self serverEndpoint], jobId];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!self || self.cancelled) return;
        if (error || !data) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ 
                [self pollJobStatus:jobId isAudio:isAudio presenter:presenter completion:completionBlock]; 
            });
            return;
        }
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSString *status = json[@"status"];
        
        if ([status isEqualToString:@"done"]) {
            NSString *singleFileName = json[@"filename"];
            
            if (!singleFileName || singleFileName.length == 0) {
                singleFileName = isAudio ? @"downloaded_file.mp3" : @"downloaded_file.mp4";
            }
            
            [self downloadSingleFile:singleFileName isAudio:isAudio forJobId:jobId presenter:presenter completion:completionBlock];
            
        } else if ([status isEqualToString:@"error"]) {
            completionBlock(nil, json[@"error"] ?: @"Error.");
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{ 
                [self updateProgressTitle:LOC(@"DOWNLOADING_TO_SERVER") progress:0.0f]; 
            });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ 
                [self pollJobStatus:jobId isAudio:isAudio presenter:presenter completion:completionBlock]; 
            });
        }
    }] resume];
}

- (void)downloadSingleFile:(NSString *)filename isAudio:(BOOL)isAudio forJobId:(NSString *)jobId presenter:(UIViewController *)presenter completion:(void (^)(NSURL *localURL, NSString *errorMsg))completionBlock {
    if (!self || self.cancelled) return;
    
    self.downloadCompletionBlock = completionBlock;
    
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    self.destinationURL = [NSURL fileURLWithPath:tempPath];
    
    self.finishedCurrentFile = NO;
    self.currentBytes = 0;
    self.currentExpectedBytes = 0;
    self.baseProgressTitle = isAudio ? LOC(@"DOWNLOADING_AUDIO") : LOC(@"DOWNLOADING_VIDEO");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateProgressTitle:self.baseProgressTitle progress:0.0f];
    });

    NSString *urlString = [NSString stringWithFormat:@"%@/api/file/%@", [self serverEndpoint], jobId];
    
    self.task = [self.session downloadTaskWithURL:[NSURL URLWithString:urlString]];
    self.task.taskDescription = filename;
    
    [self.task resume];
}

@end

static void YouModShowThumbnailViewer(YTPlayerViewController *player, UIViewController *presenter) {
    NSURL *thumbnailURL = YouModThumbnailURL(player);
    if (!thumbnailURL) {
        YouModSendError(LOC(@"NO_THUMBNAIL_FOUND"));
        return;
    }

    [[NSURLSession.sharedSession dataTaskWithURL:thumbnailURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        UIImage *image = data ? [UIImage imageWithData:data] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!image || error) {
                YouModSendError(error.localizedDescription ?: LOC(@"THUMBNAIL_FAILED"));
                return;
            }
            
            YouModThumbnailViewController *viewerVC = [[YouModThumbnailViewController alloc] init];
            viewerVC.thumbnailImage = image;
            viewerVC.modalPresentationStyle = UIModalPresentationFormSheet;
            viewerVC.modalTransitionStyle = UIModalTransitionStyleCoverVertical; 
            
            [presenter presentViewController:viewerVC animated:YES completion:nil];
        });
    }] resume];
}

static void YouModCopyThumbnail(YTPlayerViewController *player, UIViewController *presenter) {
    NSURL *thumbnailURL = YouModThumbnailURL(player);
    if (!thumbnailURL) {
        YouModSendError(LOC(@"NO_THUMBNAIL_FOUND"));
        return;
    }

    YouModSendToast(LOC(@"DOWNLOADING_THUMBNAIL"));
    [[NSURLSession.sharedSession dataTaskWithURL:thumbnailURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        UIImage *image = data ? [UIImage imageWithData:data] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!image || error) {
                YouModSendError(error.localizedDescription ?: LOC(@"THUMBNAIL_FAILED"));
                return;
            }
            [[UIPasteboard generalPasteboard] setImage:image];
            YouModSendSuccess(LOC(@"COPIED_TO_CLIPBOARD"));
        });
    }] resume];
}

static void YouModDownloadThumbnail(YTPlayerViewController *player, UIViewController *presenter) {
    NSURL *thumbnailURL = YouModThumbnailURL(player);
    if (!thumbnailURL) {
        YouModSendError(LOC(@"NO_THUMBNAIL_FOUND"));
        return;
    }

    YouModSendToast(LOC(@"DOWNLOADING_THUMBNAIL"));
    [[NSURLSession.sharedSession dataTaskWithURL:thumbnailURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        UIImage *image = data ? [UIImage imageWithData:data] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!image || error) {
                YouModSendError(error.localizedDescription ?: LOC(@"THUMBNAIL_FAILED"));
                return;
            }
            YouModHandlePostDownloadImage(image, presenter);
        });
    }] resume];
}

static void YouModCopyTextToPasteboard(NSString *text, NSString *successKey) {
    UIPasteboard.generalPasteboard.string = text;
    YouModSendSuccess(LOC(successKey));
}

static void YouModCopyImageToPasteboard(UIImage *image, NSString *successKey) {
    UIPasteboard.generalPasteboard.image = image;
    YouModSendSuccess(LOC(successKey));
}

static void YouModShowCopyVideoInfoSheet(YTPlayerViewController *player, UIViewController *presenter, UIView *sender) {
    NSString *author = YouModAuthorForPlayer(player);
    NSString *title = YouModTitleForPlayer(player);
    NSString *description = YouModDescriptionForPlayer(player);
    NSString *all = [NSString stringWithFormat:@"%@ - %@\n%@", author, title, description];

    NSMutableArray *items = [NSMutableArray array];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_ALL_VID_INFO") subtitle:nil icon:YouModYTIconImage(250, NO, nil) handler:^{
        YouModCopyTextToPasteboard(all, @"COPIED_VID_INFO");
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_AUTHOR") subtitle:nil icon:YouModYTIconImage(250, NO, nil) handler:^{
        YouModCopyTextToPasteboard(author, @"COPIED_AUTHOR");
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_TITLE") subtitle:nil icon:YouModYTIconImage(250, NO, nil) handler:^{
        YouModCopyTextToPasteboard(title, @"COPIED_TITLE");
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_DESCRIPTION") subtitle:nil icon:YouModYTIconImage(250, NO, nil) handler:^{
        YouModCopyTextToPasteboard(description, @"COPIED_DESCRIPTION");
    }]];

    YouModPresentMenu(nil, items, presenter, sender);
}

static void YouModShowAudioTrackSelectionSheet(YTPlayerViewController *player, UIViewController *presenter, UIView *sender, NSString *fileName, BOOL downloadVideo, YouModMediaFormat *videoFormat) {
    NSArray <YouModMediaFormat *> *audioFormats = YouModFormatsForPlayer(player, NO);
    if (audioFormats.count == 0) {
        YouModSendError(LOC(@"NO_AUDIO_STREAM_FOUND"));
        return;
    }

    // Skip the audio-track chooser for a single format, or the server path (which
    // can't fetch a chosen track). Direct and on-device SABR both honor the choice.
    if (audioFormats.count == 1 || INTFORVAL(DownloadMethod) == DownloadMethodServer) {
        YouModMediaFormat *selectedFormat = audioFormats.firstObject;
        if (downloadVideo) {
            [[YouModDownloadCoordinator sharedCoordinator] startVideoDownloadWithVideoFormat:videoFormat audioFormat:selectedFormat fileName:fileName presenter:presenter videoID:player.currentVideoID];
        } else {
            [[YouModDownloadCoordinator sharedCoordinator] startAudioDownloadWithAudioFormat:selectedFormat fileName:fileName presenter:presenter videoID:player.currentVideoID];
        }
        return;
    }

    NSMutableArray *items = [NSMutableArray array];
    for (YouModMediaFormat *format in audioFormats) {
        NSString *rowTitle = format.qualityLabel.length > 0 ? format.qualityLabel : (format.idp.length > 0 ? format.idp : LOC(@"AUDIO"));
        NSString *subtitle = YouModFormatSubtitle(format, NO);
        [items addObject:[YouModMenuItem itemWithTitle:rowTitle subtitle:subtitle icon:YouModYTIconImage(906, NO, nil) handler:^{
            if (downloadVideo) {
                [[YouModDownloadCoordinator sharedCoordinator] startVideoDownloadWithVideoFormat:videoFormat audioFormat:format fileName:fileName presenter:presenter videoID:player.currentVideoID];
            } else {
                [[YouModDownloadCoordinator sharedCoordinator] startAudioDownloadWithAudioFormat:format fileName:fileName presenter:presenter videoID:player.currentVideoID];
            }
        }]];
    }

    YouModPresentMenu(nil, items, presenter, sender);
}

static void YouModShowVideoQualitySheet(YTPlayerViewController *player, UIViewController *presenter, UIView *sender, BOOL isShorts) {
    NSArray <YouModMediaFormat *> *videoFormats = YouModFormatsForPlayer(player, YES);
    NSString *title = YouModTitleForPlayer(player);

    if (videoFormats.count == 0) {
        YouModSendError(LOC(@"NO_VID_AUDIO_STREAM_FOUND"));
        return;
    }

    NSMutableArray *items = [NSMutableArray array];
    for (YouModMediaFormat *format in videoFormats) {
        NSString *rowTitle = format.qualityLabel;
        NSString *subtitle = YouModFormatSubtitle(format, YES);
        if (isShorts) {
            [items addObject:[YouModMenuItem itemWithTitle:rowTitle subtitle:subtitle icon:YouModYTIconImage(769, NO, nil) handler:^{
                YouModShowAudioTrackSelectionSheet(player, presenter, sender, title, YES, format);
            }]];
        } else {
            [items addObject:[YouModMenuItem itemWithTitle:rowTitle subtitle:subtitle icon:YouModYTIconImage(658, NO, nil) handler:^{
                YouModShowAudioTrackSelectionSheet(player, presenter, sender, title, YES, format);
            }]];
        }
    }
    YouModPresentMenu(nil, items, presenter, sender);
}

static void YouModStartDownloadAudio(YTPlayerViewController *player, UIViewController *presenter, UIView *sender) {
    NSString *title = YouModTitleForPlayer(player);
    YouModShowAudioTrackSelectionSheet(player, presenter, sender, title, NO, nil);
}

static void YouModShowCaptionsSheet(YTPlayerViewController *player, UIViewController *presenter, UIView *sender) {
    NSArray *tracks = YouModCaptionTracksForPlayer(player);
    if (tracks.count == 0) {
        YouModSendError(LOC(@"NO_CAPTIONS"));
        return;
    }
    
    NSMutableArray *items = [NSMutableArray array];
    for (YTICaptionTrackEntry *track in tracks) {
        NSString *baseURL = track.baseURL;
        if (baseURL.length == 0) continue;
        
        NSString *languageCode = track.languageCode;
        YTIFormattedString *nameObj = track.name;
        NSString *nameStr = nameObj.dropdownOptionTitle;
        
        [items addObject:[YouModMenuItem itemWithTitle:nameStr subtitle:languageCode icon:YouModYTIconImage(50, NO, nil) handler:^{
            NSString *vttURL = [baseURL stringByAppendingString:@"&fmt=vtt"];
            NSURL *url = [NSURL URLWithString:vttURL];
            if (!url) {
                YouModSendError(LOC(@"NO_CAPTIONS_URL"));
                return;
            }
            YouModSendToast(LOC(@"DOWNLOADING_CAPTIONS"));
            [[NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (error || data.length == 0) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        YouModSendError(LOC(@"CAPTIONS_FAILED"));
                    });
                    return;
                }
                
                NSString *title = YouModTitleForPlayer(player);
                NSString *filename = [NSString stringWithFormat:@"%@.%@", title, languageCode];
                NSURL *tempURL = YouModUniqueFileURL(filename, @"vtt");
                
                NSError *writeError = nil;
                BOOL writeSuccess = [data writeToURL:tempURL options:NSDataWritingAtomic error:&writeError];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (writeSuccess) {
                        YouModSendSuccess(LOC(@"DOWNLOAD_COMPLETED"));
                        YouModShareFile(tempURL, presenter);
                    } else {
                        YouModSendError(writeError.localizedDescription ?: LOC(@"CAPTIONS_FAILED"));
                    }
                });
            }] resume];
        }]];
    }
    
    if (items.count == 0) {
        YouModSendError(LOC(@"NO_CAPTIONS_URL"));
        return;
    }
    
    YouModPresentMenu(nil, items, presenter, sender);
}

static void YouModShowThumbnailSheet(YTPlayerViewController *player, UIViewController *presenter, UIView *sender) {
    NSMutableArray *items = [NSMutableArray array];

    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"SAVE_THUMBNAIL") subtitle:nil icon:YouModYTIconImage(57, NO, nil) handler:^{
        YouModDownloadThumbnail(player, presenter);
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"SHOW_THUMBNAIL") subtitle:nil icon:YouModYTIconImage(208, NO, nil) handler:^{
        YouModShowThumbnailViewer(player, presenter);
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_THUMBNAIL") subtitle:nil icon:YouModYTIconImage(250, NO, nil) handler:^{
        YouModCopyThumbnail(player, presenter);
    }]];

    YouModPresentMenu(nil, items, presenter, sender);
}

static void YouModShowDownloadManager(YTPlayerViewController *player, UIViewController *presenter, UIView *sender, BOOL isShorts) {
    if (!player) {
        YouModSendError(LOC(@"OPEN_VID_BEFORE"));
        return;
    }
    NSMutableArray *items = [NSMutableArray array];
    YTSingleVideoController *sgvidcon = player.activeVideo;
    YTSingleVideo *sgvid = sgvidcon.singleVideo;

    if (!sgvid.isLivePlayback) {
        if (isShorts) {
            [items addObject:[YouModMenuItem itemWithTitle:LOC(@"DOWNLOAD_SHORTS") subtitle:nil icon:YouModYTIconImage(769, NO, nil) handler:^{
                YouModShowVideoQualitySheet(player, presenter, sender, YES);
            }]];
        } else {
            [items addObject:[YouModMenuItem itemWithTitle:LOC(@"DOWNLOAD_VIDEO") subtitle:nil icon:YouModYTIconImage(658, NO, nil) handler:^{
                YouModShowVideoQualitySheet(player, presenter, sender, NO);
            }]];
        }
        [items addObject:[YouModMenuItem itemWithTitle:LOC(@"DOWNLOAD_AUDIO") subtitle:nil icon:YouModYTIconImage(21, NO, nil) handler:^{
            YouModStartDownloadAudio(player, presenter, sender);
        }]];
        [items addObject:[YouModMenuItem itemWithTitle:LOC(@"DOWNLOAD_CAPTIONS") subtitle:nil icon:YouModYTIconImage(50, NO, nil) handler:^{
            YouModShowCaptionsSheet(player, presenter, sender);
        }]];
    }
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"THUMBNAIL_OPTIONS") subtitle:nil icon:YouModYTIconImage(367, NO, nil) handler:^{
        YouModShowThumbnailSheet(player, presenter, sender);
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_VID_INFO") subtitle:nil icon:YouModYTIconImage(250, NO, nil) handler:^{
        YouModShowCopyVideoInfoSheet(player, presenter, sender);
    }]];
    YouModPresentMenu(player, items, presenter, sender);
}

%hook YTPlayerViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    YouModCurrentPlayerViewController = self;
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    if (YouModCurrentPlayerViewController == self)
        YouModCurrentPlayerViewController = nil;
}

%end

NSString *YouModGlobalAuthHeader = nil;

%hook SSOAuthorization
- (id)accessToken {
    id token = %orig;
    if ([token isKindOfClass:[NSString class]] && [(NSString *)token length] > 0) {
        YouModGlobalAuthHeader = [NSString stringWithFormat:@"Bearer %@", token];
    }
    return token;
}
%end

%hook SSOAuthorizationImpl
- (id)accessToken {
    id token = %orig;
    if ([token isKindOfClass:[NSString class]] && [(NSString *)token length] > 0) {
        YouModGlobalAuthHeader = [NSString stringWithFormat:@"Bearer %@", token];
    }
    return token;
}
%end

%hook GNPSSOAuthorizationService
- (id)authToken {
    id token = %orig;
    if ([token isKindOfClass:[NSString class]] && [(NSString *)token length] > 0) {
        YouModGlobalAuthHeader = [NSString stringWithFormat:@"Bearer %@", token];
    }
    return token;
}
%end

void YouModConfigureDownloadButton(_ASDisplayView *view, NSString *iden) {
    if (!IS_ENABLED(DownloadManager) || INTFORVAL(DownloadButtonPosition) == DownloadButtonPositionOverlay) return;
    if ([iden isEqualToString:@"id.ui.add_to.offline.button"]) {
        view.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:view action:@selector(YouModDownloadButtonTapped:)];
        tap.cancelsTouchesInView = YES;
        tap.delaysTouchesBegan = YES;
        tap.delaysTouchesEnded = YES;
        [view addGestureRecognizer:tap];
        objc_setAssociatedObject(view, @selector(YouModDownloadButtonTapped:), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if ([iden isEqualToString:@"id.elements.list_item"]) {
        ASDisplayNode *node = view.keepalive_node;
        NSString *desc = nil;
        @try {
            desc = [[[[node valueForKey:@"_weakNodeController"] valueForKey:@"_weakComponent"] valueForKey:@"_weakOwningComponent"] description];
        } @catch (id ex) {
            return;
        }
        if ([desc containsString:@"download_button_inner.eml"]) {
            view.userInteractionEnabled = YES;
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:view action:@selector(YouModDownloadButtonTapped:)];
            tap.cancelsTouchesInView = YES;
            tap.delaysTouchesBegan = YES;
            tap.delaysTouchesEnded = YES;
            [view addGestureRecognizer:tap];
            objc_setAssociatedObject(view, @selector(YouModDownloadButtonTapped:), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}

static void YouModShowTranslationDialog(NSString *text, UIViewController *presenter) {
    if (!text || text.length == 0 || !presenter) return;
    
    YouModTranslationViewController *vc = [[YouModTranslationViewController alloc] init];
    vc.originalText = text;
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    
    if ([nav respondsToSelector:@selector(sheetPresentationController)]) {
        UISheetPresentationController *sheet = nav.sheetPresentationController;
        if (sheet) {
            sheet.detents = @[ 
                [UISheetPresentationControllerDetent mediumDetent],
                [UISheetPresentationControllerDetent largeDetent]
            ];
            sheet.prefersGrabberVisible = YES;
            sheet.preferredCornerRadius = 24.0;
        }
    } else {
        // Fallback for iOS 14
        nav.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    [presenter presentViewController:nav animated:YES completion:nil];
}

static NSString *YouModExtractCommentText(UIView *cellView) {
    NSString *resultText = nil;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:cellView];

    while (queue.count > 0) {
        UIView *current = queue.firstObject;
        [queue removeObjectAtIndex:0];

        if ([current isKindOfClass:%c(_ASDisplayView)]) {
            BOOL isCommentLabel = [current.accessibilityIdentifier isEqualToString:@"id.comment.content.label"];
            if (isCommentLabel) {
                resultText = current.accessibilityLabel;
                break;
            }
            ASDisplayNode *node = [current performSelector:@selector(keepalive_node)];

            if (![node isKindOfClass:%c(ELMExpandableTextNode)] && ![node isKindOfClass:%c(ELMTextNode)]) {
                BOOL found = NO;
                for (id child in node.yogaChildren) {
                    if ([child isKindOfClass:%c(ELMExpandableTextNode)] || [child isKindOfClass:%c(ELMTextNode)]) {
                        node = child;
                        found = YES;
                        break;
                    }
                }
                if (!found) continue;
            }
            NSString *desc = nil;
            @try {
                desc = [[[[node valueForKey:@"_weakNodeController"] valueForKey:@"_parent"] valueForKey:@"_weakComponent"] description];
            } @catch (id ex) {
                continue;
            }
            if ([desc containsString:@"post_text.eml"]) {
                NSAttributedString *strings = [node valueForKey:@"_attributedText"];
                resultText = strings.string;
                break;
            }
        }

        [queue addObjectsFromArray:current.subviews];
    }

    return resultText;
}

static UIImage *YouModRenderViewToImage(_ASDisplayView *view) {
    if (!view || view.bounds.size.width <= 0 || view.bounds.size.height <= 0) return nil;
    
    UIColor *realBgColor = isDarkMode(view) ? [%c(YTColor) black3] : [%c(YTColor) white1];  
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, [UIScreen mainScreen].scale);
    CGContextRef context = UIGraphicsGetCurrentContext();    
    [realBgColor setFill];
    CGContextFillRect(context, view.bounds);
    [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();    
    return image;
}

/*
static UIImage *YouModExtractPostImage(UIView *cellView) {
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:cellView];
    Class asDisplayClass = NSClassFromString(@"_ASDisplayView");
    Class imageZoomNodeClass = NSClassFromString(@"YTImageZoomNode");
    UIView *targetViewForRender = nil;

    while (queue.count > 0) {
        UIView *current = queue.firstObject;
        [queue removeObjectAtIndex:0];

        if (asDisplayClass && [current isKindOfClass:asDisplayClass]) {
            id node = [current performSelector:@selector(keepalive_node)];
            
            if (imageZoomNodeClass && [node isKindOfClass:imageZoomNodeClass]) {
                if (!targetViewForRender) {
                    targetViewForRender = current;
                }
            }
        }

        @synchronized (current) {
            [queue addObjectsFromArray:current.subviews];
        }
    }

    if (targetViewForRender && targetViewForRender.bounds.size.width > 0 && targetViewForRender.bounds.size.height > 0) {
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:targetViewForRender.bounds.size];
        return [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
            [targetViewForRender.layer renderInContext:rendererContext.CGContext];
        }];
    }

    return nil;
}
*/

void YouModSetupDownloadGestures(_ASDisplayView *view, NSString *iden) {
    if ([iden isEqualToString:@"id.ui.comment_cell"] && IS_ENABLED(DownloadComment)) {
        BOOL hasGesture = NO;
        for (UIGestureRecognizer *g in view.gestureRecognizers) {
            if ([g.name isEqualToString:@"YouModCommentLongPress"]) {
                hasGesture = YES;
                break;
            }
        }
        
        if (!hasGesture) {
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:view action:@selector(YouModHandleCommentLongPress:)];
            longPress.name = @"YouModCommentLongPress";
            longPress.minimumPressDuration = 0.3;
            [view addGestureRecognizer:longPress];
        }
    } else if ([iden isEqualToString:@"id.ui.backstage.original_post"] && IS_ENABLED(DownloadPost)) {
        BOOL hasGesture = NO;
        for (UIGestureRecognizer *g in view.gestureRecognizers) {
            if ([g.name isEqualToString:@"YouModPostLongPress"]) {
                hasGesture = YES;
                break;
            }
        }
        
        if (!hasGesture) {
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:view action:@selector(YouModHandlePostLongPress:)];
            longPress.name = @"YouModPostLongPress";
            longPress.minimumPressDuration = 0.3;
            [view addGestureRecognizer:longPress];
        }
    }
}


void YouModHandleCommentLongPressAction(_ASDisplayView *view, UILongPressGestureRecognizer *sender) {
    if (sender.state != UIGestureRecognizerStateBegan) return;

    NSMutableArray *items = [NSMutableArray array];
    NSString *commentText = YouModExtractCommentText(view);

    if (commentText && commentText.length > 0) {
        [items addObject:[YouModMenuItem itemWithTitle:LOC(@"TRANSLATE_COMMENT") subtitle:nil icon:YouModYTIconImage(897, NO, nil) handler:^{
            UIViewController *presenter = view._viewControllerForAncestor;
            YouModShowTranslationDialog(commentText, presenter);
        }]];

        [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_COMMENT_TEXT") subtitle:nil icon:YouModYTIconImage(243, NO, nil) handler:^{
            YouModCopyTextToPasteboard(commentText, @"COPIED_TO_CLIPBOARD");
        }]];
    }

    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"SAVE_COMMENT_IMAGE") subtitle:nil icon:YouModYTIconImage(367, NO, nil) handler:^{
        UIImage *image = YouModRenderViewToImage(view);
        if (image) {
            UIViewController *p = view._viewControllerForAncestor;
            YouModHandlePostDownloadImage(image, p);
        }
    }]];

    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_COMMENT_IMAGE") subtitle:nil icon:YouModYTIconImage(208, NO, nil) handler:^{
        UIImage *image = YouModRenderViewToImage(view);
        if (image) {
            YouModCopyImageToPasteboard(image, @"COPIED_TO_CLIPBOARD");
        }
    }]];

    UIViewController *presenter = view._viewControllerForAncestor;
    if (!presenter) return;

    YouModPresentMenu(nil, items, presenter, view);
}

void YouModHandlePostLongPressAction(_ASDisplayView *view, UILongPressGestureRecognizer *sender) {
    if (sender.state != UIGestureRecognizerStateBegan) return;

    NSMutableArray *items = [NSMutableArray array];
    NSString *commentText = YouModExtractCommentText(view);

    if (commentText && commentText.length > 0) {
        [items addObject:[YouModMenuItem itemWithTitle:LOC(@"TRANSLATE_POST") subtitle:nil icon:YouModYTIconImage(897, NO, nil) handler:^{
            UIViewController *presenter = view._viewControllerForAncestor;
            YouModShowTranslationDialog(commentText, presenter);
        }]];

        [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_POST_TEXT") subtitle:nil icon:YouModYTIconImage(243, NO, nil) handler:^{
            YouModCopyTextToPasteboard(commentText, @"COPIED_TO_CLIPBOARD");
        }]];
    }

    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"SAVE_POST_IMAGE") subtitle:nil icon:YouModYTIconImage(367, NO, nil) handler:^{
        UIImage *image = YouModRenderViewToImage(view);
        if (image) {
            UIViewController *p = view._viewControllerForAncestor;
            YouModHandlePostDownloadImage(image, p);
        }
    }]];

    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_POST_IMAGE") subtitle:nil icon:YouModYTIconImage(208, NO, nil) handler:^{
        UIImage *image = YouModRenderViewToImage(view);
        if (image) {
            YouModCopyImageToPasteboard(image, @"COPIED_TO_CLIPBOARD");
        }
    }]];

    UIViewController *presenter = view._viewControllerForAncestor;
    if (!presenter) return;

    YouModPresentMenu(nil, items, presenter, view);
}

void YouModHandleDownloadButtonAction(_ASDisplayView *view, UITapGestureRecognizer *sender) {
    if (sender.state != UIGestureRecognizerStateEnded) return;
    UIViewController *presenter = view._viewControllerForAncestor;
    if ([presenter isKindOfClass:%c(YTActionSheetDialogViewController)]) {
        parentResponder = [[presenter valueForKey:@"_delegate"] valueForKey:@"_parentResponder"];
    } else {
        parentResponder = [presenter valueForKey:@"_parentResponder"];
    }
    YouModShowDownloadManager(YouModCurrentPlayerViewController, presenter, view, NO);
}

%hook YTReelWatchPlaybackOverlayView
- (void)layoutSubviews {
    %orig;
    if (!IS_ENABLED(AddDownloadToShorts)) return;
    YTQTMButton *downloadBtn = (YTQTMButton *)[self viewWithTag:1501];
    if (!downloadBtn) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
        UIImage *icon = [[UIImage systemImageNamed:@"arrow.down.circle" withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        downloadBtn = [%c(YTQTMButton) iconButton];
        [downloadBtn setImage:icon forState:UIControlStateNormal];
        downloadBtn.tintColor = [UIColor whiteColor];
        downloadBtn.exclusiveTouch = YES;
        downloadBtn.tag = 1501;
        [downloadBtn addTarget:self action:@selector(didTapYouModShortsDownload:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:downloadBtn];
    }
    CGFloat btnWidth = 64.0;
    CGFloat btnHeight = 60.0;
    YTReelElementAsyncComponentView *pov = nil;
    @try {
        pov = [self valueForKey:@"_playerOverlayView"];
    } @catch (...) {}
    YTReelElementAsyncComponentView *actionBar = [self valueForKey:@"_actionBarComponentView"];
    CGFloat X = actionBar.frame.origin.x;
    CGFloat Y = 0.0;
    if (pov == nil) {
        Y = actionBar.frame.origin.y - 76.0;
        btnHeight = btnHeight + 16.0;
    } else {
        Y = pov.frame.origin.y - 60.0;
        [downloadBtn enableNewTouchFeedback];
    }
    downloadBtn.frame = CGRectMake(X, Y, btnWidth, btnHeight);
    [self bringSubviewToFront:downloadBtn];
}
%new
- (void)didTapYouModShortsDownload:(YTQTMButton *)button {
    YTShortsPlayerViewController *shortsPlayerView = (YTShortsPlayerViewController *)self._viewControllerForAncestor;
    YTPlayerViewController *player = (YTPlayerViewController *)shortsPlayerView.childViewControllers[0];
    UIViewController *presenter = button._viewControllerForAncestor;
    parentResponder = [presenter valueForKey:@"_parentResponder"];
    YouModShowDownloadManager(player, presenter, button, YES);
}
%end

%ctor {
    %init;
    YMOverlayButtonSpec *download = [[YMOverlayButtonSpec alloc] init];
    download.identifier = @"download.video";
    download.symbolName = @"arrow.down.circle";
    download.settingsSymbolName = @"arrow.down.circle";
    download.displayName = LOC(@"DOWNLOAD_BUTTON");
    download.tintColor = [UIColor whiteColor];
    download.sortOrder = 200;
    download.isVisible = ^BOOL(YTPlayerViewController *player) {
        return YMIsOverlayButtonEnabled(@"download.video");
    };
    download.onTap = ^(YTPlayerViewController *player, UIButton *button) {
        UIViewController *presenter = button._viewControllerForAncestor;
        parentResponder = [presenter valueForKey:@"_parentResponder"];
        YouModShowDownloadManager(YouModCurrentPlayerViewController, presenter, button, NO);
    };
    YMRegisterOverlayButton(download);
}

// HUGE thanks to @daisuke1227 for implementing all of this
#import "Headers.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <math.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <stdarg.h>
#import <stdlib.h>

#define TweakName @"YouMod"

static NSBundle *YouModBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:TweakName ofType:@"bundle"];
        if (tweakBundlePath)
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        else
            bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:PS_ROOT_PATH_NS(@"/Library/Application Support/%@.bundle"), TweakName]];
    });
    return bundle;
}

#define LOC(x) [YouModBundle() localizedStringForKey:x value:nil table:nil]

static UIImage *YouModIconImage(NSInteger iconType) {
    YTIIcon *icon = [%c(YTIIcon) new];
    icon.iconType = iconType;
    UIImage *image = [icon iconImageWithColor:[UIColor labelColor]];
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

@interface YouModMenuItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, strong) UIImage *iconImage;
@property (nonatomic, copy) void (^handler)(void);
+ (instancetype)itemWithTitle:(NSString *)title subtitle:(NSString *)subtitle handler:(void (^)(void))handler;
+ (instancetype)itemWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(UIImage *)icon handler:(void (^)(void))handler;
@end

@implementation YouModMenuItem
+ (instancetype)itemWithTitle:(NSString *)title subtitle:(NSString *)subtitle handler:(void (^)(void))handler {
    return [self itemWithTitle:title subtitle:subtitle icon:nil handler:handler];
}
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
@property (nonatomic, assign) int resolution;
@property (nonatomic, assign) BOOL video;
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
@property (nonatomic, strong) UIProgressView *progressView;
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
+ (instancetype)sharedCoordinator;
- (void)startVideoDownloadWithVideoFormat:(YouModMediaFormat *)videoFormat audioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID;
- (void)startAudioDownloadWithAudioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID;
- (void)startDirectVideoDownloadWithVideoFormat:(YouModMediaFormat *)videoFormat audioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID;
- (void)startDirectSingleVideoDownloadWithFormat:(YouModMediaFormat *)format fileName:(NSString *)fileName presenter:(UIViewController *)presenter;
- (void)startDirectAudioDownloadWithAudioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID;
- (void)trimAudioToHalfLengthAtURL:(NSURL *)inputURL toURL:(NSURL *)outputURL completion:(void (^)(NSError *error))completion;
- (void)mergeVideoURL:(NSURL *)videoURL audioURL:(NSURL *)audioURL fileName:(NSString *)fileName outputExtension:(NSString *)outputExtension durationMs:(unsigned long long)durationMs presenter:(UIViewController *)presenter;
- (void)mergeVideoWithAVFoundationVideoURL:(NSURL *)videoURL audioURL:(NSURL *)audioURL outputURL:(NSURL *)outputURL durationMs:(unsigned long long)durationMs presenter:(UIViewController *)presenter fallbackError:(NSError *)fallbackError;
- (void)trimSingleVideoURL:(NSURL *)inputURL outputURL:(NSURL *)outputURL durationMs:(unsigned long long)durationMs presenter:(UIViewController *)presenter;
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
    NSString *device = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? @"iPad" : @"iPhone";
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

        // Aim for ~100 chunks (≈1% per chunk) but respect min/max bounds.
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

static __weak YTPlayerViewController *YouModCurrentPlayerViewController;

void YouModDownloadSetCurrentPlayer(YTPlayerViewController *player) {
    YouModCurrentPlayerViewController = player;
}

YTPlayerViewController *YouModDownloadGetCurrentPlayer(void) {
    return YouModCurrentPlayerViewController;
}

static id YouModObjectFromSelector(id object, SEL selector) {
    if (!object) return nil;
    if ([object respondsToSelector:selector]) {
        return ((id (*)(id, SEL))objc_msgSend)(object, selector);
    }
    @try {
        return [object valueForKey:NSStringFromSelector(selector)];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static UIViewController *YouModTopViewController(UIViewController *root) {
    if (!root) {
        UIWindow *keyWindow = nil;
        for (UIWindow *window in UIApplication.sharedApplication.windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
        root = keyWindow.rootViewController;
    }
    while (root.presentedViewController) root = root.presentedViewController;
    if ([root isKindOfClass:UINavigationController.class])
        return YouModTopViewController(((UINavigationController *)root).topViewController);
    if ([root isKindOfClass:UITabBarController.class])
        return YouModTopViewController(((UITabBarController *)root).selectedViewController);
    return root;
}

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

static NSString *YouModAuthorForPlayer(YTPlayerViewController *player) {
    YTIPlayerResponse *playerData = YouModPlayerDataForPlayer(player);
    YTIVideoDetails *details = playerData.videoDetails;
    return details.author;
}

static NSString *YouModTitleForPlayer(YTPlayerViewController *player) {
    YTIPlayerResponse *playerData = YouModPlayerDataForPlayer(player);
    YTIVideoDetails *details = playerData.videoDetails;
    return details.title;
}

static NSString *YouModDescriptionForPlayer(YTPlayerViewController *player) {
    YTIPlayerResponse *playerData = YouModPlayerDataForPlayer(player);
    YTIVideoDetails *details = playerData.videoDetails;
    NSString *description = details.shortDescription;
    return description;
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
            if (IS_ENABLED(UseOrigAudio) && ![audioidp hasSuffix:@".4"]) return nil;
            format.qualityLabel = audio.displayName;
            format.idp = audioidp;
        }
    }
    format.contentLength = stream.contentLength;
    format.durationMs = stream.approxDurationMs;

    return format;
}

static NSArray <YouModMediaFormat *> *YouModFormatsForPlayer(YTPlayerViewController *player, BOOL video) {
    NSMutableArray *formats = [NSMutableArray array];
    for (YTIFormatStream *stream in YouModAdaptiveFormatObjectsForPlayer(player)) {
        YouModMediaFormat *format = YouModMediaFormatFromStream(stream, video);
        if (format) [formats addObject:format];
    }

    [formats sortUsingComparator:^NSComparisonResult(YouModMediaFormat *left, YouModMediaFormat *right) {
        if (video) {
            NSInteger leftRes = left.resolution;
            NSInteger rightRes = right.resolution;
            if (leftRes != rightRes) return leftRes > rightRes ? NSOrderedAscending : NSOrderedDescending;
            NSInteger leftFPS = left.fps;
            NSInteger rightFPS = right.fps;
            if (leftFPS != rightFPS) return leftFPS > rightFPS ? NSOrderedAscending : NSOrderedDescending;
        }
        
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
        NSString *key = video
            ? [NSString stringWithFormat:@"%@-%ld-%@", format.qualityLabel, (long)fps, YouModMimeDetail(format.mimeType)]
            : [NSString stringWithFormat:@"%@-%@", format.qualityLabel, YouModMimeDetail(format.mimeType)];
        if ([seen containsObject:key]) continue;
        [seen addObject:key];
        [unique addObject:format];
    }
    return unique.copy;
}

static UIViewController *YouModPresenterForSender(UIView *sender, YTPlayerViewController *player) {
    UIViewController *presenter = nil;
    if ([sender respondsToSelector:@selector(_viewControllerForAncestor)])
        presenter = [sender _viewControllerForAncestor];
    if (!presenter) presenter = player;
    return YouModTopViewController(presenter);
}

static YTPlayerViewController *YouModPlayerFromViewController(UIViewController *vc) {
    Class playerClass = NSClassFromString(@"YTPlayerViewController");
    UIViewController *cursor = vc;
    while (cursor) {
        if (playerClass && [cursor isKindOfClass:playerClass]) return (YTPlayerViewController *)cursor;
        id player = YouModObjectFromSelector(cursor, @selector(playerViewController));
        if (playerClass && [player isKindOfClass:playerClass]) return (YTPlayerViewController *)player;
        cursor = cursor.parentViewController;
    }
    return YouModCurrentPlayerViewController;
}

static NSURL *YouModThumbnailURLForVideoID(NSString *videoID) {
    if (videoID.length == 0) return nil;
    NSString *urlString = [NSString stringWithFormat:@"https://i.ytimg.com/vi/%@/hqdefault.jpg", videoID];
    return [NSURL URLWithString:urlString];
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

static void YouModShareFile(NSURL *fileURL, UIViewController *presenter) {
    if (!fileURL || !presenter) return;
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[fileURL] applicationActivities:nil];
    // Fix for iPad and specific presentation alignment
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        activity.popoverPresentationController.sourceView = presenter.view;
        // Position at the bottom center of the screen
        activity.popoverPresentationController.sourceRect = CGRectMake(presenter.view.bounds.size.width / 2, presenter.view.bounds.size.height, 0, 0);
        activity.popoverPresentationController.permittedArrowDirections = 0; // No arrow pointing to a button
    } else {
        // On iPhone, UIActivityViewController naturally comes from the bottom center
        activity.popoverPresentationController.sourceView = presenter.view;
    }
    [presenter presentViewController:activity animated:YES completion:nil];
}

static void YouModPresentMenu(NSString *title, NSArray <YouModMenuItem *> *items, UIViewController *presenter, UIView *sender) {
    presenter = YouModTopViewController(presenter);
    YTDefaultSheetController *sheet = [%c(YTDefaultSheetController) sheetControllerWithParentResponder:presenter];;
    for (YouModMenuItem *item in items) {
        YTActionSheetAction *action = [%c(YTActionSheetAction) actionWithTitle:item.title subtitle:item.subtitle iconImage:item.iconImage handler:^(__unused YTActionSheetAction *action) {
            if (item.handler) item.handler();
        }];
        [sheet addAction:action];
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

- (void)cancelWithMessage:(NSString *)message {
    [self.task cancel];
    [self.metadataTask cancel];
    [self.rangeDownloader cancel];
    [self.exporter cancelExport];
    self.task = nil;
    self.metadataTask = nil;
    self.rangeDownloader = nil;
    self.exporter = nil;
    self.fileCompletion = nil;
    self.active = NO;
    self.cancelled = YES;
    if (self.progressPill) { [self.progressPill dismiss]; self.progressPill = nil; }
    [self cleanupTemporaryFiles];
    if (message.length) YouModSendError(message);
}

- (void)cleanupTemporaryFiles {
    if (self.videoTempURL) [NSFileManager.defaultManager removeItemAtURL:self.videoTempURL error:nil];
    if (self.audioTempURL) [NSFileManager.defaultManager removeItemAtURL:self.audioTempURL error:nil];
    self.videoTempURL = nil;
    self.audioTempURL = nil;
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

- (void)triggerSilentDownloadWithQuality:(NSString *)quality isAudio:(BOOL)isAudio videoID:(NSString *)vidID presenter:(UIViewController *)presenter {
    [self requestDownloadForVideoId:vidID isAudio:isAudio quality:quality presenter:presenter completion:^(NSArray<NSURL *> *localURLs, NSString *errorMsg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!localURLs) { YouModSendError(errorMsg); return; }
            [self completeWithFileURL:localURLs isVideo:!isAudio presenter:presenter];
        });
    }];
}

- (void)startVideoDownloadWithVideoFormat:(YouModMediaFormat *)videoFormat audioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID {
    if (self.active) {
        YouModSendToast(LOC(@"ALREADY_DOWNLOADING"));
        return;
    }
    [self startDirectVideoDownloadWithVideoFormat:videoFormat audioFormat:audioFormat fileName:fileName presenter:presenter videoID:vidID];
}

- (void)startDirectVideoDownloadWithVideoFormat:(YouModMediaFormat *)videoFormat audioFormat:(YouModMediaFormat *)audioFormat fileName:(NSString *)fileName presenter:(UIViewController *)presenter videoID:(NSString *)vidID {
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
    if (IS_ENABLED(DownloadFix)) {
        NSString *resolutionStr = [NSString stringWithFormat:@"%d", videoFormat.resolution];
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

- (void)startDirectSingleVideoDownloadWithFormat:(YouModMediaFormat *)format fileName:(NSString *)fileName presenter:(UIViewController *)presenter {
    NSURL *videoURL = [NSURL URLWithString:format.urlString];
    if (!videoURL) {
        YouModSendError(LOC(@"NO_STREAM_URL"));
        return;
    }

    self.active = YES;
    self.cancelled = NO;
    self.completedBytes = 0;
    self.totalBytes = format.contentLength;
    NSString *extension = YouModFileExtensionForFormat(format);
    BOOL canFinalizeWithAVFoundation = format.durationMs > 0 && YouModPathExtensionIsPhotosVideo(extension);
    NSURL *finalURL = YouModUniqueFileURL(fileName, extension);
    NSURL *downloadURL = canFinalizeWithAVFoundation ? YouModTemporaryFileURL(extension) : finalURL;
    self.videoTempURL = canFinalizeWithAVFoundation ? downloadURL : nil;
    [self showProgressWithTitle:LOC(@"DOWNLOADING_VIDEO") presenter:presenter];

    __weak typeof(self) weakSelf = self;
    [self downloadURL:videoURL toURL:downloadURL expectedBytes:format.contentLength headers:nil completion:^(NSURL *fileURL, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || error) {
            [self failWithError:error ?: [NSError errorWithDomain:@"YouMod" code:8 userInfo:@{NSLocalizedDescriptionKey: @"Video download failed"}]];
            return;
        }
        if (canFinalizeWithAVFoundation) {
            [self trimSingleVideoURL:fileURL outputURL:finalURL durationMs:format.durationMs presenter:presenter];
            return;
        }
        [self completeWithFileURL:fileURL isVideo:YES presenter:presenter];
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
    if (IS_ENABLED(DownloadFix)) {
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

- (void)trimSingleVideoURL:(NSURL *)inputURL outputURL:(NSURL *)outputURL durationMs:(unsigned long long)durationMs presenter:(UIViewController *)presenter {
    [self updateProgressTitle:LOC(@"FINA_VIDEO") progress:0.99f];
    [NSFileManager.defaultManager removeItemAtURL:outputURL error:nil];

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:inputURL options:nil];
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    if (!videoTrack) {
        [self failWithError:[NSError errorWithDomain:@"YouMod" code:10 userInfo:@{NSLocalizedDescriptionKey: @"Cannot finalize video"}]];
        return;
    }

    CMTime duration = YouModExportDuration(asset, nil, durationMs);
    if (!YouModCMTimeIsUsable(duration)) {
        [self failWithError:[NSError errorWithDomain:@"YouMod" code:11 userInfo:@{NSLocalizedDescriptionKey: @"Cannot determine duration"}]];
        return;
    }

    AVMutableComposition *composition = [AVMutableComposition composition];
    NSError *insertError = nil;
    AVMutableCompositionTrack *compositionVideo = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionVideo insertTimeRange:CMTimeRangeMake(kCMTimeZero, duration) ofTrack:videoTrack atTime:kCMTimeZero error:&insertError];
    compositionVideo.preferredTransform = videoTrack.preferredTransform;
    if (insertError) {
        [self failWithError:insertError];
        return;
    }

    AVAssetTrack *audioTrack = [[asset tracksWithMediaType:AVMediaTypeAudio] firstObject];
    if (audioTrack) {
        CMTime audioDuration = YouModMinUsableDuration(duration, audioTrack.timeRange.duration);
        AVMutableCompositionTrack *compositionAudio = [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        [compositionAudio insertTimeRange:CMTimeRangeMake(kCMTimeZero, audioDuration) ofTrack:audioTrack atTime:kCMTimeZero error:&insertError];
        if (insertError) {
            [self failWithError:insertError];
            return;
        }
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
                [self failWithError:exporter.error ?: [NSError errorWithDomain:@"YouMod" code:12 userInfo:@{NSLocalizedDescriptionKey: @"Finalize failed"}]];
            }
        });
    }];
}

- (void)completeWithFileURL:(NSURL *)fileURL isVideo:(BOOL)isVideo presenter:(UIViewController *)presenter {
    if (self.cancelled) return;
    self.active = NO;
    [self updateProgressTitle:LOC(@"DOWNLOAD_COMPLETED") progress:1.0f];
    if (self.progressPill) { [self.progressPill dismiss]; self.progressPill = nil; }
    self.progressView = nil;
    [self cleanupTemporaryFiles];

    if (isVideo && IS_ENABLED(DownloadSaveToPhotos) && YouModVideoFileCanSaveToPhotos(fileURL)) {
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
}

- (void)failWithError:(NSError *)error {
    if (self.cancelled) return;
    self.active = NO;
    if (self.progressPill) { [self.progressPill dismiss]; self.progressPill = nil; }
    self.progressView = nil;
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
    NSError *error = nil;
    [NSFileManager.defaultManager removeItemAtURL:self.destinationURL error:nil];
    [NSFileManager.defaultManager moveItemAtURL:location toURL:self.destinationURL error:&error];
    if (self.fileCompletion) self.fileCompletion(error ? nil : self.destinationURL, error);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error && !self.finishedCurrentFile && self.fileCompletion) {
        self.fileCompletion(nil, error);
    }
}

- (NSString *)serverEndpoint {
    if (INTFORVAL(DownloadServerIndex) == 1) {
        return @"https://appropriatenet.tail6a9ca7.ts.net/"; // Romania - Europe (@AppropriateNet2928)
    } else if (INTFORVAL(DownloadServerIndex) == 2) {
        return @"http://203.159.93.128/"; // Thailand - Asia (@Tonwalter888) 
    }
    return @"";
}

- (void)requestDownloadForVideoId:(NSString *)vId isAudio:(BOOL)isAudio quality:(NSString *)quality presenter:(UIViewController *)presenter completion:(void (^)(NSArray<NSURL *> *localURLs, NSString *errorMsg))completionBlock {
    NSString *watchURL = [NSString stringWithFormat:@"https://www.youtube.com/watch?v=%@", vId];
    [self startYTDMDownloadWithWatchURL:watchURL format:isAudio ? @"audio" : @"video" formatId:quality presenter:presenter completion:completionBlock];
}

- (void)startYTDMDownloadWithWatchURL:(NSString *)watchURL format:(NSString *)format formatId:(NSString *)formatId presenter:(UIViewController *)presenter completion:(void (^)(NSArray<NSURL *> *localURLs, NSString *errorMsg))completionBlock {
    NSString *urlStr = [[self serverEndpoint] stringByAppendingString:@"/api/download"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSMutableDictionary *payload = [@{@"url": watchURL, @"format": format} mutableCopy];
    if (formatId) payload[@"format_id"] = formatId;
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) { completionBlock(nil, @"Server unreachable."); return; }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (json[@"job_id"]) [self pollJobStatus:json[@"job_id"] presenter:presenter completion:completionBlock];
        else completionBlock(nil, json[@"error"] ?: @"Job init failed.");
    }] resume];
}

- (void)pollJobStatus:(NSString *)jobId presenter:(UIViewController *)presenter completion:(void (^)(NSArray<NSURL *> *localURLs, NSString *errorMsg))completionBlock {
    NSString *urlStr = [NSString stringWithFormat:@"%@/api/status/%@", [self serverEndpoint], jobId];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self pollJobStatus:jobId presenter:presenter completion:completionBlock]; });
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSString *status = json[@"status"];
        
        if ([status isEqualToString:@"done"]) {
            id filesData = json[@"files"] ?: json[@"filenames"] ?: json[@"filename"] ?: json[@"file_path"];
            NSMutableArray<NSString *> *filesToDownload = [NSMutableArray array];
            
            if ([filesData isKindOfClass:[NSArray class]]) {
                for (id fileItem in filesData) {
                    if ([fileItem isKindOfClass:[NSString class]]) [filesToDownload addObject:[fileItem lastPathComponent]];
                }
            } else if ([filesData isKindOfClass:[NSString class]]) {
                [filesToDownload addObject:[filesData lastPathComponent]];
            }
            
            if (filesToDownload.count == 0) {
                completionBlock(nil, @"No files found in job.");
                return;
            }
            
            [self downloadMultipleFiles:filesToDownload forJobId:jobId presenter:presenter completion:completionBlock];
        } else if ([status isEqualToString:@"error"]) {
            completionBlock(nil, json[@"error"] ?: @"Error.");
        } else {
            // LOC(@"DOWNLOADING_TO_SERVER")
            dispatch_async(dispatch_get_main_queue(), ^{ [self showProgressWithTitle:@"Downloading to the server..." presenter:presenter]; });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self pollJobStatus:jobId presenter:presenter completion:completionBlock]; });
        }
    }] resume];
}

- (void)downloadMultipleFiles:(NSArray<NSString *> *)filenames forJobId:(NSString *)jobId presenter:(UIViewController *)presenter completion:(void (^)(NSArray<NSURL *> *localURLs, NSString *errorMsg))completionBlock {
    NSMutableArray<NSURL *> *localURLs = [NSMutableArray array];
    __block NSInteger remaining = filenames.count;
    __block NSString *errStr = nil;
    NSInteger totalCount = filenames.count;
    // LOC(@"DOWNLOADING")
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showProgressWithTitle:@"Downloading..." presenter:presenter];
    });

    for (NSString *filename in filenames) {
        NSString *encodedName = [filename stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSString *urlString = [NSString stringWithFormat:@"%@/api/file/%@?filename=%@", [self serverEndpoint], jobId, encodedName];
        
        [[[NSURLSession sharedSession] downloadTaskWithURL:[NSURL URLWithString:urlString] completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            if (error || !location) {
                errStr = error.localizedDescription;
            } else {
                NSString *tempDir = NSTemporaryDirectory();
                NSURL *destURL = [NSURL fileURLWithPath:[tempDir stringByAppendingPathComponent:filename]];
                [[NSFileManager defaultManager] removeItemAtURL:destURL error:nil];
                
                if ([[NSFileManager defaultManager] moveItemAtURL:location toURL:destURL error:nil]) {
                    @synchronized(localURLs) { [localURLs addObject:destURL]; }
                }
            }
            
            @synchronized(self) {
                remaining--;
                float progress = (float)(totalCount - remaining) / (float)totalCount;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self updateProgressTitle:@"Downloading..." progress:progress];
                    [self updateDownloadProgressWithCurrentBytes:(totalCount - remaining) expectedBytes:totalCount];
                });
                
                if (remaining == 0) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (localURLs.count > 0) completionBlock(localURLs, nil);
                        else completionBlock(nil, errStr ?: @"Download sync failed.");
                    });
                }
            }
        }] resume];
    }
}

@end

static void YouModShowThumbnailViewer(NSString *videoID, UIViewController *presenter) {
    NSURL *thumbnailURL = YouModThumbnailURLForVideoID(videoID);
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
            viewerVC.modalPresentationStyle = UIModalPresentationOverFullScreen;
            viewerVC.modalTransitionStyle = UIModalTransitionStyleCoverVertical; 
            
            [presenter presentViewController:viewerVC animated:YES completion:nil];
        });
    }] resume];
}

static void YouModCopyThumbnail(NSString *videoID, UIViewController *presenter) {
    NSURL *thumbnailURL = YouModThumbnailURLForVideoID(videoID);
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

static void YouModDownloadThumbnail(NSString *videoID, UIViewController *presenter) {
    NSURL *thumbnailURL = YouModThumbnailURLForVideoID(videoID);
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
            YouModRequestPhotoAccess(^(BOOL granted) {
                if (!granted) {
                    YouModSendError(LOC(@"PHOTO_ACCESS_DENINED"));
                    return;
                }
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                } completionHandler:^(BOOL success, NSError *saveError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (success) YouModSendSuccess(LOC(@"SAVED_TO_PHOTOS")); else YouModSendError(saveError.localizedDescription ?: LOC(@"SAVE_FAILED"));
                    });
                }];
            });
        });
    }] resume];
}

static void YouModCopyTextToPasteboard(NSString *text, NSString *successKey) {
    UIPasteboard.generalPasteboard.string = text;
    YouModSendSuccess(LOC(successKey));
}

static void YouModShowCopyVideoInfoSheet(YTPlayerViewController *player, UIViewController *presenter, UIView *sender) {
    NSString *author = YouModAuthorForPlayer(player);
    NSString *title = YouModTitleForPlayer(player);
    NSString *description = YouModDescriptionForPlayer(player);
    NSString *all = [NSString stringWithFormat:@"%@ - %@\n%@", author, title, description];

    NSMutableArray *items = [NSMutableArray array];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_ALL_VID_INFO") subtitle:LOC(@"COPY_ALL_VID_INFO_DESC") icon:YouModIconImage(250) handler:^{
        YouModCopyTextToPasteboard(all, @"COPIED_VID_INFO");
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_AUTHOR") subtitle:LOC(@"COPY_AUTHOR_DESC") icon:YouModIconImage(250) handler:^{
        YouModCopyTextToPasteboard(author, @"COPIED_AUTHOR");
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_TITLE") subtitle:LOC(@"COPY_TITLE_DESC") icon:YouModIconImage(250) handler:^{
        YouModCopyTextToPasteboard(title, @"COPIED_TITLE");
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_DESCRIPTION") subtitle:LOC(@"COPY_DESCRIPTION_DESC") icon:YouModIconImage(250) handler:^{
        YouModCopyTextToPasteboard(description, @"COPIED_DESCRIPTION");
    }]];

    YouModPresentMenu(LOC(@"COPY_VID_INFO"), items, presenter, sender);
}

static void YouModShowAudioTrackSelectionSheet(YTPlayerViewController *player, UIViewController *presenter, UIView *sender, NSString *fileName, BOOL downloadVideo, YouModMediaFormat *videoFormat) {
    NSArray <YouModMediaFormat *> *audioFormats = YouModFormatsForPlayer(player, NO);
    if (audioFormats.count == 0) {
        YouModSendError(LOC(@"NO_AUDIO_STREAM_FOUND"));
        return;
    }

    if (audioFormats.count == 1) {
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
        NSString *rowTitle = format.qualityLabel;
        NSString *subtitle = YouModFormatSubtitle(format, NO);
        [items addObject:[YouModMenuItem itemWithTitle:rowTitle subtitle:subtitle icon:YouModIconImage(906) handler:^{
            if (downloadVideo) {
                [[YouModDownloadCoordinator sharedCoordinator] startVideoDownloadWithVideoFormat:videoFormat audioFormat:format fileName:fileName presenter:presenter videoID:player.currentVideoID];
            } else {
                [[YouModDownloadCoordinator sharedCoordinator] startAudioDownloadWithAudioFormat:format fileName:fileName presenter:presenter videoID:player.currentVideoID];
            }
        }]];
    }

    YouModPresentMenu(LOC(@"DOWNLOAD_AUDIO"), items, presenter, sender);
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
            [items addObject:[YouModMenuItem itemWithTitle:rowTitle subtitle:subtitle icon:YouModIconImage(769) handler:^{
                YouModShowAudioTrackSelectionSheet(player, presenter, sender, title, YES, format);
            }]];
        } else {
            [items addObject:[YouModMenuItem itemWithTitle:rowTitle subtitle:subtitle icon:YouModIconImage(658) handler:^{
                YouModShowAudioTrackSelectionSheet(player, presenter, sender, title, YES, format);
            }]];
        }
    }
    YouModPresentMenu(LOC(@"DOWNLOAD_VIDEO"), items, presenter, sender);
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
        
        [items addObject:[YouModMenuItem itemWithTitle:nameStr subtitle:languageCode icon:YouModIconImage(50) handler:^{
            NSString *vttURL = [baseURL stringByAppendingString:@"&fmt=vtt"];
            NSURL *url = [NSURL URLWithString:vttURL];
            if (!url) {
                YouModSendError(LOC(@"NO_CAPTIONS_URL"));
                return;
            }
            YouModSendToast(LOC(@"DOWNLOADING_CAPTIONS"));
            [[NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (error || data.length == 0) {
                        YouModSendError(LOC(@"CAPTIONS_FAILED"));
                        return;
                    }
                    NSString *videoID = player.currentVideoID;
                    NSString *filename = [NSString stringWithFormat:@"%@_%@.vtt", videoID, languageCode];
                    NSURL *tempURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:filename]];
                    [data writeToURL:tempURL atomically:YES];
                    YouModSendSuccess(LOC(@"DOWNLOAD_COMPLETED"));
                    YouModShareFile(tempURL, presenter);
                });
            }] resume];
        }]];
    }
    
    if (items.count == 0) {
        YouModSendError(LOC(@"NO_CAPTIONS_URL"));
        return;
    }
    
    YouModPresentMenu(LOC(@"DOWNLOAD_CAPTIONS"), items, presenter, sender);
}

static void YouModShowThumbnailSheet(YTPlayerViewController *player, UIViewController *presenter, UIView *sender) {
    NSString *videoID = player.currentVideoID;

    NSMutableArray *items = [NSMutableArray array];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"SAVE_THUMBNAIL") subtitle:LOC(@"SAVE_THUMBNAIL_DESC") icon:YouModIconImage(57) handler:^{
        YouModDownloadThumbnail(videoID, presenter);
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"SHOW_THUMBNAIL") subtitle:LOC(@"SHOW_THUMBNAIL_DESC") icon:YouModIconImage(208) handler:^{
        YouModShowThumbnailViewer(videoID, presenter);
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_THUMBNAIL") subtitle:LOC(@"COPY_THUMBNAIL_DESC") icon:YouModIconImage(250) handler:^{
        YouModCopyThumbnail(videoID, presenter);
    }]];

    YouModPresentMenu(LOC(@"COPY_VID_INFO"), items, presenter, sender);
}

static void YouModShowDownloadManager(YTPlayerViewController *player, UIViewController *presenter, UIView *sender, BOOL isShorts) {
    if (!player) {
        YouModSendError(LOC(@"OPEN_VID_BEFORE"));
        return;
    }
    NSMutableArray *items = [NSMutableArray array];

    if (isShorts) {
        [items addObject:[YouModMenuItem itemWithTitle:LOC(@"DOWNLOAD_SHORTS") subtitle:LOC(@"DOWNLOAD_SHORTS_DESC") icon:YouModIconImage(769) handler:^{
            YouModShowVideoQualitySheet(player, presenter, sender, YES);
        }]];
    } else {
        [items addObject:[YouModMenuItem itemWithTitle:LOC(@"DOWNLOAD_VIDEO") subtitle:LOC(@"DOWNLOAD_VIDEO_DESC") icon:YouModIconImage(658) handler:^{
            YouModShowVideoQualitySheet(player, presenter, sender, NO);
        }]];
    }
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"DOWNLOAD_AUDIO") subtitle:LOC(@"DOWNLOAD_AUDIO_DESC") icon:YouModIconImage(21) handler:^{
        YouModStartDownloadAudio(player, presenter, sender);
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"DOWNLOAD_CAPTIONS") subtitle:LOC(@"DOWNLOAD_CAPTIONS_DESC") icon:YouModIconImage(50) handler:^{
        YouModShowCaptionsSheet(player, presenter, sender);
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"THUMBNAIL_OPTIONS") subtitle:LOC(@"THUMBNAIL_OPTIONS_DESC") icon:YouModIconImage(367) handler:^{
        YouModShowThumbnailSheet(player, presenter, sender);
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_VID_INFO") subtitle:LOC(@"COPY_VID_INFO_DESC") icon:YouModIconImage(250) handler:^{
        YouModShowCopyVideoInfoSheet(player, presenter, sender);
    }]];
    YouModPresentMenu(LOC(@"DOWNLOAD_MANAGER"), items, presenter, sender);
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

void YouModConfigureDownloadButton(_ASDisplayView *view) {
    if (!IS_ENABLED(DownloadManager)) return;
    if (objc_getAssociatedObject(view, @selector(YouModDownloadButtonTapped:))) return;

    // For iPad (Old ID)
    if ([view.accessibilityIdentifier isEqualToString:@"id.ui.add_to.offline.button"]) {
        view.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:view action:@selector(YouModDownloadButtonTapped:)];
        tap.cancelsTouchesInView = YES;
        tap.delaysTouchesBegan = YES;
        tap.delaysTouchesEnded = YES;
        [view addGestureRecognizer:tap];
        objc_setAssociatedObject(view, @selector(YouModDownloadButtonTapped:), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%hook _ASDisplayView

%new
- (void)YouModDownloadButtonTapped:(UITapGestureRecognizer *)sender {
    if (sender.state != UIGestureRecognizerStateEnded) return;
    UIViewController *presenter = YouModPresenterForSender(self, YouModCurrentPlayerViewController);
    YTPlayerViewController *player = YouModPlayerFromViewController(presenter);
    YouModShowDownloadManager(player, presenter, self, NO);
}

%end

// Download button in Shorts
%hook YTReelWatchPlaybackOverlayView

- (void)layoutSubviews {
    %orig;
    if (!IS_ENABLED(DownloadManager) || !IS_ENABLED(AddDownloadToShorts)) return;
    UIView *likeButtonView = nil;
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:%c(YTReelPlayerButton)]) {
            likeButtonView = subview;
            break;
        }
    }
    
    if (!likeButtonView) return;
    
    YTQTMButton *downloadBtn = (YTQTMButton *)[self viewWithTag:1501];
    if (!downloadBtn) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
        // Template rendering so YTQTMButton's tint colours the glyph reliably.
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
    
    CGFloat pX = likeButtonView.frame.origin.x;
    CGFloat pY;
    // In older YT versions, the button frame is 0, 0. So we will manually set the button frame.
    if (likeButtonView.frame.origin.y == 0) {
        pY = likeButtonView.frame.origin.y + 80.0;
    } else {
        pY = likeButtonView.frame.origin.y + 85.0;
    }
    
    downloadBtn.frame = CGRectMake(pX, pY, btnWidth, btnHeight);
    
    [self bringSubviewToFront:downloadBtn];
}

%new
- (void)didTapYouModShortsDownload:(UIButton *)button {
    // Loop to find playerview
    UIResponder *responder = self.nextResponder;
    while (responder && ![responder isKindOfClass:%c(YTShortsPlayerViewController)]) {
        responder = responder.nextResponder;
    }
    if (responder) {
        YTShortsPlayerViewController *shortsPlayerView = (YTShortsPlayerViewController *)responder;
        YTPlayerViewController *player = (YTPlayerViewController *)shortsPlayerView.childViewControllers[0];
        UIViewController *presenter = YouModPresenterForSender(button, player);
        YouModShowDownloadManager(player, presenter, button, YES);
    }
}

%end

%ctor {
    // An explicit constructor must call %init itself; without it Logos does not
    // initialize the hooks in this file.
    %init;
    // Register the download button in the player overlay's custom button row.
    // sortOrder 200 places it to the left of the SponsorBlock toggle (sortOrder 100).
    YMOverlayButtonSpec *download = [[YMOverlayButtonSpec alloc] init];
    download.identifier = @"download.video";
    download.symbolName = @"arrow.down.circle";
    download.tintColor = [UIColor whiteColor];
    download.sortOrder = 200;
    download.isVisible = ^BOOL(YTPlayerViewController *player) {
        return IS_ENABLED(DownloadManager);
    };
    download.onTap = ^(YTPlayerViewController *player, UIButton *button) {
        UIViewController *presenter = YouModPresenterForSender(button, player ?: YouModCurrentPlayerViewController);
        YTPlayerViewController *resolved = YouModPlayerFromViewController(presenter) ?: player ?: YouModCurrentPlayerViewController;
        YouModShowDownloadManager(resolved, presenter, button, NO);
    };
    YMRegisterOverlayButton(download);
}

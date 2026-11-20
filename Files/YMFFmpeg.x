#import "Headers.h"
#import <objc/message.h>
#import <os/log.h>
#import <dlfcn.h>

static Class gFFmpegKitClass = nil;
static Class gReturnCodeClass = nil;
static NSString *gLoadFailure = nil;
static BOOL gFFmpegInitDone = NO;

#define YMFFmpegLog(fmt, ...) os_log([YMFFmpegHelpers logHandle], "[YouMod] " fmt, ##__VA_ARGS__)

// ffmpegKit loading and synchronous command execution.
@implementation YMFFmpegHelpers

+ (os_log_t)logHandle {
    static os_log_t handle; static dispatch_once_t once;
    dispatch_once(&once, ^{ handle = os_log_create("dev.water888.youmod", "ffmpeg"); });
    return handle;
}

#pragma mark - Loading

+ (NSArray<NSString *> *)libraries {
    return @[@"libavutil", @"libswresample", @"libswscale",
             @"libavcodec", @"libavformat", @"libavfilter", @"libavdevice"];
}

+ (NSString *)frameworkBinaryPathForRoot:(NSString *)root name:(NSString *)name {
    return [[root stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"framework"]]
            stringByAppendingPathComponent:name];
}

+ (void)ensureLoaded {
    if (gFFmpegInitDone) return;
    gFFmpegInitDone = YES;
    NSString *root = [YMHelpers bundle].bundlePath;
    if (root.length == 0) {
        gLoadFailure = @"YouMod.bundle not found";
        return;
    }
    for (NSString *library in [YMFFmpegHelpers libraries]) {
        NSString *path = [YMFFmpegHelpers frameworkBinaryPathForRoot:root name:library];
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            gLoadFailure = [NSString stringWithFormat:@"missing %@", library];
            YMFFmpegLog("ffmpeg unavailable: %{public}@", gLoadFailure);
            return;
        }
        if (!dlopen(path.UTF8String, RTLD_NOW | RTLD_GLOBAL)) {
            gLoadFailure = [NSString stringWithFormat:@"dlopen %@: %s", library, dlerror() ?: "unknown"];
            YMFFmpegLog("ffmpeg unavailable: %{public}@", gLoadFailure);
            return;
        }
    }
    NSString *facade = [YMFFmpegHelpers frameworkBinaryPathForRoot:root name:@"ffmpegkit"];
    if (!dlopen(facade.UTF8String, RTLD_NOW | RTLD_GLOBAL)) {
        gLoadFailure = [NSString stringWithFormat:@"dlopen ffmpegkit: %s", dlerror() ?: "unknown"];
        YMFFmpegLog("ffmpeg unavailable: %{public}@", gLoadFailure);
        return;
    }
    gFFmpegKitClass = NSClassFromString(@"FFmpegKit");
    gReturnCodeClass = NSClassFromString(@"ReturnCode");
    if (!gFFmpegKitClass || !gReturnCodeClass) {
        gLoadFailure = @"frameworks loaded but FFmpegKit classes absent";
        YMFFmpegLog("ffmpeg unavailable: %{public}@", gLoadFailure);
        return;
    }
    YMFFmpegLog("ffmpeg ready (%{public}@)", root.lastPathComponent);
}

#pragma mark - Running

+ (BOOL)runSync:(NSArray<NSString *> *)arguments failureOut:(NSString **)failureOut {
    if (!YMFFmpegIsAvailable()) {
        if (failureOut) *failureOut = YMFFmpegUnavailableReason();
        return NO;
    }
    SEL execute = @selector(executeWithArguments:);
    if (![gFFmpegKitClass respondsToSelector:execute]) {
        if (failureOut) *failureOut = @"FFmpegKit has no executeWithArguments:";
        return NO;
    }
    id session = ((id (*)(id, SEL, id))objc_msgSend)(gFFmpegKitClass, execute, arguments);
    if (!session) {
        if (failureOut) *failureOut = @"ffmpeg session did not start";
        return NO;
    }
    id returnCode = ((id (*)(id, SEL))objc_msgSend)(session, @selector(getReturnCode));
    BOOL success = ((BOOL (*)(id, SEL, id))objc_msgSend)(gReturnCodeClass, @selector(isSuccess:), returnCode);
    if (!success && failureOut) {
        id output = ((id (*)(id, SEL))objc_msgSend)(session, @selector(getOutput));
        NSString *log = [output isKindOfClass:NSString.class] ? output : @"";
        NSArray<NSString *> *lines = [log componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];
        NSUInteger take = MIN((NSUInteger)6, lines.count);
        *failureOut = [[lines subarrayWithRange:NSMakeRange(lines.count - take, take)]
                       componentsJoinedByString:@"\n"];
    }
    return success;
}

@end

BOOL YMFFmpegIsAvailable(void) {
    [YMFFmpegHelpers ensureLoaded];
    return gFFmpegKitClass != nil;
}

NSString *YMFFmpegUnavailableReason(void) {
    [YMFFmpegHelpers ensureLoaded];
    if (gFFmpegKitClass) return nil;
    return gLoadFailure ?: @"unknown";
}

BOOL YMFFmpegConvertStartupVideo(NSURL *inputURL, NSURL *outputURL, NSString **failureOut) {
    if (!inputURL.isFileURL || !outputURL.isFileURL) {
        if (failureOut) *failureOut = @"Startup video conversion requires local files";
        return NO;
    }
    NSArray<NSString *> *arguments = @[
        @"-y", @"-hide_banner", @"-nostdin",
        @"-i", inputURL.path,
        @"-t", @"10",
        @"-map", @"0:v:0",
        // Keep the primary audio stream so AVPlayer has one default track.
        @"-map", @"0:a:0?",
        @"-vf", @"scale='min(1920,iw)':'min(1080,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2",
        // FFmpegKitNext has no GPL encoders; native mpeg4 keeps this available.
        @"-c:v", @"mpeg4", @"-q:v", @"4",
        @"-c:a", @"aac", @"-b:a", @"128k",
        @"-movflags", @"+faststart", @"-f", @"mp4",
        outputURL.path
    ];
    [[NSFileManager defaultManager] removeItemAtURL:outputURL error:nil];
    return [YMFFmpegHelpers runSync:arguments failureOut:failureOut];
}

void YMFFmpegMuxTracks(NSURL *videoURL, NSArray<NSURL *> *audioURLs, NSArray<YMCaptionTrack *> *subtitles,
                       NSURL *outputURL, void (^completion)(BOOL success, NSString *failure)) {
    if (!completion) return;
    if (!videoURL && audioURLs.count == 0) {
        completion(NO, @"nothing to mux");
        return;
    }
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray<NSString *> *arguments = [@[@"-y", @"-hide_banner", @"-nostdin"] mutableCopy];

        NSUInteger inputIndex = 0;
        NSUInteger videoInput = NSNotFound;
        if (videoURL) {
            [arguments addObjectsFromArray:@[@"-i", videoURL.path]];
            videoInput = inputIndex++;
        }
        NSMutableArray<NSNumber *> *audioInputs = [NSMutableArray array];
        for (NSURL *audioURL in audioURLs) {
            [arguments addObjectsFromArray:@[@"-i", audioURL.path]];
            [audioInputs addObject:@(inputIndex++)];
        }

        NSMutableArray<NSNumber *> *subtitleInputs = [NSMutableArray array];
        for (YMCaptionTrack *track in subtitles) {
            if (!track.localURL) continue;
            [arguments addObjectsFromArray:@[@"-i", track.localURL.path]];
            [subtitleInputs addObject:@(inputIndex++)];
        }

        if (videoURL) {
            [arguments addObjectsFromArray:@[@"-map", [NSString stringWithFormat:@"%lu:v:0", (unsigned long)videoInput]]];
        }
        for (NSNumber *input in audioInputs) {
            [arguments addObjectsFromArray:@[@"-map", [NSString stringWithFormat:@"%@:a:0", input]]];
        }

        for (NSNumber *input in subtitleInputs) {
            [arguments addObjectsFromArray:@[@"-map", [NSString stringWithFormat:@"%@:s:0", input]]];
        }

        [arguments addObjectsFromArray:@[@"-c:v", @"copy", @"-c:a", @"copy"]];

        NSString *extension = outputURL.pathExtension.lowercaseString;
        BOOL isMP4 = [extension isEqualToString:@"mp4"] || [extension isEqualToString:@"m4a"];

        if (subtitleInputs.count > 0) {
            NSUInteger position = 0;
            for (YMCaptionTrack *track in subtitles) {
                if (!track.localURL) continue;
                if (track.languageCode.length > 0) {
                    [arguments addObjectsFromArray:@[
                        [NSString stringWithFormat:@"-metadata:s:s:%lu", (unsigned long)position],
                        [NSString stringWithFormat:@"language=%@", track.languageCode]]];
                }
                position++;
            }
        }

        if (isMP4) {
            [arguments addObjectsFromArray:@[@"-movflags", @"+faststart"]];
        }

        [arguments addObject:outputURL.path];

        [[NSFileManager defaultManager] removeItemAtURL:outputURL error:nil];

        NSString *failure = nil;
        NSDate *started = [NSDate date];
        BOOL ok = [YMFFmpegHelpers runSync:arguments failureOut:&failure];
        YMFFmpegLog("mux %{public}s in %{public}.0fms%{public}@",
                    ok ? "ok" : "FAILED", [[NSDate date] timeIntervalSinceDate:started] * 1000.0,
                    ok ? @"" : [@" — " stringByAppendingString:failure ?: @"?"]);
        completion(ok, ok ? nil : failure);
    });
}

void YMFFmpegMux(NSURL *videoURL, NSURL *audioURL, NSArray<YMCaptionTrack *> *subtitles,
                 NSURL *outputURL, void (^completion)(BOOL success, NSString *failure)) {
    YMFFmpegMuxTracks(videoURL, audioURL ? @[audioURL] : @[], subtitles, outputURL, completion);
}

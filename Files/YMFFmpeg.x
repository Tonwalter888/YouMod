#import "Headers.h"
#import <objc/message.h>
#import <os/log.h>
#import <dlfcn.h>

static os_log_t YMFFmpegLogHandle(void) {
    static os_log_t handle; static dispatch_once_t once;
    dispatch_once(&once, ^{ handle = os_log_create("dev.water888.youmod", "ffmpeg"); });
    return handle;
}
#define YMFFmpegLog(fmt, ...) os_log(YMFFmpegLogHandle(), "[YouMod] " fmt, ##__VA_ARGS__)

static Class gFFmpegKitClass = nil;
static Class gReturnCodeClass = nil;
static NSString *gLoadFailure = nil;
static BOOL gFFmpegInitDone = NO;

#pragma mark - Loading

static NSArray<NSString *> *YMFFmpegLibraries(void) {
    return @[@"libavutil", @"libswresample", @"libswscale",
             @"libavcodec", @"libavformat", @"libavfilter", @"libavdevice"];
}

static NSString *YMFrameworkBinaryPath(NSString *root, NSString *name) {
    return [[root stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"framework"]]
            stringByAppendingPathComponent:name];
}

static void YMFFmpegEnsureLoaded(void) {
    if (gFFmpegInitDone) return;
    gFFmpegInitDone = YES;
    NSString *root = YouModBundle().bundlePath;
    if (root.length == 0) {
        gLoadFailure = @"YouMod.bundle not found";
        return;
    }
    for (NSString *library in YMFFmpegLibraries()) {
        NSString *path = YMFrameworkBinaryPath(root, library);
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
    NSString *facade = YMFrameworkBinaryPath(root, @"ffmpegkit");
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

BOOL YMFFmpegIsAvailable(void) {
    YMFFmpegEnsureLoaded();
    return gFFmpegKitClass != nil;
}

NSString *YMFFmpegUnavailableReason(void) {
    YMFFmpegEnsureLoaded();
    if (gFFmpegKitClass) return nil;
    return gLoadFailure ?: @"unknown";
}

#pragma mark - Running

static BOOL YMFFmpegRunSync(NSArray<NSString *> *arguments, NSString **failureOut) {
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
        BOOL ok = YMFFmpegRunSync(arguments, &failure);
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

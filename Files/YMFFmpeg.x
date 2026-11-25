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

#pragma mark - Language tags

// MP4/Matroska stream language tags are ISO 639-2 (three letters). YouTube gives two-letter codes such as "en" or "pt-BR". Anything unknown becomes "und" rather than a bad tag.
static NSString *YMISO639Language(NSString *code) {
    static NSDictionary<NSString *, NSString *> *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        table = @{@"af":@"afr", @"ar":@"ara", @"az":@"aze", @"be":@"bel", @"bg":@"bul", @"bn":@"ben", @"bs":@"bos",
                  @"ca":@"cat", @"cs":@"ces", @"cy":@"cym", @"da":@"dan", @"de":@"deu", @"el":@"ell", @"en":@"eng",
                  @"es":@"spa", @"et":@"est", @"eu":@"eus", @"fa":@"fas", @"fi":@"fin", @"fil":@"fil", @"fr":@"fra",
                  @"gl":@"glg", @"gu":@"guj", @"he":@"heb", @"iw":@"heb", @"hi":@"hin", @"hr":@"hrv", @"hu":@"hun",
                  @"hy":@"hye", @"id":@"ind", @"is":@"isl", @"it":@"ita", @"ja":@"jpn", @"ka":@"kat", @"kk":@"kaz",
                  @"km":@"khm", @"kn":@"kan", @"ko":@"kor", @"lo":@"lao", @"lt":@"lit", @"lv":@"lav", @"mk":@"mkd",
                  @"ml":@"mal", @"mn":@"mon", @"mr":@"mar", @"ms":@"msa", @"my":@"mya", @"ne":@"nep", @"nl":@"nld",
                  @"no":@"nor", @"nb":@"nob", @"pa":@"pan", @"pl":@"pol", @"pt":@"por", @"ro":@"ron", @"ru":@"rus",
                  @"si":@"sin", @"sk":@"slk", @"sl":@"slv", @"sq":@"sqi", @"sr":@"srp", @"sv":@"swe", @"sw":@"swa",
                  @"ta":@"tam", @"te":@"tel", @"th":@"tha", @"tr":@"tur", @"uk":@"ukr", @"ur":@"urd", @"uz":@"uzb",
                  @"vi":@"vie", @"zh":@"zho", @"zu":@"zul", @"am":@"amh", @"ha":@"hau", @"ig":@"ibo", @"yo":@"yor"};
    });
    NSString *base = [[code lowercaseString] componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"-_."]].firstObject;
    if (base.length == 0) return @"und";
    if (table[base]) return table[base];
    return base.length == 3 ? base : @"und";
}

void YMFFmpegMuxTracks(NSURL *videoURL, NSArray<NSURL *> *audioURLs, NSArray<YMFormat *> *audioFormats, NSArray<YMCaptionTrack *> *subtitles,
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

        void (^tag)(NSString *, NSUInteger, NSString *, NSString *) = ^(NSString *kind, NSUInteger index, NSString *key, NSString *value) {
            if (value.length == 0) return;
            [arguments addObjectsFromArray:@[[NSString stringWithFormat:@"-metadata:s:%@:%lu", kind, (unsigned long)index],
                                             [NSString stringWithFormat:@"%@=%@", key, value]]];
        };
        NSUInteger defaultAudio = 0;
        for (NSUInteger i = 0; i < audioInputs.count && i < audioFormats.count; i++) {
            YMFormat *f = audioFormats[i];
            if (f.isOriginal || f.audioIsDefault) { defaultAudio = i; break; }
        }
        for (NSUInteger i = 0; i < audioInputs.count; i++) {
            YMFormat *f = i < audioFormats.count ? audioFormats[i] : nil;
            NSString *language = f.audioTrackID.length > 0 ? YMISO639Language([f.audioTrackID componentsSeparatedByString:@"."].firstObject) : nil;
            tag(@"a", i, @"language", language);
            tag(@"a", i, @"title", f.audioTrackName);
            if (isMP4) tag(@"a", i, @"handler_name", f.audioTrackName);
            if (audioInputs.count > 1) {
                [arguments addObjectsFromArray:@[[NSString stringWithFormat:@"-disposition:a:%lu", (unsigned long)i], i == defaultAudio ? @"default" : @"0"]];
            }
        }
        NSUInteger subtitlePosition = 0;
        for (YMCaptionTrack *track in subtitles) {
            if (!track.localURL) continue;
            tag(@"s", subtitlePosition, @"language", YMISO639Language(track.languageCode));
            tag(@"s", subtitlePosition, @"title", track.name);
            if (isMP4) tag(@"s", subtitlePosition, @"handler_name", track.name);
            subtitlePosition++;
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
    YMFFmpegMuxTracks(videoURL, audioURL ? @[audioURL] : @[], nil, subtitles, outputURL, completion);
}


#pragma mark - Probe

NSDictionary *YMFFmpegProbe(NSURL *fileURL) {
    if (!fileURL.isFileURL || !YMFFmpegIsAvailable()) return nil;
    Class probe = NSClassFromString(@"FFprobeKit");
    SEL getInfo = NSSelectorFromString(@"getMediaInformation:");
    if (!probe || ![probe respondsToSelector:getInfo]) return nil;
    id session = ((id (*)(id, SEL, id))objc_msgSend)(probe, getInfo, fileURL.path);
    if (![session respondsToSelector:NSSelectorFromString(@"getMediaInformation")]) return nil;
    id info = ((id (*)(id, SEL))objc_msgSend)(session, NSSelectorFromString(@"getMediaInformation"));
    if (!info) return nil;
    NSMutableArray<NSDictionary *> *streams = [NSMutableArray array];
    NSArray *list = ((id (*)(id, SEL))objc_msgSend)(info, NSSelectorFromString(@"getStreams"));
    for (id stream in list) {
        id all = [stream respondsToSelector:NSSelectorFromString(@"getAllProperties")]
            ? ((id (*)(id, SEL))objc_msgSend)(stream, NSSelectorFromString(@"getAllProperties")) : nil;
        if ([all isKindOfClass:NSDictionary.class]) [streams addObject:all];
    }
    NSString *duration = ((id (*)(id, SEL))objc_msgSend)(info, NSSelectorFromString(@"getDuration"));
    return @{@"duration": [duration isKindOfClass:NSString.class] ? duration : @"", @"streams": streams};
}

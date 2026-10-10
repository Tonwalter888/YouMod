#import "Headers.h"
#import <stdarg.h>

static NSString *YMFormatsLogPath(void) {
    static NSString *path = nil; static dispatch_once_t o;
    dispatch_once(&o, ^{
        path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"youmod-formats.log"];
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    });
    return path;
}
static void YMFormatsLogMsg(NSString *format, ...) {
    va_list ap; va_start(ap, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:ap];
    va_end(ap);
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:YMFormatsLogPath()];
    NSString *line = [msg stringByAppendingString:@"\n"];
    @try {
        if (!fh) {
            [line writeToFile:YMFormatsLogPath() atomically:YES encoding:NSUTF8StringEncoding error:nil];
        } else {
            [fh seekToEndOfFile];
            [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            [fh closeFile];
        }
    } @catch (id e) {}
}
#define YMFormatsLog(fmt, ...) YMFormatsLogMsg(@"" fmt, ##__VA_ARGS__)

@implementation YMFormat

- (BOOL)isAudio {
    return !self.isVideo;
}

- (NSString *)displayLabel {
    if (!self.isVideo) {
        if (self.audioTrackName.length > 0) {
            NSString *name = self.audioTrackName;
            NSRange originalSuffix = [name rangeOfString:@" original" options:NSCaseInsensitiveSearch | NSBackwardsSearch];
            BOOL nameSaysOriginal = originalSuffix.location != NSNotFound && NSMaxRange(originalSuffix) == name.length;
            if (nameSaysOriginal) name = [name substringToIndex:originalSuffix.location];
            if (self.isAutoDubbed) {
                return [NSString stringWithFormat:LOC(@"AUDIO_AUTO_DUBBED"), name];
            }
            return name;
        }
        NSString *first = [self.audioTrackID componentsSeparatedByString:@"."].firstObject;
        if (first.length > 0) {
            return [[NSLocale currentLocale] localizedStringForLanguageCode:first] ?: first;
        }
        return LOC(@"AUDIO_ORIGINAL");
    }
    NSMutableString *label = [NSMutableString string];
    [label appendString:(self.qualityLabel.length > 0 ? self.qualityLabel : [NSString stringWithFormat:@"%dp", self.height])];
    if (self.isHDR && ![label containsString:@"HDR"]) {
        [label appendString:@" HDR"];
    }
    return label;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<YMFormat %d %@ %@ %lldB%@>",
            self.itag, self.codec ?: @"?", self.displayLabel, self.contentLength,
            self.urlString ? @" +url" : @""];
}

@end

@implementation YMCaptionTrack
@end

@protocol YMFormatStreamReading <NSObject>
- (int)itag;
- (NSString *)mimeType;
- (long long)contentLength;
- (unsigned long long)approxDurationMs;
- (long long)bitrate;
- (NSString *)xtags;
- (int)height;
- (int)width;
- (int)fps;
- (NSString *)qualityLabel;
- (id)colorInfo;
- (id)audioTrack;
@end

@protocol YMAudioTrackReading <NSObject>
- (NSString *)id_p;
- (NSString *)displayName;
@optional
- (BOOL)isAutoDubbed;
- (BOOL)isOriginal;
- (BOOL)isDubbed;
- (BOOL)audioIsDefault;
@end

@protocol YMCaptionReading <NSObject>
- (NSString *)baseURL;
- (NSString *)languageCode;
- (id)name;
@end

static NSString *YMFormatValueForXtagsKey(NSString *xtags, NSString *key) {
    if (xtags.length == 0) return nil;
    NSMutableString *b64 = [xtags mutableCopy];
    [b64 replaceOccurrencesOfString:@"-" withString:@"+" options:0 range:NSMakeRange(0, b64.length)];
    [b64 replaceOccurrencesOfString:@"_" withString:@"/" options:0 range:NSMakeRange(0, b64.length)];
    while ((b64.length & 3) != 0) [b64 appendString:@"="];
    NSData *data = [[NSData alloc] initWithBase64EncodedString:b64 options:0];
    if (data.length < 2) return nil;
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSUInteger total = data.length;
    NSUInteger pos = 0;
    while (pos + 1 < total) {
        if (bytes[pos] != 10) return nil;
        NSUInteger recEnd = pos + 2 + bytes[pos + 1];
        if (recEnd > total) return nil;
        NSString *foundKey = nil;
        NSString *foundValue = nil;
        NSUInteger fpos = pos + 2;
        NSUInteger fend = pos + 3;
        if (fend < recEnd) {
            while (YES) {
                NSUInteger flen = bytes[fend];
                NSUInteger fvalEnd = fpos + 2 + flen;
                if (fvalEnd > recEnd) break;
                uint8_t tag = bytes[fpos];
                NSString *s = [[NSString alloc] initWithBytes:&bytes[fpos + 2] length:flen encoding:NSUTF8StringEncoding];
                if (tag == 10) {
                    foundKey = s;
                    break;
                }
                if (tag == 18) foundValue = s;
                fend = fvalEnd + 1;
                fpos = fvalEnd;
                if (fvalEnd + 1 >= recEnd) break;
            }
        }
        if ([foundKey isEqualToString:key]) return foundValue;
        pos = recEnd;
        if (recEnd + 1 >= total) return nil;
    }
    return nil;
}

NSArray<YMFormat *> *YMFormatsFromResponse(YTPlayerResponse *response) {
    id streaming = [[response playerData] streamingData];
    NSArray *adaptive = [streaming adaptiveFormatsArray];
    NSMutableArray<YMFormat *> *out = [NSMutableArray arrayWithCapacity:adaptive.count];
    for (id<YMFormatStreamReading> stream in adaptive) {
        NSString *mime = [stream mimeType];
        YMFormatsLog("raw itag=%d mime=%@ height=%d width=%d fps=%d quality=%@ len=%lld",
                     (int)[stream itag], mime, (int)[stream height], (int)[stream width],
                     (int)[stream fps], (NSString *)[stream qualityLabel], (long long)[stream contentLength]);
        if (mime.length == 0) { YMFormatsLog("skip itag=%d: empty mime", (int)[stream itag]); continue; }
        YMFormat *f = [YMFormat new];
        f.source = stream;
        f.itag = [stream itag];
        f.mimeType = mime;
        NSString *codec = nil;
        NSRange codecsRange = [mime rangeOfString:@"codecs=\""];
        if (codecsRange.location != NSNotFound) {
            NSString *rest = [mime substringFromIndex:(codecsRange.location + codecsRange.length)];
            NSRange end = [rest rangeOfString:@"\""];
            if (end.location != NSNotFound) {
                NSString *first = [[rest substringToIndex:end.location] componentsSeparatedByString:@","].firstObject;
                codec = [[[first componentsSeparatedByString:@"."].firstObject stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet] copy];
            }
        }
        f.codec = codec;
        f.isVideo = [mime.lowercaseString hasPrefix:@"video/"];
        f.contentLength = [stream contentLength];
        f.durationMs = [stream approxDurationMs];
        f.bitrate = (int)[stream bitrate];
        f.xtags = [stream xtags];
        if (f.isVideo) {
            f.height = [stream height];
            f.width = [stream width];
            f.fps = [stream fps];
            f.qualityLabel = [stream qualityLabel];
            id colorInfo = [stream colorInfo];
            BOOL hdr = colorInfo && (([colorInfo transferCharacteristics] & ~2) == 16);
            if (!hdr && [f.qualityLabel containsString:@"HDR"]) hdr = YES;
            f.isHDR = hdr;
        } else {
            NSString *acont = YMFormatValueForXtagsKey(f.xtags, @"acont");
            f.isDRC = [YMFormatValueForXtagsKey(f.xtags, @"drc") isEqualToString:@"1"];
            id<YMAudioTrackReading> track = (id<YMAudioTrackReading>)[stream audioTrack];
            if (track) {
                f.audioTrackID = [track id_p];
                f.audioTrackName = [track displayName];
                f.audioIsDefault = [track respondsToSelector:@selector(audioIsDefault)] && [track audioIsDefault];
            }
            BOOL trackAutoDubbed = [track respondsToSelector:@selector(isAutoDubbed)] && [track isAutoDubbed];
            BOOL trackOriginal = [track respondsToSelector:@selector(isOriginal)] && [track isOriginal];
            BOOL trackDubbed = [track respondsToSelector:@selector(isDubbed)] && [track isDubbed];
            BOOL nameSaysOriginal = [f.audioTrackName rangeOfString:@"original" options:NSCaseInsensitiveSearch].location != NSNotFound;
            f.isAutoDubbed = trackAutoDubbed || [acont isEqualToString:@"dubbed-auto"];
            f.isDubbed = f.isAutoDubbed || trackDubbed || [acont hasPrefix:@"dubbed"];
            f.isOriginal = !f.isAutoDubbed && (trackOriginal || !acont.length || [acont isEqualToString:@"original"] || nameSaysOriginal);
            YMFormatsLog("audio itag=%d class=%@ track=%@ acont=%@ xtags=%lu original=%d autoDubbed=%d dubbed=%d selectors=%d/%d/%d",
                         f.itag, NSStringFromClass([track class]), f.audioTrackName, acont, (unsigned long)f.xtags.length,
                         f.isOriginal, f.isAutoDubbed, f.isDubbed,
                         [track respondsToSelector:@selector(isOriginal)],
                         [track respondsToSelector:@selector(isAutoDubbed)],
                         [track respondsToSelector:@selector(isDubbed)]);
        }
        [out addObject:f];
    }
    YMFormatsLog("parsed %lu formats", (unsigned long)out.count);
    return out;
}

NSArray<YMFormat *> *YMFormatsFromPlayer(YTPlayerViewController *player) {
    id response = [player respondsToSelector:@selector(contentPlayerResponse)]
        ? [player contentPlayerResponse]
        : [player playerResponse];
    return YMFormatsFromResponse(response);
}

static NSArray<NSString *> *YMVideoCodecPreference(void) {
    static NSArray<NSString *> *pref = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ pref = @[@"av01", @"vp09", @"avc1"]; });
    return pref;
}

static NSArray<NSString *> *YMAudioCodecPreference(void) {
    static NSArray<NSString *> *pref = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ pref = @[@"opus", @"mp4a"]; });
    return pref;
}

NSArray<NSString *> *YMVideoCodecsInFormats(NSArray<YMFormat *> *formats) {
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    for (NSString *codec in YMVideoCodecPreference()) {
        for (YMFormat *f in formats) {
            if (f.isVideo && [f.codec isEqualToString:codec]) {
                [out addObject:codec];
                break;
            }
        }
    }
    for (YMFormat *f in formats) {
        if (f.isVideo && f.codec.length > 0 && ![out containsObject:f.codec]) {
            [out addObject:f.codec];
        }
    }
    return out;
}

NSArray<YMFormat *> *YMVideoFormatsForCodec(NSArray<YMFormat *> *formats, NSString *codec) {
    NSMutableArray<YMFormat *> *matching = [NSMutableArray array];
    for (YMFormat *f in formats) {
        if (f.isVideo && [f.codec isEqualToString:codec]) [matching addObject:f];
    }
    YMFormatsLog("codec %@ match %lu/%lu", codec, (unsigned long)matching.count, (unsigned long)formats.count);
    [matching sortUsingComparator:^NSComparisonResult(YMFormat *a, YMFormat *b) {
        if (a.height != b.height) return a.height > b.height ? NSOrderedAscending : NSOrderedDescending;
        if (a.fps != b.fps) return a.fps > b.fps ? NSOrderedAscending : NSOrderedDescending;
        if (a.isHDR != b.isHDR) return a.isHDR ? NSOrderedAscending : NSOrderedDescending;
        if (a.contentLength != b.contentLength) return a.contentLength > b.contentLength ? NSOrderedAscending : NSOrderedDescending;
        return NSOrderedSame;
    }];
    NSMutableArray<YMFormat *> *out = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (YMFormat *f in matching) {
        NSString *key = [NSString stringWithFormat:@"%d-%d-%d", f.height, f.fps, f.isHDR];
        YMFormatsLog("row itag=%d h=%d fps=%d hdr=%d key=%@", f.itag, f.height, f.fps, f.isHDR, key);
        if (![seen containsObject:key]) {
            [seen addObject:key];
            [out addObject:f];
        }
    }
    YMFormatsLog("codec %@ rows %lu", codec, (unsigned long)out.count);
    return out;
}

NSArray<NSString *> *YMAudioCodecsInFormats(NSArray<YMFormat *> *formats) {
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    for (NSString *codec in YMAudioCodecPreference()) {
        for (YMFormat *f in formats) {
            if (!f.isVideo && [f.codec isEqualToString:codec]) {
                [out addObject:codec];
                break;
            }
        }
    }
    for (YMFormat *f in formats) {
        if (!f.isVideo && f.codec.length > 0 && ![out containsObject:f.codec]) {
            [out addObject:f.codec];
        }
    }
    return out;
}

NSArray<YMFormat *> *YMAudioTracksForCodec(NSArray<YMFormat *> *formats, NSString *codec) {
    NSMutableArray<YMFormat *> *matching = [NSMutableArray array];
    for (YMFormat *f in formats) {
        if (!f.isVideo && [f.codec isEqualToString:codec]) [matching addObject:f];
    }
    return YMAudioTracksInFormats(matching);
}

NSArray<YMFormat *> *YMAudioTracksInFormats(NSArray<YMFormat *> *formats) {
    NSMutableArray<YMFormat *> *audios = [NSMutableArray array];
    for (YMFormat *f in formats) {
        if (!f.isVideo) [audios addObject:f];
    }
    [audios sortUsingComparator:^NSComparisonResult(YMFormat *a, YMFormat *b) {
        if (a.isOriginal != b.isOriginal) return a.isOriginal ? NSOrderedAscending : NSOrderedDescending;
        if (a.isDRC != b.isDRC) return a.isDRC ? NSOrderedDescending : NSOrderedAscending;
        if (a.audioIsDefault != b.audioIsDefault) return a.audioIsDefault ? NSOrderedAscending : NSOrderedDescending;
        if (a.bitrate != b.bitrate) return a.bitrate > b.bitrate ? NSOrderedAscending : NSOrderedDescending;
        return NSOrderedSame;
    }];
    NSMutableArray<YMFormat *> *out = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (YMFormat *f in audios) {
        NSString *key = f.audioTrackID.length > 0 ? f.audioTrackID : (f.codec ?: @"audio");
        if (![seen containsObject:key]) {
            [seen addObject:key];
            [out addObject:f];
        }
    }
    return out;
}

NSUInteger YMAttachURLs(NSArray<YMFormat *> *formats, NSArray *innerTubeFormats) {
    if (formats.count == 0 || innerTubeFormats.count == 0) return 0;
    NSMutableDictionary<NSNumber *, NSString *> *urlByItag = [NSMutableDictionary dictionary];
    for (id entry in innerTubeFormats) {
        if (![entry isKindOfClass:[NSDictionary class]]) continue;
        NSString *url = entry[@"url"];
        if (![url isKindOfClass:[NSString class]] || url.length == 0) continue;
        NSNumber *itag = entry[@"itag"];
        if ([itag isKindOfClass:[NSNumber class]] && urlByItag[itag] == nil) {
            urlByItag[itag] = url;
        }
    }
    NSUInteger attached = 0;
    for (YMFormat *f in formats) {
        NSString *url = urlByItag[@(f.itag)];
        if (url.length > 0) {
            f.urlString = url;
            attached++;
        }
    }
    return attached;
}

NSString *YMCodecDisplayName(NSString *codec) {
    if ([codec isEqualToString:@"av01"]) return LOC(@"CODEC_AV1");
    if ([codec isEqualToString:@"vp09"] || [codec isEqualToString:@"vp9"]) return LOC(@"CODEC_VP9");
    if ([codec isEqualToString:@"avc1"]) return LOC(@"CODEC_H264");
    if ([codec isEqualToString:@"hvc1"] || [codec isEqualToString:@"hev1"]) return LOC(@"CODEC_HEVC");
    if ([codec isEqualToString:@"mp4a"]) return LOC(@"CODEC_AAC");
    if ([codec isEqualToString:@"opus"]) return LOC(@"CODEC_OPUS");
    return codec ?: @"";
}

NSString *YMCodecQualifier(NSString *codec) {
    if ([codec isEqualToString:@"av01"]) return LOC(@"CODEC_MOST_EFFICIENT");
    if ([codec isEqualToString:@"vp09"] || [codec isEqualToString:@"vp9"] || [codec isEqualToString:@"opus"]) {
        return LOC(@"CODEC_EFFICIENT");
    }
    if ([codec isEqualToString:@"avc1"] || [codec isEqualToString:@"mp4a"]) {
        return LOC(@"CODEC_BEST_COMPATIBILITY");
    }
    return nil;
}

NSString *YMCodecFriendlyName(NSString *codec) {
    NSString *display = YMCodecDisplayName(codec);
    NSString *qualifier = YMCodecQualifier(codec);
    if (qualifier.length > 0) return [NSString stringWithFormat:@"%@ (%@)", display, qualifier];
    return display;
}

BOOL YMCodecIsApplePlayable(NSString *codec, BOOL isVideo) {
    if (codec.length == 0) return NO;
    if (!isVideo) return [codec isEqualToString:@"mp4a"];
    return [codec isEqualToString:@"avc1"] || [codec isEqualToString:@"hvc1"] || [codec isEqualToString:@"hev1"];
}

NSString *YMContainerExtensionFor(YMFormat *video, YMFormat *audio) {
    BOOL videoOK = video ? YMCodecIsApplePlayable(video.codec, YES) : YES;
    BOOL audioOK = audio ? YMCodecIsApplePlayable(audio.codec, NO) : YES;
    if (video) return (videoOK && audioOK) ? @"mp4" : @"mkv";
    return (videoOK && audioOK) ? @"m4a" : @"mka";
}

BOOL YMFormatsArePhotosCompatible(YMFormat *video, YMFormat *audio) {
    if (video && !YMCodecIsApplePlayable(video.codec, YES)) return NO;
    if (audio && !YMCodecIsApplePlayable(audio.codec, NO)) return NO;
    return YES;
}

NSArray<YMFormat *> *YMPhotosCompatibleFormats(NSArray<YMFormat *> *formats) {
    NSMutableArray<YMFormat *> *out = [NSMutableArray array];
    for (YMFormat *f in formats) {
        if (YMCodecIsApplePlayable(f.codec, f.isVideo)) [out addObject:f];
    }
    return out;
}

NSArray<YMCaptionTrack *> *YMCaptionTracksFromPlayer(YTPlayerViewController *player) {
    id response = [player respondsToSelector:@selector(contentPlayerResponse)]
        ? [player contentPlayerResponse]
        : [player playerResponse];
    id tracklist = [[[response playerData] captions] playerCaptionsTracklistRenderer];
    NSMutableArray<YMCaptionTrack *> *out = [NSMutableArray array];
    for (id<YMCaptionReading> track in [tracklist captionTracksArray]) {
        NSString *baseURL = [track baseURL];
        if (baseURL.length == 0) continue;
        YMCaptionTrack *t = [YMCaptionTrack new];
        t.languageCode = [track languageCode];
        // dropdownOptionTitle only exists on YTIFormattedString from 20.x; 19.x would throw.
        id name = [track name];
        NSString *title = [name respondsToSelector:@selector(dropdownOptionTitle)] ? [name dropdownOptionTitle] : [name stringWithFormattingRemoved];
        t.name = title ?: [track languageCode];
        t.vttURL = [baseURL stringByAppendingString:@"&fmt=vtt"];
        [out addObject:t];
    }
    return out;
}

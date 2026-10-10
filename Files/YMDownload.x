#import "Headers.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <os/log.h>

static os_log_t YMDownloadLogHandle(void) {
    static os_log_t handle; static dispatch_once_t once;
    dispatch_once(&once, ^{ handle = os_log_create("dev.water888.youmod", "download"); });
    return handle;
}
#define YMDownloadLog(fmt, ...) os_log(YMDownloadLogHandle(), "[YouMod] " fmt, ##__VA_ARGS__)

@interface YMProgressMeter : NSObject
@property (nonatomic, assign) unsigned long long expectedTotal;
@property (nonatomic, assign) unsigned long long lastBytes;
@property (nonatomic, assign) NSTimeInterval lastSample;
@property (nonatomic, assign) double smoothedBytesPerSecond;
@property (nonatomic, assign) NSTimeInterval startedAt;
- (void)observeBytes:(unsigned long long)bytes;
- (NSString *)statusCaptionForCompletedBytes:(unsigned long long)completedBytes;
- (double)averageBytesPerSecondFor:(unsigned long long)bytes;
@end

static BOOL gYMDownloadBusy = NO;
static YMProgressMeter *gYMDownloadMeter = nil;
static YMDownloadProgressView *gYMDownloadProgressView = nil;

@implementation YMProgressMeter

- (instancetype)init {
    self = [super init];
    if (self) {
        _startedAt = [NSDate timeIntervalSinceReferenceDate];
        _lastSample = _startedAt;
    }
    return self;
}

- (void)observeBytes:(unsigned long long)bytes {
    if (bytes < self.lastBytes) {
        // A new phase (e.g. the next audio track) restarted its byte counter.
        self.lastBytes = bytes;
        self.lastSample = [NSDate timeIntervalSinceReferenceDate];
        return;
    }
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    NSTimeInterval dt = now - self.lastSample;
    if (dt >= 0.4) {
        if (bytes >= self.lastBytes) {
            double rate = (double)(bytes - self.lastBytes) / dt;
            if (self.smoothedBytesPerSecond > 0) {
                rate = rate * 0.3 + self.smoothedBytesPerSecond * 0.7;
            }
            self.smoothedBytesPerSecond = rate;
        }
        self.lastBytes = bytes;
        self.lastSample = now;
    }
}

static NSString *YMDLByteCountString(unsigned long long bytes) {
    if (bytes < 1) return @"0 B";
    NSByteCountFormatter *fmt = [NSByteCountFormatter new];
    fmt.countStyle = NSByteCountFormatterCountStyleFile;
    return [fmt stringFromByteCount:(long long)bytes];
}

- (NSString *)statusCaptionForCompletedBytes:(unsigned long long)completedBytes {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    if (self.expectedTotal > 0 && completedBytes > 0) {
        unsigned long long done = completedBytes > self.expectedTotal ? self.expectedTotal : completedBytes;
        [parts addObject:[NSString stringWithFormat:@"%@ / %@",
                          YMDLByteCountString(done), YMDLByteCountString(self.expectedTotal)]];
    }
    if (self.smoothedBytesPerSecond > 1024) {
        NSByteCountFormatter *fmt = [NSByteCountFormatter new];
        fmt.countStyle = NSByteCountFormatterCountStyleFile;
        fmt.allowedUnits = NSByteCountFormatterUseKB | NSByteCountFormatterUseMB;
        [parts addObject:[NSString stringWithFormat:@"%@/s",
                          [fmt stringFromByteCount:(long long)self.smoothedBytesPerSecond]]];
    }
    return [parts componentsJoinedByString:@" · "];
}

- (double)averageBytesPerSecondFor:(unsigned long long)bytes {
    NSTimeInterval dt = [NSDate timeIntervalSinceReferenceDate] - self.startedAt;
    if (dt > 0) return (double)bytes / dt;
    return 0;
}

@end

#pragma mark - Notifications

void YouModSendToast(NSString *message) {
    [SBSkipNotificationView showInView:sbGetNotificationParent() message:message buttonTitle:nil action:nil duration:3.0];
}

void YouModSendSuccess(NSString *message) {
    [SBSkipNotificationView showSuccessInView:sbGetNotificationParent() message:message duration:3.0];
}

void YouModSendError(NSString *message) {
    [SBSkipNotificationView showErrorInView:sbGetNotificationParent() message:message duration:4.0];
}

#pragma mark - File helpers

NSString *YouModSanitizedFileName(NSString *name) {
    NSString *out = @"YouTube Video";
    if (name.length > 0) {
        NSMutableCharacterSet *bad = [NSMutableCharacterSet characterSetWithCharactersInString:@"/\\?%*|\"<>:"];
        [bad formUnionWithCharacterSet:NSCharacterSet.newlineCharacterSet];
        NSString *joined = [[name componentsSeparatedByCharactersInSet:bad] componentsJoinedByString:@" "];
        NSString *trimmed = [joined stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        while ([trimmed containsString:@"  "]) {
            trimmed = [trimmed stringByReplacingOccurrencesOfString:@"  " withString:@" "];
        }
        if (trimmed.length >= 121) trimmed = [trimmed substringToIndex:120];
        out = trimmed.length > 0 ? trimmed : @"YouTube Video";
    }
    return out;
}

NSURL *YouModDownloadsDirectoryURL(void) {
    NSURL *docs = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *dir = [docs URLByAppendingPathComponent:@"YouMod_Downloads" isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

NSURL *YouModUniqueFileURL(NSString *fileName, NSString *extension) {
    NSString *base = YouModSanitizedFileName(fileName);
    NSURL *dir = YouModDownloadsDirectoryURL();
    NSURL *url = [dir URLByAppendingPathComponent:[base stringByAppendingPathExtension:extension]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
        NSUInteger n = 2;
        do {
            NSString *numbered = [NSString stringWithFormat:@"%@ %lu", base, (unsigned long)n];
            url = [dir URLByAppendingPathComponent:[numbered stringByAppendingPathExtension:extension]];
            n++;
        } while ([[NSFileManager defaultManager] fileExistsAtPath:url.path]);
    }
    return url;
}

NSURL *YouModTemporaryFileURL(NSString *extension) {
    NSString *name = [[NSUUID.UUID.UUIDString stringByAppendingPathExtension:extension] copy];
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:name]];
}

#pragma mark - Photos and sharing

void YouModRequestPhotoAccess(void (^completion)(BOOL granted)) {
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelReadWrite handler:^(PHAuthorizationStatus status) {
        completion(status == PHAuthorizationStatusAuthorized || status == PHAuthorizationStatusLimited);
    }];
}

void YouModSaveVideoToPhotos(NSURL *fileURL, UIViewController *presenter, void (^completion)(BOOL success, NSError *error)) {
    YouModRequestPhotoAccess(^(BOOL granted) {
        if (!granted) {
            completion(NO, [NSError errorWithDomain:@"YouMod" code:1
                                           userInfo:@{NSLocalizedDescriptionKey: @"Photos access denied"}]);
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

void YouModShareItem(id item, UIViewController *presenter, UIView *sourceView) {
    if (!item || !presenter) return;
    UIActivityViewController *vc = [[UIActivityViewController alloc] initWithActivityItems:@[item] applicationActivities:nil];
    YouModConfigureSharePopover(vc, sourceView ?: presenter.view);
    [presenter presentViewController:vc animated:YES completion:nil];
}

void YouModShareFile(NSURL *fileURL, UIViewController *presenter, UIView *sourceView) {
    YouModShareItem(fileURL, presenter, sourceView);
}

BOOL YouModFileIsPhotosCompatible(NSURL *fileURL) {
    if (![fileURL.pathExtension.lowercaseString isEqualToString:@"mp4"]) return NO;
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:fileURL options:nil];
    AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    if (track && track.isPlayable) return asset.isPlayable;
    return NO;
}

void YouModHandlePostDownloadFile(NSURL *fileURL, BOOL isVideo, YMDownloadDestination destination, UIViewController *presenter) {
    if (!fileURL) return;
    BOOL wantsPhotos = destination == YMDownloadDestinationPhotos && isVideo && YouModFileIsPhotosCompatible(fileURL);
    if (wantsPhotos) {
        YouModSaveVideoToPhotos(fileURL, presenter, ^(BOOL success, NSError *error) {
            if (success) {
                YouModSendSuccess(LOC(@"SAVED_TO_PHOTOS"));
            } else {
                YouModSendError(error.localizedDescription ?: LOC(@"CANNOT_SAVE_TO_PHOTOS"));
            }
        });
    } else {
        YouModSendSuccess(LOC(@"DOWNLOAD_COMPLETED"));
    }
}

void YouModHandlePostDownloadImage(UIImage *image, UIViewController *presenter) {
    if (!image) return;
    YouModRequestPhotoAccess(^(BOOL granted) {
        if (!granted) {
            YouModSendError(LOC(@"PHOTO_ACCESS_DENINED"));
            return;
        }
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromImage:image];
        } completionHandler:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    YouModSendSuccess(LOC(@"SAVED_TO_PHOTOS"));
                } else {
                    YouModSendError(error.localizedDescription ?: LOC(@"SAVE_FAILED"));
                    YouModShareItem(image, presenter, nil);
                }
            });
        }];
    });
}

#pragma mark - Download path

static void YMDownloadFail(NSString *message, NSArray<NSURL *> *temporaries) {
    for (NSURL *url in temporaries) {
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    }
    if (!gYMDownloadBusy) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        gYMDownloadBusy = NO;
        [gYMDownloadProgressView dismiss];
        gYMDownloadProgressView = nil;
        YouModSendError(message ?: LOC(@"DOWNLOAD_FAILED"));
    });
}

static void YMSaveThumbnailAlongsideVideo(NSURL *thumbnailURL, NSURL *videoOutputURL) {
    if (!thumbnailURL || !videoOutputURL) return;
    NSURL *dest = [[videoOutputURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"jpg"];
    [[NSURLSession.sharedSession dataTaskWithURL:thumbnailURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data.length > 0) [data writeToURL:dest atomically:YES];
    }] resume];
}

static void YMDownloadMuxAndFinish(NSURL *videoURL, NSArray<NSURL *> *audioURLs, NSArray<YMCaptionTrack *> *subtitles,
                                   NSString *fileName, YMFormat *video, NSArray<YMFormat *> *audioFormats,
                                   YMDownloadDestination destination, NSURL *thumbnailURL, UIViewController *presenter) {
    NSMutableArray<NSURL *> *temporaries = [NSMutableArray array];
    if (videoURL) [temporaries addObject:videoURL];
    [temporaries addObjectsFromArray:audioURLs];
    for (YMCaptionTrack *t in subtitles) {
        if (t.localURL) [temporaries addObject:t.localURL];
    }
    BOOL audioOK = YES;
    for (YMFormat *track in audioFormats) {
        if (!YMCodecIsApplePlayable(track.codec, NO)) {
            audioOK = NO;
            break;
        }
    }
    NSString *ext = video
        ? ((YMCodecIsApplePlayable(video.codec, YES) && audioOK) ? @"mp4" : @"mkv")
        : (audioOK ? @"m4a" : @"mka");
    NSURL *output = YouModUniqueFileURL(fileName, ext);
    unsigned long long totalBytes = 0;
    for (NSURL *url in (@[videoURL ?: (id)[NSNull null]])) {
        if (![url isKindOfClass:[NSURL class]]) continue;
        totalBytes += [[[[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:nil]
                        objectForKeyedSubscript:NSFileSize] unsignedLongLongValue];
    }
    for (NSURL *url in audioURLs) {
        totalBytes += [[[[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:nil]
                        objectForKeyedSubscript:NSFileSize] unsignedLongLongValue];
    }
    YMDownloadLog("fetched %llu bytes at %.0f KB/s average",
                  totalBytes, [gYMDownloadMeter averageBytesPerSecondFor:totalBytes] * 0.0009765625);
    dispatch_async(dispatch_get_main_queue(), ^{
        [gYMDownloadProgressView updateProgress:1.0 title:LOC(@"MERGING_VID") subtitle:nil];
    });
    YMFFmpegMuxTracks(videoURL, audioURLs, subtitles, output, ^(BOOL success, NSString *failure) {
        if (success) {
            for (NSURL *url in temporaries) {
                [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
            }
            if (video) YMSaveThumbnailAlongsideVideo(thumbnailURL, output);
            dispatch_async(dispatch_get_main_queue(), ^{
                gYMDownloadBusy = NO;
                [gYMDownloadProgressView dismiss];
                gYMDownloadProgressView = nil;
                if (output) YouModHandlePostDownloadFile(output, video != nil, destination, presenter);
            });
        } else {
            YMDownloadFail(failure ?: LOC(@"DOWNLOAD_FAILED"), temporaries);
        }
    });
}

void YMDownloadStart(YMFormat *video, NSArray<YMFormat *> *audioTracks, NSArray<YMCaptionTrack *> *captions,
                     NSString *fileName, YMDownloadDestination destination, NSURL *thumbnailURL, UIViewController *presenter) {
    if (gYMDownloadBusy) {
        YouModSendError(LOC(@"ALREADY_DOWNLOADING"));
        return;
    }
    if (audioTracks.count == 0) {
        YouModSendError(LOC(@"NO_AUDIO_STREAM_FOUND"));
        return;
    }
    NSString *unavailable = YMFFmpegUnavailableReason();
    if (!YMFFmpegIsAvailable()) {
        YouModSendError(unavailable ?: LOC(@"DOWNLOAD_FAILED"));
        return;
    }
    gYMDownloadBusy = YES;
    gYMDownloadMeter = [YMProgressMeter new];
    unsigned long long expectedTotal = video ? (unsigned long long)video.contentLength : 0;
    for (YMFormat *track in audioTracks) expectedTotal += (unsigned long long)track.contentLength;
    gYMDownloadMeter.expectedTotal = expectedTotal;
    __block unsigned long long completedBeforePhase = 0;
    // Pushes cumulative progress into the download pill: percent in the title,
    // downloaded/total bytes and speed in the subtitle. `phaseFraction` is only
    // a fallback for when the expected sizes are unknown.
    void (^reportProgress)(float, unsigned long long, BOOL) = ^(float phaseFraction, unsigned long long completedBytes, BOOL isAudio) {
        [gYMDownloadMeter observeBytes:completedBytes];
        float overall = expectedTotal > 0 ? (float)((double)completedBytes / (double)expectedTotal) : phaseFraction;
        if (overall > 1.0f) overall = 1.0f;
        NSString *title = [NSString stringWithFormat:@"%@  %.0f%%",
                           LOC(isAudio ? @"DOWNLOADING_AUDIO" : @"DOWNLOADING_VIDEO"),
                           (double)overall * 100.0];
        NSString *subtitle = [gYMDownloadMeter statusCaptionForCompletedBytes:completedBytes];
        dispatch_async(dispatch_get_main_queue(), ^{
            [gYMDownloadProgressView updateProgress:overall title:title subtitle:subtitle];
        });
    };
    NSString *msg = LOC(video ? @"DOWNLOADING_VIDEO" : @"DOWNLOADING_AUDIO");
    gYMDownloadProgressView = [YMDownloadProgressView showInView:sbGetNotificationParent()
                                                         message:msg
                                                    cancelAction:^{
                                                        [YMSABR cancelCurrent];
                                                        gYMDownloadBusy = NO;
                                                        gYMDownloadProgressView = nil;
                                                        YouModSendError(LOC(@"DOWNLOAD_CANCELLED"));
                                                    }];
    YMFormat *audio = audioTracks.firstObject;
    if (video) {
        [YMSABR downloadVideoItag:video.itag audioItag:audio.itag audioStream:audio.source progress:^(float fraction, unsigned long long bytes, BOOL isAudio) {
            reportProgress(fraction, completedBeforePhase + bytes, isAudio);
        } completion:^(NSURL *videoURL, NSURL *audioURL, NSString *err) {
            if (!videoURL || !audioURL || err) {
                YMDownloadFail(err, @[]);
                return;
            }
            NSMutableArray<YMCaptionTrack *> *localCaptions = [NSMutableArray array];
            for (YMCaptionTrack *t in captions) {
                if (t.vttURL.length == 0) continue;
                NSURL *remote = [NSURL URLWithString:t.vttURL];
                if (!remote) continue;
                NSData *data = [NSData dataWithContentsOfURL:remote];
                if (data.length == 0) continue;
                NSURL *tmp = YouModTemporaryFileURL(@"vtt");
                if ([data writeToURL:tmp atomically:YES]) {
                    t.localURL = tmp;
                    [localCaptions addObject:t];
                }
            }
            NSMutableArray<NSURL *> *audioURLs = [NSMutableArray arrayWithObject:audioURL];
            completedBeforePhase += (unsigned long long)video.contentLength + (unsigned long long)audio.contentLength;
            __block NSUInteger nextAudio = 1;
            NSMutableArray *nextBox = [NSMutableArray arrayWithObject:[NSNull null]];
            void (^downloadNextAudio)(void) = ^{
                if (nextAudio >= audioTracks.count) {
                    YMDownloadMuxAndFinish(videoURL, audioURLs, localCaptions, fileName, video, audioTracks, destination, thumbnailURL, presenter);
                    return;
                }
                YMFormat *next = audioTracks[nextAudio++];
                [YMSABR downloadAudioItag:next.itag audioStream:next.source progress:^(float fraction, unsigned long long bytes) {
                    reportProgress(fraction, completedBeforePhase + bytes, YES);
                } completion:^(NSURL *url, NSString *error) {
                    if (!url || error) { YMDownloadFail(error, audioURLs); return; }
                    completedBeforePhase += (unsigned long long)next.contentLength;
                    [audioURLs addObject:url];
                    id next = nextBox.firstObject;
                    if (next != [NSNull null]) ((void (^)(void))next)();
                }];
            };
            nextBox[0] = [downloadNextAudio copy];
            downloadNextAudio();
        }];
    } else {
        __block NSMutableArray<NSURL *> *audioURLs = [NSMutableArray array];
        __block NSUInteger nextAudio = 0;
        NSMutableArray *nextBox = [NSMutableArray arrayWithObject:[NSNull null]];
        void (^downloadNextAudio)(void) = ^{
            if (nextAudio >= audioTracks.count) {
                YMDownloadMuxAndFinish(nil, audioURLs, @[], fileName, nil, audioTracks, destination, thumbnailURL, presenter);
                return;
            }
            YMFormat *currentAudio = audioTracks[nextAudio++];
            [YMSABR downloadAudioItag:currentAudio.itag audioStream:currentAudio.source progress:^(float fraction, unsigned long long bytes) {
                reportProgress(fraction, completedBeforePhase + bytes, YES);
            } completion:^(NSURL *audioURL, NSString *err) {
                if (!audioURL || err) {
                    YMDownloadFail(err, audioURLs);
                    return;
                }
                completedBeforePhase += (unsigned long long)currentAudio.contentLength;
                [audioURLs addObject:audioURL];
                id next = nextBox.firstObject;
                if (next != [NSNull null]) ((void (^)(void))next)();
            }];
        };
        nextBox[0] = [downloadNextAudio copy];
        downloadNextAudio();
    }
}

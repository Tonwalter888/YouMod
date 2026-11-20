// YMDownloadHelpers — download pipeline helpers: logging, file naming/dedup,
// failure cleanup, thumbnail and library side effects, mux-and-finish flow.
#import <UIKit/UIKit.h>
#import <os/log.h>

#import "YMDownloadSheet.h"

@class YMFormat;
@class YMCaptionTrack;

@interface YMDownloadHelpers : NSObject
// Shared "download" os_log handle, created once.
+ (os_log_t)logHandle;
// Byte size like "1.2 MB"; @"0 B" when bytes is 0.
+ (NSString *)byteCountString:(unsigned long long)bytes;
// Trailing " [videoID]" suffix of a sanitized name, or nil when absent.
+ (NSString *)duplicateSuffix:(NSString *)fileName;
// Deletes temp files, then resets the busy state and reports the failure (main queue).
+ (void)failWithMessage:(NSString *)message temporaries:(NSArray<NSURL *> *)temporaries;
// Downloads the thumbnail next to the output video as a .jpg (best effort).
+ (void)saveThumbnail:(NSURL *)thumbnailURL alongsideVideo:(NSURL *)videoOutputURL;
// Tags the output file as a Shorts download in the library metadata defaults.
+ (void)recordLibraryDownloadTypeForFileURL:(NSURL *)fileURL isShorts:(BOOL)isShorts;
// Muxes video + audio + captions into the final container, cleans up temp files,
// then finishes (Photos save or library record + completion toast).
+ (void)muxAndFinishWithVideoURL:(NSURL *)videoURL audioURLs:(NSArray<NSURL *> *)audioURLs subtitles:(NSArray<YMCaptionTrack *> *)subtitles
                        fileName:(NSString *)fileName video:(YMFormat *)video audioFormats:(NSArray<YMFormat *> *)audioFormats
                     destination:(YMDownloadDestination)destination thumbnailURL:(NSURL *)thumbnailURL isShorts:(BOOL)isShorts presenter:(UIViewController *)presenter;
// Existing downloads sharing the name's video-ID suffix (duplicate detection).
+ (NSArray<NSURL *> *)existingDownloadsForFileName:(NSString *)fileName;
@end

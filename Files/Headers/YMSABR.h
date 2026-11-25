#import "YTIFormatStream.h"

// On-device SABR downloader (SABRDownload.x): produces video mp4 + audio m4a for
// the existing muxer; progress/completion on the main queue.
//
// audioStream is the picked audio format from the player response. Language dubs
// share one itag (140) and differ only in the FormatId's xtags, so the track
// identity is read from this format (nil = no preference, first match wins).
@interface YMSABR : NSObject
+ (void)downloadVideoItag:(int)videoItag audioItag:(int)audioItag audioStream:(YTIFormatStream *)audioStream
                 progress:(void (^)(float fraction, unsigned long long bytesDownloaded, BOOL isAudio))progress
               completion:(void (^)(NSURL *videoURL, NSURL *audioURL, NSString *err))completion;
+ (void)downloadAudioItag:(int)audioItag audioStream:(YTIFormatStream *)audioStream
                 progress:(void (^)(float fraction, unsigned long long bytesDownloaded))progress
               completion:(void (^)(NSURL *audioURL, NSString *err))completion;
+ (void)cancelCurrent;
// Build the next downloads from this resolved player response instead of the
// playing video's captured request (nil = back to the captured request).
+ (void)useResolvedResponse:(id)response capture:(NSDictionary *)capture;
// The playing video's current SABR request (@{body, headers}), or nil if none seen yet. Main queue.
+ (void)currentCapture:(void (^)(NSDictionary *capture))completion;
@end

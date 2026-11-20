// YMFFmpegHelpers — ffmpegKit loading and synchronous command execution (YMFFmpeg.x).
#import <os/log.h>

@interface YMFFmpegHelpers : NSObject
// Shared os_log handle for the ffmpeg subsystem.
+ (os_log_t)logHandle;
// FFmpegKit library names, in the order they must be dlopened.
+ (NSArray<NSString *> *)libraries;
// Path of a framework's Mach-O binary inside the bundle root.
+ (NSString *)frameworkBinaryPathForRoot:(NSString *)root name:(NSString *)name;
// One-time dlopen of the ffmpeg libraries and the ffmpegkit facade; records the failure reason.
+ (void)ensureLoaded;
// Runs FFmpegKit synchronously; on failure writes the tail of the session output to failureOut.
+ (BOOL)runSync:(NSArray<NSString *> *)arguments failureOut:(NSString **)failureOut;
@end

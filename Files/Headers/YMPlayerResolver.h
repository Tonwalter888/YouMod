// YMPlayerResolver — resolves a player response for any video ID and keeps the
// PO tokens the app mints (PlayerResolver.x). Completions run on the main queue.
#import <Foundation/Foundation.h>

@interface YMPlayerResolver : NSObject
+ (BOOL)templateReady;
+ (NSData *)poTokenForVideoID:(NSString *)videoID; // per-video if seen, else the latest, else nil
+ (void)resolveVideoID:(NSString *)videoID completion:(void (^)(id response, NSError *error))completion;
+ (void)refreshVideoID:(NSString *)videoID completion:(void (^)(id response, NSError *error))completion; // drops the cached response first
+ (void)reloadVideoID:(NSString *)videoID token:(NSString *)reloadToken completion:(void (^)(id response, NSError *error))completion; // answers a SABR RELOAD
+ (NSString *)recentLog; // last resolver log lines, newest last
+ (void)appendLog:(NSString *)line; // adds a line to that log (downloader / queue events)
@end

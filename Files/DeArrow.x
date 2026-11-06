#import "Headers.h"

// DeArrow thumbnail replacement (https://dearrow.ajay.app)
// API docs: https://wiki.sponsor.ajay.app/w/API_Docs/DeArrow
//
// The ELMImageNode hooks let %orig load YouTube's thumbnail first, then we look
// up DeArrow for a replacement frame and call -[ELMImageNode setImage:] again.
// Replacement choice: trusted community thumbnail (locked = true or votes >= 0),
// else a random-time screenshot (randomTime * videoDuration) when the duration
// is known, else YouTube's thumbnail stays as-is.

@interface YMDeArrow ()
+ (NSString *)cachePath;
+ (void)loadCacheIfNeeded;
+ (void)scheduleCacheSave;
+ (NSDictionary *)cachedEntryForVideoID:(NSString *)videoID;
+ (NSNumber *)pickTimeFromBranding:(NSDictionary *)json;
+ (void)fetchBrandingForVideoID:(NSString *)videoID completion:(void (^)(NSNumber *time))completion;
+ (void)loadImageForVideoID:(NSString *)videoID time:(double)time node:(ELMImageNode *)node;
+ (void)applyImage:(UIImage *)image toNode:(ELMImageNode *)node videoID:(NSString *)videoID;
@end

// videoID -> @{ @"time": NSNumber } for a DeArrow frame, or @{} (no @"time") = keep YouTube's.
static NSMutableDictionary<NSString *, NSDictionary *> *ymDeArrowCache = nil;
static NSCache<NSString *, UIImage *> *ymDeArrowImages = nil;
static BOOL ymDeArrowCacheLoaded = NO;

// Marks which video a node is currently displaying so late results are dropped
// after cell reuse.
static const void *kYMDeArrowNodeVideoID = &kYMDeArrowNodeVideoID;

@implementation YMDeArrow

#pragma mark - Entry point

+ (void)applyToNode:(ELMImageNode *)node forURL:(NSURL *)url {
    if (!node || !url) return;
    NSString *videoID = YMExtractYouTubeVideoID(url.description);
    if (videoID.length != 11) return;

    // Tag the node; if it gets reused for another video, late callbacks bail out.
    objc_setAssociatedObject(node, kYMDeArrowNodeVideoID, videoID, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIImage *image = [ymDeArrowImages objectForKey:videoID];
    if (image) {
        [self applyImage:image toNode:node videoID:videoID];
        return;
    }

    NSDictionary *entry = [self cachedEntryForVideoID:videoID];
    if (entry) {
        NSNumber *time = entry[@"time"];
        if (time) [self loadImageForVideoID:videoID time:time.doubleValue node:node];
        return;
    }

    [self fetchBrandingForVideoID:videoID completion:^(NSNumber *time) {
        if (time) [self loadImageForVideoID:videoID time:time.doubleValue node:node];
    }];
}

#pragma mark - Cache

+ (NSString *)cachePath {
    // Not NSCachesDirectory: Cache.x wipes it at launch when AutoClearCache is on.
    NSString *appSupport = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    NSString *dir = [appSupport stringByAppendingPathComponent:@"YouMod"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return [dir stringByAppendingPathComponent:@"DeArrowCache.plist"];
}

+ (void)loadCacheIfNeeded {
    @synchronized (ymDeArrowCache) {
        if (ymDeArrowCacheLoaded) return;
        ymDeArrowCacheLoaded = YES;
        NSDictionary *disk = [NSDictionary dictionaryWithContentsOfFile:[self cachePath]];
        NSTimeInterval now = NSDate.date.timeIntervalSince1970;
        for (NSString *key in disk) {
            NSDictionary *entry = disk[key];
            if ([entry isKindOfClass:[NSDictionary class]] && [entry[@"expires"] doubleValue] > now) {
                ymDeArrowCache[key] = entry;
            }
        }
    }
}

+ (void)scheduleCacheSave {
    static BOOL pending = NO;
    @synchronized (ymDeArrowCache) {
        if (pending) return;
        pending = YES;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSDictionary *snapshot;
        @synchronized (ymDeArrowCache) {
            snapshot = [ymDeArrowCache copy];
            pending = NO;
        }
        [snapshot writeToFile:[self cachePath] atomically:YES];
    });
}

+ (NSDictionary *)cachedEntryForVideoID:(NSString *)videoID {
    [self loadCacheIfNeeded];
    @synchronized (ymDeArrowCache) {
        NSDictionary *entry = ymDeArrowCache[videoID];
        if (entry && [entry[@"expires"] doubleValue] > NSDate.date.timeIntervalSince1970) return entry;
        if (entry) [ymDeArrowCache removeObjectForKey:videoID];
    }
    return nil;
}

#pragma mark - Branding lookup

// Returns the frame time (seconds) for the video, or nil to keep YouTube's thumbnail.
+ (NSNumber *)pickTimeFromBranding:(NSDictionary *)json {
    // API returns thumbnails in quality order; a submission is only trusted when
    // locked = true or votes >= 0. Entries marked original = true are "the original
    // is fine" votes, not replacements, so they are skipped.
    NSArray *thumbnails = [json[@"thumbnails"] isKindOfClass:[NSArray class]] ? json[@"thumbnails"] : nil;
    for (NSDictionary *thumb in thumbnails) {
        if (![thumb isKindOfClass:[NSDictionary class]]) continue;
        if (![thumb[@"locked"] boolValue] && [thumb[@"votes"] integerValue] < 0) continue;
        if ([thumb[@"original"] boolValue]) continue;
        NSNumber *timestamp = thumb[@"timestamp"];
        if ([timestamp isKindOfClass:[NSNumber class]]) return timestamp;
    }
    // No usable submission: fall back to a server-picked random-time screenshot.
    // randomTime (0..1) must be multiplied by the duration; unusable when unknown.
    NSNumber *duration = json[@"videoDuration"];
    NSNumber *randomTime = json[@"randomTime"];
    if ([duration isKindOfClass:[NSNumber class]] && [randomTime isKindOfClass:[NSNumber class]] && duration.doubleValue > 0) {
        return @(randomTime.doubleValue * duration.doubleValue);
    }
    return nil;
}

+ (void)fetchBrandingForVideoID:(NSString *)videoID completion:(void (^)(NSNumber *time))completion {
    NSString *urlStr = [NSString stringWithFormat:@"https://sponsor.ajay.app/api/branding?videoID=%@", videoID];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:urlStr] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *entry = nil;
        NSTimeInterval expires = NSDate.date.timeIntervalSince1970;
        if (!error) {
            NSInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
            if (statusCode == 200) {
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([json isKindOfClass:[NSDictionary class]]) {
                    NSNumber *time = [self pickTimeFromBranding:json];
                    if (time) entry = @{ @"time": time, @"expires": @(expires + 7 * 24 * 3600) };
                    // Negative result: shorter TTL so new submissions get picked up.
                    else entry = @{ @"expires": @(expires + 24 * 3600) };
                }
            } else if (statusCode == 404) {
                // No branding exists for this video at all.
                entry = @{ @"expires": @(expires + 24 * 3600) };
            }
            // Other failures are not cached so the lookup retries later.
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (entry) {
                @synchronized (ymDeArrowCache) {
                    ymDeArrowCache[videoID] = entry;
                }
                [self scheduleCacheSave];
            }
            if (completion) completion(entry[@"time"]);
        });
    }];
    [task resume];
}

#pragma mark - Frame image

+ (void)loadImageForVideoID:(NSString *)videoID time:(double)time node:(ELMImageNode *)node {
    NSURLComponents *url = [NSURLComponents componentsWithString:@"https://dearrow-thumb.ajay.app/api/v1/getThumbnail"];
    url.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"videoID" value:videoID],
        [NSURLQueryItem queryItemWithName:@"time" value:[NSString stringWithFormat:@"%.3f", time]],
    ];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url.URL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        UIImage *image = nil;
        if (!error && data.length > 0 && ((NSHTTPURLResponse *)response).statusCode == 200) {
            image = [UIImage imageWithData:data];
        }
        if (!image) return;
        [ymDeArrowImages setObject:image forKey:videoID];
        [self applyImage:image toNode:node videoID:videoID];
    }];
    [task resume];
}

+ (void)applyImage:(UIImage *)image toNode:(ELMImageNode *)node videoID:(NSString *)videoID {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *expected = objc_getAssociatedObject(node, kYMDeArrowNodeVideoID);
        if (![expected isEqualToString:videoID]) return;
        [node setImage:image];
        // %orig's own download may land after us and overwrite the frame; assert once more.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSString *current = objc_getAssociatedObject(node, kYMDeArrowNodeVideoID);
            if ([current isEqualToString:videoID]) [node setImage:image];
        });
    });
}

@end

#pragma mark - ELMImageNode Hooks

%hook ELMImageNode

- (id)downloadImageWithURL:(NSURL *)URL shouldRetry:(BOOL)retry callbackQueue:(id)queue downloadProgress:(id)progress completion:(id)completion {
    if (IS_ENABLED(DeArrowEnabled)) [YMDeArrow applyToNode:self forURL:URL];
    return %orig;
}

- (void)cachedImageWithURL:(NSURL *)URL callbackQueue:(id)queue completion:(id)completion {
    if (IS_ENABLED(DeArrowEnabled)) [YMDeArrow applyToNode:self forURL:URL];
    %orig;
}

%end

%ctor {
    ymDeArrowCache = [NSMutableDictionary dictionary];
    // No countLimit: NSCache still evicts automatically under memory pressure.
    ymDeArrowImages = [NSCache new];
}
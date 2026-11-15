#import "YTIColorInfo.h"
#import "YTIAudioTrack.h"

@interface YTIFormatStream : NSObject
@property (nonatomic, strong, readwrite) YTIColorInfo *colorInfo;
@property (nonatomic, copy, readwrite) NSString *URL;
@property (nonatomic, copy, readwrite) NSString *qualityLabel;
@end

@interface YTIFormatStream (YouMod)
- (NSString *)mimeType;
- (NSInteger)contentLength;
- (NSUInteger)approxDurationMs;
- (int)height;
- (int)width;
- (int)fps;
- (int)bitrate;
- (YTIAudioTrack *)audioTrack;
- (int)itag;
- (YTIColorInfo *)colorInfo;
- (NSString *)xtags;
@end

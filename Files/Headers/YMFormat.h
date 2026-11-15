#import "YTIFormatStream.h"

@interface YMFormat : NSObject
@property (nonatomic, assign) int itag;
@property (nonatomic, copy) NSString *mimeType;
@property (nonatomic, copy) NSString *codec;
@property (nonatomic, copy) NSString *qualityLabel;
@property (nonatomic, copy) NSString *xtags;
@property (nonatomic, assign) int height, width, fps;
@property (nonatomic, assign) long long contentLength, bitrate;
@property (nonatomic, assign) unsigned long long durationMs;
@property (nonatomic, assign) BOOL isVideo, isHDR;
@property (nonatomic, copy) NSString *audioTrackID, *audioTrackName;
@property (nonatomic, assign) BOOL audioIsDefault;
@property (nonatomic, assign) BOOL isDubbed;
@property (nonatomic, assign) BOOL isOriginal, isAutoDubbed, isDRC;
@property (nonatomic, copy) NSString *urlString;
@property (nonatomic, readonly) BOOL isAudio;
@property (nonatomic, readonly) NSString *displayLabel;
@property (nonatomic, strong) YTIFormatStream *source;
@end

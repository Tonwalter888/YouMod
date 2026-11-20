#import "YTIVideoDetails.h"
#import "YTICaptionsSupportedRenderers.h"
#import "YTIStreamingData.h"

@interface YTIPlayerResponse : NSObject
@property (nonatomic, strong, readwrite) YTIVideoDetails *videoDetails;
@end

@interface YTIPlayerResponse (YouMod)
- (YTIStreamingData *)streamingData;
- (YTICaptionsSupportedRenderers *)captions;
@end

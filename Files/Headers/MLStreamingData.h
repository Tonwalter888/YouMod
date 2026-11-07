#import "MLRemoteStream.h"
#import "YTIStreamingData.h"

@interface MLStreamingData : NSObject
@property (nonatomic, readonly) YTIStreamingData *streamingData;
- (NSArray <MLRemoteStream *> *)adaptiveStreams;
@end
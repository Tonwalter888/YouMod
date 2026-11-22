#import "MLRemoteStream.h"
#import "YTIStreamingData.h"

@interface MLStreamingData : NSObject
@property (nonatomic, readonly) YTIStreamingData *streamingData;
@property (nonatomic, readonly) BOOL hasHLSData;
- (NSArray <MLRemoteStream *> *)adaptiveStreams;
@end
#import <Foundation/NSObject.h>

@interface MLPlayerReloadContext : NSObject
- (instancetype)initWithStartPlayback:(BOOL)startPlayback refreshStreamingData:(BOOL)refreshStreamingData;
- (instancetype)initWithStartPlayback:(BOOL)startPlayback refreshStreamingData:(BOOL)refreshStreamingData playbackParamsToken:(NSString *)playbackParamsToken disableSABR:(BOOL)disableSABR firstRequestNumber:(NSInteger)firstRequestNumber disableDAI:(BOOL)disableDAI;
@end

// YMProgressMeter — smooths download byte samples into a speed estimate and
// renders the progress pill's size/speed caption. Implemented in YMDownload.x.
#import <UIKit/UIKit.h>

@interface YMProgressMeter : NSObject
@property (nonatomic, assign) unsigned long long expectedTotal;
@property (nonatomic, assign) unsigned long long lastBytes;
@property (nonatomic, assign) NSTimeInterval lastSample;
@property (nonatomic, assign) double smoothedBytesPerSecond;
@property (nonatomic, assign) NSTimeInterval startedAt;
@property (atomic, copy) NSString *remaining;   // "1m 20s remaining", nil until there's a speed estimate
// Feeds a cumulative byte sample; a lower count restarts the sampling (new phase).
- (void)observeBytes:(unsigned long long)bytes;
// "done / total · speed" caption for the progress pill.
- (NSString *)statusCaptionForCompletedBytes:(unsigned long long)completedBytes;
- (double)averageBytesPerSecondFor:(unsigned long long)bytes;
@end

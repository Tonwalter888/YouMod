#import "SBSegment.h"

@interface SBRequest : NSObject
+ (void)fetchSegmentsForVideoID:(NSString *)videoID completion:(void (^)(NSArray<SBSegment *> *segments))completion;
@end

@interface SBRequest (Write)
+ (void)voteOnSegment:(SBSegment *)segment videoID:(NSString *)videoID type:(NSInteger)voteType completion:(void (^)(BOOL success, NSString *errorMessage))completion;
+ (void)voteCategoryOnSegment:(SBSegment *)segment videoID:(NSString *)videoID category:(NSString *)category completion:(void (^)(BOOL success, NSString *errorMessage))completion;
+ (void)submitSegmentForVideoID:(NSString *)videoID category:(NSString *)category start:(float)start end:(float)end duration:(float)duration completion:(void (^)(BOOL success, NSString *errorMessage))completion;
@end

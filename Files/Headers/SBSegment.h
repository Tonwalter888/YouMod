// SponsorBlock action modes
typedef NS_ENUM(NSInteger, SBSegmentAction) {
    SBSegmentActionDisable = 0,
    SBSegmentActionAutoSkip = 1,
    SBSegmentActionAsk = 2,
    SBSegmentActionDisplay = 3,
    SBSegmentActionSkipTo = 4,
    SBSegmentActionAlwaysSkip = 5
};

@interface SBSegment : NSObject
@property (nonatomic, strong) NSString *UUID;
@property (nonatomic, strong) NSString *category;
@property (nonatomic, assign) float startTime;
@property (nonatomic, assign) float endTime;
@property (nonatomic, strong) NSString *actionType;
@property (nonatomic, assign) NSInteger votes;
+ (instancetype)segmentWithUUID:(NSString *)UUID category:(NSString *)category start:(float)start end:(float)end action:(NSString *)actionType;
- (SBSegmentAction)configuredAction;
- (UIColor *)segmentColor;
@end

typedef NS_ENUM(NSInteger, YMVisibilityOperator) {
    YMVisibilityOperatorBoolEquals = 0,
    YMVisibilityOperatorIntEquals,
    YMVisibilityOperatorIntNotEquals,
    YMVisibilityOperatorIntGreaterThan,
    YMVisibilityOperatorIntGreaterThanOrEqual,
    YMVisibilityOperatorIntLessThan,
    YMVisibilityOperatorIntLessThanOrEqual,
    YMVisibilityOperatorIntInValues,
    YMVisibilityOperatorIntNotInValues,
    YMVisibilityOperatorCustomBlock
};

@interface YMVisibilityCondition : NSObject
@property (nonatomic, copy) NSString *key;
@property (nonatomic, assign) YMVisibilityOperator op;
@property (nonatomic, assign) BOOL boolValue;
@property (nonatomic, assign) NSInteger intValue;
@property (nonatomic, strong) NSArray<NSNumber *> *intValues;
@property (nonatomic, copy) BOOL (^customBlock)(NSUserDefaults *defaults);

+ (instancetype)conditionWithBoolKey:(NSString *)key equals:(BOOL)value;
+ (instancetype)conditionWithKey:(NSString *)key intOperator:(YMVisibilityOperator)op value:(NSInteger)value;
+ (instancetype)conditionWithKey:(NSString *)key inValues:(NSArray<NSNumber *> *)values;
+ (instancetype)conditionWithKey:(NSString *)key notInValues:(NSArray<NSNumber *> *)values;
+ (instancetype)conditionWithBlock:(BOOL (^)(NSUserDefaults *defaults))block;

- (BOOL)evaluateWithDefaults:(NSUserDefaults *)defaults;
@end

#import "YTIIcon.h"

@interface YTIPivotBarIconOnlyItemRenderer : GPBMessage
@property (nonatomic, copy, readwrite) NSString *pivotIdentifier;
@property (nonatomic, strong, readwrite) YTIIcon *icon;
@property (nonatomic, strong, readwrite) YTICommand *navigationEndpoint;
@property (nonatomic, assign, readwrite) int backgroundStyle;
@end

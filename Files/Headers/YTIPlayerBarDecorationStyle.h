#import "YTIPlayerBarGradientColor.h"

@interface YTIPlayerBarDecorationStyle : GPBMessage
@property (nonatomic, strong, readwrite) YTIPlayerBarGradientColor *gradientColor;
@end

@interface YTIPlayerBarDecorationStyle (YouMod)
@property (nonatomic, assign, readwrite) BOOL hasRoundedCorners;
@end

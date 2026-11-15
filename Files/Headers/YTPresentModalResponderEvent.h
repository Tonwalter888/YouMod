#import "YTResponderEvent.h"

@interface YTPresentModalResponderEvent : YTResponderEvent
+ (instancetype)eventWithViewController:(UIViewController *)viewController animated:(BOOL)animated firstResponder:(id)firstResponder;
@end

#import <UIKit/UIKit.h>
#import "YTLightweightQTMButton.h"
#import "YTQTMButton.h"

@interface YTRightNavigationButtons : UIView
@property (nonatomic, readwrite, assign) CGFloat leadingPadding;
@property (nonatomic, readwrite, assign) CGFloat tailingPadding; // Legitimate typo
- (id)buttonForType:(NSUInteger)type;
- (void)setButton:(id)button forType:(NSUInteger)type;
@end

@interface YTRightNavigationButtons (YouMod)
- (YTLightweightQTMButton *)notificationButton;
- (YTLightweightQTMButton *)searchButton;
- (YTLightweightQTMButton *)connectionsInboxButton;
- (YTLightweightQTMButton *)MDXButton;
- (YTLightweightQTMButton *)rightButton;
- (NSArray <YTQTMButton *> *)visibleButtons;
@end

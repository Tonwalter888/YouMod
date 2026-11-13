#import <UIKit/UIKit.h>

@interface YTRightNavigationButtons : UIView
@property (nonatomic, readwrite, assign) CGFloat leadingPadding;
@property (nonatomic, readwrite, assign) CGFloat tailingPadding; // Legitimate typo
- (id)buttonForType:(NSUInteger)type;
- (void)setButton:(id)button forType:(NSUInteger)type;
@end

#import <Foundation/NSObject.h>

@protocol MLPlayerDelegate <NSObject>
- (void)playerRateDidChange:(float)rate;
- (void)player:(id)player rateDidChange:(float)rate;
@end

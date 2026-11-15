#import <Foundation/NSObject.h>

@interface YTPlayerOverlayProvider : NSObject
@end

@interface YTPlayerOverlayProvider (YouMod)
- (void)removePlayerOverlayWithIdentifier:(NSString *)identifier;
@end

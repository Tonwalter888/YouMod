#import <Foundation/NSObject.h>

@interface MLInnerTubeCaptionTrack : NSObject
@end

@interface MLInnerTubeCaptionTrack (YouMod)
- (NSString *)languageCode;
- (NSString *)VSSID;
@end

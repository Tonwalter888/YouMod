#import "GPBMessage.h"

@interface YTIAudioTrack : GPBMessage
@property (nonatomic, copy, readwrite) NSString *displayName;
@property (nonatomic, copy, readwrite) NSString *id_p;
@property (nonatomic, assign, readwrite) BOOL audioIsDefault;
@end

@interface YTIAudioTrack (YouMod)
@property (nonatomic, assign, readwrite) BOOL isAutoDubbed;
- (BOOL)hasId_p;
@end

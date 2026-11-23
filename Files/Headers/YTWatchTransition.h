#import "YTICommand.h"

// The transition that opened the current watch page video; its player
// transition carries the navigation command that originated it (a reel
// command means the video came from Shorts).
@interface YTPlayerTransition : NSObject
@property (nonatomic, readonly) YTICommand *navigationEndpoint;
@end

@interface YTWatchTransition : NSObject
@property (nonatomic, readonly) YTPlayerTransition *playerTransition;
@end

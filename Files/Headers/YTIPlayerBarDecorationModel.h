#import "YTIPlayerBarDecorationStyle.h"
#import "YTIPlayerBarPlayingState.h"
#import "YTIPlayerBarItemData.h"

@interface YTIPlayerBarDecorationModel : GPBMessage
@property (nonatomic, strong, readwrite) YTIPlayerBarDecorationStyle *style;
@property (nonatomic, strong, readwrite) YTIPlayerBarPlayingState *playingState;
@end

@interface YTIPlayerBarDecorationModel (YouMod)
- (YTIPlayerBarItemData *)itemData;
- (YTIPlayerBarPlayingState *)playingState;
@end

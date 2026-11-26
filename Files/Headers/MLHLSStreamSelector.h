#import <Foundation/NSObject.h>
#import "MLHLSMasterPlaylist.h"
#import "MLStreamSelectorDelegate.h"

@interface MLHLSStreamSelector : NSObject
@property (nonatomic, weak) id <MLStreamSelectorDelegate> delegate;
- (void)didLoadHLSMasterPlaylist:(id)playlist;
@end

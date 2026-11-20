#import "YTCollectionViewController.h"
#import "YTPageStyling.h"

@interface YTInnerTubeCollectionViewController : YTCollectionViewController <YTPageStyling>
- (void)loadWithModel:(id)model;
- (void)displaySections;
- (void)displaySectionsWithReloadingSectionControllerByRenderer:(id)renderer;
- (void)addSectionsFromArray:(NSArray *)array;
@end

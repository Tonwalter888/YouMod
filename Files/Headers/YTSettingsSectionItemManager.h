#import "GIMMe.h"

@interface YTSettingsSectionItemManager : NSObject
@property (nonatomic, readwrite, weak) GIMMe *gimme;
- (id)parentResponder;
@end

@interface YTSettingsSectionItemManager (YouMod)
- (void)updateYouModSectionWithEntry:(id)entry;
@end

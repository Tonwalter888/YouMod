#import "YTSettingsSectionItemManager.h"

// SponsorBlock section entry hook (implemented via %new in SponsorBlockSettings.x).
@interface YTSettingsSectionItemManager (SponsorBlock)
- (void)updateSponsorBlockSectionWithEntry:(id)entry;
@end

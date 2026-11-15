// YMSBSettingsHelpers — file-local helpers for SponsorBlockSettings.x:
// accent tint, segment-action naming, toggle rows and color-to-hex conversion.

#import "SBSegment.h"

@class SBToggleRow;

@interface YMSBSettingsHelpers : NSObject
// YouMod accent for this page's toggles/sliders (distinct from SponsorBlock.x's overlay accent).
+ (UIColor *)controlTintColor;
// Localization key for a segment action's display name (action label and picker menu).
+ (NSString *)actionLocKey:(SBSegmentAction)action;
// Toggle-section rows — single source for row count, cells and preference writes.
+ (NSArray<SBToggleRow *> *)toggleRows;
// Localized display name for a segment action value.
+ (NSString *)actionName:(NSInteger)action;
// "#RRGGBB" string for a color.
+ (NSString *)hexFromColor:(UIColor *)color;
@end

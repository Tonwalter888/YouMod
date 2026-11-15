#import "YTPlayerViewController.h"
#import "YTQTMButton.h"

#pragma mark - Custom Overlay Button Registry

// A button registered into the player's controls overlay (top-right, under
// YouTube's gear). Features register a spec from their %ctor; OverlayButtons.x
// lays them all out.
@interface YMOverlayButtonSpec : NSObject
@property (nonatomic, copy) NSString *identifier;       // unique, e.g. @"sponsorblock.toggle"
@property (nonatomic, copy) NSString *symbolName;       // SF Symbol name (icon button)
@property (nonatomic, copy) NSString *title;            // text label; set this instead of symbolName for a text button
@property (nonatomic, copy) NSString *displayName;      // localized display name for settings
@property (nonatomic, copy) NSString *settingsSymbolName; // custom symbol name for settings table view
@property (nonatomic, assign) NSInteger sortOrder;      // ascending; lower = closer to gear (rightmost)
@property (nonatomic, copy) void (^onTap)(YTPlayerViewController *player, YTQTMButton *button);
@property (nonatomic, copy) BOOL (^isVisible)(YTPlayerViewController *player);     // nil = always visible
@property (nonatomic, assign) NSInteger viewTag;        // assigned by the registry; do not set
@end

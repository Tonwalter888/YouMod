// YMSBHelpers — SponsorBlock core helpers: banner durations, overlay
// snapshot hiding, lifecycle observers, category filtering, view pings.
#import <UIKit/UIKit.h>

@class SBSegment;

@interface YMSBHelpers : NSObject
// Clamps a stored banner duration to the supported range (default when unset).
+ (float)clampedAlertDuration:(NSString *)key;
// Hides the pill overlay and clears notifications before an app-switcher snapshot.
+ (void)hideOverlayForSnapshot;
// Fades the overlay back in if notifications are present; guarded to the hidden state.
+ (void)restoreOverlayAfterSnapshot;
// Binds scene/app observers that hide/restore the overlay and re-sync the pivot inset.
+ (void)registerOverlayLifecycleObservers:(UIWindowScene *)targetScene;
// Categories whose configured action isn't "disable", in the shared category order.
+ (NSArray<NSString *> *)enabledCategories;
// Credits the segment's submitter with a view (SponsorBlock stats), as intended by API spec.
+ (void)sendViewedSegment:(SBSegment *)segment;
@end

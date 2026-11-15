// YMSBMarkerHelpers — builds and lays out SponsorBlock segment marker
// layers on YouTube's player, miniplayer and feed progress bars.
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@class SBSegment;

@interface YMSBMarkerHelpers : NSObject
// Master switch per bar context (player / feed / miniplayer), checked on every layout.
+ (BOOL)markersEnabledForContext:(NSInteger)context;
// Capsule-rounds a marker container to the bar height.
+ (void)applyMarkerContainerRounding:(CALayer *)container barHeight:(CGFloat)barHeight;
// Rounds a marker's ends; mode is the round-left/right bitmask (0 = square).
+ (void)applyMarkerEndRounding:(CALayer *)markerLayer mode:(NSInteger)mode barWidth:(CGFloat)barWidth barHeight:(CGFloat)barHeight;
// Reads the decoration view's model time range; NO when empty or invalid.
+ (BOOL)getDecorationViewTimeRange:(UIView *)view start:(CGFloat *)outStart end:(CGFloat *)outEnd;
// YES when the decoration style has rounded corners and the player is fullscreen.
+ (BOOL)decorationCanApplyRoundedCorners:(UIView *)view;
// Removes every marker container from a host layer.
+ (void)removeMarkerContainerFromLayer:(CALayer *)hostLayer;
// Builds one marker layer; nil when the segment falls outside the visible range.
+ (CALayer *)makeMarkerLayer:(SBSegment *)segment rangeStart:(CGFloat)rangeStart rangeEnd:(CGFloat)rangeEnd videoStart:(CGFloat)videoStart videoEnd:(CGFloat)videoEnd barWidth:(CGFloat)barWidth barHeight:(CGFloat)barHeight;
// Repositions stamped marker layers for the current bar size; rounded wraps the container.
+ (void)layoutMarkerLayers:(CALayer *)container barWidth:(CGFloat)barWidth barHeight:(CGFloat)barHeight rounded:(BOOL)rounded;
// Rebuilds marker layers for segments overlapping the visible range on a host layer.
+ (void)rebuildMarkersInLayer:(CALayer *)hostLayer segments:(NSArray<SBSegment *> *)segments rangeStart:(CGFloat)rangeStart rangeEnd:(CGFloat)rangeEnd videoStart:(CGFloat)videoStart videoEnd:(CGFloat)videoEnd;
// Rebuilds markers in a bar decoration view from the bar view's segment stamps.
+ (void)rebuildMarkersInDecorationView:(UIView *)view;
@end

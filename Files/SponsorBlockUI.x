#import "Headers.h"

// Min width keeps short range segments visible; poi_highlight points render as a fixed-width tick.
static const CGFloat SBMarkerMinWidth = 2.0;
static const CGFloat SBPoiMarkerWidth = 3.0;
static const CGFloat SBPoiMarkerXOffset = 1.5;

#pragma mark - Marker Repositioning Hooks

static NSString *const SBSegmentMarkerLayerName = @"SBSegmentMarkerLayer";

// Each bar view carries its own segments as associated objects (stamped by sbRefreshMarkers);
// a shared list would bleed one player's segments onto another player's bar.
static const NSInteger SBMarkerContextPlayer = 1;
static const NSInteger SBMarkerContextFeed = 2;
static const NSInteger SBMarkerContextMiniplayer = 3;

// Master switch per bar context; checked on every layout so setting toggles apply immediately.
@implementation YMSBMarkerHelpers

+ (BOOL)markersEnabledForContext:(NSInteger)context {
    if (!IS_ENABLED(SBEnabled) || !IS_ENABLED(SBButtonKey)) return NO;
    if (context == SBMarkerContextPlayer) return IS_ENABLED(SBSegmentsInPlayer);
    if (context == SBMarkerContextFeed) return IS_ENABLED(SBSegmentsInFeed);
    if (context == SBMarkerContextMiniplayer) return IS_ENABLED(SBSegmentsInMiniPlayer);
    return NO;
}

+ (void)applyMarkerContainerRounding:(CALayer *)container barHeight:(CGFloat)barHeight {
    if (!container || barHeight <= 0) return;
    container.masksToBounds = YES;
    container.cornerRadius = barHeight / 2.0;
}

static const NSInteger SBMarkerRoundsLeft = 1;
static const NSInteger SBMarkerRoundsRight = 2;

+ (void)applyMarkerEndRounding:(CALayer *)markerLayer mode:(NSInteger)mode barWidth:(CGFloat)barWidth barHeight:(CGFloat)barHeight {
    if (!markerLayer || barHeight <= 0 || barWidth <= 0) return;
    if (mode == 0) {
        markerLayer.cornerRadius = 0.0;
        return;
    }
    markerLayer.cornerRadius = MIN(barHeight / 2.0, barWidth / 2.0);
    if ((mode & SBMarkerRoundsLeft) && (mode & SBMarkerRoundsRight)) return;
    markerLayer.maskedCorners = ((mode & SBMarkerRoundsLeft) ? kCALayerMinXMinYCorner | kCALayerMinXMaxYCorner : 0)
                              | ((mode & SBMarkerRoundsRight) ? kCALayerMaxXMinYCorner | kCALayerMaxXMaxYCorner : 0);
}

+ (BOOL)getDecorationViewTimeRange:(UIView *)view start:(CGFloat *)outStart end:(CGFloat *)outEnd {
    YTIPlayerBarDecorationModel *model = [view valueForKey:@"_model"];
    YTIPlayerBarItemData *itemData = [model itemData];
    CGFloat start = [itemData startTimeSec];
    CGFloat end = [itemData endTimeSec];
    if (end > start) {
        if (outStart) *outStart = start;
        if (outEnd) *outEnd = end;
        return YES;
    }
    return NO;
}

+ (BOOL)decorationCanApplyRoundedCorners:(UIView *)view {
    YTIPlayerBarDecorationModel *model = [view valueForKey:@"_model"];
    if (!model.style.hasRoundedCorners || model.itemData.startTimeSec > 0 || model.itemData.endTimeSec != model.playingState.totalTimeSec) return NO;
    YTMainAppVideoPlayerOverlayViewController *ovc = (YTMainAppVideoPlayerOverlayViewController *)view._viewControllerForAncestor;
    if (![ovc isKindOfClass:%c(YTMainAppVideoPlayerOverlayViewController)]) return NO;
    return ovc.isFullscreen;
}

+ (void)removeMarkerContainerFromLayer:(CALayer *)hostLayer {
    for (CALayer *layer in [hostLayer.sublayers copy]) {
        if ([layer.name isEqualToString:SBSegmentMarkerLayerName]) [layer removeFromSuperlayer];
    }
}

+ (CALayer *)makeMarkerLayer:(SBSegment *)segment rangeStart:(CGFloat)rangeStart rangeEnd:(CGFloat)rangeEnd videoStart:(CGFloat)videoStart videoEnd:(CGFloat)videoEnd barWidth:(CGFloat)barWidth barHeight:(CGFloat)barHeight {
    CGFloat viewDuration = rangeEnd - rangeStart;
    BOOL isPoi = [segment.category isEqualToString:@"poi_highlight"];
    CALayer *markerLayer = [CALayer layer];
    markerLayer.masksToBounds = YES;
    markerLayer.backgroundColor = [segment segmentColor].CGColor;

    NSInteger rounding = 0;
    if (isPoi) {
        if (segment.startTime < rangeStart || segment.startTime > rangeEnd) return nil;
        CGFloat frac = (segment.startTime - rangeStart) / viewDuration;
        markerLayer.frame = CGRectMake(MAX(0.0, frac * barWidth - SBPoiMarkerXOffset), 0, SBPoiMarkerWidth, barHeight);
        objc_setAssociatedObject(markerLayer, @selector(sbSegmentData), @[@(frac), @(frac), @(YES), @(rounding)], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        CGFloat overlapStart = MAX((CGFloat)segment.startTime, rangeStart);
        CGFloat overlapEnd = MIN((CGFloat)segment.endTime, rangeEnd);
        if (overlapEnd <= overlapStart) return nil;

        if ((NSInteger)segment.startTime == (NSInteger)videoStart) rounding |= SBMarkerRoundsLeft;
        if ((NSInteger)segment.endTime == (NSInteger)videoEnd) rounding |= SBMarkerRoundsRight;

        CGFloat fracStart = (overlapStart - rangeStart) / viewDuration;
        CGFloat fracEnd = (overlapEnd - rangeStart) / viewDuration;
        markerLayer.frame = CGRectMake(fracStart * barWidth, 0, MAX(SBMarkerMinWidth, (fracEnd - fracStart) * barWidth), barHeight);
        objc_setAssociatedObject(markerLayer, @selector(sbSegmentData), @[@(fracStart), @(fracEnd), @(NO), @(rounding)], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [YMSBMarkerHelpers applyMarkerEndRounding:markerLayer mode:rounding barWidth:markerLayer.bounds.size.width barHeight:barHeight];
    }

    return markerLayer;
}

+ (void)layoutMarkerLayers:(CALayer *)container barWidth:(CGFloat)barWidth barHeight:(CGFloat)barHeight rounded:(BOOL)rounded {
    if (!container) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (rounded) [YMSBMarkerHelpers applyMarkerContainerRounding:container barHeight:barHeight];
    for (CALayer *layer in container.sublayers) {
        NSArray *data = objc_getAssociatedObject(layer, @selector(sbSegmentData));
        if (!data || data.count < 3) continue;
        CGFloat fracStart = [data[0] floatValue];
        CGFloat fracEnd = [data[1] floatValue];
        BOOL isPoi = [data[2] boolValue];
        NSInteger rounding = data.count > 3 ? [data[3] integerValue] : 0;
        CGFloat x, w;
        if (isPoi) {
            x = MAX(0.0, fracStart * barWidth - SBPoiMarkerXOffset);
            w = SBPoiMarkerWidth;
        } else {
            x = fracStart * barWidth;
            w = MAX(SBMarkerMinWidth, (fracEnd - fracStart) * barWidth);
        }
        CGRect target = CGRectMake(x, 0, w, barHeight);
        if (!CGRectEqualToRect(layer.frame, target)) {
            layer.frame = target;
            [YMSBMarkerHelpers applyMarkerEndRounding:layer mode:rounding barWidth:w barHeight:barHeight];
        }
    }
    [CATransaction commit];
}

+ (void)rebuildMarkersInLayer:(CALayer *)hostLayer segments:(NSArray<SBSegment *> *)segments rangeStart:(CGFloat)rangeStart rangeEnd:(CGFloat)rangeEnd videoStart:(CGFloat)videoStart videoEnd:(CGFloat)videoEnd {
    if (!hostLayer) return;
    [YMSBMarkerHelpers removeMarkerContainerFromLayer:hostLayer];
    CGFloat barWidth = hostLayer.bounds.size.width;
    CGFloat barHeight = hostLayer.bounds.size.height;
    if (barWidth <= 0 || barHeight <= 0) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (SBSegment *segment in segments) {
        SBSegmentAction action = [segment configuredAction];
        if (action == SBSegmentActionDisable) continue;
        CALayer *markerLayer = [YMSBMarkerHelpers makeMarkerLayer:segment rangeStart:rangeStart rangeEnd:rangeEnd videoStart:videoStart videoEnd:videoEnd barWidth:barWidth barHeight:barHeight];
        if (markerLayer) {
            markerLayer.name = SBSegmentMarkerLayerName;
            [hostLayer addSublayer:markerLayer];
        }
    }
    [CATransaction commit];
}

+ (void)rebuildMarkersInDecorationView:(UIView *)view {
    // Stamps live on the bar view: YouTube swaps decoration subviews, and a fresh view reads the same stamps.
    UIView *barView = view.superview;
    if (![barView isKindOfClass:%c(YTModularPlayerBarView)]) return;

    NSArray<SBSegment *> *segments = objc_getAssociatedObject(barView, @selector(sbSegmentsForView));
    NSInteger context = [objc_getAssociatedObject(barView, @selector(sbMarkerContextForView)) integerValue];

    // Disabled or no segments: remove existing markers.
    if (![YMSBMarkerHelpers markersEnabledForContext:context] || segments.count == 0) {
        [YMSBMarkerHelpers removeMarkerContainerFromLayer:view.layer];
        return;
    }

    // Transient states (model not ready, zero size): keep the old container to avoid blinking.
    CGFloat start = 0.0, end = 0.0;
    if (![YMSBMarkerHelpers getDecorationViewTimeRange:view start:&start end:&end]) return;
    CGFloat barHeight = view.bounds.size.height;
    if (view.bounds.size.width <= 0 || barHeight <= 0) return;

    CGFloat videoEnd = [[[view valueForKey:@"_model"] playingState] totalTimeSec];
    CALayer *container = [CALayer layer];
    container.name = SBSegmentMarkerLayerName;
    container.frame = view.bounds;
    if ([YMSBMarkerHelpers decorationCanApplyRoundedCorners:view]) [YMSBMarkerHelpers applyMarkerContainerRounding:container barHeight:barHeight];
    [view.layer addSublayer:container];

    [YMSBMarkerHelpers rebuildMarkersInLayer:container segments:segments rangeStart:start rangeEnd:end videoStart:start videoEnd:videoEnd];
}

@end

%hook YTPlayerBarProgressDecorationView
- (void)layoutSubviews {
    %orig;
    [YMSBMarkerHelpers rebuildMarkersInDecorationView:self];
}
%end

%hook YTPlayerBarRectangleDecorationView
- (void)layoutSubviews {
    %orig;
    [YMSBMarkerHelpers rebuildMarkersInDecorationView:self];
}
%end

// Bars without a decoration view (miniplayer, legacy feed slider) carry markers on their own layer.
%hook YTWatchFloatingMiniplayerProgressBarView
- (void)layoutSubviews {
    %orig;
    if (![YMSBMarkerHelpers markersEnabledForContext:SBMarkerContextMiniplayer]) {
        [YMSBMarkerHelpers removeMarkerContainerFromLayer:self.layer];
        return;
    }
    CGFloat barWidth = self.bounds.size.width, barHeight = self.bounds.size.height;
    if (barWidth <= 0 || barHeight <= 0) return;
    [YMSBMarkerHelpers layoutMarkerLayers:self.layer barWidth:barWidth barHeight:barHeight rounded:NO];
}
%end

%hook YTInlineMutedPlaybackScrubbingSlider
- (void)layoutSubviews {
    %orig;
    if (![YMSBMarkerHelpers markersEnabledForContext:SBMarkerContextFeed]) {
        [YMSBMarkerHelpers removeMarkerContainerFromLayer:self.layer];
        return;
    }
    CGFloat barWidth = self.bounds.size.width, barHeight = self.bounds.size.height;
    if (barWidth <= 0 || barHeight <= 0) return;
    [YMSBMarkerHelpers layoutMarkerLayers:self.layer barWidth:barWidth barHeight:barHeight rounded:NO];
}
%end

#pragma mark - YTPlayerViewController Hook (Notification Observer)

%hook YTPlayerViewController
- (void)viewDidLoad {
    %orig;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SBSegmentsDidLoad" object:self];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sbSegmentsDidLoad:)
                                                 name:@"SBSegmentsDidLoad"
                                               object:self];
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SBSegmentsDidLoad" object:self];
    %orig;
}
%new
- (void)sbSegmentsDidLoad:(NSNotification *)notification {
    [self sbRefreshMarkers:notification.userInfo[@"segments"]];
}
%new
// Stamps each bar with its segments (associated objects) and rebuilds once; an empty list clears stale markers.
- (void)sbRefreshMarkers:(NSArray<SBSegment *> *)segments {
    if (!IS_ENABLED(SBEnabled) || !IS_ENABLED(SBButtonKey)) return;
    if (!segments) segments = self.sbSegments;

    CGFloat totalTime = [self currentVideoTotalMediaTime];
    if (segments.count > 0 && totalTime <= 0) return;

    if ([self.parentViewController isKindOfClass:%c(YTWatchFloatingMiniplayerViewController)]) {
        if (!IS_ENABLED(SBSegmentsInMiniPlayer)) return;
        UIView *progressView = ((YTWatchFloatingMiniplayerViewController *)self.parentViewController).watchFloatingMiniplayerView.progressBarView;
        [YMSBMarkerHelpers rebuildMarkersInLayer:progressView.layer segments:segments rangeStart:0.0 rangeEnd:totalTime videoStart:0.0 videoEnd:totalTime];
    } else if ([self.activeVideoPlayerOverlay isKindOfClass:%c(YTMainAppVideoPlayerOverlayViewController)]) {
        if (!IS_ENABLED(SBSegmentsInPlayer)) return;
        YTModularPlayerBarView *playerBarView = ((YTMainAppVideoPlayerOverlayViewController *)self.activeVideoPlayerOverlay).playerBarController.playerBar.modularPlayerBar.view;
        objc_setAssociatedObject(playerBarView, @selector(sbSegmentsForView), segments, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(playerBarView, @selector(sbMarkerContextForView), @(SBMarkerContextPlayer), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        for (UIView *sub in playerBarView.subviews) {
            if ([sub isKindOfClass:%c(YTPlayerBarProgressDecorationView)] ||
                [sub isKindOfClass:%c(YTPlayerBarRectangleDecorationView)]) {
                [YMSBMarkerHelpers rebuildMarkersInDecorationView:sub];
            }
        }
    } else if ([self.activeVideoPlayerOverlay isKindOfClass:%c(YTInlineMutedPlaybackPlayerOverlayViewController)]) {
        if (!IS_ENABLED(SBSegmentsInFeed)) return;
        YTInlineMutedPlaybackPlayerOverlayView *view = (YTInlineMutedPlaybackPlayerOverlayView *)((YTInlineMutedPlaybackPlayerOverlayViewController *)self.activeVideoPlayerOverlay).view;
        YTInlineMutedPlaybackScrubberView *scrubView = view.scrubberView;
        if (scrubView.modularPlayerBarEnabled) {
            YTModularPlayerBarView *modularView = scrubView.modularPlayerBar.view;
            objc_setAssociatedObject(modularView, @selector(sbSegmentsForView), segments, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(modularView, @selector(sbMarkerContextForView), @(SBMarkerContextFeed), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            for (UIView *sub in modularView.subviews) {
                if ([sub isKindOfClass:%c(YTPlayerBarProgressDecorationView)] ||
                    [sub isKindOfClass:%c(YTPlayerBarRectangleDecorationView)]) {
                    [YMSBMarkerHelpers rebuildMarkersInDecorationView:sub];
                }
            }
        } else {
            [YMSBMarkerHelpers rebuildMarkersInLayer:scrubView.scrubber.layer segments:segments rangeStart:0.0 rangeEnd:totalTime videoStart:0.0 videoEnd:totalTime];
        }
    }
}
- (void)setPlayerViewLayout:(NSInteger)layout {
    %orig;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{ 
        [weakSelf sbRefreshMarkers:nil];
        sbUpdateOverlayInsetForPivotBar();
    });
}
- (void)updateViewportSizeProvider {
    %orig;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{ 
        [weakSelf sbRefreshMarkers:nil];
        sbUpdateOverlayInsetForPivotBar();
    });
}
%end
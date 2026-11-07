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
static BOOL SBMarkersEnabledForContext(NSInteger context) {
    if (!IS_ENABLED(SBEnabled) || !IS_ENABLED(SBButtonKey)) return NO;
    if (context == SBMarkerContextPlayer) return IS_ENABLED(SBSegmentsInPlayer);
    if (context == SBMarkerContextFeed) return IS_ENABLED(SBSegmentsInFeed);
    if (context == SBMarkerContextMiniplayer) return IS_ENABLED(SBSegmentsInMiniPlayer);
    return NO;
}

static void SBApplyMarkerContainerRounding(CALayer *container, CGFloat barHeight) {
    if (!container || barHeight <= 0) return;
    container.masksToBounds = YES;
    container.cornerRadius = barHeight / 2.0;
}

static const NSInteger SBMarkerRoundsLeft = 1;
static const NSInteger SBMarkerRoundsRight = 2;

static void SBApplyMarkerEndRounding(CALayer *markerLayer, NSInteger mode, CGFloat barWidth, CGFloat barHeight) {
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

static BOOL SBGetDecorationViewTimeRange(UIView *view, CGFloat *outStart, CGFloat *outEnd) {
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

static BOOL SBDecorationCanApplyRoundedCorners(UIView *view) {
    YTIPlayerBarDecorationModel *model = [view valueForKey:@"_model"];
    if (!model.style.hasRoundedCorners) return NO;
    YTMainAppVideoPlayerOverlayViewController *ovc = (YTMainAppVideoPlayerOverlayViewController *)view._viewControllerForAncestor;
    if (![ovc isKindOfClass:%c(YTMainAppVideoPlayerOverlayViewController)]) return NO;
    return ovc.isFullscreen;
}

static void SBRemoveMarkerContainerFromLayer(CALayer *hostLayer) {
    for (CALayer *layer in [hostLayer.sublayers copy]) {
        if ([layer.name isEqualToString:SBSegmentMarkerLayerName]) {
            [layer removeFromSuperlayer];
        }
    }
}

static CALayer *SBMakeMarkerLayer(SBSegment *segment, CGFloat rangeStart, CGFloat rangeEnd, CGFloat videoStart, CGFloat videoEnd, CGFloat barWidth, CGFloat barHeight) {
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
        SBApplyMarkerEndRounding(markerLayer, rounding, markerLayer.bounds.size.width, barHeight);
    }

    return markerLayer;
}

static void SBLayoutMarkerLayers(CALayer *container, CGFloat barWidth, CGFloat barHeight, BOOL rounded) {
    if (!container) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (rounded) SBApplyMarkerContainerRounding(container, barHeight);
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
            SBApplyMarkerEndRounding(layer, rounding, w, barHeight);
        }
    }
    [CATransaction commit];
}

static void SBRebuildMarkersInLayer(CALayer *hostLayer, NSArray<SBSegment *> *segments, CGFloat rangeStart, CGFloat rangeEnd, CGFloat videoStart, CGFloat videoEnd) {
    if (!hostLayer) return;
    SBRemoveMarkerContainerFromLayer(hostLayer);
    CGFloat barWidth = hostLayer.bounds.size.width;
    CGFloat barHeight = hostLayer.bounds.size.height;
    if (barWidth <= 0 || barHeight <= 0) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (SBSegment *segment in segments) {
        SBSegmentAction action = [segment configuredAction];
        if (action == SBSegmentActionDisable) continue;
        CALayer *markerLayer = SBMakeMarkerLayer(segment, rangeStart, rangeEnd, videoStart, videoEnd, barWidth, barHeight);
        if (markerLayer) {
            markerLayer.name = SBSegmentMarkerLayerName;
            [hostLayer addSublayer:markerLayer];
        }
    }
    [CATransaction commit];
}

static void SBRebuildMarkersInDecorationView(UIView *view) {
    // Stamps live on the bar view: YouTube swaps decoration subviews, and a fresh view reads the same stamps.
    UIView *barView = view.superview;
    if (![barView isKindOfClass:%c(YTModularPlayerBarView)]) return;

    NSArray<SBSegment *> *segments = objc_getAssociatedObject(barView, @selector(sbSegmentsForView));
    NSInteger context = [objc_getAssociatedObject(barView, @selector(sbMarkerContextForView)) integerValue];

    // Disabled or no segments: remove existing markers.
    if (!SBMarkersEnabledForContext(context) || segments.count == 0) {
        SBRemoveMarkerContainerFromLayer(view.layer);
        return;
    }

    // Transient states (model not ready, zero size): keep the old container to avoid blinking.
    CGFloat start = 0.0, end = 0.0;
    if (!SBGetDecorationViewTimeRange(view, &start, &end)) return;
    CGFloat barHeight = view.bounds.size.height;
    if (view.bounds.size.width <= 0 || barHeight <= 0) return;

    CGFloat videoEnd = [[[view valueForKey:@"_model"] playingState] totalTimeSec];
    CALayer *container = [CALayer layer];
    container.name = SBSegmentMarkerLayerName;
    container.frame = view.bounds;
    if (SBDecorationCanApplyRoundedCorners(view)) SBApplyMarkerContainerRounding(container, barHeight);
    [view.layer addSublayer:container];

    SBRebuildMarkersInLayer(container, segments, start, end, start, videoEnd);
}

%hook YTPlayerBarProgressDecorationView
- (void)layoutSubviews {
    %orig;
    SBRebuildMarkersInDecorationView(self);
}
%end

%hook YTPlayerBarRectangleDecorationView
- (void)layoutSubviews {
    %orig;
    SBRebuildMarkersInDecorationView(self);
}
%end

// Bars without a decoration view (miniplayer, legacy feed slider) carry markers on their own layer.
%hook YTWatchFloatingMiniplayerProgressBarView
- (void)layoutSubviews {
    %orig;
    if (!SBMarkersEnabledForContext(SBMarkerContextMiniplayer)) {
        SBRemoveMarkerContainerFromLayer(self.layer);
        return;
    }
    CGFloat barWidth = self.bounds.size.width, barHeight = self.bounds.size.height;
    if (barWidth <= 0 || barHeight <= 0) return;
    SBLayoutMarkerLayers(self.layer, barWidth, barHeight, NO);
}
%end

%hook YTInlineMutedPlaybackScrubbingSlider
- (void)layoutSubviews {
    %orig;
    if (!SBMarkersEnabledForContext(SBMarkerContextFeed)) {
        SBRemoveMarkerContainerFromLayer(self.layer);
        return;
    }
    CGFloat barWidth = self.bounds.size.width, barHeight = self.bounds.size.height;
    if (barWidth <= 0 || barHeight <= 0) return;
    SBLayoutMarkerLayers(self.layer, barWidth, barHeight, NO);
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
        SBRebuildMarkersInLayer(progressView.layer, segments, 0.0, totalTime, 0.0, totalTime);
    } else if ([self.activeVideoPlayerOverlay isKindOfClass:%c(YTMainAppVideoPlayerOverlayViewController)]) {
        if (!IS_ENABLED(SBSegmentsInPlayer)) return;
        id playerBar = ((YTMainAppVideoPlayerOverlayViewController *)self.activeVideoPlayerOverlay).playerBarController.playerBar;
        if (![playerBar respondsToSelector:@selector(modularPlayerBar)]) return; // 19.20.x and older: no modular bar
        YTModularPlayerBarView *playerBarView = [playerBar modularPlayerBar].view;
        objc_setAssociatedObject(playerBarView, @selector(sbSegmentsForView), segments, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(playerBarView, @selector(sbMarkerContextForView), @(SBMarkerContextPlayer), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        for (UIView *sub in playerBarView.subviews) {
            if ([sub isKindOfClass:%c(YTPlayerBarProgressDecorationView)] ||
                [sub isKindOfClass:%c(YTPlayerBarRectangleDecorationView)]) {
                SBRebuildMarkersInDecorationView(sub);
            }
        }
    } else if ([self.activeVideoPlayerOverlay isKindOfClass:%c(YTInlineMutedPlaybackPlayerOverlayViewController)]) {
        if (!IS_ENABLED(SBSegmentsInFeed)) return;
        YTInlineMutedPlaybackPlayerOverlayView *view = (YTInlineMutedPlaybackPlayerOverlayView *)((YTInlineMutedPlaybackPlayerOverlayViewController *)self.activeVideoPlayerOverlay).view;
        YTInlineMutedPlaybackScrubberView *scrubView = view.scrubberView;
        if ([scrubView respondsToSelector:@selector(modularPlayerBarEnabled)] && scrubView.modularPlayerBarEnabled) {
            YTModularPlayerBarView *modularView = scrubView.modularPlayerBar.view;
            objc_setAssociatedObject(modularView, @selector(sbSegmentsForView), segments, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(modularView, @selector(sbMarkerContextForView), @(SBMarkerContextFeed), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            for (UIView *sub in modularView.subviews) {
                if ([sub isKindOfClass:%c(YTPlayerBarProgressDecorationView)] ||
                    [sub isKindOfClass:%c(YTPlayerBarRectangleDecorationView)]) {
                    SBRebuildMarkersInDecorationView(sub);
                }
            }
        } else {
            SBRebuildMarkersInLayer(scrubView.scrubber.layer, segments, 0.0, totalTime, 0.0, totalTime);
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

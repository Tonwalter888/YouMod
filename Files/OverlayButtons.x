#import "Headers.h"

static NSString *YouModUpdateSpeedLabel = @"YouModUpdateSpeedLabel";
static NSString *currentSpeedLabel = @"1x";
static float currentPlaybackRate = 1.0;

static NSString *YouModUpdateNotification = @"YouModUpdateNotification";
static NSString *currentQualityLabel = @"Auto";

static NSString *speedLabel(float rate) {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.minimumFractionDigits = 0;
    formatter.maximumFractionDigits = 2;
    NSString *rateString = [formatter stringFromNumber:[NSNumber numberWithFloat:rate]];
    return [NSString stringWithFormat:@"%@x", rateString];
}

static void didSelectRate(float rate) {
    currentPlaybackRate = rate;
    currentSpeedLabel = speedLabel(rate);
    [[NSNotificationCenter defaultCenter] postNotificationName:YouModUpdateSpeedLabel object:nil];
}

@interface YTMainAppControlsOverlayView ()
- (void)updateQualityButton:(id)arg;
- (void)updateSpeedButton:(id)arg;
@end

// YouGetCaption (https://github.com/PoomSmart/YouGetCaption)
static void showTranscript(YTFormat3CaptionViewController *cvc) {
    UIView *parent = sbGetNotificationParent();
    MLFormat3Captions *currentCaptions = [cvc valueForKey:@"_currentCaptions"];
    YTIntervalTree *tree = currentCaptions.captions;
    NSMutableString *transcript = [NSMutableString string];
    [tree enumerateAllIntervalsWithBlock:^(YTInterval *interval) {
        MLCaption *caption = (MLCaption *)interval;
        NSArray <MLCaptionSegment *> *segments = caption.segments;
        for (MLCaptionSegment *segment in segments) {
            [transcript appendString:segment.text];
        }
    }];
    if (transcript.length == 0) {
        [SBSkipNotificationView showErrorInView:parent message:LOC(@"NO_CAPTIONS") duration:4.0];
        return;
    }
    YTAlertView *alertView = [%c(YTAlertView) confirmationDialogWithAction:^{
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = transcript;
        [SBSkipNotificationView showSuccessInView:parent message:LOC(@"COPIED_TO_CLIPBOARD") duration:3.0];
    } actionTitle:LOC(@"COPY")];
    alertView.title = nil;
    alertView.subtitle = transcript;
    alertView.shouldDismissOnBackgroundTap = YES;
    [alertView show];
}

#pragma mark - YMOverlayButtonSpec

@implementation YMOverlayButtonSpec
@end

#pragma mark - Registry

// Base of the view-tag range for registered overlay buttons. Chosen to avoid
// colliding with other tagged views in the player overlay (e.g. the seek-bar
// segment markers at 9900).
static const NSInteger YMOverlayButtonBaseTag = 9910;

// Button geometry. The top inset places the row just below YouTube's own
// CC/gear row in the top-right corner of the player overlay.
static const CGFloat YMOverlayButtonSize = 30.0;
static const CGFloat YMOverlayButtonGap = 6.0;
static const CGFloat YMOverlayButtonTopInset = 52.0; // fallback row top when the gear can't be located
static const CGFloat YMOverlayButtonEdgePadding = 12.0; // fallback right padding when the gear isn't found

// Width of a text button. Tweak this to make text buttons wider or narrower; icon
// buttons stay square at YMOverlayButtonSize.
static const CGFloat YMOverlayTextButtonWidth = 30.0;

static NSMutableArray<YMOverlayButtonSpec *> *gOverlayButtons = nil;
static NSInteger gOverlayButtonNextTag = YMOverlayButtonBaseTag;

void YMRegisterOverlayButton(YMOverlayButtonSpec *spec) {
    if (!spec || spec.identifier.length == 0) return;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ gOverlayButtons = [NSMutableArray array]; });

    // Replace any previous registration with the same identifier (idempotent).
    for (YMOverlayButtonSpec *existing in [gOverlayButtons copy]) {
        if ([existing.identifier isEqualToString:spec.identifier]) {
            spec.viewTag = existing.viewTag;
            [gOverlayButtons removeObject:existing];
        }
    }
    if (spec.viewTag == 0) spec.viewTag = gOverlayButtonNextTag++;
    [gOverlayButtons addObject:spec];
}

NSArray<YMOverlayButtonSpec *> *YMRegisteredOverlayButtons(void) {
    if (!gOverlayButtons) return @[];
    return [gOverlayButtons sortedArrayUsingComparator:^NSComparisonResult(YMOverlayButtonSpec *a, YMOverlayButtonSpec *b) {
        if (a.sortOrder == b.sortOrder) return [a.identifier compare:b.identifier];
        return a.sortOrder < b.sortOrder ? NSOrderedAscending : NSOrderedDescending;
    }];
}

BOOL YMIsOverlayButtonEnabled(NSString *identifier) {
    if (!identifier || identifier.length == 0) return NO;
    if ([identifier isEqualToString:@"download.video"]) {
        if (!IS_ENABLED(DownloadManager)) return NO;
        return INTFORVAL(DownloadButtonPosition) != DownloadButtonPositionUnderPlayer;
    }
    if ([identifier isEqualToString:@"sponsorblock.toggle"]) return IS_ENABLED(SBEnabled) && IS_ENABLED(SBShowButton);
    NSArray *savedOrder = [[NSUserDefaults standardUserDefaults] arrayForKey:OverlayButtonOrder];
    if (savedOrder.count > 0) {
        for (NSDictionary *entry in savedOrder) {
            if ([entry[@"id"] isEqualToString:identifier]) {
                return [entry[@"enabled"] boolValue];
            }
        }
        return YES;
    }
    // Fallback migration for legacy keys if custom order is not saved yet
    if ([identifier isEqualToString:@"mute.video"]) return IS_ENABLED(MuteButton);
    if ([identifier isEqualToString:@"speed.video"]) return IS_ENABLED(SpeedButton);
    if ([identifier isEqualToString:@"quality.video"]) return IS_ENABLED(QualityButton);
    if ([identifier isEqualToString:@"share.video"]) return IS_ENABLED(ShareButton);
    if ([identifier isEqualToString:@"loop.video"]) return IS_ENABLED(LoopButton);
    if ([identifier isEqualToString:@"caption.video"]) return IS_ENABLED(CaptionButton);
    if ([identifier isEqualToString:@"download.video"]) return IS_ENABLED(DownloadManager) && INTFORVAL(DownloadButtonPosition) != DownloadButtonPositionUnderPlayer;
    return YES;
}

// Whether a button is placed in the bottom bar (YTInlinePlayerBarContainerView)
// instead of the top overlay row. Persisted per-entry as "bottom" in the
// OverlayButtonOrder prefs array; defaults to NO (top row).
BOOL YMIsOverlayButtonBottom(NSString *identifier) {
    if (!identifier || identifier.length == 0) return NO;
    NSArray *savedOrder = [[NSUserDefaults standardUserDefaults] arrayForKey:OverlayButtonOrder];
    for (NSDictionary *entry in savedOrder) {
        if ([entry[@"id"] isEqualToString:identifier]) {
            return [entry[@"bottom"] boolValue];
        }
    }
    return NO;
}

NSArray<YMOverlayButtonSpec *> *YMOrderedOverlayButtons(void) {
    if (!gOverlayButtons || gOverlayButtons.count == 0) return @[];

    NSMutableDictionary<NSString *, YMOverlayButtonSpec *> *lookup = [NSMutableDictionary dictionary];
    for (YMOverlayButtonSpec *spec in gOverlayButtons) {
        if (spec.identifier) lookup[spec.identifier] = spec;
    }

    NSArray *savedOrder = [[NSUserDefaults standardUserDefaults] arrayForKey:OverlayButtonOrder];
    NSMutableArray<YMOverlayButtonSpec *> *ordered = [NSMutableArray array];

    if (savedOrder.count > 0) {
        for (NSDictionary *entry in savedOrder) {
            NSString *ident = entry[@"id"];
            BOOL enabled;
            if ([ident isEqualToString:@"sponsorblock.toggle"] || [ident isEqualToString:@"download.video"]) {
                enabled = YMIsOverlayButtonEnabled(ident);
            } else {
                enabled = [entry[@"enabled"] boolValue];
            }
            if (!enabled) continue;
            YMOverlayButtonSpec *spec = lookup[ident];
            if (spec) [ordered addObject:spec];
        }
        // Append any registered specs not present in savedOrder
        for (YMOverlayButtonSpec *spec in YMRegisteredOverlayButtons()) {
            BOOL found = NO;
            for (NSDictionary *entry in savedOrder) {
                if ([entry[@"id"] isEqualToString:spec.identifier]) {
                    found = YES;
                    break;
                }
            }
            if (!found) {
                if (YMIsOverlayButtonEnabled(spec.identifier)) {
                    [ordered addObject:spec];
                }
            }
        }
    } else {
        for (YMOverlayButtonSpec *spec in YMRegisteredOverlayButtons()) {
            if (YMIsOverlayButtonEnabled(spec.identifier)) {
                [ordered addObject:spec];
            }
        }
    }

    return ordered;
}

#pragma mark - Helpers

// The player view controller that owns this controls overlay, reached through the
// overlay's events delegate. Button handlers use it to act on the current video.
static YTPlayerViewController *YMPlayerVCFromOverlay(YTMainAppControlsOverlayView *overlay) {
    YTMainAppVideoPlayerOverlayViewController *mainOverlayController = (YTMainAppVideoPlayerOverlayViewController *)overlay.eventsDelegate;
    return mainOverlayController.parentViewController;
}

// Recursively find the right-most YTQTMButton in the overlay's top region. YouTube
// nests the gear/CC/cast buttons inside a container, so a one-level scan would miss
// them; recursion reaches the nested buttons wherever they sit.
static void YMScanForGearFrame(UIView *view, YTMainAppControlsOverlayView *overlay, CGFloat topRegionMaxY, CGRect *bestFrame) {
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:%c(YTQTMButton)]) {
            CGRect f = [sub convertRect:sub.bounds toView:overlay];
            // Zero-size frames show up transiently while the overlay is
            // animating; anchoring to one parks the row at a garbage spot.
            if (!CGRectIsEmpty(f) && CGRectGetMidY(f) <= topRegionMaxY) { // in the top button row
                // The CGRectIsNull check must stay first: CGRectGetMidX(CGRectNull) is
                // infinite, so the > comparison alone would never accept the first match.
                if (CGRectIsNull(*bestFrame) || CGRectGetMidX(f) > CGRectGetMidX(*bestFrame)) *bestFrame = f;
            }
        }
        YMScanForGearFrame(sub, overlay, topRegionMaxY, bestFrame);
    }
}

// Find YouTube's settings/overflow button so we can anchor our row directly beneath it.
// Prefer the overlay's own overflowButton; otherwise take the right-most YTQTMButton in
// the overlay's top region. Returns its frame in the overlay's coordinate space, or
// CGRectNull if not found (the caller then falls back to the screen edge / top inset).
static CGRect YMGearFrameInOverlay(YTMainAppControlsOverlayView *overlay) {
    YTQTMButton *overflow = [overlay valueForKey:@"_overflowButton"];
    if (overflow.window) {
        CGRect frame = [overflow convertRect:overflow.bounds toView:overlay];
        if (!CGRectIsEmpty(frame)) return frame;
    }

    CGFloat topRegionMaxY = overlay.bounds.size.height * 0.25;
    CGRect bestFrame = CGRectNull;
    YMScanForGearFrame(overlay, overlay, topRegionMaxY, &bestFrame);
    return bestFrame;
}

static UIFont *YMOverlayTextButtonFont(NSString *text, CGSize maxSize) {
    if (text.length == 0) return [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    
    YTDefaultTypeStyle *typeStyle = [%c(YTTypeStyle) defaultTypeStyle];
    BOOL hasYTFont = [typeStyle respondsToSelector:@selector(ytSansFontOfSize:weight:)];
    NSInteger bestSize = 10;

    for (NSInteger size = (NSInteger)maxSize.height; size >= 8; size--) {
        UIFont *testFont = hasYTFont ? [typeStyle ytSansFontOfSize:(CGFloat)size weight:UIFontWeightSemibold] : [UIFont systemFontOfSize:(CGFloat)size weight:UIFontWeightSemibold];
        CGRect rect = [text boundingRectWithSize:CGSizeMake(maxSize.width, CGFLOAT_MAX)
                                         options:NSStringDrawingUsesLineFragmentOrigin
                                      attributes:@{NSFontAttributeName: testFont}
                                         context:nil];
        if (ceil(rect.size.width) <= maxSize.width && ceil(rect.size.height) <= maxSize.height) {
            bestSize = size;
            break;
        }
    } 
    return hasYTFont ? [typeStyle ytSansFontOfSize:(CGFloat)bestSize weight:UIFontWeightSemibold] : [UIFont systemFontOfSize:(CGFloat)bestSize weight:UIFontWeightSemibold];
}

static UIImage *YMOverlayButtonIcon(NSString *symbolName) {
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
    UIImage *symbol = [UIImage systemImageNamed:symbolName withConfiguration:config];
    return [symbol imageWithTintColor:[UIColor whiteColor]];
}

// Sleep timer button: red moon (not filled) while a timer is running, white otherwise.
// AlwaysOriginal so YTQTMButton's own white tint can't repaint the icon.
static UIImage *YMSleepTimerOverlayIcon(void) {
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
    UIImage *symbol = [UIImage systemImageNamed:@"moon" withConfiguration:config];
    UIColor *tint = YMSleepTimerIsActive() ? [UIColor systemRedColor] : [UIColor whiteColor];
    return [[symbol imageWithTintColor:tint] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

static YTQTMButton *YMCreateOverlayButton(UIView *parent, YMOverlayButtonSpec *spec) {
    YTQTMButton *button;
    if (spec.title.length > 0) {
        button = [%c(YTQTMButton) textButton];
        [button setTitle:spec.title forState:UIControlStateNormal];
        button.titleLabel.font = YMOverlayTextButtonFont(spec.title, CGSizeMake(25, 25));
        button.titleLabel.textAlignment = NSTextAlignmentCenter;
        button.sizeWithPaddingAndInsets = NO;
        button.titleLabel.numberOfLines = 2;
        button.titleLabel.adjustsFontSizeToFitWidth = YES;
        button.titleLabel.lineBreakMode = NSLineBreakByClipping; 
        button.titleLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
        button.contentEdgeInsets = UIEdgeInsetsZero;
        button.titleEdgeInsets = UIEdgeInsetsZero;
        button.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    } else {
        // The sleep button bakes its own state color (red while active), so a
        // freshly created button reflects the timer without waiting for a notification.
        UIImage *icon = [spec.identifier isEqualToString:@"sleep.timer"] ? YMSleepTimerOverlayIcon() : YMOverlayButtonIcon(spec.symbolName);
        button = [%c(YTQTMButton) iconButton];
        [button setImage:icon forState:UIControlStateNormal];
        button.imageView.contentMode = UIViewContentModeScaleAspectFit;
        [button setTintColor:[UIColor whiteColor]];
    }

    button.exclusiveTouch = YES;
    button.tag = spec.viewTag;
    button.frame = CGRectMake(0, 0, YMOverlayButtonSize, YMOverlayButtonSize);
    [button addTarget:parent action:@selector(ymOverlayButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [parent addSubview:button];
    return button;
}

#pragma mark - YTMainAppControlsOverlayView Hook

static BOOL isRelatedVideosExpanded = NO;

%hook YTMainAppControlsOverlayView

- (void)layoutSubviews {
    %orig;
    YouModApplyPrevNextReplacement(self);
    NSArray<YMOverlayButtonSpec *> *allRegistered = YMRegisteredOverlayButtons();
    // Bottom-placed buttons live in YTInlinePlayerBarContainerView, not here.
    NSMutableArray<YMOverlayButtonSpec *> *specs = [NSMutableArray array];
    for (YMOverlayButtonSpec *spec in YMOrderedOverlayButtons()) {
        if (!YMIsOverlayButtonBottom(spec.identifier)) [specs addObject:spec];
    }

    // Nothing enabled on this side — drop any leftovers and bail before the
    // gear lookup / player resolution.
    if (specs.count == 0) {
        for (YMOverlayButtonSpec *spec in allRegistered) {
            UIView *btn = [self viewWithTag:spec.viewTag];
            if (btn) [btn removeFromSuperview];
        }
        return;
    }

    NSMutableSet<NSNumber *> *activeTags = [NSMutableSet set];
    for (YMOverlayButtonSpec *spec in specs) {
        [activeTags addObject:@(spec.viewTag)];
    }
    for (YMOverlayButtonSpec *spec in allRegistered) {
        if (![activeTags containsObject:@(spec.viewTag)]) {
            UIView *btn = [self viewWithTag:spec.viewTag];
            if (btn) [btn removeFromSuperview];
        }
    }

    YTPlayerViewController *player = YMPlayerVCFromOverlay(self);
    YTSingleVideoController *sgvid = player.activeVideo;
    YTSingleVideo *sgvid2 = sgvid.singleVideo;
    BOOL isLive = [sgvid2 isLivePlayback];
    BOOL overlayVisible = self.isOverlayVisible;
    CGRect gearFrame = YMGearFrameInOverlay(self);
    BOOL hasGear = !CGRectIsNull(gearFrame);
    CGFloat trailingCenterX = hasGear ? CGRectGetMidX(gearFrame) : self.bounds.size.width - YMOverlayButtonEdgePadding - YMOverlayButtonSize / 2.0;
    CGFloat rowTop = hasGear ? CGRectGetMaxY(gearFrame) : YMOverlayButtonTopInset;
    CGFloat prevHalfWidth = 0;

    for (YMOverlayButtonSpec *spec in specs) {
        BOOL isHiddenOnLive = isLive && ([spec.identifier isEqualToString:@"sponsorblock.toggle"] ||
                                         [spec.identifier isEqualToString:@"loop.video"] ||
                                         [spec.identifier isEqualToString:@"caption.video"]);
        BOOL visible = !isHiddenOnLive && ((spec.isVisible == nil) || spec.isVisible(player));
        YTQTMButton *btn = (YTQTMButton *)[self viewWithTag:spec.viewTag];

        if (!visible) {
            if (btn) [btn removeFromSuperview];
            continue;
        }
        if (!btn) btn = YMCreateOverlayButton(self, spec);

        btn.hidden = !overlayVisible || isRelatedVideosExpanded;


        CGFloat width = (spec.title.length > 0) ? YMOverlayTextButtonWidth : YMOverlayButtonSize;
        CGFloat centerX = (prevHalfWidth == 0) ? trailingCenterX : trailingCenterX - prevHalfWidth - YMOverlayButtonGap - width / 2.0;

        btn.frame = CGRectMake(centerX - width / 2.0, rowTop, width, YMOverlayButtonSize);
        trailingCenterX = centerX;
        prevHalfWidth = width / 2.0;
        [self bringSubviewToFront:btn];
    }
}

- (void)setOverlayVisible:(BOOL)visible {
    %orig;
    for (YMOverlayButtonSpec *spec in YMRegisteredOverlayButtons()) {
        YTQTMButton *btn = (YTQTMButton *)[self viewWithTag:spec.viewTag];
        if (btn) btn.hidden = !visible || isRelatedVideosExpanded;
    }
}

%new
- (void)ymOverlayButtonTapped:(YTQTMButton *)sender {
    YMOverlayButtonSpec *matched = nil;
    for (YMOverlayButtonSpec *spec in YMRegisteredOverlayButtons()) {
        if (spec.viewTag == sender.tag) { matched = spec; break; }
    }
    if (!matched || !matched.onTap) return;

    YTPlayerViewController *player = YMPlayerVCFromOverlay(self);
    matched.onTap(player, sender);
}

- (id)initWithDelegate:(id)delegate {
    self = %orig;
    [self updateSpeedButton:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSpeedButton:) name:YouModUpdateSpeedLabel object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateQualityButton:) name:YouModUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ymUpdateSleepButtonIcon:) name:YouModUpdateNotification object:nil];
    return self;
}

- (id)initWithDelegate:(id)delegate autoplaySwitchEnabled:(BOOL)autoplaySwitchEnabled {
    self = %orig;
    [self updateSpeedButton:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSpeedButton:) name:YouModUpdateSpeedLabel object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateQualityButton:) name:YouModUpdateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ymUpdateSleepButtonIcon:) name:YouModUpdateNotification object:nil];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:YouModUpdateSpeedLabel object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:YouModUpdateNotification object:nil];
    %orig;
}

%new
- (void)updateSpeedButton:(id)arg {
    for (YMOverlayButtonSpec *spec in YMRegisteredOverlayButtons()) {
        if ([spec.identifier isEqualToString:@"speed.video"]) {
            spec.title = currentSpeedLabel;

            YTQTMButton *btn = (YTQTMButton *)[self viewWithTag:spec.viewTag];
            if (btn) {
                [btn setTitle:currentSpeedLabel forState:UIControlStateNormal];
                btn.titleLabel.font = YMOverlayTextButtonFont(currentSpeedLabel, CGSizeMake(25, 25));
            }
            break;
        }
    }
}

%new
- (void)updateQualityButton:(id)arg {
    for (YMOverlayButtonSpec *spec in YMRegisteredOverlayButtons()) {
        if ([spec.identifier isEqualToString:@"quality.video"]) {
            spec.title = currentQualityLabel;

            YTQTMButton *btn = (YTQTMButton *)[self viewWithTag:spec.viewTag];
            if (btn) {
                [btn setTitle:currentQualityLabel forState:UIControlStateNormal];
                btn.titleLabel.font = YMOverlayTextButtonFont(currentQualityLabel, CGSizeMake(25, 25));
            }
            break;
        }
    }
}

// Refresh the sleep timer icon (white/red) when the timer state changes
// outside the button itself — start/cancel from the tab menu, expiry, etc.
%new
- (void)ymUpdateSleepButtonIcon:(id)arg {
    for (YMOverlayButtonSpec *spec in YMRegisteredOverlayButtons()) {
        if ([spec.identifier isEqualToString:@"sleep.timer"]) {
            YTQTMButton *btn = (YTQTMButton *)[self viewWithTag:spec.viewTag];
            if (btn) [btn setImage:YMSleepTimerOverlayIcon() forState:UIControlStateNormal];
            break;
        }
    }
}
%end

%hook YTRelatedVideosViewController
- (void)setExpanded:(BOOL)arg {
    %orig;
    isRelatedVideosExpanded = arg;
    YTRelatedVideosView *relatedview = (YTRelatedVideosView *)self.view;
    YTFullscreenEngagementOverlayView *fullov = (YTFullscreenEngagementOverlayView *)relatedview.superview;
    YTMainAppVideoPlayerOverlayView *mainov = (YTMainAppVideoPlayerOverlayView *)fullov.superview;
    YTMainAppControlsOverlayView *conov = [mainov controlsOverlayView];
    [conov setNeedsLayout];
}
%end

#pragma mark - Bottom Row (YTInlinePlayerBarContainerView)

#pragma mark - Frosted Glass Background

// View-tag for the frosted-glass pill behind the bottom button row. Sits just
// below YMOverlayButtonBaseTag so it never collides with button tags.
static const NSInteger YMFrostedBackgroundTag = 9905;

// Padding around the button union. Vertical padding stays 0 — the pill must
// match the button height exactly (30pt) rather than grow taller than it.
static const CGFloat YMFrostedBackgroundHPadding = 8.0;
static const CGFloat YMFrostedBackgroundVPadding = 0.0;

// Applies YouTube's own frosted-glass effect to `view` (the pill that covers
// every bottom overlay button). Pass nil for frostedGlassView and one is
// created with YouTube's current blur style (falls back to style 16 when the
// class-level accessor is missing, matching YouTube's own default).
static void maybeApplyFrostedGlassToView(YTFrostedGlassView *frostedGlassView, UIView *view) {
    Class YTFrostedGlassViewClass = %c(YTFrostedGlassView);
    if (!YTFrostedGlassViewClass || !view) return;
    NSInteger blurEffectStyle = [YTFrostedGlassViewClass respondsToSelector:@selector(frostedGlassBlurEffectStyle)] ? [YTFrostedGlassViewClass frostedGlassBlurEffectStyle] : 16;
    if (!frostedGlassView) {
        @try {
            frostedGlassView = [[YTFrostedGlassViewClass alloc] initWithBlurEffectStyle:blurEffectStyle alpha:1.0];
        } @catch (id ex) {
            frostedGlassView = [[YTFrostedGlassViewClass alloc] initWithBlurEffectStyle:blurEffectStyle];
        }
    }
    if (!frostedGlassView) return;
    if ([frostedGlassView respondsToSelector:@selector(maybeApplyToView:)]) [frostedGlassView maybeApplyToView:view];
}

// Creates (once) and maintains a frosted-glass pill sized to the union of the
// bottom overlay buttons. Kept below the buttons in the subview order so the
// icons draw on top; removed entirely when there is nothing to cover.
static void YMFrostedBackgroundUpdate(YTInlinePlayerBarContainerView *self_, NSArray<UIView *> *buttons) {
    UIView *background = [self_ viewWithTag:YMFrostedBackgroundTag];
    if (buttons.count == 0) {
        [background removeFromSuperview];
        return;
    }

    CGRect unionFrame = CGRectNull;
    for (UIView *btn in buttons) {
        unionFrame = CGRectIsNull(unionFrame) ? btn.frame : CGRectUnion(unionFrame, btn.frame);
    }
    unionFrame = CGRectInset(unionFrame, -YMFrostedBackgroundHPadding, -YMFrostedBackgroundVPadding);

    if (!background) {
        background = [[UIView alloc] initWithFrame:unionFrame];
        background.tag = YMFrostedBackgroundTag;
        background.userInteractionEnabled = NO; // taps fall through to the player
        background.clipsToBounds = YES;
        maybeApplyFrostedGlassToView(nil, background);
        // The blur/overlay layers YTFrostedGlassView attaches must track the
        // pill's frame on every relayout, since only this pill (not the frosted
        // view itself) stays in the hierarchy.
        for (UIView *sub in background.subviews) {
            sub.frame = background.bounds;
            sub.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        }
        background.layer.cornerRadius = CGRectGetHeight(unionFrame) / 2.0;
        [self_ insertSubview:background belowSubview:buttons.firstObject];
    } else {
        background.frame = unionFrame;
        background.layer.cornerRadius = CGRectGetHeight(unionFrame) / 2.0;
    }
    background.hidden = ((UIView *)buttons.firstObject).hidden;
}

%hook YTInlinePlayerBarContainerView

- (id)init {
    self = %orig;
    if (self && [self._viewControllerForAncestor isKindOfClass:%c(YTMainAppVideoPlayerOverlayViewController)]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ymUpdateBarButtonLabels:) name:YouModUpdateSpeedLabel object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ymUpdateBarButtonLabels:) name:YouModUpdateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ymUpdateSleepButtonIcon:) name:YouModUpdateNotification object:nil];
        if (IS_ENABLED(SBShowButton)) {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTimeLabels) name:@"YouModUpdateTimeLabel" object:nil];
        }
    } 
    return self;
}

- (void)layoutSubviews {
    %orig;
    if (![self._viewControllerForAncestor isKindOfClass:%c(YTMainAppVideoPlayerOverlayViewController)]) return;
    NSArray<YMOverlayButtonSpec *> *allRegistered = YMRegisteredOverlayButtons();
    NSMutableArray<YMOverlayButtonSpec *> *specs = [NSMutableArray array];
    for (YMOverlayButtonSpec *spec in YMOrderedOverlayButtons()) {
        if (YMIsOverlayButtonBottom(spec.identifier)) [specs addObject:spec];
    }
    // Nothing enabled on this side — drop any leftovers and bail before the
    // anchor lookup / player resolution.
    if (specs.count == 0) {
        for (YMOverlayButtonSpec *spec in allRegistered) {
            UIView *btn = [self viewWithTag:spec.viewTag];
            if (btn) [btn removeFromSuperview];
        }
        [[self viewWithTag:YMFrostedBackgroundTag] removeFromSuperview];
        return;
    }
    UIView *button = [self exitFullscreenButton];
    if (button == nil) button = [[self valueForKey:@"_enterExitFullscreenButton"] valueForKey:@"_enterExitFullscreenButton"];
    // A mid-transition anchor can report a zero rect; anchoring to it would
    // stack the row on a garbage frame, so wait for a real one.
    BOOL hasAnchor = button && button.window && !CGRectIsEmpty(button.bounds);
    if (!hasAnchor) return;
    NSMutableSet<NSNumber *> *activeTags = [NSMutableSet set];
    for (YMOverlayButtonSpec *spec in specs) [activeTags addObject:@(spec.viewTag)];
    // Remove stale buttons — all of them when the anchor is unavailable.
    for (YMOverlayButtonSpec *spec in allRegistered) {
        if (![activeTags containsObject:@(spec.viewTag)]) {
            UIView *btn = [self viewWithTag:spec.viewTag];
            if (btn) [btn removeFromSuperview];
        }
    }

    YTPlayerViewController *player = ((YTMainAppVideoPlayerOverlayViewController *)self._viewControllerForAncestor).parentViewController;
    YTSingleVideoController *sgvid = player.activeVideo;
    YTSingleVideo *sgvid2 = sgvid.singleVideo;
    BOOL isLive = [sgvid2 isLivePlayback];
    BOOL peekVisible = [self isPeekableViewVisible];

    CGRect exitFrame = [button convertRect:button.bounds toView:self];
    CGFloat trailingCenterX = CGRectGetMidX(exitFrame);
    // Stack the row on top of the fullscreen button, not beside/over it.
    CGFloat rowTop = CGRectGetMinY(exitFrame) - YMOverlayButtonSize;
    CGFloat prevHalfWidth = 0;
    NSMutableArray<UIView *> *laidOutButtons = [NSMutableArray array];

    for (YMOverlayButtonSpec *spec in specs) {
        BOOL isHiddenOnLive = isLive && ([spec.identifier isEqualToString:@"sponsorblock.toggle"] ||
                                         [spec.identifier isEqualToString:@"loop.video"] ||
                                         [spec.identifier isEqualToString:@"caption.video"]);
        BOOL visible = !isHiddenOnLive && ((spec.isVisible == nil) || spec.isVisible(player));
        YTQTMButton *btn = (YTQTMButton *)[self viewWithTag:spec.viewTag];

        if (!visible) {
            if (btn) [btn removeFromSuperview];
            continue;
        }
        if (!btn) btn = YMCreateOverlayButton(self, spec);

        btn.hidden = !peekVisible || isRelatedVideosExpanded;


        CGFloat width = (spec.title.length > 0) ? YMOverlayTextButtonWidth : YMOverlayButtonSize;
        CGFloat centerX = (prevHalfWidth == 0) ? trailingCenterX : trailingCenterX - prevHalfWidth - YMOverlayButtonGap - width / 2.0;

        btn.frame = CGRectMake(centerX - width / 2.0, rowTop, width, YMOverlayButtonSize);
        trailingCenterX = centerX;
        prevHalfWidth = width / 2.0;
        [self bringSubviewToFront:btn];
        [laidOutButtons addObject:btn];
    }

    // Wrap the whole bottom row in one frosted-glass pill.
    YMFrostedBackgroundUpdate(self, laidOutButtons);
}

- (void)setPeekableViewVisible:(BOOL)visible {
    %orig;
    if (![self._viewControllerForAncestor isKindOfClass:%c(YTMainAppVideoPlayerOverlayViewController)]) return;
    for (YMOverlayButtonSpec *spec in YMRegisteredOverlayButtons()) {
        UIView *btn = [self viewWithTag:spec.viewTag];
        if ([btn isKindOfClass:%c(YTQTMButton)]) btn.hidden = !visible;
    }
    [[self viewWithTag:YMFrostedBackgroundTag] setHidden:!visible];
}

%new
- (void)ymOverlayButtonTapped:(YTQTMButton *)sender {
    YMOverlayButtonSpec *matched = nil;
    for (YMOverlayButtonSpec *spec in YMRegisteredOverlayButtons()) {
        if (spec.viewTag == sender.tag) { matched = spec; break; }
    }
    if (!matched || !matched.onTap) return;

    YTMainAppVideoPlayerOverlayViewController *ovcon = (YTMainAppVideoPlayerOverlayViewController *)self._viewControllerForAncestor;
    YTPlayerViewController *player = ovcon.parentViewController;
    if (player) matched.onTap(player, sender);
}

%new
- (void)ymUpdateBarButtonLabels:(id)arg {
    for (YMOverlayButtonSpec *spec in YMRegisteredOverlayButtons()) {
        NSString *label = nil;
        if ([spec.identifier isEqualToString:@"speed.video"]) label = currentSpeedLabel;
        else if ([spec.identifier isEqualToString:@"quality.video"]) label = currentQualityLabel;
        else continue;

        spec.title = label;
        YTQTMButton *btn = (YTQTMButton *)[self viewWithTag:spec.viewTag];
        if (btn) {
            [btn setTitle:label forState:UIControlStateNormal];
            btn.titleLabel.font = YMOverlayTextButtonFont(label, CGSizeMake(25, 25));
        }
    }
}

%new
- (void)ymUpdateSleepButtonIcon:(id)arg {
    for (YMOverlayButtonSpec *spec in YMRegisteredOverlayButtons()) {
        if ([spec.identifier isEqualToString:@"sleep.timer"]) {
            YTQTMButton *btn = (YTQTMButton *)[self viewWithTag:spec.viewTag];
            if (btn) [btn setImage:YMSleepTimerOverlayIcon() forState:UIControlStateNormal];
            break;
        }
    }
}
- (void)dealloc {
    if ([self._viewControllerForAncestor isKindOfClass:%c(YTMainAppVideoPlayerOverlayViewController)]) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:YouModUpdateSpeedLabel object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:YouModUpdateNotification object:nil];
        if (IS_ENABLED(SBShowButton)) {
            [[NSNotificationCenter defaultCenter] removeObserver:self name:@"YouModUpdateTimeLabel" object:nil];
        }
    }
    %orig;
}
%end

static void YouModShowShareNotification(NSString *message, BOOL success) {
    UIView *parent = sbGetNotificationParent();
    if (success) {
        [SBSkipNotificationView showSuccessInView:parent message:message duration:3.0];
    } else {
        [SBSkipNotificationView showErrorInView:parent message:message duration:4.0];
    }
}

%hook YTPlayerViewController
%new
- (void)YouModShareButton:(UIView *)sourceView {
    if (!self.currentVideoID) {
        YouModShowShareNotification(LOC(@"ERROR_VIDEOID"), NO);
        return;
    } else if (self.isPlayingAd) {
        YouModShowShareNotification(LOC(@"ERROR_ADS"), NO);
        return;
    }

    NSString *videoURL = [NSString stringWithFormat:@"https://youtube.com/watch?v=%@", self.currentVideoID];
    NSInteger seconds = (NSInteger)floor(self.currentVideoMediaTime);
    NSString *timestampURL = [NSString stringWithFormat:@"%@&t=%lds", videoURL, (long)seconds];

    UIViewController *presenter = (UIViewController *)[self activeVideoPlayerOverlay];
    YTDefaultSheetController *sheet = [%c(YTDefaultSheetController) sheetControllerWithParentResponder:presenter];

    YTActionSheetAction *copyURL = [%c(YTActionSheetAction) actionWithTitle:LOC(@"COPY_URL") iconImage:YouModYTIconImage(250, NO, nil) style:0 handler:^(__unused YTActionSheetAction *action) {
        UIPasteboard.generalPasteboard.string = videoURL;
        YouModShowShareNotification(LOC(@"URL_COPIED"), YES);
    }];

    YTActionSheetAction *copyTimestamp = [%c(YTActionSheetAction) actionWithTitle:LOC(@"COPY_URL_TIMESTAMP") iconImage:YouModYTIconImage(250, NO, nil) style:0 handler:^(__unused YTActionSheetAction *action) {
        UIPasteboard.generalPasteboard.string = timestampURL;
        YouModShowShareNotification(LOC(@"URL_TIMESTAMP_COPIED"), YES);
    }];

    [sheet addAction:copyURL];
    [sheet addAction:copyTimestamp];

    [sheet presentFromView:sourceView animated:YES completion:nil];
}
%new
- (void)YouModLoopButton {
    YTMainAppVideoPlayerOverlayViewController *playerOverlay = self.activeVideoPlayerOverlay;
    YTAutoplayAutonavController *autoplayController = [playerOverlay valueForKey:@"_autonavController"];
    BOOL isLoopEnabled = !IS_ENABLED(KeepLoopKey);
    [[NSUserDefaults standardUserDefaults] setBool:isLoopEnabled forKey:KeepLoopKey];
    [autoplayController setLoopMode:isLoopEnabled ? 2 : 0];
    YouModShowShareNotification(LOC(isLoopEnabled ? @"LOOP_ENABLED" : @"LOOP_DISABLED"), YES);
}
- (void)setPlaybackRate:(float)rate {
    didSelectRate(rate);
    %orig;
}
%end

%hook YTAutoplayAutonavController
- (id)initWithParentResponder:(id)arg {
    self = %orig;
    if (self && IS_ENABLED(KeepLoopKey)) {
        [self setLoopMode:2];
    }
    return self;
}
- (void)setLoopMode:(NSInteger)arg {
    NSInteger set = IS_ENABLED(KeepLoopKey) ? 2 : arg;
    %orig(set);
}
%end

static NSString *getCompactQualityLabel(MLFormat *format) {
    NSString *qualityLabel = [format qualityLabel];
    BOOL shouldShowFPS = [format FPS] > 30;
    if ([qualityLabel hasPrefix:@"2160p"])
        qualityLabel = [qualityLabel stringByReplacingOccurrencesOfString:@"2160p" withString:@"4K"];
    else if ([qualityLabel hasPrefix:@"1440p"])
        qualityLabel = [qualityLabel stringByReplacingOccurrencesOfString:@"1440p" withString:@"2K"];
    else if ([qualityLabel hasPrefix:@"1080p"])
        qualityLabel = [qualityLabel stringByReplacingOccurrencesOfString:@"1080p" withString:@"FHD"];
    else if ([qualityLabel hasPrefix:@"720p"])
        qualityLabel = [qualityLabel stringByReplacingOccurrencesOfString:@"720p" withString:@"HD"];
    else if (shouldShowFPS)
        qualityLabel = [qualityLabel stringByReplacingOccurrencesOfString:@"p" withString:@""];
    if ([qualityLabel hasSuffix:@" HDR"])
        qualityLabel = [qualityLabel stringByReplacingOccurrencesOfString:@" HDR" withString:@"\nHDR"];
    return qualityLabel;
}

%hook YTVideoQualitySwitchOriginalController

- (void)singleVideo:(id)singleVideo didSelectVideoFormat:(MLFormat *)format {
    currentQualityLabel = getCompactQualityLabel(format);
    [[NSNotificationCenter defaultCenter] postNotificationName:YouModUpdateNotification object:nil];
    %orig;
}

%end

%hook YTVideoQualitySwitchRedesignedController

- (void)singleVideo:(id)singleVideo didSelectVideoFormat:(MLFormat *)format {
    currentQualityLabel = getCompactQualityLabel(format);
    [[NSNotificationCenter defaultCenter] postNotificationName:YouModUpdateNotification object:nil];
    %orig;
}

%end

%ctor {
    YMOverlayButtonSpec *mute = [[YMOverlayButtonSpec alloc] init];
    mute.identifier = @"mute.video";
    mute.symbolName = IS_ENABLED(KeepMutedKey) ? @"speaker.slash" : @"speaker.wave.2";
    mute.settingsSymbolName = @"speaker.wave.2";
    mute.displayName = LOC(@"MUTE_BUTTON");
    mute.sortOrder = 300;
    mute.isVisible = ^BOOL(YTPlayerViewController *player) {
        return YMIsOverlayButtonEnabled(@"mute.video");
    };
    mute.onTap = ^(YTPlayerViewController *player, YTQTMButton *button) {
        YTSingleVideoController *sgvid = player.activeVideo;
        BOOL muteStatus = ![sgvid isMuted];
        [[NSUserDefaults standardUserDefaults] setBool:muteStatus forKey:KeepMutedKey];
        [sgvid setMuted:muteStatus];
        [button setImage:YMOverlayButtonIcon(muteStatus ? @"speaker.slash" : @"speaker.wave.2") forState:UIControlStateNormal];
    };
    YMRegisterOverlayButton(mute);
    YMOverlayButtonSpec *speed = [[YMOverlayButtonSpec alloc] init];
    speed.identifier = @"speed.video";
    speed.title = currentSpeedLabel;
    speed.settingsSymbolName = @"speedometer";
    speed.displayName = LOC(@"SPEED_BUTTON");
    speed.sortOrder = 400;
    speed.isVisible = ^BOOL(YTPlayerViewController *player) {
        return YMIsOverlayButtonEnabled(@"speed.video");
    };
    speed.onTap = ^(YTPlayerViewController *player, YTQTMButton *button) {
        YTMainAppVideoPlayerOverlayViewController *ovcon = [player activeVideoPlayerOverlay];
        YTMainAppVideoPlayerOverlayView *ovview = [ovcon videoPlayerOverlayView];
        YTMainAppControlsOverlayView *conview = [ovview controlsOverlayView];
        [ovcon didPressVarispeed:button];
        [conview updateSpeedButton:nil];
    };
    YMRegisterOverlayButton(speed);
    YMOverlayButtonSpec *quality = [[YMOverlayButtonSpec alloc] init];
    quality.identifier = @"quality.video";
    quality.title = currentQualityLabel;
    quality.settingsSymbolName = @"slider.horizontal.3";
    quality.displayName = LOC(@"QUALITY_BUTTON");
    quality.sortOrder = 500;
    quality.isVisible = ^BOOL(YTPlayerViewController *player) {
        return YMIsOverlayButtonEnabled(@"quality.video");
    };
    quality.onTap = ^(YTPlayerViewController *player, YTQTMButton *button) {
        YTMainAppVideoPlayerOverlayViewController *ovcon = [player activeVideoPlayerOverlay];
        YTMainAppVideoPlayerOverlayView *ovview = [ovcon videoPlayerOverlayView];
        YTMainAppControlsOverlayView *conview = [ovview controlsOverlayView];
        [ovcon didPressVideoQuality:button];
        [conview updateQualityButton:nil];
    };
    YMRegisterOverlayButton(quality);
    YMOverlayButtonSpec *share = [[YMOverlayButtonSpec alloc] init];
    share.identifier = @"share.video";
    share.symbolName = @"arrowshape.turn.up.right";
    share.settingsSymbolName = @"arrowshape.turn.up.right";
    share.displayName = LOC(@"SHARE_BUTTON");
    share.sortOrder = 600;
    share.isVisible = ^BOOL(YTPlayerViewController *player) {
        return YMIsOverlayButtonEnabled(@"share.video");
    };
    share.onTap = ^(YTPlayerViewController *player, YTQTMButton *button) {
        [player YouModShareButton:button];
    };
    YMRegisterOverlayButton(share);
    YMOverlayButtonSpec *loop = [[YMOverlayButtonSpec alloc] init];
    loop.identifier = @"loop.video";
    loop.symbolName = IS_ENABLED(KeepLoopKey) ? @"repeat.1" : @"repeat";
    loop.settingsSymbolName = @"repeat";
    loop.displayName = LOC(@"LOOP_BUTTON");
    loop.sortOrder = 700;
    loop.isVisible = ^BOOL(YTPlayerViewController *player) {
        return YMIsOverlayButtonEnabled(@"loop.video");
    };
    loop.onTap = ^(YTPlayerViewController *player, YTQTMButton *button) {
        [player YouModLoopButton];
        [button setImage:YMOverlayButtonIcon(IS_ENABLED(KeepLoopKey) ? @"repeat.1" : @"repeat") forState:UIControlStateNormal];
    };
    YMRegisterOverlayButton(loop);
    YMOverlayButtonSpec *caption = [[YMOverlayButtonSpec alloc] init];
    caption.identifier = @"caption.video";
    caption.symbolName = @"captions.bubble";
    caption.settingsSymbolName = @"captions.bubble";
    caption.displayName = LOC(@"CAPTION_BUTTON");
    caption.sortOrder = 800;
    caption.isVisible = ^BOOL(YTPlayerViewController *player) {
        return YMIsOverlayButtonEnabled(@"caption.video");
    };
    caption.onTap = ^(YTPlayerViewController *player, YTQTMButton *button) {
        YTMainAppVideoPlayerOverlayViewController *c = [player activeVideoPlayerOverlay];
        YTFormat3CaptionViewController *cvc = [c valueForKey:@"_captionOverlayViewController"];
        showTranscript(cvc);
    };
    YMRegisterOverlayButton(caption);
    YMOverlayButtonSpec *sleep = [[YMOverlayButtonSpec alloc] init];
    sleep.identifier = @"sleep.timer";
    sleep.symbolName = @"moon"; // drawn red via YMSleepTimerOverlayIcon while active
    sleep.settingsSymbolName = @"moon";
    sleep.displayName = LOC(@"SLEEP_TIMER");
    sleep.sortOrder = 900;
    sleep.isVisible = ^BOOL(YTPlayerViewController *player) {
        NSInteger sleepEntry = INTFORVAL(SleepTimerEntry);
        return (sleepEntry == 2 || sleepEntry == 3) && YMIsOverlayButtonEnabled(@"sleep.timer"); // overlay / both
    };
    sleep.onTap = ^(YTPlayerViewController *player, YTQTMButton *button) {
        YMSleepTimerPresentPicker(button);
        [button setImage:YMSleepTimerOverlayIcon() forState:UIControlStateNormal];
    };
    YMRegisterOverlayButton(sleep);
    %init;
}

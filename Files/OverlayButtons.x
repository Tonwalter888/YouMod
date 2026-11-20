#import "Headers.h"

static NSString *YouModUpdateSpeedLabel = @"YouModUpdateSpeedLabel";
static NSString *currentSpeedLabel = @"1x";
static float currentPlaybackRate = 1.0;

static NSString *YouModUpdateQualityLabel = @"YouModUpdateQualityLabel";
static NSString *currentQualityLabel = @"Auto";

static NSString *YouModUpdateSleepTimerButton = @"YouModUpdateSleepTimerButton";

#pragma mark - YMOverlayButtonSpec

@implementation YMOverlayButtonSpec
@end

#pragma mark - Registry

static const NSInteger YMOverlayButtonBaseTag = 9910;
static const NSInteger YMFrostedBackgroundTag = 9905; // frosted-glass pill behind the bottom-row buttons

static const CGFloat YMOverlayButtonSize = 30.0;
static const CGFloat YMOverlayButtonGap = 6.0;
static const CGFloat YMOverlayButtonTopInset = 52.0; // fallback row top when the gear can't be located
static const CGFloat YMOverlayButtonEdgePadding = 12.0; // fallback right padding when the gear isn't found
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
    else if ([identifier isEqualToString:@"speed.video"]) return IS_ENABLED(SpeedButton);
    else if ([identifier isEqualToString:@"quality.video"]) return IS_ENABLED(QualityButton);
    else if ([identifier isEqualToString:@"share.video"]) return IS_ENABLED(ShareButton);
    else if ([identifier isEqualToString:@"loop.video"]) return IS_ENABLED(LoopButton);
    else if ([identifier isEqualToString:@"caption.video"]) return IS_ENABLED(CaptionButton);
    else if ([identifier isEqualToString:@"download.video"]) return IS_ENABLED(DownloadManager) && INTFORVAL(DownloadButtonPosition) != DownloadButtonPositionUnderPlayer;
    return YES;
}

// Whether a button goes in the bottom bar (YTInlinePlayerBarContainerView) instead of the top
// overlay row. Persisted as "bottom" in the OverlayButtonOrder prefs array; defaults to NO.
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
    NSMutableSet<NSString *> *savedIds = [NSMutableSet set];

    if (savedOrder.count > 0) {
        for (NSDictionary *entry in savedOrder) {
            NSString *ident = entry[@"id"];
            if (ident) [savedIds addObject:ident];
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
            if (![savedIds containsObject:spec.identifier] && YMIsOverlayButtonEnabled(spec.identifier)) {
                [ordered addObject:spec];
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

@implementation YMOverlayHelpers

+ (NSString *)speedLabel:(float)rate {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.minimumFractionDigits = 0;
    formatter.maximumFractionDigits = 2;
    NSString *rateString = [formatter stringFromNumber:[NSNumber numberWithFloat:rate]];
    return [NSString stringWithFormat:@"%@x", rateString];
}

+ (void)didSelectRate:(float)rate {
    currentPlaybackRate = rate;
    currentSpeedLabel = [self speedLabel:rate];
    [[NSNotificationCenter defaultCenter] postNotificationName:YouModUpdateSpeedLabel object:nil];
}

// YouGetCaption (https://github.com/PoomSmart/YouGetCaption)
+ (void)showTranscript:(YTFormat3CaptionViewController *)cvc {
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
        [YouModPillView showErrorInView:parent message:LOC(@"NO_CAPTIONS") duration:4.0];
        return;
    }
    YTAlertView *alertView = [%c(YTAlertView) confirmationDialogWithAction:^{
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = transcript;
        [YouModPillView showSuccessInView:parent message:LOC(@"COPIED_TO_CLIPBOARD") duration:3.0];
    } actionTitle:LOC(@"COPY")];
    alertView.title = nil;
    alertView.subtitle = transcript;
    alertView.shouldDismissOnBackgroundTap = YES;
    [alertView show];
}

+ (YTPlayerViewController *)playerVCFromOverlay:(YTMainAppControlsOverlayView *)overlay {
    YTMainAppVideoPlayerOverlayViewController *mainOverlayController = (YTMainAppVideoPlayerOverlayViewController *)overlay.eventsDelegate;
    return (YTPlayerViewController *)mainOverlayController.parentViewController;
}

+ (void)scanForGearFrame:(UIView *)view overlay:(YTMainAppControlsOverlayView *)overlay topRegionMaxY:(CGFloat)topRegionMaxY bestFrame:(CGRect *)bestFrame {
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:%c(YTQTMButton)]) {
            CGRect f = [sub convertRect:sub.bounds toView:overlay];
            // Skip transient zero-size frames from the overlay animation.
            if (!CGRectIsEmpty(f) && CGRectGetMidY(f) <= topRegionMaxY) { // in the top button row
                // CGRectNull's midX is infinite, so the null check must come first.
                if (CGRectIsNull(*bestFrame) || CGRectGetMidX(f) > CGRectGetMidX(*bestFrame)) *bestFrame = f;
            }
        }
        [self scanForGearFrame:sub overlay:overlay topRegionMaxY:topRegionMaxY bestFrame:bestFrame];
    }
}

+ (CGRect)gearFrameInOverlay:(YTMainAppControlsOverlayView *)overlay {
    YTQTMButton *overflow = [overlay valueForKey:@"_overflowButton"];
    if (overflow.window) {
        CGRect frame = [overflow convertRect:overflow.bounds toView:overlay];
        if (!CGRectIsEmpty(frame)) return frame;
    }

    CGFloat topRegionMaxY = overlay.bounds.size.height * 0.25;
    CGRect bestFrame = CGRectNull;
    [self scanForGearFrame:overlay overlay:overlay topRegionMaxY:topRegionMaxY bestFrame:&bestFrame];
    return bestFrame;
}

+ (UIFont *)overlayTextButtonFont:(NSString *)text maxSize:(CGSize)maxSize {
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

+ (void)setOverlayButtonIcon:(YTQTMButton *)button symbolName:(NSString *)symbolName {
    UIColor *color = [UIColor whiteColor];
    if ([symbolName isEqualToString:@"moon"]) color = YMSleepTimerIsActive() ? [UIColor systemRedColor] : [UIColor whiteColor];
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
    UIImage *image = [UIImage systemImageNamed:symbolName withConfiguration:config];
    [button setImage:image forState:UIControlStateNormal];
    button.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [button setTintColor:color];
}

+ (YTQTMButton *)createOverlayButton:(UIView *)parent spec:(YMOverlayButtonSpec *)spec {
    YTQTMButton *button;
    if (spec.title.length > 0) {
        button = [%c(YTQTMButton) textButton];
        [button setTitle:spec.title forState:UIControlStateNormal];
        button.titleLabel.font = [self overlayTextButtonFont:spec.title maxSize:CGSizeMake(25, 25)];
        button.titleLabel.textAlignment = NSTextAlignmentCenter;
        button.sizeWithPaddingAndInsets = NO;
        button.titleLabel.numberOfLines = 2;
        button.titleLabel.adjustsFontSizeToFitWidth = YES;
        button.titleLabel.lineBreakMode = NSLineBreakByClipping; 
        button.titleLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
        // Intentionally the deprecated legacy insets (iOS 15): on the legacy layout
        // path they're the only way to zero the textButton factory's insets without
        // clobbering YTQTMButton's styling via UIButtonConfiguration (no-ops there).
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        button.contentEdgeInsets = UIEdgeInsetsZero;
        button.titleEdgeInsets = UIEdgeInsetsZero;
#pragma clang diagnostic pop
        button.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    } else {
        button = [%c(YTQTMButton) iconButton];
        [self setOverlayButtonIcon:button symbolName:spec.symbolName];
    }
    if ([button respondsToSelector:@selector(enableNewTouchFeedback)]) [button enableNewTouchFeedback];
    button.exclusiveTouch = YES;
    button.tag = spec.viewTag;
    button.frame = CGRectMake(0, 0, YMOverlayButtonSize, YMOverlayButtonSize);
    [button addTarget:parent action:@selector(ymOverlayButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [parent addSubview:button];
    return button;
}

+ (void)maybeApplyFrostedGlass:(YTFrostedGlassView *)frostedGlassView toView:(UIView *)view {
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

// Frosted-glass pill sized to the union of the bottom-row buttons, kept below them
// so icons draw on top; removed entirely when there is nothing to cover.
+ (void)frostedBackgroundUpdate:(YTInlinePlayerBarContainerView *)view buttons:(NSArray<UIView *> *)buttons {
    UIView *background = [view viewWithTag:YMFrostedBackgroundTag];
    if (buttons.count == 0) {
        [background removeFromSuperview];
        return;
    }

    CGRect unionFrame = CGRectNull;
    for (UIView *btn in buttons) {
        unionFrame = CGRectIsNull(unionFrame) ? btn.frame : CGRectUnion(unionFrame, btn.frame);
    }
    unionFrame = CGRectInset(unionFrame, 0, 0);

    if (!background) {
        background = [[UIView alloc] initWithFrame:unionFrame];
        background.tag = YMFrostedBackgroundTag;
        background.userInteractionEnabled = NO; // taps fall through to the player
        background.clipsToBounds = YES;
        [self maybeApplyFrostedGlass:nil toView:background];
        // The blur/overlay layers must track the pill's frame on every relayout.
        for (UIView *sub in background.subviews) {
            sub.frame = background.bounds;
            sub.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        }
        background.layer.cornerRadius = CGRectGetHeight(unionFrame) / 2.0;
        [view insertSubview:background belowSubview:buttons.firstObject];
    } else {
        background.frame = unionFrame;
        background.layer.cornerRadius = CGRectGetHeight(unionFrame) / 2.0;
    }
    background.alpha = ((UIView *)buttons.firstObject).alpha;
}

// Unhides and re-icons bottom-row buttons after YouTube hides the bar's icons.
+ (void)revealBottomOverlayButtons:(YTInlinePlayerBarContainerView *)view {
    for (YMOverlayButtonSpec *spec in YMRegisteredOverlayButtons()) {
        if (!YMIsOverlayButtonBottom(spec.identifier)) continue;
        YTQTMButton *btn = (YTQTMButton *)[view viewWithTag:spec.viewTag];
        if (![btn isKindOfClass:%c(YTQTMButton)]) continue;
        btn.hidden = NO;
        if (spec.symbolName.length > 0) [self setOverlayButtonIcon:btn symbolName:spec.symbolName];
    }
}

+ (void)setBottomOverlayButtonsAlpha:(YTInlinePlayerBarContainerView *)view alpha:(CGFloat)alpha {
    for (YMOverlayButtonSpec *spec in YMRegisteredOverlayButtons()) {
        if (!YMIsOverlayButtonBottom(spec.identifier)) continue;
        UIView *btn = [view viewWithTag:spec.viewTag];
        if ([btn isKindOfClass:%c(YTQTMButton)]) btn.alpha = alpha;
    }
    [[view viewWithTag:YMFrostedBackgroundTag] setAlpha:alpha];
}

+ (void)setBottomNotifications:(YTInlinePlayerBarContainerView *)view {
    [[NSNotificationCenter defaultCenter] addObserver:view selector:@selector(updateSpeedButton:) name:YouModUpdateSpeedLabel object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:view selector:@selector(updateQualityButton:) name:YouModUpdateQualityLabel object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:view selector:@selector(updateSleepButtonIcon:) name:YouModUpdateSleepTimerButton object:nil];
    if (IS_ENABLED(SBShowButton)) {
        [[NSNotificationCenter defaultCenter] addObserver:view selector:@selector(updateTimeLabels) name:@"YouModUpdateTimeLabel" object:nil];
    }
}

+ (void)showShareNotification:(NSString *)message success:(BOOL)success {
    UIView *parent = sbGetNotificationParent();
    if (success) [YouModPillView showSuccessInView:parent message:message duration:3.0];
    else [YouModPillView showErrorInView:parent message:message duration:4.0];
}

+ (NSString *)compactQualityLabel:(MLFormat *)format {
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

@end

#pragma mark - YTMainAppControlsOverlayView Hook

static BOOL isRelatedVideosExpanded = NO;

%hook YTMainAppControlsOverlayView
- (void)layoutSubviews {
    %orig;
    YouModApplyPrevNextReplacement(self);
    NSArray<YMOverlayButtonSpec *> *allRegistered = YMRegisteredOverlayButtons();
    NSMutableArray<YMOverlayButtonSpec *> *specs = [NSMutableArray array];
    for (YMOverlayButtonSpec *spec in YMOrderedOverlayButtons()) {
        if (!YMIsOverlayButtonBottom(spec.identifier)) [specs addObject:spec];
    }

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

    YTPlayerViewController *player = [YMOverlayHelpers playerVCFromOverlay:self];
    YTSingleVideoController *sgvid = player.activeVideo;
    YTSingleVideo *sgvid2 = sgvid.singleVideo;
    BOOL isLive = [sgvid2 isLivePlayback];
    BOOL overlayVisible = self.isOverlayVisible;
    CGRect gearFrame = [YMOverlayHelpers gearFrameInOverlay:self];
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
        if (!btn) btn = [YMOverlayHelpers createOverlayButton:self spec:spec];

        btn.alpha = overlayVisible && !isRelatedVideosExpanded;

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
        if (btn) btn.alpha = visible && !isRelatedVideosExpanded;
    }
}
%new
- (void)ymOverlayButtonTapped:(YTQTMButton *)sender {
    YMOverlayButtonSpec *matched = nil;
    for (YMOverlayButtonSpec *spec in YMRegisteredOverlayButtons()) {
        if (spec.viewTag == sender.tag) { matched = spec; break; }
    }
    if (!matched || !matched.onTap) return;

    YTPlayerViewController *player = [YMOverlayHelpers playerVCFromOverlay:self];
    matched.onTap(player, sender);
}
- (id)initWithDelegate:(id)delegate {
    self = %orig;
    [self updateSpeedButton:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSpeedButton:) name:YouModUpdateSpeedLabel object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateQualityButton:) name:YouModUpdateQualityLabel object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSleepButtonIcon:) name:YouModUpdateSleepTimerButton object:nil];
    return self;
}
- (id)initWithDelegate:(id)delegate autoplaySwitchEnabled:(BOOL)autoplaySwitchEnabled {
    self = %orig;
    [self updateSpeedButton:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSpeedButton:) name:YouModUpdateSpeedLabel object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateQualityButton:) name:YouModUpdateQualityLabel object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSleepButtonIcon:) name:YouModUpdateSleepTimerButton object:nil];
    return self;
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:YouModUpdateSpeedLabel object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:YouModUpdateQualityLabel object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:YouModUpdateSleepTimerButton object:nil];
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
                btn.titleLabel.font = [YMOverlayHelpers overlayTextButtonFont:currentSpeedLabel maxSize:CGSizeMake(25, 25)];
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
                btn.titleLabel.font = [YMOverlayHelpers overlayTextButtonFont:currentQualityLabel maxSize:CGSizeMake(25, 25)];
            }
            break;
        }
    }
}
%new
- (void)updateSleepButtonIcon:(id)arg {
    for (YMOverlayButtonSpec *spec in YMRegisteredOverlayButtons()) {
        if ([spec.identifier isEqualToString:@"sleep.timer"]) {
            YTQTMButton *btn = (YTQTMButton *)[self viewWithTag:spec.viewTag];
            if (btn) [YMOverlayHelpers setOverlayButtonIcon:btn symbolName:@"moon"];
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

%hook YTInlinePlayerBarContainerView
- (id)init {
    self = %orig;
    [YMOverlayHelpers setBottomNotifications:self];
    return self;
}
- (id)initWithParentResponder:(id)responder {
    self = %orig;
    [YMOverlayHelpers setBottomNotifications:self];
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
    if (specs.count == 0) {
        for (YMOverlayButtonSpec *spec in allRegistered) {
            UIView *btn = [self viewWithTag:spec.viewTag];
            if (btn) [btn removeFromSuperview];
        }
        [[self viewWithTag:YMFrostedBackgroundTag] removeFromSuperview];
        return;
    }
    UIView *button = [self exitFullscreenButton];
    if (button == nil) button = [[self enterExitFullscreenButton] valueForKey:@"_enterExitFullscreenButton"];
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

    YTPlayerViewController *player = (YTPlayerViewController *)(((YTMainAppVideoPlayerOverlayViewController *)self._viewControllerForAncestor).parentViewController);
    YTSingleVideoController *sgvid = player.activeVideo;
    YTSingleVideo *sgvid2 = sgvid.singleVideo;
    BOOL isLive = [sgvid2 isLivePlayback];
    BOOL peekVisible = [self isPeekableViewVisible];

    CGRect exitFrame = [button convertRect:button.bounds toView:self];
    CGFloat trailingCenterX = CGRectGetMidX(exitFrame);
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
        if (!btn) btn = [YMOverlayHelpers createOverlayButton:self spec:spec];

        btn.alpha = peekVisible && !isRelatedVideosExpanded;

        CGFloat width = (spec.title.length > 0) ? YMOverlayTextButtonWidth : YMOverlayButtonSize;
        CGFloat centerX = (prevHalfWidth == 0) ? trailingCenterX : trailingCenterX - prevHalfWidth - YMOverlayButtonGap - width / 2.0;

        btn.frame = CGRectMake(centerX - width / 2.0, rowTop, width, YMOverlayButtonSize);
        trailingCenterX = centerX;
        prevHalfWidth = width / 2.0;
        [self bringSubviewToFront:btn];
        [laidOutButtons addObject:btn];
    }

    // Wrap the whole bottom row in one frosted-glass pill.
    [YMOverlayHelpers frostedBackgroundUpdate:self buttons:laidOutButtons];
}
- (void)setPeekableViewVisible:(BOOL)visible {
    %orig;
    [YMOverlayHelpers setBottomOverlayButtonsAlpha:self alpha:visible];
}
// Reveal after YT hides the bar's icons; fade with the scrubber/peekable state.
- (void)updateIconVisibilityAndLayout {
    %orig;
    [YMOverlayHelpers revealBottomOverlayButtons:self];
}
- (void)updateIconVisibility {
    %orig;
    [YMOverlayHelpers revealBottomOverlayButtons:self];
}
- (void)updateIconsHiddenAttribute {
    %orig;
    [YMOverlayHelpers revealBottomOverlayButtons:self];
}
- (void)hideScrubber {
    %orig;
    [YMOverlayHelpers setBottomOverlayButtonsAlpha:self alpha:0];
}
- (void)setPeekableViewVisible:(BOOL)visible fullscreenButtonVisibleShouldMatchPeekableView:(BOOL)match {
    %orig;
    [YMOverlayHelpers setBottomOverlayButtonsAlpha:self alpha:visible];
}
- (void)peekWithShowScrubber:(BOOL)scrubber setControlsAbovePlayerBarVisible:(BOOL)visible {
    %orig;
    [YMOverlayHelpers setBottomOverlayButtonsAlpha:self alpha:visible];
}
%new
- (void)ymOverlayButtonTapped:(YTQTMButton *)sender {
    YMOverlayButtonSpec *matched = nil;
    for (YMOverlayButtonSpec *spec in YMRegisteredOverlayButtons()) {
        if (spec.viewTag == sender.tag) { matched = spec; break; }
    }
    if (!matched || !matched.onTap) return;

    YTMainAppVideoPlayerOverlayViewController *ovcon = (YTMainAppVideoPlayerOverlayViewController *)self._viewControllerForAncestor;
    YTPlayerViewController *player = (YTPlayerViewController *)ovcon.parentViewController;
    if (player) matched.onTap(player, sender);
}
%new
- (void)updateQualityButton:(id)arg {
    if (![self._viewControllerForAncestor isKindOfClass:%c(YTMainAppVideoPlayerOverlayViewController)]) return;
    for (YMOverlayButtonSpec *spec in YMRegisteredOverlayButtons()) {
        if ([spec.identifier isEqualToString:@"quality.video"]) {
            spec.title = currentQualityLabel;
            YTQTMButton *btn = (YTQTMButton *)[self viewWithTag:spec.viewTag];
            if (btn) {
                [btn setTitle:currentQualityLabel forState:UIControlStateNormal];
                btn.titleLabel.font = [YMOverlayHelpers overlayTextButtonFont:currentQualityLabel maxSize:CGSizeMake(25, 25)];
            }
        }
    }
}
%new
- (void)updateSpeedButton:(id)arg {
    if (![self._viewControllerForAncestor isKindOfClass:%c(YTMainAppVideoPlayerOverlayViewController)]) return;
    for (YMOverlayButtonSpec *spec in YMRegisteredOverlayButtons()) {
        if ([spec.identifier isEqualToString:@"speed.video"]) {
            spec.title = currentSpeedLabel;
            YTQTMButton *btn = (YTQTMButton *)[self viewWithTag:spec.viewTag];
            if (btn) {
                [btn setTitle:currentSpeedLabel forState:UIControlStateNormal];
                btn.titleLabel.font = [YMOverlayHelpers overlayTextButtonFont:currentSpeedLabel maxSize:CGSizeMake(25, 25)];
            }
        }
    }
}
%new
- (void)updateSleepButtonIcon:(id)arg {
    if (![self._viewControllerForAncestor isKindOfClass:%c(YTMainAppVideoPlayerOverlayViewController)]) return;
    for (YMOverlayButtonSpec *spec in YMRegisteredOverlayButtons()) {
        if ([spec.identifier isEqualToString:@"sleep.timer"]) {
            YTQTMButton *btn = (YTQTMButton *)[self viewWithTag:spec.viewTag];
            if (btn) [YMOverlayHelpers setOverlayButtonIcon:btn symbolName:@"moon"];
            break;
        }
    }
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:YouModUpdateSpeedLabel object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:YouModUpdateQualityLabel object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:YouModUpdateSleepTimerButton object:nil];
    if (IS_ENABLED(SBShowButton)) [[NSNotificationCenter defaultCenter] removeObserver:self name:@"YouModUpdateTimeLabel" object:nil];
    %orig;
}
%end

%hook YTPlayerViewController
%new
- (void)YouModShareButton:(UIView *)sourceView {
    if (!self.currentVideoID) {
        [YMOverlayHelpers showShareNotification:LOC(@"ERROR_VIDEOID") success:NO];
        return;
    } else if (self.isPlayingAd) {
        [YMOverlayHelpers showShareNotification:LOC(@"ERROR_ADS") success:NO];
        return;
    }

    NSString *videoURL = [NSString stringWithFormat:@"https://youtube.com/watch?v=%@", self.currentVideoID];
    NSInteger seconds = (NSInteger)floor(self.currentVideoMediaTime);
    NSString *timestampURL = [NSString stringWithFormat:@"%@&t=%lds", videoURL, (long)seconds];
    YTDefaultSheetController *sheet = [%c(YTDefaultSheetController) sheetControllerWithParentResponder:self];

    YTActionSheetAction *copyURL = [%c(YTActionSheetAction) actionWithTitle:LOC(@"COPY_URL") iconImage:[YMHelpers ytIconImage:250 useCustomColor:NO customColor:nil] style:0 handler:^(__unused YTActionSheetAction *action) {
        UIPasteboard.generalPasteboard.string = videoURL;
        [YMOverlayHelpers showShareNotification:LOC(@"URL_COPIED") success:YES];
    }];

    YTActionSheetAction *copyTimestamp = [%c(YTActionSheetAction) actionWithTitle:LOC(@"COPY_URL_TIMESTAMP") iconImage:[YMHelpers ytIconImage:250 useCustomColor:NO customColor:nil] style:0 handler:^(__unused YTActionSheetAction *action) {
        UIPasteboard.generalPasteboard.string = timestampURL;
        [YMOverlayHelpers showShareNotification:LOC(@"URL_TIMESTAMP_COPIED") success:YES];
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
    [YMOverlayHelpers showShareNotification:LOC(isLoopEnabled ? @"LOOP_ENABLED" : @"LOOP_DISABLED") success:YES];
}
- (void)setPlaybackRate:(float)rate {
    [YMOverlayHelpers didSelectRate:rate];
    %orig;
}
%end

%hook YTAutoplayAutonavController
- (id)initWithParentResponder:(id)arg {
    self = %orig;
    if (self && IS_ENABLED(KeepLoopKey)) [self setLoopMode:2];
    return self;
}
- (void)setLoopMode:(NSInteger)arg {
    if (IS_ENABLED(KeepLoopKey)) arg = 2;
    %orig(arg);
}
%end

%hook YTVideoQualitySwitchOriginalController
- (void)singleVideo:(id)singleVideo didSelectVideoFormat:(MLFormat *)format {
    currentQualityLabel = [YMOverlayHelpers compactQualityLabel:format];
    [[NSNotificationCenter defaultCenter] postNotificationName:YouModUpdateQualityLabel object:nil];
    %orig;
}
%end

%hook YTVideoQualitySwitchRedesignedController
- (void)singleVideo:(id)singleVideo didSelectVideoFormat:(MLFormat *)format {
    currentQualityLabel = [YMOverlayHelpers compactQualityLabel:format];
    [[NSNotificationCenter defaultCenter] postNotificationName:YouModUpdateQualityLabel object:nil];
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
        [YMOverlayHelpers setOverlayButtonIcon:button symbolName:(muteStatus ? @"speaker.slash" : @"speaker.wave.2")];
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
        [YMOverlayHelpers setOverlayButtonIcon:button symbolName:(IS_ENABLED(KeepLoopKey) ? @"repeat.1" : @"repeat")];
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
        [YMOverlayHelpers showTranscript:cvc];
    };
    YMRegisterOverlayButton(caption);
    YMOverlayButtonSpec *sleep = [[YMOverlayButtonSpec alloc] init];
    sleep.identifier = @"sleep.timer";
    sleep.symbolName = @"moon";
    sleep.settingsSymbolName = @"moon";
    sleep.displayName = LOC(@"SLEEP_TIMER");
    sleep.sortOrder = 900;
    sleep.isVisible = ^BOOL(YTPlayerViewController *player) {
        NSInteger sleepEntry = INTFORVAL(SleepTimerEntry);
        return (sleepEntry == 2 || sleepEntry == 3) && YMIsOverlayButtonEnabled(@"sleep.timer"); // overlay / both
    };
    sleep.onTap = ^(YTPlayerViewController *player, YTQTMButton *button) {
        YMSleepTimerPresentPicker(button);
    };
    YMRegisterOverlayButton(sleep);
    %init;
}
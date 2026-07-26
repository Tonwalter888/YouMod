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

#define LOC(x) [YouModBundle() localizedStringForKey:x value:nil table:nil]

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
static const CGFloat YMOverlayButtonGap = 18.25;
static const CGFloat YMOverlayButtonTopInset = 52.0; // fallback row top when the gear can't be located
static const CGFloat YMOverlayButtonEdgePadding = 12.0; // fallback right padding when the gear isn't found

// Point size of a text button's label. Tweak this to change how large the text renders.
static const CGFloat YMOverlayTextButtonFontSize = 13.0;
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
            if (CGRectGetMidY(f) <= topRegionMaxY) { // in the top button row
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
        return [overflow convertRect:overflow.bounds toView:overlay];
    }

    CGFloat topRegionMaxY = overlay.bounds.size.height * 0.25;
    CGRect bestFrame = CGRectNull;
    YMScanForGearFrame(overlay, overlay, topRegionMaxY, &bestFrame);
    return bestFrame;
}

// The font for a text button's label, in YouTube Sans to match native controls,
// with a plain system-font fallback on versions lacking the YouTube Sans style API.
static UIFont *YMOverlayTextButtonFont(void) {
    YTDefaultTypeStyle *typeStyle = [%c(YTTypeStyle) defaultTypeStyle];
    if ([typeStyle respondsToSelector:@selector(ytSansFontOfSize:weight:)]) {
        return [typeStyle ytSansFontOfSize:YMOverlayTextButtonFontSize weight:UIFontWeightSemibold];
    }
    return [UIFont systemFontOfSize:YMOverlayTextButtonFontSize weight:UIFontWeightSemibold];
}

static YTQTMButton *YMCreateOverlayButton(YTMainAppControlsOverlayView *overlay, YMOverlayButtonSpec *spec) {
    YTQTMButton *button;
    UIColor *tint = spec.tintColor ?: [UIColor whiteColor];

    if (spec.title.length > 0) {
        // Text button: a label instead of an icon. customTitleColor is YTQTMButton's
        // own text-colour channel; sizeWithPaddingAndInsets is disabled so the width
        // stays fixed rather than expanding to fit the text.
        button = [%c(YTQTMButton) textButton];
        [button setTitle:spec.title forState:UIControlStateNormal];
        button.customTitleColor = tint;
        button.titleLabel.font = YMOverlayTextButtonFont();
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
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
        // Template rendering so YTQTMButton's tint colours the glyph reliably.
        UIImage *icon = [[UIImage systemImageNamed:spec.symbolName withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        button = [%c(YTQTMButton) iconButton];
        [button setImage:icon forState:UIControlStateNormal];
        button.tintColor = tint;
        button.imageView.contentMode = UIViewContentModeScaleAspectFit;
    }

    button.exclusiveTouch = YES;
    button.tag = spec.viewTag;
    // The row's frame is assigned authoritatively in layoutSubviews.
    button.frame = CGRectMake(0, 0, YMOverlayButtonSize, YMOverlayButtonSize);
    [button addTarget:overlay action:@selector(ymOverlayButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [overlay addSubview:button];
    return button;
}

#pragma mark - YTMainAppControlsOverlayView Hook

%hook YTMainAppControlsOverlayView

- (void)layoutSubviews {
    %orig;
    NSArray<YMOverlayButtonSpec *> *specs = YMRegisteredOverlayButtons();
    if (specs.count == 0) return;

    YTPlayerViewController *player = YMPlayerVCFromOverlay(self);

    // layoutSubviews is the high-frequency path and may (re)create buttons, so it
    // owns the hidden state — otherwise a freshly created button shows on top of a
    // faded-out overlay until the next setOverlayVisible: call.
    BOOL overlayVisible = self.isOverlayVisible;

    // Anchor the row to the gear: right-most button under the gear's centre-x, row top
    // just below the gear's bottom edge; grow leftward. Deriving Y from the gear (rather
    // than a fixed inset) keeps the row the same distance below the gear on every device —
    // YouTube's gear sits at a different Y on iPhone vs iPad. Fall back to the screen edge
    // and the fixed top inset when the gear can't be located, so buttons never collapse to
    // x=0 or y=0. trailingCenterX is the center of the button placed in the previous
    // iteration; each button steps left by half of both widths plus the gap, so text
    // buttons (which may be wider than icon buttons) still pack without overlap.
    CGRect gearFrame = YMGearFrameInOverlay(self);
    BOOL hasGear = !CGRectIsNull(gearFrame);
    CGFloat trailingCenterX = hasGear ? CGRectGetMidX(gearFrame) : self.bounds.size.width - YMOverlayButtonEdgePadding - YMOverlayButtonSize / 2.0;
    CGFloat rowTop = hasGear ? CGRectGetMaxY(gearFrame) : YMOverlayButtonTopInset;
    CGFloat prevHalfWidth = 0;

    for (YMOverlayButtonSpec *spec in specs) {
        BOOL visible = (spec.isVisible == nil) || spec.isVisible(player);
        YTQTMButton *btn = (YTQTMButton *)[self viewWithTag:spec.viewTag];

        if (!visible) {
            if (btn) [btn removeFromSuperview];
            continue;
        }
        if (!btn) btn = YMCreateOverlayButton(self, spec);

        btn.hidden = !overlayVisible;
        if (spec.tintProvider) {
            // Text buttons colour their label through customTitleColor; icon buttons
            // through tintColor. Route the dynamic colour to the right channel.
            UIColor *dynamic = spec.tintProvider(player);
            if (spec.title.length > 0) btn.customTitleColor = dynamic;
            else btn.tintColor = dynamic;
        }

        CGFloat width = (spec.title.length > 0) ? YMOverlayTextButtonWidth : YMOverlayButtonSize;
        CGFloat centerX = (prevHalfWidth == 0)
            ? trailingCenterX
            : trailingCenterX - prevHalfWidth - YMOverlayButtonGap - width / 2.0;

        btn.frame = CGRectMake(centerX - width / 2.0,
                                rowTop,
                                width,
                                YMOverlayButtonSize);
        trailingCenterX = centerX;
        prevHalfWidth = width / 2.0;
    }
}

- (void)setOverlayVisible:(BOOL)visible {
    %orig;
    for (YMOverlayButtonSpec *spec in YMRegisteredOverlayButtons()) {
        YTQTMButton *btn = (YTQTMButton *)[self viewWithTag:spec.viewTag];
        if (btn) btn.hidden = !visible;
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
    return self;
}

- (id)initWithDelegate:(id)delegate autoplaySwitchEnabled:(BOOL)autoplaySwitchEnabled {
    self = %orig;
    [self updateSpeedButton:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateSpeedButton:) name:YouModUpdateSpeedLabel object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateQualityButton:) name:YouModUpdateNotification object:nil];
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
            }
            break;
        }
    }
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

static UIImage *YouModIconImage(NSInteger iconType) {
    YTIIcon *icon = [%c(YTIIcon) new];
    icon.iconType = iconType;
    UIImage *image = [icon iconImageWithColor:[UIColor labelColor]];
    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
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

    YTActionSheetAction *copyURL = [%c(YTActionSheetAction) actionWithTitle:LOC(@"COPY_URL") iconImage:YouModIconImage(250) style:0 handler:^(__unused YTActionSheetAction *action) {
        UIPasteboard.generalPasteboard.string = videoURL;
        YouModShowShareNotification(LOC(@"URL_COPIED"), YES);
    }];

    YTActionSheetAction *copyTimestamp = [%c(YTActionSheetAction) actionWithTitle:LOC(@"COPY_URL_TIMESTAMP") iconImage:YouModIconImage(250) style:0 handler:^(__unused YTActionSheetAction *action) {
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
    mute.tintColor = [UIColor whiteColor];
    mute.sortOrder = 300;
    mute.isVisible = ^BOOL(YTPlayerViewController *player) {
        return IS_ENABLED(MuteButton);
    };
    mute.onTap = ^(YTPlayerViewController *player, YTQTMButton *button) {
        YTSingleVideoController *sgvid = player.activeVideo;
        BOOL muteStatus = ![sgvid isMuted];
        [[NSUserDefaults standardUserDefaults] setBool:muteStatus forKey:KeepMutedKey];
        [sgvid setMuted:muteStatus];
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
        UIImage *newIcon = [UIImage systemImageNamed:muteStatus ? @"speaker.slash" : @"speaker.wave.2" withConfiguration:config];
        [button setImage:newIcon forState:UIControlStateNormal];
    };
    YMRegisterOverlayButton(mute);
    YMOverlayButtonSpec *speed = [[YMOverlayButtonSpec alloc] init];
    speed.identifier = @"speed.video";
    speed.title = currentSpeedLabel;
    speed.sortOrder = 400;
    speed.isVisible = ^BOOL(YTPlayerViewController *player) {
        return IS_ENABLED(SpeedButton);
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
    quality.sortOrder = 500;
    quality.isVisible = ^BOOL(YTPlayerViewController *player) {
        return IS_ENABLED(QualityButton);
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
    share.tintColor = [UIColor whiteColor];
    share.sortOrder = 600;
    share.isVisible = ^BOOL(YTPlayerViewController *player) {
        return IS_ENABLED(ShareButton);
    };
    share.onTap = ^(YTPlayerViewController *player, YTQTMButton *button) {
        [player YouModShareButton:button];
    };
    YMRegisterOverlayButton(share);
    YMOverlayButtonSpec *loop = [[YMOverlayButtonSpec alloc] init];
    loop.identifier = @"loop.video";
    loop.symbolName = IS_ENABLED(KeepLoopKey) ? @"repeat.1" : @"repeat";
    loop.tintColor = [UIColor whiteColor];
    loop.sortOrder = 700;
    loop.isVisible = ^BOOL(YTPlayerViewController *player) {
        return IS_ENABLED(LoopButton);
    };
    loop.onTap = ^(YTPlayerViewController *player, YTQTMButton *button) {
        [player YouModLoopButton];
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
        UIImage *newIcon = [UIImage systemImageNamed:IS_ENABLED(KeepLoopKey) ? @"repeat.1" : @"repeat" withConfiguration:config];
        [button setImage:newIcon forState:UIControlStateNormal];
    };
    YMRegisterOverlayButton(loop);
    YMOverlayButtonSpec *caption = [[YMOverlayButtonSpec alloc] init];
    caption.identifier = @"caption.video";
    caption.symbolName = @"captions.bubble";
    caption.tintColor = [UIColor whiteColor];
    caption.sortOrder = 800;
    caption.isVisible = ^BOOL(YTPlayerViewController *player) {
        return IS_ENABLED(CaptionButton);
    };
    caption.onTap = ^(YTPlayerViewController *player, YTQTMButton *button) {
        YTMainAppVideoPlayerOverlayViewController *c = [player activeVideoPlayerOverlay];
        YTFormat3CaptionViewController *cvc = [c valueForKey:@"_captionOverlayViewController"];
        showTranscript(cvc);
    };
    YMRegisterOverlayButton(caption);
    %init;
}

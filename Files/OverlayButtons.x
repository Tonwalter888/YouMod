#import "Headers.h"

#pragma mark - YMOverlayButtonSpec

@implementation YMOverlayButtonSpec
@end

#pragma mark - Registry

// Reserved view-tag range for registered overlay buttons. Kept distinct from the
// seek-bar marker tag (9900) and the legacy SB button tag (9901).
static const NSInteger YMOverlayButtonBaseTag = 9910;

// Button geometry. Y matches the SponsorBlock button's historical top inset so the
// row sits just below YouTube's CC/gear row, exactly as before.
static const CGFloat YMOverlayButtonSize = 40.0;
static const CGFloat YMOverlayButtonGap = 8.0;
static const CGFloat YMOverlayButtonTopInset = 52.0;
static const CGFloat YMOverlayButtonEdgePadding = 12.0; // fallback right padding when the gear isn't found

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

// Resolve the player VC that owns this overlay. Prefer the exposed property, fall
// back to walking the responder chain (older layouts), mirroring the old SB code.
static YTPlayerViewController *YMPlayerVCFromOverlay(YTMainAppControlsOverlayView *overlay) {
    YTMainAppVideoPlayerOverlayViewController *mainOverlayController = (YTMainAppVideoPlayerOverlayViewController *)overlay.eventsDelegate;
    return mainOverlayController.parentViewController;
}

// Recursively find the right-most YTQTMButton in the overlay's top region. YouTube
// sometimes nests the gear/CC/cast buttons inside a container, so a one-level scan
// would miss them and silently fall back to the screen edge.
static void YMScanForGearMidX(UIView *view, YTMainAppControlsOverlayView *overlay, CGFloat topRegionMaxY, CGFloat *bestMidX) {
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:%c(YTQTMButton)]) {
            CGRect f = [sub convertRect:sub.bounds toView:overlay];
            if (CGRectGetMidY(f) <= topRegionMaxY) { // in the top button row
                CGFloat midX = CGRectGetMidX(f);
                if (midX > *bestMidX) *bestMidX = midX;
            }
        }
        YMScanForGearMidX(sub, overlay, topRegionMaxY, bestMidX);
    }
}

// Find YouTube's settings/gear button so we can anchor our row directly beneath it.
// The gear is the right-most YTQTMButton sitting in the overlay's top region. Returns
// its center-x in the overlay's coordinate space, or a negative value if not found.
static CGFloat YMGearCenterXInOverlay(YTMainAppControlsOverlayView *overlay) {
    CGFloat topRegionMaxY = overlay.bounds.size.height * 0.25;
    CGFloat bestMidX = -1.0;
    YMScanForGearMidX(overlay, overlay, topRegionMaxY, &bestMidX);
    return bestMidX;
}

// Might use YTQTMButton
static UIButton *YMCreateOverlayButton(YTMainAppControlsOverlayView *overlay, YMOverlayButtonSpec *spec) {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.tag = spec.viewTag;
    btn.frame = CGRectMake(0, 0, YMOverlayButtonSize, YMOverlayButtonSize);

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
    UIImage *icon = [UIImage systemImageNamed:spec.symbolName withConfiguration:config];
    [btn setImage:icon forState:UIControlStateNormal];
    btn.tintColor = spec.tintColor ?: [UIColor whiteColor];

    [btn addTarget:overlay action:@selector(ymOverlayButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [overlay addSubview:btn];
    return btn;
}

#pragma mark - YTMainAppControlsOverlayView Hook

// static BOOL isSetSleepTimerButton = NO;
// static BOOL isSetSpeedButton = NO;
// static BOOL isSetMuteButton = NO;

%hook YTMainAppControlsOverlayView

- (void)layoutSubviews {
    %orig;
    /*
    if (IS_ENABLED(MuteButton) && !isSetMuteButton) {
        YMOverlayButtonSpec *mute = [[YMOverlayButtonSpec alloc] init];
        mute.identifier = @"mute.video";
        mute.symbolName = @"speaker.wave.2";
        mute.tintColor = [UIColor whiteColor];
        mute.sortOrder = 300;
        mute.isVisible = nil; // always visible when the overlay is up
        mute.onTap = ^(YTPlayerViewController *player, UIButton *button) {
            UIViewController *presenter = YouModPresenterForSender(button, player ?: YouModCurrentPlayerViewController);
            YTPlayerViewController *resolved = YouModPlayerFromViewController(presenter) ?: player ?: YouModCurrentPlayerViewController;
            YouModShowDownloadManager(resolved, presenter, button);
        };
        YMRegisterOverlayButton(mute);
        isSetMuteButton = YES;
    }
    */
    NSArray<YMOverlayButtonSpec *> *specs = YMRegisteredOverlayButtons();
    if (specs.count == 0) return;

    YTPlayerViewController *player = YMPlayerVCFromOverlay(self);

    // layoutSubviews is the high-frequency path and may (re)create buttons, so it
    // owns the hidden state — otherwise a freshly created button shows on top of a
    // faded-out overlay until the next setOverlayVisible: call.
    BOOL overlayVisible = self.isOverlayVisible;

    // Anchor the row's right-most button under the gear; grow leftward.
    CGFloat gearMidX = YMGearCenterXInOverlay(self);
    CGFloat anchorCenterX = (gearMidX > 0) ? gearMidX : self.bounds.size.width - YMOverlayButtonEdgePadding - YMOverlayButtonSize / 2.0;

    NSInteger row = 0;
    for (YMOverlayButtonSpec *spec in specs) {
        BOOL visible = (spec.isVisible == nil) || spec.isVisible(player);
        UIButton *btn = (UIButton *)[self viewWithTag:spec.viewTag];

        if (!visible) {
            if (btn) [btn removeFromSuperview];
            continue;
        }
        if (!btn) btn = YMCreateOverlayButton(self, spec);

        btn.hidden = !overlayVisible;
        if (spec.tintProvider) btn.tintColor = spec.tintProvider(player);

        CGFloat centerX = anchorCenterX - row * (YMOverlayButtonSize + YMOverlayButtonGap);
        btn.frame = CGRectMake(centerX - YMOverlayButtonSize / 2.0,
                                YMOverlayButtonTopInset,
                                YMOverlayButtonSize,
                                YMOverlayButtonSize);
        row++;
    }
}

- (void)setOverlayVisible:(BOOL)visible {
    %orig;
    for (YMOverlayButtonSpec *spec in YMRegisteredOverlayButtons()) {
        UIButton *btn = (UIButton *)[self viewWithTag:spec.viewTag];
        if (btn) btn.hidden = !visible;
    }
}

%new
- (void)ymOverlayButtonTapped:(UIButton *)sender {
    YMOverlayButtonSpec *matched = nil;
    for (YMOverlayButtonSpec *spec in YMRegisteredOverlayButtons()) {
        if (spec.viewTag == sender.tag) { matched = spec; break; }
    }
    if (!matched || !matched.onTap) return;

    YTPlayerViewController *player = YMPlayerVCFromOverlay(self);
    matched.onTap(player, sender);
}

/* Mute logic from YouMute
%new
- (void)YouModDidPressMute:(BOOL)mute {
    YTMainAppVideoPlayerOverlayViewController *c = [self valueForKey:@"_eventsDelegate"];
    YTSingleVideoController *video = [c valueForKey:@"_currentSingleVideoObservable"];
    BOOL muteStatus = ![video isMuted];
    [[NSUserDefaults standardUserDefaults] setBool:muteStatus forKey:Muted];
    [video setMuted:muteStatus];
    // Change this to our button logic
    [self.overlayButtons[TweakKey] setImage:muteImage([video isMuted]) forState:UIControlStateNormal];
}
*/

%end

%ctor {
    YMOverlayButtonSpec *mute = [[YMOverlayButtonSpec alloc] init];
    mute.identifier = @"mute.video";
    mute.symbolName = IS_ENABLED(KeepMutedKey) ? @"speaker.slash" : @"speaker.wave.2";
    mute.tintColor = [UIColor whiteColor];
    mute.sortOrder = 300;
    mute.isVisible = nil; // always visible when the overlay is up
    mute.onTap = ^(YTPlayerViewController *player, UIButton *button) {
        YTSingleVideoController *sgvid = self.activeVideo;
        BOOL muteStatus = ![self isMuted];
        [[NSUserDefaults standardUserDefaults] setBool:muteStatus forKey:KeepMutedKey];
        [player setMuted:muteStatus];
        mute.symbolName = muteStatus ? @"speaker.slash" : @"speaker.wave.2"
    };
    YMRegisterOverlayButton(mute);
    %init;
}
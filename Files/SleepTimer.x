#import "Headers.h"

// Sleep timer: counts down on wall-clock time (persisted, survives suspend /
// relaunch), shows the countdown on YouTube's slim status bar, and pauses the
// main player when it fires. Started from the overlay moon button or the tab
// long-press menu.

#pragma mark - Slim status bar classes (only exist on newer YouTube versions)

@class YTSlimStatusBarControllerImpl;

@interface YTSlimStatusBarView : UIView
- (void)updateAppearanceToSleepTimerActiveWithText:(NSString *)text;
@end

@interface YTSlimStatusBarControllerImpl : NSObject
- (void)updateWithSleepTimerActiveStatus:(BOOL)arg;
@end

#pragma mark - State

typedef NS_ENUM(NSInteger, YMSleepTimerMode) {
    YMSleepTimerModeCountdown = 0,
    YMSleepTimerModeEndOfVideo = 1,
};

// Weak set: YouTube can create/destroy slim bar views at any time, we must not
// keep deallocated ones alive.
static NSHashTable<YTSlimStatusBarView *> *slimBarSet = nil;
static YTSlimStatusBarControllerImpl *slimBarController = nil;
static BOOL slimBarThemed = NO;
static NSUInteger slimBarReconnectSequence = 0;

// While a playable game is up or the player is fullscreen, the bar is hidden
// and text updates stop until the layout comes back.
static BOOL layoutHidesBar = NO;

static NSString *YMSleepTimerFormatClock(NSTimeInterval interval) {
    NSInteger secs = (NSInteger)ceil(interval);
    if (secs < 0) secs = 0;
    NSInteger hours = secs / 3600;
    NSInteger mins = (secs % 3600) / 60;
    NSInteger seconds = secs % 60;
    if (hours > 0) return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)hours, (long)mins, (long)seconds];
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)mins, (long)seconds];
}

#pragma mark - YMSleepTimer

@interface YMSleepTimer : NSObject
@property (nonatomic, assign) YMSleepTimerMode mode;
@property (nonatomic, strong) NSDate *endDate;
@property (nonatomic, strong) NSTimer *tickTimer;
@property (nonatomic, assign) float originalVolume;
@property (nonatomic, assign) BOOL volumeCaptured;
@property (nonatomic, assign) BOOL connectionLost;
+ (instancetype)shared;
- (void)startWithMinutes:(NSInteger)minutes;
- (void)startAtDate:(NSDate *)date;
- (void)startEndOfVideo;
- (void)cancel;
- (void)fire;
- (void)tick;
- (void)playbackTick;
- (void)scheduleTimer;
- (BOOL)isActive;
- (NSString *)remainingText;
- (void)updateSlimBars;
@end

@implementation YMSleepTimer

+ (instancetype)shared {
    static YMSleepTimer *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[YMSleepTimer alloc] init];
    });
    return shared;
}

#pragma mark State helpers

- (BOOL)isActive {
    return self.endDate != nil || self.mode == YMSleepTimerModeEndOfVideo;
}

- (NSTimeInterval)remainingSeconds {
    if (self.mode == YMSleepTimerModeEndOfVideo) return 0;
    NSTimeInterval remaining = [self.endDate timeIntervalSinceNow];
    return remaining > 0 ? remaining : 0;
}

- (NSString *)remainingText {
    if (self.mode == YMSleepTimerModeEndOfVideo) {
        // Count down the remaining playback time of the current video.
        YTPlayerViewController *player = YouModCurrentPlayerViewController;
        if (!player) return @"0:00";
        return YMSleepTimerFormatClock([player currentVideoTotalMediaTime] - [player currentVideoMediaTime]);
    }
    return YMSleepTimerFormatClock([self remainingSeconds]);
}

- (void)persist {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setDouble:self.endDate ? [self.endDate timeIntervalSince1970] : 0.0 forKey:SleepTimerEndDate];
    [defaults setInteger:self.mode forKey:SleepTimerMode];
}

#pragma mark Start / cancel

- (void)startAtDate:(NSDate *)date {
    [self restoreVolume];
    self.mode = YMSleepTimerModeCountdown;
    self.endDate = date;
    self.connectionLost = NO;
    [self persist];
    [self scheduleTimer];
    [self updateSlimBars];
    [self notifyButtons];
}

- (void)startWithMinutes:(NSInteger)minutes {
    [self startAtDate:[NSDate dateWithTimeIntervalSinceNow:(NSTimeInterval)minutes * 60.0]];
}

- (void)startEndOfVideo {
    [self restoreVolume];
    self.mode = YMSleepTimerModeEndOfVideo;
    self.endDate = nil;
    self.connectionLost = NO;
    [self persist];
    [self scheduleTimer];
    [self updateSlimBars];
    [self notifyButtons];
}

- (void)cancel {
    [self restoreVolume];
    [self stopTimer];
    self.endDate = nil;
    self.mode = YMSleepTimerModeCountdown;
    [self persist];
    [self deactivateSlimBars];
    [self notifyButtons];
}

- (void)fire {
    [self stopTimer];
    [self restoreVolumeAfterPause];
    self.endDate = nil;
    self.mode = YMSleepTimerModeCountdown;
    [self persist];
    [self deactivateSlimBars];
    [self notifyButtons];
    [self pausePlayer];
    void (^alert)(void) = ^{
        YTAlertView *alertView = [%c(YTAlertView) infoDialog];
        alertView.title = LOC(@"SLEEP_TIMER");
        alertView.subtitle = LOC(@"SLEEP_TIMER_TIME_UP");
        alertView.shouldDismissOnBackgroundTap = YES;
        [alertView show];
    };
    if ([NSThread isMainThread]) alert();
    else dispatch_async(dispatch_get_main_queue(), alert);
}

#pragma mark Timer

- (void)scheduleTimer {
    [self stopTimer];
    void (^schedule)(void) = ^{
        self.tickTimer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(tick) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.tickTimer forMode:NSRunLoopCommonModes];
    };
    if ([NSThread isMainThread]) schedule();
    else dispatch_async(dispatch_get_main_queue(), schedule);
}

- (void)stopTimer {
    [self.tickTimer invalidate];
    self.tickTimer = nil;
}

- (void)tick {
    if (![self isActive]) return;

    if (self.mode == YMSleepTimerModeCountdown) {
        NSTimeInterval remaining = [self.endDate timeIntervalSinceNow];
        if (remaining <= 0) {
            [self fire];
            return;
        }
        if (remaining <= 7.0) [self applyFadeFraction:(remaining / 7.0)];
    } else {
        YTPlayerViewController *player = YouModCurrentPlayerViewController;
        if (player && [player isPlaybackFinished]) {
            [self fire];
            return;
        }
    }
    [self updateSlimBars];
}

// Called from the playback time-change hooks as well, so expiry and fade stay
// accurate even when the NSTimer is suspended (locked screen with audio on).
- (void)playbackTick {
    if (![self isActive]) return;
    NSDate *now = [NSDate date];
    static NSDate *lastTick = nil;
    if (lastTick && [now timeIntervalSinceDate:lastTick] < 0.5) return;
    lastTick = now;
    [self tick];
}

#pragma mark Volume fade

- (void)applyFadeFraction:(float)fraction {
    YTPlayerViewController *player = YouModCurrentPlayerViewController;
    YTSingleVideoController *sgvid = player.activeVideo;
    if (!sgvid) return;
    if (!self.volumeCaptured) {
        self.originalVolume = [sgvid volume];
        self.volumeCaptured = YES;
    }
    [sgvid setVolume:(self.originalVolume * fraction)];
}

- (void)restoreVolume {
    if (!self.volumeCaptured) return;
    YTPlayerViewController *player = YouModCurrentPlayerViewController;
    YTSingleVideoController *sgvid = player.activeVideo;
    if (sgvid) [sgvid setVolume:self.originalVolume];
    self.volumeCaptured = NO;
}

// After firing, the player may already be tearing down; restoring the volume
// on the active video keeps the *next* playback from starting muted-silent.
- (void)restoreVolumeAfterPause {
    [self restoreVolume];
}

- (void)pausePlayer {
    YTPlayerViewController *player = YouModCurrentPlayerViewController;
    if (!player) return;
    void (^pause)(void) = ^{
        [player pause];
    };
    if ([NSThread isMainThread]) pause();
    else dispatch_async(dispatch_get_main_queue(), pause);
}

#pragma mark Slim status bar

- (void)notifyButtons {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"YouModUpdateNotification" object:nil];
}

- (void)updateSlimBars {
    if (![self isActive] || self.connectionLost || layoutHidesBar) return;

    NSString *text = [self remainingText];
    void (^update)(void) = ^{
        if (!slimBarController) return;
        if (!slimBarThemed) {
            [slimBarController updateWithSleepTimerActiveStatus:YES];
            for (YTSlimStatusBarView *barView in slimBarSet) {
                [barView updateAppearanceToSleepTimerActiveWithText:text];
            }
            slimBarThemed = YES;
        } else {
            for (YTSlimStatusBarView *barView in slimBarSet) {
                [barView updateAppearanceToSleepTimerActiveWithText:text];
            }
        }
    };
    if ([NSThread isMainThread]) update();
    else dispatch_async(dispatch_get_main_queue(), update);
}

- (void)deactivateSlimBars {
    slimBarThemed = NO;
    void (^deactivate)(void) = ^{
        [slimBarController updateWithSleepTimerActiveStatus:NO];
    };
    if ([NSThread isMainThread]) deactivate();
    else dispatch_async(dispatch_get_main_queue(), deactivate);
}

@end

#pragma mark - Public C API

// Hide/restore the bar from layout changes (fullscreen, playable games).
static void YMSleepTimerSetBarHiddenByLayout(BOOL hidden) {
    layoutHidesBar = hidden;
    void (^apply)(void) = ^{
        if (hidden) {
            [slimBarController updateWithSleepTimerActiveStatus:NO];
            slimBarThemed = NO;
        } else if ([[YMSleepTimer shared] isActive]) {
            slimBarThemed = NO;
            [[YMSleepTimer shared] updateSlimBars];
        }
    };
    if ([NSThread isMainThread]) apply();
    else dispatch_async(dispatch_get_main_queue(), apply);
}

void YMSleepTimerStartWithMinutes(NSInteger minutes) {
    [[YMSleepTimer shared] startWithMinutes:minutes];
}

void YMSleepTimerStartEndOfVideo(void) {
    [[YMSleepTimer shared] startEndOfVideo];
}

void YMSleepTimerCancel(void) {
    [[YMSleepTimer shared] cancel];
}

BOOL YMSleepTimerIsActive(void) {
    return [[YMSleepTimer shared] isActive];
}

NSString *YMSleepTimerRemainingText(void) {
    return [[YMSleepTimer shared] remainingText];
}

void YMSleepTimerUpdateSlimBars(void) {
    [[YMSleepTimer shared] updateSlimBars];
}

#pragma mark - Picker UI

static NSString *YMSleepTimerVideoTimeLeftText(void) {
    YTPlayerViewController *player = YouModCurrentPlayerViewController;
    if (!player) return nil;
    CGFloat timeLeft = [player currentVideoTotalMediaTime] - [player currentVideoMediaTime];
    if (timeLeft <= 0) return nil;

    // System-localized units ("1 hr 20 min" / "45 minutes" / "30 seconds").
    NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
    formatter.allowedUnits = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleFull;
    formatter.maximumUnitCount = 2;
    formatter.zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorDropAll;
    NSString *text = [formatter stringFromTimeInterval:timeLeft];
    return text;
}

// Container that keeps the picker centered inside whatever space the dialog
// actually gives it — the dialog's content width varies by device/locale, so a
// fixed frame set up front drifts off-center.
@interface YMSleepTimerPickerContainer : UIView
@property (nonatomic, strong) UIDatePicker *datePicker;
@end

@implementation YMSleepTimerPickerContainer
- (void)layoutSubviews {
    [super layoutSubviews];
    CGSize natural = self.datePicker.intrinsicContentSize;
    CGFloat width = (natural.width > 0 && natural.width < self.bounds.size.width) ? natural.width : self.bounds.size.width;
    CGFloat height = (natural.height > 0 && natural.height < self.bounds.size.height) ? natural.height : self.bounds.size.height;
    self.datePicker.frame = CGRectMake(floorf((self.bounds.size.width - width) / 2.0),
                                       floorf((self.bounds.size.height - height) / 2.0),
                                       width, height);
}
@end

// Custom time picker inside a YT-native alert (not a system dialog).
static void YMSleepTimerShowCustomTimeAlert(void) {
    YTAlertView *alertView = [%c(YTAlertView) dialog];
    alertView.title = LOC(@"SLEEP_TIMER_CUSTOM_TIME");
    alertView.shouldDismissOnBackgroundTap = YES;

    YMSleepTimerPickerContainer *container = [[YMSleepTimerPickerContainer alloc] initWithFrame:CGRectMake(0, 0, 238, 150)];
    container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    UIDatePicker *datePicker = [[UIDatePicker alloc] init];
    datePicker.datePickerMode = UIDatePickerModeTime;
    // Force the scrolling-wheel style: on iOS 14+ the default is compact, which
    // collapses to a button that opens a separate popover instead of sitting
    // inside this dialog.
    datePicker.preferredDatePickerStyle = UIDatePickerStyleWheels;
    datePicker.locale = [NSLocale currentLocale]; // renders 12/24h per system setting
    container.datePicker = datePicker;
    [container addSubview:datePicker];

    alertView.customContentView = container;
    alertView.customContentViewInsets = UIEdgeInsetsMake(0, 8, 4, 8);

    [alertView addCancelButtonWithAction:nil];
    [alertView addTitle:LOC(@"OK") withAction:^{
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDateComponents *picked = [calendar componentsInTimeZone:calendar.timeZone fromDate:datePicker.date];
        NSDateComponents *target = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay |
                                                         NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond)
                                               fromDate:[NSDate date]];
        target.hour = picked.hour;
        target.minute = picked.minute;
        target.second = 0;
        NSDate *endDate = [calendar dateFromComponents:target];
        // A time already past today schedules for tomorrow.
        if ([endDate timeIntervalSinceNow] <= 0) {
            endDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:endDate options:0];
        }
        [[YMSleepTimer shared] startAtDate:endDate];
    }];
    [alertView show];
}

void YMSleepTimerPresentPicker(UIView *sourceView) {
    void (^present)(void) = ^{
        id parentResponder = [sourceView._viewControllerForAncestor valueForKey:@"_parentResponder"];

        YMSleepTimer *timer = [YMSleepTimer shared];
        NSString *timeLeftText = YMSleepTimerVideoTimeLeftText();

        YTDefaultSheetController *sheet = [%c(YTDefaultSheetController) sheetControllerWithParentResponder:parentResponder];

        // Header subtitle: timer remaining + how long until the video ends.
        NSMutableArray<NSString *> *subtitleParts = [NSMutableArray array];
        if ([timer isActive] && timer.mode == YMSleepTimerModeCountdown) {
            [subtitleParts addObject:[NSString stringWithFormat:LOC(@"SLEEP_TIMER_REMAINING_FMT"), [timer remainingText]]];
        }
        if (timeLeftText) [subtitleParts addObject:timeLeftText];

        if ([timer isActive]) {
            YTActionSheetAction *off = [%c(YTActionSheetAction) actionWithTitle:LOC(@"SLEEP_TIMER_OFF")
                                                                       subtitle:[NSString stringWithFormat:LOC(@"SLEEP_TIMER_REMAINING_FMT"), [timer remainingText]]
                                                                      iconImage:nil
                                                                       handler:^(__unused YTActionSheetAction *action) {
                [timer cancel];
            }];
            [sheet addAction:off];
        }

        for (NSNumber *minutes in @[@15, @30, @45, @60]) {
            YTActionSheetAction *duration = [%c(YTActionSheetAction) actionWithTitle:[NSString stringWithFormat:LOC(@"SLEEP_TIMER_MINUTES_FMT"), [minutes integerValue]]
                                                                            subtitle:nil
                                                                           iconImage:nil
                                                                            handler:^(__unused YTActionSheetAction *action) {
                [timer startWithMinutes:[minutes integerValue]];
            }];
            [sheet addAction:duration];
        }

        if (YouModCurrentPlayerViewController) {
            YTActionSheetAction *endOfVideo = [%c(YTActionSheetAction) actionWithTitle:LOC(@"SLEEP_TIMER_END_OF_VIDEO")
                                                                            subtitle:timeLeftText
                                                                            iconImage:nil
                                                                            handler:^(__unused YTActionSheetAction *action) {
                [timer startEndOfVideo];
            }];
            [sheet addAction:endOfVideo];
        }

        YTActionSheetAction *customTime = [%c(YTActionSheetAction) actionWithTitle:LOC(@"SLEEP_TIMER_CUSTOM_TIME")
                                                                          subtitle:nil
                                                                         iconImage:nil
                                                                          handler:^(__unused YTActionSheetAction *action) {
            YMSleepTimerShowCustomTimeAlert();
        }];
        [sheet addAction:customTime];
        [sheet presentFromView:sourceView animated:YES completion:nil];
    };
    if ([NSThread isMainThread]) present();
    else dispatch_async(dispatch_get_main_queue(), present);
}

#pragma mark - Hooks

// Mirror of SponsorBlock's time-change hooks: keeps the countdown / fade and
// expiry check running on real playback ticks even when the runloop timer is
// suspended (e.g. locked screen while audio keeps playing).
%hook YTPlayerViewController
- (void)singleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    if (INTFORVAL(SleepTimerEntry) == 0) return;
    [[YMSleepTimer shared] playbackTick];
}

// Time-change hook for YouTube versions that use the renamed selector.
- (void)potentiallyMutatedSingleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    if (INTFORVAL(SleepTimerEntry) == 0) return;
    [[YMSleepTimer shared] playbackTick];
}
%end

%hook YTSlimStatusBarControllerImpl
- (void)addSlimStatusBarView:(YTSlimStatusBarView *)barView withObserver:(NSMapTable *)observers {
    %orig;
    if (!barView || INTFORVAL(SleepTimerEntry) == 0) return;
    if (!slimBarSet) slimBarSet = [NSHashTable weakObjectsHashTable];
    BOOL isWatch = NO;
    if ([barView._viewControllerForAncestor isKindOfClass:%c(YTWatchViewController)]) {
        isWatch = YES;
        for (YTSlimStatusBarView *view in slimBarSet) {
            if ([view._viewControllerForAncestor isKindOfClass:%c(YTWatchViewController)]) {
                [slimBarSet removeObject:view];
                break;
            }
        }
    }
    [slimBarSet addObject:barView];
    slimBarController = self;
    // If the timer is already running (e.g. started before this bar existed),
    // theme the new bar right away.
    if ([[YMSleepTimer shared] isActive]) {
        if (isWatch) slimBarThemed = NO;
        [[YMSleepTimer shared] updateSlimBars];
    }
}
- (void)connectionStatusDidChange:(BOOL)connected {
    %orig;
    if (INTFORVAL(SleepTimerEntry) == 0) return;
    YMSleepTimer *timer = [YMSleepTimer shared];
    if (connected) {
        if (![timer isActive]) {
            timer.connectionLost = NO;
            return;
        }
        // Give YouTube ~3s to settle its own bar before we re-apply the sleep
        // timer theme; connectionLost stays YES so ticks don't touch the bar
        // in the meantime.
        NSUInteger seq = ++slimBarReconnectSequence;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (seq != slimBarReconnectSequence) return; // flapped again meanwhile
            timer.connectionLost = NO;
            // YouTube may have reset the bar's appearance while disconnected,
            // so re-apply the sleep timer theme before updating the text.
            slimBarThemed = NO;
            [timer updateSlimBars];
        });
    } else {
        timer.connectionLost = YES;
    }
}
- (void)setDismissTimer:(id)arg {
    if ([[YMSleepTimer shared] isActive]) return;
    %orig;
}
%end

// While a playable game is up, hide the bar and stop updating the text until
// the game screen goes away.
%hook YTPlayablesFullscreenViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (INTFORVAL(SleepTimerEntry) == 0) return;
    YMSleepTimerSetBarHiddenByLayout(YES);
}
- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    if (INTFORVAL(SleepTimerEntry) == 0) return;
    YMSleepTimerSetBarHiddenByLayout(NO);
}
%end

%hook YTMainAppVideoPlayerOverlayViewController
- (void)setPlayerViewLayout:(int)mode {
    %orig;
    if (INTFORVAL(SleepTimerEntry) == 0) return;
    // Fullscreen hides the bar; the inline layout brings it back.
    YMSleepTimerSetBarHiddenByLayout(self.isFullscreen);
}
%end

#pragma mark - Constructor

%ctor {
    %init;
    if (!slimBarSet) slimBarSet = [NSHashTable weakObjectsHashTable];
    // Resume a timer persisted before the app was suspended or relaunched.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    double savedEnd = [defaults doubleForKey:SleepTimerEndDate];
    if (savedEnd > [[NSDate date] timeIntervalSince1970]) {
        YMSleepTimer *timer = [YMSleepTimer shared];
        timer.mode = (YMSleepTimerMode)[defaults integerForKey:SleepTimerMode];
        timer.endDate = [NSDate dateWithTimeIntervalSince1970:savedEnd];
        [timer scheduleTimer];
    }
    __weak YMSleepTimer *weakTimer = [YMSleepTimer shared];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note) {
        // The runloop timer is suspended in the background; catch up on the
        // wall clock as soon as we come back.
        [weakTimer tick];
    }];
}
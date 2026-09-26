#import "Headers.h"

// Sleep timer: counts down on wall-clock time (persisted, survives suspend /
// relaunch), shows the countdown on YouTube's slim status bar, and pauses the
// main player when it fires. Started from the overlay moon button or the tab
// long-press menu.

#pragma mark - Slim status bar classes (only exist on newer YouTube versions)

@class YTSlimStatusBarControllerImpl;

@interface YTSlimStatusBarView : UIView
- (void)updateApperanceToSleepTimerActiveWithText:(NSString *)text;
@end

@interface YTSlimStatusBarControllerImpl : NSObject
- (void)updateWithSleepTimerActiveStatus:(BOOL)arg;
- (void)addSlimStatusBarView:(YTSlimStatusBarView *)barView withObserver:(NSMapTable *)observers;
- (void)connectionStatusDidChange:(BOOL)connected;
- (void)setDismissTimer:(id)arg;
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
    if (self.mode == YMSleepTimerModeEndOfVideo) return LOC(@"SLEEP_TIMER_END_OF_VIDEO");
    NSInteger secs = (NSInteger)ceil([self remainingSeconds]);
    NSInteger hours = secs / 3600;
    NSInteger mins = (secs % 3600) / 60;
    NSInteger seconds = secs % 60;
    if (hours > 0) return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)hours, (long)mins, (long)seconds];
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)mins, (long)seconds];
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
    YouModSendToast(LOC(@"SLEEP_TIMER_TIME_UP"));
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
        if (remaining <= 5.0) [self applyFadeFraction:(remaining / 5.0)];
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
    if (![self isActive] || self.connectionLost) return;

    NSString *text = [self remainingText];
    void (^update)(void) = ^{
        if (!slimBarController) return;
        // Theme switch happens once per activation; continuous text updates
        // go straight to the label so the theme method isn't re-run.
        if (!slimBarThemed) {
            [slimBarController updateWithSleepTimerActiveStatus:YES];
            for (YTSlimStatusBarView *barView in slimBarSet) {
                [barView updateApperanceToSleepTimerActiveWithText:text];
            }
            slimBarThemed = YES;
        }
        for (YTSlimStatusBarView *barView in slimBarSet) {
            YTLabel *label = [barView valueForKey:@"_statusLabel"];
            if (label) label.text = text;
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

static UIViewController *YMSleepTimerPresentingViewController(void) {
    UIViewController *top = YouModTopViewController(nil);
    while (top.presentedViewController && !top.presentedViewController.isBeingDismissed) {
        top = top.presentedViewController;
    }
    return top;
}

static void YMSleepTimerShowCustomTimeAlert(UIViewController *presenter) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LOC(@"SLEEP_TIMER_CUSTOM_TIME")
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIDatePicker *datePicker = [[UIDatePicker alloc] initWithFrame:CGRectMake(0, 40, 270, 160)];
    datePicker.datePickerMode = UIDatePickerModeTime;
    datePicker.locale = [NSLocale currentLocale]; // renders 12/24h per system setting
    [alert.view addSubview:datePicker];

    [alert addAction:[UIAlertAction actionWithTitle:LOC(@"CANCEL") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:LOC(@"OK") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
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
    }]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

static void YMSleepTimerPresentPicker(UIView *sourceView) {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:LOC(@"SLEEP_TIMER")
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    YMSleepTimer *timer = [YMSleepTimer shared];
    if ([timer isActive]) {
        NSString *title = [NSString stringWithFormat:LOC(@"SLEEP_TIMER_OFF_FMT"), [timer remainingText]];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [timer cancel];
        }]];
    }

    NSArray<NSNumber *> *minutesOptions = @[@15, @30, @45, @60];
    for (NSNumber *minutes in minutesOptions) {
        NSString *title = [NSString stringWithFormat:LOC(@"SLEEP_TIMER_MINUTES_FMT"), [minutes integerValue]];
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [timer startWithMinutes:[minutes integerValue]];
        }]];
    }

    [sheet addAction:[UIAlertAction actionWithTitle:LOC(@"SLEEP_TIMER_END_OF_VIDEO") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [timer startEndOfVideo];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:LOC(@"SLEEP_TIMER_CUSTOM_TIME") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        YMSleepTimerShowCustomTimeAlert(YMSleepTimerPresentingViewController());
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:LOC(@"CANCEL") style:UIAlertActionStyleCancel handler:nil]];

    void (^present)(void) = ^{
        UIViewController *presenter = YMSleepTimerPresentingViewController();
        if (!presenter) return;
        if (sourceView && sheet.popoverPresentationController) {
            sheet.popoverPresentationController.sourceView = sourceView;
            sheet.popoverPresentationController.sourceRect = sourceView.bounds;
        }
        [presenter presentViewController:sheet animated:YES completion:nil];
    };
    if ([NSThread isMainThread]) present();
    else dispatch_async(dispatch_get_main_queue(), present);
}

void YMSleepTimerShowPicker(void) {
    YMSleepTimerPresentPicker(nil);
}

void YMSleepTimerShowPickerFromView(UIView *sourceView) {
    YMSleepTimerPresentPicker(sourceView);
}

#pragma mark - Hooks

// Mirror of SponsorBlock's time-change hooks: keeps the countdown / fade and
// expiry check running on real playback ticks even when the runloop timer is
// suspended (e.g. locked screen while audio keeps playing).
%hook YTPlayerViewController
- (void)singleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    [[YMSleepTimer shared] playbackTick];
}

// Time-change hook for YouTube versions that use the renamed selector.
- (void)potentiallyMutatedSingleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    [[YMSleepTimer shared] playbackTick];
}
%end

%hook YTSlimStatusBarControllerImpl

- (void)addSlimStatusBarView:(YTSlimStatusBarView *)barView withObserver:(NSMapTable *)observers {
    %orig;
    if (!barView) return;
    if (!slimBarSet) slimBarSet = [NSHashTable weakObjectsHashTable];
    [slimBarSet addObject:barView];
    slimBarController = self;
    // If the timer is already running (e.g. started before this bar existed),
    // theme the new bar right away.
    if ([[YMSleepTimer shared] isActive]) [[YMSleepTimer shared] updateSlimBars];
}

// While the "No connection" bar is up, YouTube owns the slim bar — stop
// drawing our countdown over it and pick back up once connected again.
- (void)connectionStatusDidChange:(BOOL)connected {
    %orig;
    YMSleepTimer *timer = [YMSleepTimer shared];
    if (connected) {
        timer.connectionLost = NO;
        if ([timer isActive]) {
            // YouTube may have reset the bar's appearance while disconnected,
            // so re-apply the sleep timer theme before updating the text.
            slimBarThemed = NO;
            [timer updateSlimBars];
        }
    } else {
        timer.connectionLost = YES;
    }
}

// Don't let the slim bar auto-dismiss itself while the countdown is running.
- (void)setDismissTimer:(id)arg {
    if ([[YMSleepTimer shared] isActive]) return;
    %orig;
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

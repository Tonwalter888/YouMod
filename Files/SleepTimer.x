#import "Headers.h"

#pragma mark - State

static YTSlimStatusBarConfiguration *sleepTimerConfig = nil;

static void createSleepTimerConfig(NSString *time) {
    sleepTimerConfig = [%c(YTSlimStatusBarConfiguration) configurationWithText:time style:0];
    sleepTimerConfig.animated = YES;
    YTIIcon *sleepIcon = [%c(YTIIcon) new];
    sleepIcon.iconType = 916;
    sleepTimerConfig.icon = [sleepIcon iconImageWithColor:[UIColor whiteColor]];
    // for YT 21.41 or newer
    @try {
        sleepTimerConfig.backgroundColor = [UIColor blackColor];
        sleepTimerConfig.textColor = [UIColor whiteColor];
    } @catch (id ex) {}
}

static BOOL isNewYTSlimStatusBarConfig() {
    return %c(YTSlimStatusBarConfiguration);
}

typedef NS_ENUM(NSInteger, YMSleepTimerMode) {
    YMSleepTimerModeCountdown = 0,
    YMSleepTimerModeEndOfVideo = 1,
};

// Weak set: YouTube can destroy slim bar views at any time; don't keep them alive.
static NSHashTable<YTSlimStatusBarView *> *slimBarSet = nil;
static YTSlimStatusBarControllerImpl *slimBarController = nil;
static BOOL slimBarThemed = NO;
static NSUInteger slimBarReconnectSequence = 0;

// Bar hidden while a playable game or fullscreen player is up.
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
@property (nonatomic, copy) NSString *endOfVideoID;
// Last remaining time from YTSingleVideoTime; tells a natural end (< 0.1 s)
// from a manual video switch.
@property (nonatomic, assign) CGFloat capturedRemainingTime;
+ (instancetype)shared;
- (void)startWithMinutes:(NSInteger)minutes;
- (void)startAtDate:(NSDate *)date;
- (void)startEndOfVideo;
- (void)cancel;
- (void)cancelForVideoChange;
- (void)fire;
- (void)tick;
- (void)playbackTick;
- (void)noteSingleVideoTime:(YTSingleVideoTime *)time video:(YTSingleVideoController *)video;
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
        if (!player) return @"--:--";
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
    YTPlayerViewController *player = YouModCurrentPlayerViewController;
    self.endOfVideoID = [player currentVideoID];
    CGFloat total = player ? [player currentVideoTotalMediaTime] : 0.0;
    CGFloat current = player ? [player currentVideoMediaTime] : 0.0;
    // Unknown duration: treat video changes as manual until ticks report a
    // real remaining time.
    self.capturedRemainingTime = total > current ? total - current : CGFLOAT_MAX;
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

// Manual video switch: cancel without pausing playback and show a pill.
- (void)cancelForVideoChange {
    [self restoreVolume];
    [self stopTimer];
    self.endDate = nil;
    self.mode = YMSleepTimerModeCountdown;
    self.endOfVideoID = nil;
    [self persist];
    [self deactivateSlimBars];
    [self notifyButtons];
    void (^pill)(void) = ^{
        YouModSendToast(LOC(@"SLEEP_TIMER_VIDEO_CHANGED"));
    };
    if ([NSThread isMainThread]) pill();
    else dispatch_async(dispatch_get_main_queue(), pill);
}

- (void)fire {
    [self stopTimer];
    // Fade out, pause, restore volume (so the next playback isn't muted),
    // then show the dialog.
    [self applyFadeFraction:0.0];
    [self pausePlayer];
    [self restoreVolumeAfterPause];
    self.endDate = nil;
    self.mode = YMSleepTimerModeCountdown;
    [self persist];
    [self deactivateSlimBars];
    [self notifyButtons];
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
        NSString *videoID = [player currentVideoID];
        BOOL videoChanged = self.endOfVideoID && videoID && ![videoID isEqualToString:self.endOfVideoID];
        if (player && [player isPlaybackFinished]) {
            [self fire];
            return;
        }
        if (videoChanged) {
            // Captured remaining time tells a natural end (<0.1 s) from a
            // manual video switch.
            if (self.capturedRemainingTime < 0.1) {
                [self fire];
            } else {
                [self cancelForVideoChange];
            }
            return;
        }
    }
    [self updateSlimBars];
}

// Also called from time-change hooks so expiry/fade stay accurate while the
// NSTimer is suspended (locked screen with audio on).
- (void)playbackTick {
    if (![self isActive]) return;
    NSDate *now = [NSDate date];
    static NSDate *lastTick = nil;
    if (lastTick && [now timeIntervalSinceDate:lastTick] < 0.5) return;
    lastTick = now;
    [self tick];
}

// Keeps end-of-video remaining time fresh so video changes can be judged
// while the runloop timer is suspended.
- (void)noteSingleVideoTime:(YTSingleVideoTime *)time video:(YTSingleVideoController *)video {
    if (self.mode != YMSleepTimerModeEndOfVideo || !time) return;
    CGFloat total = video ? [video totalMediaTime] : 0.0;
    if (total <= 0.0) return;
    CGFloat remaining = total - time.time;
    if (remaining < 0.0) remaining = 0.0;
    self.capturedRemainingTime = remaining;
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

// Restore after pause so the next playback doesn't start muted.
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
    [[NSNotificationCenter defaultCenter] postNotificationName:@"YouModUpdateSleepTimerButton" object:nil];
}

- (void)updateSlimBars {
    if (![self isActive] || self.connectionLost || layoutHidesBar) return;

    NSString *text = [self remainingText];
    void (^update)(void) = ^{
        if (isNewYTSlimStatusBarConfig()) {
            if (!slimBarThemed) {
                [slimBarController updateWithSleepTimerActiveStatus:YES];
                if (!sleepTimerConfig) createSleepTimerConfig(text);
                else sleepTimerConfig.text = text;
                for (YTSlimStatusBarView *barView in slimBarSet) [barView updateWithConfiguration:sleepTimerConfig];
                slimBarThemed = YES;
            } else {
                if (!sleepTimerConfig) createSleepTimerConfig(text);
                else sleepTimerConfig.text = text;
                for (YTSlimStatusBarView *barView in slimBarSet) [barView updateWithConfiguration:sleepTimerConfig];
            }
        } else {
            if (!slimBarThemed) {
                [slimBarController updateWithSleepTimerActiveStatus:YES];
                for (YTSlimStatusBarView *barView in slimBarSet) [barView updateAppearanceToSleepTimerActiveWithText:text];
                slimBarThemed = YES;
            } else {
                for (YTSlimStatusBarView *barView in slimBarSet) [barView updateAppearanceToSleepTimerActiveWithText:text];
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

// Custom time picker inside a YT-native alert (not a system dialog).
static void YMSleepTimerShowCustomTimeAlert(void) {
    YTAlertView *alertView = [%c(YTAlertView) dialog];
    alertView.title = LOC(@"SLEEP_TIMER_CUSTOM_TIME");
    alertView.shouldDismissOnBackgroundTap = YES;

    UIDatePicker *datePicker = [[UIDatePicker alloc] initWithFrame:CGRectMake(0, 0, 238, 150)];
    datePicker.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    datePicker.datePickerMode = UIDatePickerModeTime;
    // Force wheel style: on iOS 14+ the compact default collapses into a
    // popover button instead of sitting inside this dialog.
    datePicker.preferredDatePickerStyle = UIDatePickerStyleWheels;
    datePicker.locale = [NSLocale currentLocale]; // renders 12/24h per system setting

    alertView.customContentView = datePicker;
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
                                                                       subtitle:nil
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

// Time-change hooks keep countdown/fade/expiry running on real playback ticks
// while the runloop timer is suspended (e.g. locked screen with audio).
%hook YTPlayerViewController
- (void)singleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    if (INTFORVAL(SleepTimerEntry) == 0) return;
    [[YMSleepTimer shared] noteSingleVideoTime:time video:video];
    [[YMSleepTimer shared] playbackTick];
}

// Time-change hook for YouTube versions that use the renamed selector.
- (void)potentiallyMutatedSingleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    if (INTFORVAL(SleepTimerEntry) == 0) return;
    [[YMSleepTimer shared] noteSingleVideoTime:time video:video];
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
    // Timer already running: theme the new bar right away.
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
        NSUInteger seq = ++slimBarReconnectSequence;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (seq != slimBarReconnectSequence) return; // flapped again meanwhile
            timer.connectionLost = NO;
            // Re-apply the theme; YouTube may have reset the bar's appearance
            // while disconnected.
            slimBarThemed = NO;
            [timer updateSlimBars];
        });
    } else {
        timer.connectionLost = YES;
    }
}
%end

// Hide the bar and text updates while a playable game is up.
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
    // Session-only: clear values left by an earlier app process.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:SleepTimerEndDate];
    [defaults removeObjectForKey:SleepTimerMode];
    __weak YMSleepTimer *weakTimer = [YMSleepTimer shared];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note) {
        // Timer is suspended in background; catch up on return.
        [weakTimer tick];
    }];
}

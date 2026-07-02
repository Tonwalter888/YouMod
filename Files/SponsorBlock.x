#import "Headers.h"
#import <AudioToolbox/AudioToolbox.h>

BOOL useBackwardIconForButton;

@interface SBPassthroughView : UIView
@end
@implementation SBPassthroughView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return (hit == self) ? nil : hit;
}
@end

@interface SBPassthroughWindow : UIWindow
@end
@implementation SBPassthroughWindow
- (BOOL)_canBecomeKeyWindow { return NO; }
- (BOOL)_canAffectStatusBarAppearance { return NO; }
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *rootView = self.rootViewController.view;
    if (!rootView) return nil;
    CGPoint convertedPoint = [rootView convertPoint:point fromView:self];
    UIView *hitView = [rootView hitTest:convertedPoint withEvent:event];
    if (!hitView || hitView == rootView) return nil;
    return hitView;
}
@end

static SBPassthroughWindow *sbOverlayWindow = nil;

void sbUpdateOverlayInsetForPivotBar() {
    if (!sbOverlayWindow) return;
    UIViewController *rootVC = sbOverlayWindow.rootViewController;
    if (!rootVC) return;

    // Look up YouTube's root view controller in the SAME scene as our overlay
    // window — on iPad multi-window the app delegate's window may belong to a
    // different scene, so [delegate window] is not safe here.
    UIWindow *ytWindow = nil;
    for (UIWindow *win in sbOverlayWindow.windowScene.windows) {
        if ([win.rootViewController isKindOfClass:NSClassFromString(@"YTAppViewController")] || [win.rootViewController isKindOfClass:NSClassFromString(@"YTAppViewControllerImpl")]) {
            ytWindow = win;
            break;
        }
    }
    YTAppViewController *appVC = (YTAppViewController *)ytWindow.rootViewController;
    YTAppViewControllerImpl *appVC2 = (YTAppViewControllerImpl *)ytWindow.rootViewController;
    YTPivotBarViewController *pivotVC;
    @try {
        pivotVC = (YTPivotBarViewController *)appVC.pivotBarViewController;
    } @catch (id ex) {
        pivotVC = (YTPivotBarViewController *)appVC2.pivotBarViewController;
    }
    YTPivotBarView *pivot = (YTPivotBarView *)pivotVC.viewIfLoaded;

    // Measure the pivot bar's visible top edge in our overlay window's coords
    // and convert it into the inset our pills need above the device safe area.
    // This avoids reading pivot.bounds.size.height directly — that value
    // includes home-indicator padding on notched devices and would over-correct
    // the safe area, leaving the pill floating too high above the tabbar.
    CGFloat tabH = 0.0;
    if (pivot && pivot.window != nil && !pivot.hidden && pivot.alpha > 0.01) {
        UIView *overlayView = rootVC.view;
        CGRect pivotInOverlay = [overlayView convertRect:pivot.bounds fromView:pivot];
        CGFloat pivotTop = CGRectGetMinY(pivotInOverlay);
        CGFloat overlayHeight = overlayView.bounds.size.height;
        CGFloat deviceSafeBottom = sbOverlayWindow.safeAreaInsets.bottom;
        // Clamp to [0, overlayHeight] in case convertRect returns a stale
        // value during scene transitions (e.g. iPad split-view drag) — without
        // an upper bound, an absurd tabH would push the pill off-screen.
        tabH = MAX(0.0, MIN(overlayHeight, overlayHeight - deviceSafeBottom - pivotTop));
    }
    UIEdgeInsets current = rootVC.additionalSafeAreaInsets;
    if (current.bottom != tabH) {
        rootVC.additionalSafeAreaInsets = UIEdgeInsetsMake(0, 0, tabH, 0);
    }
}

// Tracks which scene's lifecycle is currently observed. When sbOverlayWindow is
// recreated for a different scene (after the original goes Unattached), we
// re-bind observers to the new scene rather than leaving stale registrations.
static UIWindowScene *sbObservedScene = nil;
static id sbBackgroundObserver = nil;
static id sbForegroundObserver = nil;
static id sbAppBackgroundObserver = nil;
static id sbAppForegroundObserver = nil;
static id sbOrientationObserver = nil;

static void sbRegisterOverlayLifecycleObservers(UIWindowScene *targetScene) {
    if (!targetScene || sbObservedScene == targetScene) return;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    if (sbBackgroundObserver) [nc removeObserver:sbBackgroundObserver];
    if (sbForegroundObserver) [nc removeObserver:sbForegroundObserver];
    if (sbAppBackgroundObserver) [nc removeObserver:sbAppBackgroundObserver];
    if (sbAppForegroundObserver) [nc removeObserver:sbAppForegroundObserver];
    if (sbOrientationObserver) [nc removeObserver:sbOrientationObserver];

    sbObservedScene = targetScene;

    // Hide on background — synchronous change before the app-switcher snapshot
    // is captured (Apple QA1838). queue:nil delivers on the posting thread
    // without enqueuing, so the hide happens before iOS captures the snapshot.
    sbBackgroundObserver = [nc addObserverForName:UISceneDidEnterBackgroundNotification object:targetScene queue:nil usingBlock:^(__unused NSNotification *note) {
        if (sbOverlayWindow) sbOverlayWindow.hidden = YES;
    }];
    sbForegroundObserver = [nc addObserverForName:UISceneWillEnterForegroundNotification object:targetScene queue:nil usingBlock:^(__unused NSNotification *note) {
        if (sbOverlayWindow) sbOverlayWindow.hidden = NO;
    }];
    sbAppBackgroundObserver = [nc addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil usingBlock:^(__unused NSNotification *note) {
        if (sbOverlayWindow) sbOverlayWindow.hidden = YES;
    }];
    sbAppForegroundObserver = [nc addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:nil usingBlock:^(__unused NSNotification *note) {
        if (sbOverlayWindow) sbOverlayWindow.hidden = NO;
    }];

    // Recompute pivot-bar inset on rotation / dynamic tabbar height changes.
    // UIDeviceOrientationDidChangeNotification only fires when device-orientation
    // generation is enabled; this call is idempotent.
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    sbOrientationObserver = [nc addObserverForName:UIDeviceOrientationDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *note) {
        sbUpdateOverlayInsetForPivotBar();
    }];
}

UIView *sbGetNotificationParent(void) {
    if (sbOverlayWindow && sbOverlayWindow.windowScene.activationState == UISceneActivationStateUnattached) {
        sbOverlayWindow = nil;
    }
    if (!sbOverlayWindow) {
        UIWindowScene *activeScene = nil;
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                activeScene = scene;
                break;
            }
        }
        if (!activeScene) {
            activeScene = (UIWindowScene *)[[[UIApplication sharedApplication].connectedScenes allObjects] firstObject];
        }
        if (!activeScene) return nil;

        sbOverlayWindow = [[SBPassthroughWindow alloc] initWithWindowScene:activeScene];
        sbOverlayWindow.frame = activeScene.coordinateSpace.bounds;
        sbOverlayWindow.windowLevel = UIWindowLevelAlert - 1;
        sbOverlayWindow.backgroundColor = [UIColor clearColor];
        sbOverlayWindow.hidden = NO;

        UIViewController *rootVC = [[UIViewController alloc] init];
        rootVC.view = [[SBPassthroughView alloc] initWithFrame:sbOverlayWindow.bounds];
        rootVC.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        rootVC.view.backgroundColor = [UIColor clearColor];
        sbOverlayWindow.rootViewController = rootVC;

        sbRegisterOverlayLifecycleObservers(activeScene);
        sbUpdateOverlayInsetForPivotBar();
    }
    return sbOverlayWindow.rootViewController.view;
}

static NSMutableDictionary<NSString *, NSArray<SBSegment *> *> *sbSegmentCache;

static NSArray<NSString *> *sbAllCategories() {
    static NSArray *cats;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cats = @[@"sponsor", @"intro", @"outro", @"interaction", @"selfpromo",
                 @"music_offtopic", @"preview", @"poi_highlight", @"filler"];
    });
    return cats;
}

static NSArray<NSString *> *sbEnabledCategories() {
    NSMutableArray *enabled = [NSMutableArray array];
    for (NSString *cat in sbAllCategories()) {
        NSInteger action = [[NSUserDefaults standardUserDefaults] integerForKey:SB_ACTION_KEY(cat)];
        if (action != SBSegmentActionDisable) {
            [enabled addObject:cat];
        }
    }
    return enabled;
}

UIColor *SBColorFromHex(NSString *hexString) {
    if (!hexString || hexString.length < 7) return [UIColor whiteColor];
    unsigned int hex = 0;
    NSScanner *scanner = [NSScanner scannerWithString:[hexString substringFromIndex:1]];
    [scanner scanHexInt:&hex];
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >> 8) & 0xFF) / 255.0
                            blue:(hex & 0xFF) / 255.0
                           alpha:1.0];
}

#pragma mark - SBSegment Implementation

@implementation SBSegment

+ (instancetype)segmentWithUUID:(NSString *)UUID category:(NSString *)category start:(float)start end:(float)end action:(NSString *)actionType {
    SBSegment *seg = [[SBSegment alloc] init];
    seg.UUID = UUID;
    seg.category = category;
    seg.startTime = start;
    seg.endTime = end;
    seg.actionType = actionType;
    return seg;
}

- (SBSegmentAction)configuredAction {
    return (SBSegmentAction)[[NSUserDefaults standardUserDefaults] integerForKey:SB_ACTION_KEY(self.category)];
}

- (UIColor *)segmentColor {
    NSString *hex = [[NSUserDefaults standardUserDefaults] stringForKey:SB_COLOR_KEY(self.category)];
    return SBColorFromHex(hex);
}

@end

#pragma mark - SBRequest Implementation

@implementation SBRequest

+ (void)fetchSegmentsForVideoID:(NSString *)videoID completion:(void (^)(NSArray<SBSegment *> *))completion {
    if (!videoID || videoID.length == 0) {
        if (completion) completion(@[]);
        return;
    }

    @synchronized(sbSegmentCache) {
        NSArray *cached = sbSegmentCache[videoID];
        if (cached) {
            if (completion) completion(cached);
            return;
        }
    }

    NSArray *categories = sbEnabledCategories();
    if (categories.count == 0) {
        if (completion) completion(@[]);
        return;
    }

    NSData *catJSON = [NSJSONSerialization dataWithJSONObject:categories options:0 error:nil];
    NSString *catString = [[NSString alloc] initWithData:catJSON encoding:NSUTF8StringEncoding];
    NSString *encoded = [catString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlStr = [NSString stringWithFormat:@"https://sponsor.ajay.app/api/skipSegments?videoID=%@&categories=%@", videoID, encoded];
    NSURL *url = [NSURL URLWithString:urlStr];

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSMutableArray<SBSegment *> *segments = [NSMutableArray array];

        if (!error && data) {
            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
            if (httpResp.statusCode == 200) {
                NSArray *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([json isKindOfClass:[NSArray class]]) {
                    for (NSDictionary *item in json) {
                        NSArray *segment = item[@"segment"];
                        if (segment.count >= 2) {
                            SBSegment *seg = [SBSegment segmentWithUUID:item[@"UUID"] ?: @""
                                                              category:item[@"category"] ?: @""
                                                                 start:[segment[0] floatValue]
                                                                   end:[segment[1] floatValue]
                                                                action:item[@"actionType"] ?: @"skip"];
                            [segments addObject:seg];
                        }
                    }
                }
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            @synchronized(sbSegmentCache) {
                sbSegmentCache[videoID] = segments;
            }
            if (completion) completion(segments);
        });
    }];
    [task resume];
}

@end

#pragma mark - YTPlayerViewController Hooks

%hook YTPlayerViewController
%property (nonatomic, strong) NSString *sbLastVideoID;
%property (nonatomic, strong) NSArray *sbSegments;
%property (nonatomic, strong) NSMutableSet *sbSkippedSegments;
%property (nonatomic, strong) SBSkipNotificationView *sbNotificationView;
%property (nonatomic, assign) BOOL sbEnabledForVideo;

- (void)playbackController:(id)playbackController didActivateVideo:(id)video withPlaybackData:(id)playbackData {
    %orig;
    if (!IS_ENABLED(SBEnabled) || self.isPlayingAd) return;

    self.sbEnabledForVideo = YES;
    self.sbSkippedSegments = [NSMutableSet set];
    self.sbSegments = nil;

    [self.sbNotificationView dismiss];

    NSString *videoID = [self contentVideoID];
    if ([self.sbLastVideoID isEqualToString:videoID] && self.sbSegments.count > 0) return;
    self.sbLastVideoID = videoID;

    __weak typeof(self) weakSelf = self;
    [SBRequest fetchSegmentsForVideoID:videoID completion:^(NSArray<SBSegment *> *segments) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.sbSegments = segments;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SBSegmentsDidLoad"
                                                            object:strongSelf
                                                            userInfo:@{@"segments": segments ?: @[]}];

        [strongSelf sbShowHighlightBannerIfNeeded:segments];
    }];
}

- (void)singleVideo:(id)video currentVideoTimeDidChange:(id)time {
    %orig;
    if (!IS_ENABLED(SBEnabled) || !self.sbEnabledForVideo || self.isPlayingAd) return;

    CGFloat currentTime = [self currentVideoMediaTime];
    float minDuration = FLOAT_FOR_KEY(SBMinDuration);

    for (SBSegment *segment in self.sbSegments) {
        SBSegmentAction action = [segment configuredAction];
        if (action == SBSegmentActionDisable || action == SBSegmentActionDisplay) continue;
        if (action == SBSegmentActionSkipTo) continue;

        float duration = segment.endTime - segment.startTime;
        if (duration < minDuration) continue;

        if (currentTime >= segment.startTime && currentTime < segment.endTime - 0.5) {
            NSString *segID = segment.UUID;
            if ([self.sbSkippedSegments containsObject:segID]) continue;

            if (action == SBSegmentActionAutoSkip) {
                [self sbPerformSkip:segment];
            } else if (action == SBSegmentActionAsk) {
                [self sbShowAskNotification:segment];
            }
            break;
        }
    }
}

// Alternative hook for newer YouTube versions where method was renamed
- (void)potentiallyMutatedSingleVideo:(id)video currentVideoTimeDidChange:(id)time {
    %orig;
    if (!IS_ENABLED(SBEnabled) || !self.sbEnabledForVideo || self.isPlayingAd) return;

    CGFloat currentTime = [self currentVideoMediaTime];
    float minDuration = FLOAT_FOR_KEY(SBMinDuration);

    for (SBSegment *segment in self.sbSegments) {
        SBSegmentAction action = [segment configuredAction];
        if (action == SBSegmentActionDisable || action == SBSegmentActionDisplay) continue;
        if (action == SBSegmentActionSkipTo) continue;

        float duration = segment.endTime - segment.startTime;
        if (duration < minDuration) continue;

        if (currentTime >= segment.startTime && currentTime < segment.endTime - 0.5) {
            NSString *segID = segment.UUID;
            if ([self.sbSkippedSegments containsObject:segID]) continue;

            if (action == SBSegmentActionAutoSkip) {
                [self sbPerformSkip:segment];
            } else if (action == SBSegmentActionAsk) {
                [self sbShowAskNotification:segment];
            }
            break;
        }
    }
}

%new
- (void)sbPerformSkip:(SBSegment *)segment {
    [self.sbSkippedSegments addObject:segment.UUID];
    [self seekToTime:(CGFloat)segment.endTime];

    if (IS_ENABLED(SBAudioNotification)) {
        AudioServicesPlaySystemSound(1519);
    }

    if (IS_ENABLED(SBShowNotifications)) {
        useBackwardIconForButton = YES;
        NSBundle *bundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"YouMod" ofType:@"bundle"]];
        NSString *catName = [bundle localizedStringForKey:[NSString stringWithFormat:@"SB_CAT_%@", segment.category] value:segment.category table:nil];
        NSString *message = [NSString stringWithFormat:[bundle localizedStringForKey:@"SB_SKIPPED" value:@"%@ skipped" table:nil], catName];
        NSString *unskipTitle = [bundle localizedStringForKey:@"SB_UNSKIP" value:@"Unskip" table:nil];

        float alertDuration = FLOAT_FOR_KEY(SBUnskipAlertDuration);
        if (alertDuration < 2.0 || alertDuration > 20.0) alertDuration = 4.0;

        __weak typeof(self) weakSelf = self;
        // Delay notification so the seek completes before the banner is shown,
        // preventing the time-change callback from dismissing it immediately.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            UIView *parentView = sbGetNotificationParent();
            strongSelf.sbNotificationView = [SBSkipNotificationView showInView:parentView
                message:message
                buttonTitle:unskipTitle
                action:^{
                    __strong typeof(weakSelf) ss = weakSelf;
                    if (ss) [ss seekToTime:(CGFloat)segment.startTime];
                }
                duration:alertDuration];
        });
    }
}

%new
- (void)sbShowAskNotification:(SBSegment *)segment {
    [self.sbSkippedSegments addObject:segment.UUID];

    useBackwardIconForButton = NO;
    NSBundle *bundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"YouMod" ofType:@"bundle"]];
    NSString *catName = [bundle localizedStringForKey:[NSString stringWithFormat:@"SB_CAT_%@", segment.category] value:segment.category table:nil];
    NSString *message = [NSString stringWithFormat:[bundle localizedStringForKey:@"SB_DETECTED" value:@"%@ detected" table:nil], catName];

    float alertDuration = FLOAT_FOR_KEY(SBSkipAlertDuration);
    if (alertDuration < 2.0 || alertDuration > 20.0) alertDuration = 4.0;

    UIView *parentView = sbGetNotificationParent();
    __weak typeof(self) weakSelf = self;
    self.sbNotificationView = [SBSkipNotificationView showInView:parentView
        message:message
        buttonTitle:[bundle localizedStringForKey:@"SB_SKIP_NOW" value:@"Skip" table:nil]
        action:^{
            __strong typeof(weakSelf) ss = weakSelf;
            if (ss) [ss seekToTime:(CGFloat)segment.endTime];
        }
        duration:alertDuration];
}

%new
- (void)sbShowHighlightBannerIfNeeded:(NSArray<SBSegment *> *)segments {
    for (SBSegment *seg in segments) {
        if ([seg.category isEqualToString:@"poi_highlight"] && [seg configuredAction] == SBSegmentActionSkipTo) {
            useBackwardIconForButton = NO;
            NSBundle *bundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"YouMod" ofType:@"bundle"]];
            NSString *message = [bundle localizedStringForKey:@"SB_JUMP_TO_HIGHLIGHT" value:@"Highlight available. Jump to the point?" table:nil];
            NSString *skipTitle = [bundle localizedStringForKey:@"SB_SKIP_NOW" value:@"Skip" table:nil];

            float alertDuration = FLOAT_FOR_KEY(SBSkipAlertDuration);
            if (alertDuration < 2.0 || alertDuration > 20.0) alertDuration = 4.0;

            UIView *parentView = sbGetNotificationParent();
            SBSkipNotificationView *pill = [SBSkipNotificationView showInView:parentView
                message:message
                buttonTitle:skipTitle
                action:^{ [self sbSkipToHighlight]; }
                duration:alertDuration];
            if (pill) {
                pill.isHighlightPill = YES;
                self.sbNotificationView = pill;
            }
            break;
        }
    }
}

%new
- (void)sbSkipToHighlight {
    self.sbNotificationView.isHighlightPill = NO;

    for (SBSegment *segment in self.sbSegments) {
        if ([segment.category isEqualToString:@"poi_highlight"]) {
            CGFloat previousTime = [self currentVideoMediaTime];
            [self seekToTime:(CGFloat)segment.startTime];

            if (IS_ENABLED(SBShowNotifications)) {
                useBackwardIconForButton = YES;
                NSBundle *bundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"YouMod" ofType:@"bundle"]];
                NSString *message = [bundle localizedStringForKey:@"SB_JUMPED_TO_HIGHLIGHT" value:@"Jumped to highlight" table:nil];
                NSString *unskipTitle = [bundle localizedStringForKey:@"SB_UNSKIP" value:@"Unskip" table:nil];

                float alertDuration = FLOAT_FOR_KEY(SBUnskipAlertDuration);
                if (alertDuration < 2.0 || alertDuration > 20.0) alertDuration = 4.0;

                __weak typeof(self) weakSelf = self;
                SBSkipNotificationView *pill = [SBSkipNotificationView showInView:sbGetNotificationParent()
                    message:message
                    buttonTitle:unskipTitle
                    action:^{
                        __strong typeof(weakSelf) ss = weakSelf;
                        if (ss) [ss seekToTime:previousTime];
                    }
                    duration:alertDuration];
                if (pill) {
                    pill.isHighlightPill = YES;
                    self.sbNotificationView = pill;
                }
            }
            break;
        }
    }
}

%end

// SponsorBlock's accent blue, reused for the toggle button's enabled state.
static UIColor *SBAccentColor() {
    return [UIColor colorWithRed:0.4 green:0.8 blue:1.0 alpha:1.0];
}

%ctor {
    sbSegmentCache = [NSMutableDictionary dictionary];
    %init;

    // Register the SponsorBlock toggle in the player overlay's custom button row.
    // sortOrder 100 keeps it right-most (directly under YouTube's settings gear).
    YMOverlayButtonSpec *toggle = [[YMOverlayButtonSpec alloc] init];
    toggle.identifier = @"sponsorblock.toggle";
    toggle.symbolName = @"shield.fill";
    toggle.tintColor = SBAccentColor();
    toggle.sortOrder = 100;
    toggle.isVisible = ^BOOL(YTPlayerViewController *player) {
        return IS_ENABLED(SBEnabled) && IS_ENABLED(SBShowButton);
    };
    toggle.tintProvider = ^UIColor *(YTPlayerViewController *player) {
        return (player && player.sbEnabledForVideo) ? SBAccentColor() : [UIColor grayColor];
    };
    toggle.onTap = ^(YTPlayerViewController *player, UIButton *button) {
        if (!player) return;
        BOOL newState = !player.sbEnabledForVideo;
        player.sbEnabledForVideo = newState;
        button.tintColor = newState ? SBAccentColor() : [UIColor grayColor];

        NSArray *segments = newState ? (player.sbSegments ?: @[]) : @[];
        if (newState && segments.count == 0) return;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SBSegmentsDidLoad"
                                                            object:player
                                                          userInfo:@{@"segments": segments}];
    };
    YMRegisterOverlayButton(toggle);
}

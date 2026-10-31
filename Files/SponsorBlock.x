#import "Headers.h"
#import <AudioToolbox/AudioToolbox.h>

BOOL useBackwardIconForButton;

// System sound played on skip when haptic/audio feedback is enabled.
static const SystemSoundID SBSkipHapticSoundID = 1519;

// Skips are suppressed this close to a segment's end so a late time-change callback can't re-trigger one.
static const CGFloat SBSegmentEndGuardSeconds = 0.5;

// The skip banner is delayed so the seek completes first; otherwise the next time-change callback dismisses it.
static const NSTimeInterval SBSkipNotificationDelaySeconds = 0.3;

// Clamps a stored banner duration to the supported range, falling back to the default when unset or out of range.
static float SBClampedAlertDuration(NSString *key) {
    float duration = FLOAT_FOR_KEY(key);
    if (duration < SBAlertDurationMin || duration > SBAlertDurationMax) return SBAlertDurationDefault;
    return duration;
}

@implementation SBPassthroughView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return (hit == self) ? nil : hit;
}
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

    // The window's frame is set only at creation and doesn't auto-resize with the scene (rotation,
    // fullscreen exit); re-sync it so the pill safe-area math uses current bounds.
    UIWindowScene *scene = sbOverlayWindow.windowScene;
    CGRect sceneBounds = scene ? scene.coordinateSpace.bounds : sbOverlayWindow.bounds;
    if (scene && !CGRectEqualToRect(sbOverlayWindow.frame, sceneBounds)) {
        sbOverlayWindow.frame = sceneBounds;
    }

    // Find YouTube's root VC in the same scene as our overlay window (on iPad multi-window
    // the delegate's window may be a different scene).
    UIWindow *ytWindow = nil;
    for (UIWindow *win in sbOverlayWindow.windowScene.windows) {
        if ([win.rootViewController isKindOfClass:NSClassFromString(@"YTAppViewController")] || [win.rootViewController isKindOfClass:NSClassFromString(@"YTAppViewControllerImpl")]) {
            ytWindow = win;
            break;
        }
    }
    UIViewController *appVC = ytWindow.rootViewController;
    YTPivotBarViewController *pivotVC = (YTPivotBarViewController *)[appVC performSelector:@selector(pivotBarViewController)];
    YTPivotBarView *pivot = (YTPivotBarView *)pivotVC.view;

    // Convert the pivot bar's visible top edge into the inset pills need above the safe area.
    // pivot.bounds.size.height includes home-indicator padding and would over-correct.
    CGFloat tabH = 0.0;
    if (pivot && pivot.window != nil && !pivot.hidden && pivot.alpha > 0.01) {
        UIView *overlayView = rootVC.view;
        CGRect pivotInOverlay = [overlayView convertRect:pivot.bounds fromView:pivot];
        CGFloat pivotTop = CGRectGetMinY(pivotInOverlay);
        // Scene bounds are authoritative; overlayView.bounds lags until autoresizing propagates.
        CGFloat overlayHeight = sceneBounds.size.height;
        CGFloat deviceSafeBottom = sbOverlayWindow.safeAreaInsets.bottom;
        CGFloat pivotHeight = pivot.bounds.size.height;
        // Clamp to the pivot bar's height: stale convertRect values during scene transitions
        // would otherwise inflate the inset toward full screen height.
        tabH = MAX(0.0, MIN(pivotHeight, overlayHeight - deviceSafeBottom - pivotTop));
    }
    UIEdgeInsets current = rootVC.additionalSafeAreaInsets;
    if (current.bottom != tabH) {
        rootVC.additionalSafeAreaInsets = UIEdgeInsetsMake(0, 0, tabH, 0);
    }
}

static const NSTimeInterval SBOverlayRestoreFadeDuration = 0.15;

void sbDismissAllNotifications(void) {
    if (!sbOverlayWindow) return;
    UIViewController *rootVC = sbOverlayWindow.rootViewController;
    UIView *rootView = rootVC ? rootVC.view : nil;
    if (!rootView) return;
    for (UIView *sub in [rootView.subviews copy]) {
        [sub.layer removeAllAnimations];
        if ([sub isKindOfClass:[YouModPillView class]]) {
            [((YouModPillView *)sub).progressOverlay.layer removeAllAnimations];
        }
        [sub removeFromSuperview];
    }
}

// Hide the pill overlay instantly and dismiss active notifications so no stale pills
// persist into the app switcher or re-entering the app.
static void sbHideOverlayForSnapshot(void) {
    sbDismissAllNotifications();
    if (sbOverlayWindow) sbOverlayWindow.hidden = YES;
}

// Restore the overlay (faded in) only if notification subviews are present; guarded to the
// hidden state so the two "became active" notifications don't each re-trigger the fade.
static void sbRestoreOverlayAfterSnapshot(void) {
    if (!sbOverlayWindow) return;
    UIView *rootView = sbOverlayWindow.rootViewController.view;
    if (!rootView || rootView.subviews.count == 0) {
        sbOverlayWindow.hidden = YES;
        return;
    }
    if (sbOverlayWindow.hidden) {
        sbOverlayWindow.alpha = 0.0;
        sbOverlayWindow.hidden = NO;
        [UIView animateWithDuration:SBOverlayRestoreFadeDuration animations:^{
            sbOverlayWindow.alpha = 1.0;
        }];
    }
}

// Tracks the observed scene so observers re-bind when the overlay window is recreated for a new scene.
static UIWindowScene *sbObservedScene = nil;
static id sbSceneDeactivateObserver = nil;
static id sbSceneBackgroundObserver = nil;
static id sbSceneActivateObserver = nil;
static id sbAppResignObserver = nil;
static id sbAppBackgroundObserver = nil;
static id sbAppActivateObserver = nil;
static id sbOrientationObserver = nil;

static void sbRegisterOverlayLifecycleObservers(UIWindowScene *targetScene) {
    if (!targetScene || sbObservedScene == targetScene) return;
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    if (sbSceneDeactivateObserver) [nc removeObserver:sbSceneDeactivateObserver];
    if (sbSceneBackgroundObserver) [nc removeObserver:sbSceneBackgroundObserver];
    if (sbSceneActivateObserver) [nc removeObserver:sbSceneActivateObserver];
    if (sbAppResignObserver) [nc removeObserver:sbAppResignObserver];
    if (sbAppBackgroundObserver) [nc removeObserver:sbAppBackgroundObserver];
    if (sbAppActivateObserver) [nc removeObserver:sbAppActivateObserver];
    if (sbOrientationObserver) [nc removeObserver:sbOrientationObserver];

    sbObservedScene = targetScene;

    // Hide on deactivation (the app switcher only goes inactive), restore on activation.
    // queue:nil hides before the snapshot; scene notifications are per-scene, app-level ones are a backstop.
    sbSceneDeactivateObserver = [nc addObserverForName:UISceneWillDeactivateNotification object:targetScene queue:nil usingBlock:^(__unused NSNotification *note) {
        sbHideOverlayForSnapshot();
    }];
    sbSceneBackgroundObserver = [nc addObserverForName:UISceneDidEnterBackgroundNotification object:targetScene queue:nil usingBlock:^(__unused NSNotification *note) {
        sbHideOverlayForSnapshot();
    }];
    sbSceneActivateObserver = [nc addObserverForName:UISceneDidActivateNotification object:targetScene queue:nil usingBlock:^(__unused NSNotification *note) {
        sbRestoreOverlayAfterSnapshot();
    }];
    sbAppResignObserver = [nc addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:nil usingBlock:^(__unused NSNotification *note) {
        sbHideOverlayForSnapshot();
    }];
    sbAppBackgroundObserver = [nc addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil usingBlock:^(__unused NSNotification *note) {
        sbHideOverlayForSnapshot();
    }];
    sbAppActivateObserver = [nc addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:nil usingBlock:^(__unused NSNotification *note) {
        sbRestoreOverlayAfterSnapshot();
    }];

    // Recompute the pivot-bar inset on rotation / tabbar height changes; the call is idempotent.
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
    } else {
        if (sbOverlayWindow.hidden) {
            sbOverlayWindow.alpha = 1.0;
            sbOverlayWindow.hidden = NO;
        }
        sbUpdateOverlayInsetForPivotBar();
    }
    return sbOverlayWindow.rootViewController.view;
}

static NSMutableDictionary<NSString *, NSArray<SBSegment *> *> *sbSegmentCache;

// Drops the cached segments for a video (e.g. after a vote changed server-side data) so the next activation refetches.
void sbInvalidateSegmentCache(NSString *videoID) {
    if (!videoID) return;
    @synchronized(sbSegmentCache) {
        [sbSegmentCache removeObjectForKey:videoID];
    }
}

NSArray<NSString *> *sbAllCategories(void) {
    static NSArray *cats;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cats = @[@"sponsor", @"intro", @"outro", @"interaction", @"selfpromo",
                 @"music_offtopic", @"preview", @"hook", @"poi_highlight", @"filler",
                 @"exclusive_access"];
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

// Credits the segment's submitter with a view (SponsorBlock stats), as intended by API spec
static void sbSendViewedSegment(SBSegment *segment) {
    if (segment.UUID.length == 0) return;
    NSString *uuid = [segment.UUID stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[@"https://sponsor.ajay.app/api/viewedVideoSponsorTime?UUID=" stringByAppendingString:uuid]]];
    request.HTTPMethod = @"POST";
    [[[NSURLSession sharedSession] dataTaskWithRequest:request] resume];
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
    NSString *actionTypes = [@"[\"skip\",\"mute\",\"poi\",\"full\"]" stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlStr = [NSString stringWithFormat:@"https://sponsor.ajay.app/api/skipSegments?videoID=%@&categories=%@&actionTypes=%@", videoID, encoded, actionTypes];
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
                            seg.votes = [item[@"votes"] integerValue];
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
%property (nonatomic, strong) YouModPillView *sbNotificationView;
%property (nonatomic, strong) NSMutableSet *sbAcceptedMutes;
%property (nonatomic, assign) BOOL sbMutedBySegment;
- (void)playbackController:(id)playbackController didActivateVideo:(id)video withPlaybackData:(id)playbackData {
    %orig;
    if (!IS_ENABLED(SBEnabled) || self.isPlayingAd) return;
    if ([self.parentViewController isKindOfClass:%c(YTShortsPlayerViewController)]) return;

    self.sbSkippedSegments = [NSMutableSet set];
    self.sbAcceptedMutes = [NSMutableSet set];
    self.sbSegments = nil;
    // Never carry a segment mute into the next video.
    if (self.sbMutedBySegment) {
        self.sbMutedBySegment = NO;
        [self.activeVideo setMuted:NO];
    }

    [self.sbNotificationView dismiss];

    NSString *videoID = [self currentVideoID];
    if ([self.sbLastVideoID isEqualToString:videoID] && self.sbSegments.count > 0) return;
    self.sbLastVideoID = videoID;

    // Skip fetching and clear markers while disabled via the menu toggle or a whitelisted channel.
    if (!sbActiveForVideo(self)) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SBSegmentsDidLoad"
                                                            object:self
                                                          userInfo:@{@"segments": @[]}];
        return;
    }

    // Clear the previous video's markers right away; the fetch below repopulates them.
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SBSegmentsDidLoad"
                                                        object:self
                                                      userInfo:@{@"segments": @[]}];

    __weak typeof(self) weakSelf = self;
    [SBRequest fetchSegmentsForVideoID:videoID completion:^(NSArray<SBSegment *> *segments) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        // Drop the result if the player moved on to another video while this request was in flight.
        if (![[strongSelf currentVideoID] isEqualToString:videoID]) return;
        strongSelf.sbSegments = segments;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SBSegmentsDidLoad"
                                                            object:strongSelf
                                                          userInfo:@{@"segments": segments ?: @[]}];

        [strongSelf sbShowHighlightBannerIfNeeded:segments];
        [strongSelf sbShowFullVideoLabelIfNeeded:segments];
    }];
}
- (void)singleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    [self sbCheckSegmentsAtCurrentTime];
}
// Time-change hook for YouTube versions that use the renamed selector.
- (void)potentiallyMutatedSingleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    [self sbCheckSegmentsAtCurrentTime];
}
// Evaluates the loaded segments at the current playback time and performs the configured
// action for the first match; shared by both time-change hooks.
%new
- (void)sbCheckSegmentsAtCurrentTime {
    if (!sbActiveForVideo(self) || self.isPlayingAd) {
        // SponsorBlock switched off (or an ad started) mid-mute: restore audio.
        if (self.sbMutedBySegment) {
            self.sbMutedBySegment = NO;
            [self.activeVideo setMuted:NO];
        }
        return;
    }
    if ([self.parentViewController isKindOfClass:%c(YTShortsPlayerViewController)]) return;

    CGFloat currentTime = [self currentVideoMediaTime];
    float minDuration = FLOAT_FOR_KEY(SBMinDuration);

    [self sbUpdateMuteAtTime:currentTime];

    for (SBSegment *segment in self.sbSegments) {
        SBSegmentAction action = [segment configuredAction];
        if (action == SBSegmentActionDisable || action == SBSegmentActionDisplay) continue;
        if ([segment.actionType isEqualToString:@"mute"] || [segment.actionType isEqualToString:@"full"]) continue;

        BOOL isPoi = [segment.category isEqualToString:@"poi_highlight"];
        // "Always auto-skip" ignores the once-per-segment set, so re-entering a segment skips again.
        BOOL repeatSkip = (action == SBSegmentActionAlwaysSkip);

        if (isPoi) {
            if (action == SBSegmentActionSkipTo || repeatSkip) {
                NSString *segID = segment.UUID;
                if ((repeatSkip || ![self.sbSkippedSegments containsObject:segID]) && currentTime < segment.startTime) {
                    if (!repeatSkip) [self.sbSkippedSegments addObject:segID];
                    [self sbSkipToHighlight];
                    break;
                }
            }
            continue;
        }

        if (action == SBSegmentActionSkipTo) continue;

        float duration = segment.endTime - segment.startTime;
        if (minDuration > 0 && duration < minDuration) continue;

        if (currentTime >= segment.startTime && currentTime < segment.endTime - SBSegmentEndGuardSeconds) {
            NSString *segID = segment.UUID;
            if (!repeatSkip && [self.sbSkippedSegments containsObject:segID]) continue;

            if (action == SBSegmentActionAutoSkip || repeatSkip) {
                [self sbPerformSkip:segment];
            } else if (action == SBSegmentActionAsk) {
                [self sbShowAskNotification:segment];
            }
            break;
        }
    }
}
%new
- (void)sbUpdateMuteAtTime:(CGFloat)currentTime {
    SBSegment *muting = nil;
    for (SBSegment *segment in self.sbSegments) {
        if (![segment.actionType isEqualToString:@"mute"]) continue;
        if (currentTime < segment.startTime || currentTime >= segment.endTime) continue;
        SBSegmentAction action = [segment configuredAction];
        if (action == SBSegmentActionAutoSkip || action == SBSegmentActionAlwaysSkip || [self.sbAcceptedMutes containsObject:segment.UUID]) {
            muting = segment;
            break;
        }
        if (action == SBSegmentActionAsk && ![self.sbSkippedSegments containsObject:segment.UUID]) {
            [self sbShowAskNotification:segment];
        }
    }

    YTSingleVideoController *video = self.activeVideo;
    if (muting && !self.sbMutedBySegment && ![video isMuted]) {
        self.sbMutedBySegment = YES;
        [video setMuted:YES];
        sbSendViewedSegment(muting);
    } else if (!muting && self.sbMutedBySegment) {
        self.sbMutedBySegment = NO;
        [video setMuted:NO];
    }
}
%new
- (void)sbShowFullVideoLabelIfNeeded:(NSArray<SBSegment *> *)segments {
    if (!IS_ENABLED(SBShowFullVideoLabel)) return;
    if (!sbActiveForVideo(self) || self.isPlayingAd) return;
    for (SBSegment *segment in segments) {
        if (![segment.actionType isEqualToString:@"full"]) continue;
        if ([segment configuredAction] == SBSegmentActionDisable) continue;
        NSString *catName = [YouModBundle() localizedStringForKey:[NSString stringWithFormat:@"SB_CAT_%@", segment.category] value:segment.category table:nil];
        [YouModPillView showSuccessInView:sbGetNotificationParent()
                                          message:[NSString stringWithFormat:LOC(@"SB_FULL_VIDEO_LABEL"), catName]
                                         duration:SBClampedAlertDuration(SBSkipAlertDuration)];
        return;
    }
}
%new
- (void)sbPerformSkip:(SBSegment *)segment {
    // "Always auto-skip" segments stay out of the once-per-segment set so re-entry skips again.
    if ([segment configuredAction] != SBSegmentActionAlwaysSkip) [self.sbSkippedSegments addObject:segment.UUID];
    [self seekToTime:(CGFloat)segment.endTime];
    sbSendViewedSegment(segment);

    if (IS_ENABLED(SBAudioNotification)) {
        AudioServicesPlaySystemSound(SBSkipHapticSoundID);
    }

    if (IS_ENABLED(SBShowNotifications)) {
        useBackwardIconForButton = YES;
        NSBundle *bundle = YouModBundle();
        NSString *catName = [bundle localizedStringForKey:[NSString stringWithFormat:@"SB_CAT_%@", segment.category] value:segment.category table:nil];
        NSString *message = [NSString stringWithFormat:[bundle localizedStringForKey:@"SB_SKIPPED" value:@"%@ skipped" table:nil], catName];
        NSString *unskipTitle = [bundle localizedStringForKey:@"SB_UNSKIP" value:@"Unskip" table:nil];

        float alertDuration = SBClampedAlertDuration(SBUnskipAlertDuration);

        __weak typeof(self) weakSelf = self;
        // Delay the banner so the seek completes first, preventing the time-change callback from dismissing it.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SBSkipNotificationDelaySeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) return;
            UIView *parentView = sbGetNotificationParent();
            strongSelf.sbNotificationView = [YouModPillView showInView:parentView
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
    NSBundle *bundle = YouModBundle();
    NSString *catName = [bundle localizedStringForKey:[NSString stringWithFormat:@"SB_CAT_%@", segment.category] value:segment.category table:nil];
    BOOL isMute = [segment.actionType isEqualToString:@"mute"];
    NSString *message = [NSString stringWithFormat:[bundle localizedStringForKey:isMute ? @"SB_DETECTED_MUTE" : @"SB_DETECTED" value:@"%@ detected" table:nil], catName];

    float alertDuration = SBClampedAlertDuration(SBSkipAlertDuration);

    UIView *parentView = sbGetNotificationParent();
    __weak typeof(self) weakSelf = self;
    self.sbNotificationView = [YouModPillView showInView:parentView
        message:message
        buttonTitle:isMute ? LOC(@"SB_MUTE_NOW") : [bundle localizedStringForKey:@"SB_SKIP_NOW" value:@"Skip" table:nil]
        action:^{
            __strong typeof(weakSelf) ss = weakSelf;
            if (!ss) return;
            if (isMute) {
                [ss.sbAcceptedMutes addObject:segment.UUID];
                [ss sbUpdateMuteAtTime:[ss currentVideoMediaTime]];
            } else {
                [ss seekToTime:(CGFloat)segment.endTime];
                sbSendViewedSegment(segment);
            }
        }
        duration:alertDuration];
}
%new
- (void)sbShowHighlightBannerIfNeeded:(NSArray<SBSegment *> *)segments {
    if (!sbActiveForVideo(self) || self.isPlayingAd) return;
    if ([self.parentViewController isKindOfClass:%c(YTShortsPlayerViewController)]) return;

    for (SBSegment *seg in segments) {
        if ([seg.category isEqualToString:@"poi_highlight"]) {
            SBSegmentAction action = [seg configuredAction];
            CGFloat currentTime = [self currentVideoMediaTime];
            if (action == SBSegmentActionSkipTo) {
                if (currentTime < seg.startTime) {
                    [self.sbSkippedSegments addObject:seg.UUID];
                    [self sbSkipToHighlight];
                }
                break;
            } else if (action == SBSegmentActionAsk) {
                if (currentTime < seg.startTime) {
                    useBackwardIconForButton = NO;
                    NSBundle *bundle = YouModBundle();
                    NSString *message = [bundle localizedStringForKey:@"SB_JUMP_TO_HIGHLIGHT" value:@"Highlight available. Jump to the point?" table:nil];
                    NSString *skipTitle = [bundle localizedStringForKey:@"SB_SKIP_NOW" value:@"Skip" table:nil];

                    float alertDuration = SBClampedAlertDuration(SBSkipAlertDuration);

                    UIView *parentView = sbGetNotificationParent();
                    YouModPillView *pill = [YouModPillView showInView:parentView
                        message:message
                        buttonTitle:skipTitle
                        action:^{ [self sbSkipToHighlight]; }
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
                NSBundle *bundle = YouModBundle();
                NSString *message = [bundle localizedStringForKey:@"SB_JUMPED_TO_HIGHLIGHT" value:@"Jumped to highlight" table:nil];
                NSString *unskipTitle = [bundle localizedStringForKey:@"SB_UNSKIP" value:@"Unskip" table:nil];

                float alertDuration = SBClampedAlertDuration(SBUnskipAlertDuration);

                __weak typeof(self) weakSelf = self;
                YouModPillView *pill = [YouModPillView showInView:sbGetNotificationParent()
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

%ctor {
    sbSegmentCache = [NSMutableDictionary dictionary];
    %init;
    YMOverlayButtonSpec *toggle = [[YMOverlayButtonSpec alloc] init];
    toggle.identifier = @"sponsorblock.toggle";
    toggle.symbolName = @"shield";
    toggle.settingsSymbolName = @"shield";
    toggle.displayName = LOC(@"SPONSORBLOCK_BUTTON");
    toggle.sortOrder = 100;
    toggle.isVisible = ^BOOL(YTPlayerViewController *player) {
        return IS_ENABLED(SBEnabled) && YMIsOverlayButtonEnabled(@"sponsorblock.toggle");
    };
    toggle.onTap = ^(YTPlayerViewController *player, UIButton *button) {
        if (!player) return;
        [player sbShowMainMenuFromView:button];
    };
    YMRegisterOverlayButton(toggle);
}

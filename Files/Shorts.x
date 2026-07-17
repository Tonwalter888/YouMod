#import "Headers.h"

static NSBundle *YouModBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:@"YouMod" ofType:@"bundle"];
        if (tweakBundlePath)
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        else
            bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:PS_ROOT_PATH_NS(@"/Library/Application Support/%@.bundle"), @"YouMod"]];
    });
    return bundle;
}

#define LOC(x) [YouModBundle() localizedStringForKey:x value:nil table:nil]

// Audio track list
static NSArray *getAllSystemLanguageTitles() {
    NSMutableArray *titles = [NSMutableArray array];
    NSArray *allLocales = [%c(YTLanguages) languageList];
    NSMutableSet *seenLanguages = [NSMutableSet set];
    NSLocale *currentLocale = [NSLocale currentLocale];
    
    for (NSString *localeId in allLocales) {
        NSDictionary *components = [NSLocale componentsFromLocaleIdentifier:localeId];
        NSString *langCode = components[NSLocaleLanguageCode];
        
        if (langCode && ![seenLanguages containsObject:langCode]) {
            [seenLanguages addObject:langCode];
            NSString *displayName = [currentLocale localizedStringForLocaleIdentifier:langCode];
            if (displayName) [titles addObject:displayName];
        }
    }
    return [titles sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

static NSArray *getAllSystemLanguageValues() {
    NSArray *sortedTitles = getAllSystemLanguageTitles();
    NSMutableArray *sortedCodes = [NSMutableArray array];
    NSArray *allLocales = [%c(YTLanguages) languageList];
    NSLocale *currentLocale = [NSLocale currentLocale];
    
    NSMutableDictionary *titleToCodeMap = [NSMutableDictionary dictionary];
    for (NSString *localeId in allLocales) {
        NSDictionary *components = [NSLocale componentsFromLocaleIdentifier:localeId];
        NSString *langCode = components[NSLocaleLanguageCode];
        if (langCode) {
            NSString *displayName = [currentLocale localizedStringForLocaleIdentifier:langCode];
            if (displayName) titleToCodeMap[displayName] = langCode;
        }
    }
    
    for (NSString *title in sortedTitles) {
        [sortedCodes addObject:titleToCodeMap[title] ? titleToCodeMap[title] : @"en"];
    }
    return [sortedCodes copy];
}

// Enables shorts quality - works best with YTClassicVideoQuality
%hook YTHotConfig
- (BOOL)enableOmitAdvancedMenuInShortsVideoQualityPicker { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
- (BOOL)enableShortsVideoQualityPicker { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
- (BOOL)iosEnableImmersiveLivePlayerVideoQuality { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
- (BOOL)iosEnableShortsPlayerVideoQuality { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
- (BOOL)iosEnableShortsPlayerVideoQualityRestartVideo { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
- (BOOL)iosEnableSimplerTitleInShortsVideoQualityPicker { return IS_ENABLED(EnablesShortsQuality) ? YES : %orig; }
%end

// Always show Shorts seekbar
%hook YTShortsPlayerViewController
- (BOOL)shouldAlwaysEnablePlayerBar { return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; }
- (BOOL)shouldEnablePlayerBarOnlyOnPause { return IS_ENABLED(ShowShortsSeekbar) ? NO : %orig; }
%end

%hook YTReelPlayerViewController
- (BOOL)shouldAlwaysEnablePlayerBar { return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; }
- (BOOL)shouldEnablePlayerBarOnlyOnPause { return IS_ENABLED(ShowShortsSeekbar) ? NO : %orig; }
%end

%hook YTReelPlayerViewControllerSub
- (BOOL)shouldAlwaysEnablePlayerBar { return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; }
- (BOOL)shouldEnablePlayerBarOnlyOnPause { return IS_ENABLED(ShowShortsSeekbar) ? NO : %orig; }
%end

%hook YTColdConfig
- (BOOL)iosEnableVideoPlayerScrubber { return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; }
- (BOOL)mobileShortsTablnlinedExpandWatchOnDismiss { return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; }
%end

%hook YTHotConfig
- (BOOL)enablePlayerBarForVerticalVideoWhenControlsHiddenInFullscreen { return IS_ENABLED(ShowShortsSeekbar) ? YES : %orig; }
%end

static void YouModMakeAShortsAction(YTReelPlayerViewController *self, YTSingleVideoController *video, YTSingleVideoTime *time) {
    if (INTFORVAL(ShortsActionIndex) == 0) return;

    if (floor(time.time) >= floor(video.totalMediaTime)) {
        if (INTFORVAL(ShortsActionIndex) == 1) {
            [self reelContentViewRequestsAdvanceToNextVideo:nil];
        } else if (INTFORVAL(ShortsActionIndex) == 2) {
            [self reelContentViewRequestsPlayPauseToggle:nil];
        }
    }
}

%hook YTReelPlayerViewController
- (void)singleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;
    YouModMakeAShortsAction(self, video, time);
}
- (void)loadPlayerBar {
    %orig;
    YTPlayerViewController *main = self.player;
    if (INTFORVAL(CaptionTrack) != 0) [main performSelector:@selector(YouModAutoCaptions) withObject:nil afterDelay:0.5];
    if (INTFORVAL(AutoSpeedIndex) != 0) [main performSelector:@selector(YouModSetAutoSpeed) withObject:nil afterDelay:0.5];
    if (INTFORVAL(AudioTrack) != 0) [self performSelector:@selector(YouModAutoAudioTrack:) withObject:main afterDelay:0.5];
}
%new
- (void)YouModAutoAudioTrack:(YTPlayerViewController *)pv {
    NSInteger selectedIndex = INTFORVAL(AudioTrackLangIndex);
    NSArray *langCodes = getAllSystemLanguageValues();
    NSString *userTargetLang = langCodes[selectedIndex];
    id switchcon = self.audioTrackController;
    NSArray *availableTracks = [switchcon valueForKey:@"_availableAudioTracks"];
    if (!availableTracks || availableTracks.count == 0) return;
    YTIAudioTrack *matchedTrack = nil;

    if (INTFORVAL(AudioTrack) == 1) {
        // Loop for all tracks
        for (YTIAudioTrack *track in availableTracks) {
            if ([track.id_p hasSuffix:@".4"]) {
                matchedTrack = track;
                break;
            }
        }
    } else if (INTFORVAL(AudioTrack) == 2) {
        // Loop for all tracks
        for (YTIAudioTrack *track in availableTracks) {
            if ([track.id_p hasPrefix:userTargetLang]) {
                matchedTrack = track;
                break;
            }
        }

        // Check if it's dubbed
        if (matchedTrack && [matchedTrack isAutoDubbed] && IS_ENABLED(NoDubbedAudioTrack)) {
            matchedTrack = nil;
            return;
        }
    }

    // If found, change to it
    if (matchedTrack) {
        [pv setAudioTrack:matchedTrack source:0];
    } else if (!matchedTrack && IS_ENABLED(NoDubbedAudioTrack)) {
        for (YTIAudioTrack *track in availableTracks) {
            if ([track.id_p hasSuffix:@".4"]) {
                [pv setAudioTrack:track source:0];
                break;
            }
        }
    }
}
%end

extern void YouModConfigureDownloadButton(_ASDisplayView *view);

// _ASDisplayView filters
%hook _ASDisplayView
- (void)didMoveToWindow {
    %orig;
    YouModConfigureDownloadButton(self);
    NSDictionary *elements = @{
        @"product_sticker.main_target": @(IS_ENABLED(HideShortsProducts)),
        @"product_sticker.secondary_target": @(IS_ENABLED(HideShortsProducts)),
        @"id.elements.components.suggested_action": @(IS_ENABLED(HideShortsRecbar))
    };
    if ([elements[self.accessibilityIdentifier] boolValue]) [self removeFromSuperview]; 
}
%end

static BOOL isShortsOnlyOn = YES;

%hook YTReelWatchPlaybackOverlayView
%property (nonatomic, retain) UIPinchGestureRecognizer *YouModFullscreenGesture;
- (void)layoutSubviews {
    %orig;
    if (!IS_ENABLED(FullScreenShorts)) return;
    if (!self.YouModFullscreenGesture) {
        self.YouModFullscreenGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(YouModFullscrrenGestureHandler:)];
        self.YouModFullscreenGesture.delegate = (id<UIGestureRecognizerDelegate>)self;
        
        [self.superview addGestureRecognizer:self.YouModFullscreenGesture];
    }
}
%new
- (void)YouModFullscrrenGestureHandler:(UIPinchGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan || isShortsOnlyOn) return;
    id appconmain = [self valueForKey:@"_pivotBarProvider"];
    if ([appconmain isKindOfClass:%c(YTAppViewControllerImpl)]) {
        YTAppViewControllerImpl *appcon = (YTAppViewControllerImpl *)appconmain;
        BOOL isTabBarHidden = [appcon isPivotBarHidden];
        if (gesture.scale > 1.0) {
            if (!isTabBarHidden) {
                [appcon hidePivotBar];
                [UIView animateWithDuration:0.3 animations:^{
                    self.alpha = 0;
                }];
            }
        } else if (gesture.scale < 1.0) {
            if (isTabBarHidden) {
                [appcon showPivotBar];
                [UIView animateWithDuration:0.3 animations:^{
                    self.alpha = 1;
                }];
            }
        }
    } else {
        YTAppViewController *appcon = (YTAppViewController *)appconmain;
        BOOL isTabBarHidden = [appcon isPivotBarHidden];
        if (gesture.scale > 1.0) {
            if (!isTabBarHidden) {
                [appcon hidePivotBar];
                [UIView animateWithDuration:0.3 animations:^{
                    self.alpha = 0;
                }];
            }
        } else if (gesture.scale < 1.0) {
            if (isTabBarHidden) {
                [appcon showPivotBar];
                [UIView animateWithDuration:0.3 animations:^{
                    self.alpha = 1;
                }];
            }
        }
    }
}
%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == self.YouModFullscreenGesture) {
        return YES;
    }
    return NO;
}
%end

%hook YTReelContentView
- (void)setPlaybackView:(id)arg1 {
    %orig;
    if (!IS_ENABLED(ShortsOnly)) return;
    self.playbackOverlay.alpha = 0;
    UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(YouModTurnOffShortsOnly:)];
    longPressGesture.numberOfTouchesRequired = 2;
    longPressGesture.minimumPressDuration = 0.5;

    [self addGestureRecognizer:longPressGesture];
}
%new
- (void)YouModTurnOffShortsOnly:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    isShortsOnlyOn = NO;
    UIView *parent = sbGetNotificationParent();
    [SBSkipNotificationView showSuccessInView:parent message:LOC(@"SHORTS_ONLY_DISABLED") duration:3.0];

    YTReelContainerViewController *reelcon = [self valueForKey:@"_parentResponder"];
    YTAppReelWatchRootViewController *watchroot = [reelcon valueForKey:@"_delegate"];
    id appconmain = [watchroot valueForKey:@"_pivotBarProvider"];
    if ([appconmain isKindOfClass:%c(YTAppViewControllerImpl)]) {
        YTAppViewControllerImpl *appcon = (YTAppViewControllerImpl *)appconmain;
        [appcon showPivotBar];
        [UIView animateWithDuration:0.3 animations:^{
            self.playbackOverlay.alpha = 1;
        }];
    } else {
        YTAppViewController *appcon = (YTAppViewController *)appconmain;
        [appcon showPivotBar];
        [UIView animateWithDuration:0.3 animations:^{
            self.playbackOverlay.alpha = 1;
        }];
    }
}
%end
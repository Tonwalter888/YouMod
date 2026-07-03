#import "Headers.h"
#import <objc/runtime.h>

#define TweakName @"YouMod"

static NSBundle *YouModBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:TweakName ofType:@"bundle"];
        if (tweakBundlePath)
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        else
            bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:PS_ROOT_PATH_NS(@"/Library/Application Support/%@.bundle"), TweakName]];
    });
    return bundle;
}

#define LOC(x) [YouModBundle() localizedStringForKey:x value:nil table:nil]

// Tab icons
%hook YTAppPivotBarItemStyle
- (UIImage *)pivotBarItemIconImageWithIconType:(int)type color:(UIColor *)color useNewIcons:(BOOL)isNew selected:(BOOL)isSelected {
    if (type == 1 || type == 2 || type == 3 || type == 4 || type == 5 || type == 6 || type == 7 || type == 8 || type == 9 || type == 10 || type == 11 || type == 12 || type == 13 || type == 14 || type == 15) {
        NSString *imageName;
        if (type == 1) imageName = isSelected ? @"icons/history_selected" : @"icons/history";
        else if (type == 2) imageName = isSelected ? @"icons/gaming_selected" : @"icons/gaming";
        else if (type == 3) imageName = isSelected ? @"icons/sports_selected" : @"icons/sports";
        else if (type == 4) imageName = isSelected ? @"icons/noti_selected" : @"icons/noti";
        else if (type == 5) imageName = isSelected ? @"icons/news_selected" : @"icons/news";
        else if (type == 6) imageName = isSelected ? @"icons/music_selected" : @"icons/music";
        else if (type == 7) imageName = isSelected ? @"icons/watchlater_selected" : @"icons/watchlater";
        else if (type == 8) imageName = isSelected ? @"icons/playlist_selected" : @"icons/playlist";
        else if (type == 9) imageName = isSelected ? @"icons/like_selected" : @"icons/like";
        else if (type == 10) imageName = isSelected ? @"icons/live_selected" : @"icons/live";
        else if (type == 11) imageName = isSelected ? @"icons/post_selected" : @"icons/post";
        else if (type == 12) imageName = isSelected ? @"icons/video_selected" : @"icons/video";
        else if (type == 13) imageName = isSelected ? @"icons/movie_selected" : @"icons/movie";
        else if (type == 14) imageName = isSelected ? @"icons/course_selected" : @"icons/course";
        else if (type == 15) imageName = isSelected ? @"icons/minigame_selected" : @"icons/minigame";
        YTAssetLoader *al = [[%c(YTAssetLoader) alloc] initWithBundle:YouModBundle()];
        return [al imageNamed:imageName];
    }
    return %orig;
}
%end

static NSString *ymPivotIDForTabID(NSString *tabID) {
    if ([tabID isEqualToString:@"home"]) return @"FEwhat_to_watch";
    if ([tabID isEqualToString:@"shorts"]) return @"FEshorts";
    if ([tabID isEqualToString:@"create"]) return @"FEuploads";
    if ([tabID isEqualToString:@"subscriptions"]) return @"FEsubscriptions";
    if ([tabID isEqualToString:@"library"]) return @"FElibrary";
    if ([tabID isEqualToString:@"history"]) return [%c(YTIBrowseRequest) browseIDForHistory];
    if ([tabID isEqualToString:@"gaming"]) return [%c(YTIBrowseRequest) browseIDForGamingDestination];
    if ([tabID isEqualToString:@"sports"]) return [%c(YTIBrowseRequest) browseIDForSportsDestination];
    if ([tabID isEqualToString:@"notifications"]) return [%c(YTIBrowseRequest) browseIDForNotificationsInbox];
    if ([tabID isEqualToString:@"news"]) return @"UCYfdidRxbB8Qhf0Nx7ioOYw"; // FEnews_destination
    if ([tabID isEqualToString:@"music"]) return @"UC-9-kyTW8ZkZNDHQJ6FgpwQ";
    if ([tabID isEqualToString:@"watchlater"]) return @"VLWL";
    if ([tabID isEqualToString:@"playlist"]) return @"FEplaylist_aggregation";
    if ([tabID isEqualToString:@"like"]) return @"VLLL";
    if ([tabID isEqualToString:@"live"]) return @"UC4R8DWoMoI7CAwX8_LjQHig";
    if ([tabID isEqualToString:@"post"]) return @"FEpost_home";
    if ([tabID isEqualToString:@"video"]) return @"UC3qapbGAd2-S75NkBY3XWww";
    if ([tabID isEqualToString:@"movie"]) return @"FEstorefront";
    if ([tabID isEqualToString:@"course"]) return @"FEcourses";
    if ([tabID isEqualToString:@"minigame"]) return @"FEmini_app_destination";
    return nil;
}

static NSInteger ymIconTypeForTabID(NSString *tabID) {
    if ([tabID isEqualToString:@"history"]) return 1;
    if ([tabID isEqualToString:@"gaming"]) return 2;
    if ([tabID isEqualToString:@"sports"]) return 3;
    if ([tabID isEqualToString:@"notifications"]) return 4;
    if ([tabID isEqualToString:@"news"]) return 5;
    if ([tabID isEqualToString:@"music"]) return 6;
    if ([tabID isEqualToString:@"watchlater"]) return 7;
    if ([tabID isEqualToString:@"playlist"]) return 8;
    if ([tabID isEqualToString:@"like"]) return 9;
    if ([tabID isEqualToString:@"live"]) return 10;
    if ([tabID isEqualToString:@"post"]) return 11;
    if ([tabID isEqualToString:@"video"]) return 12;
    if ([tabID isEqualToString:@"movie"]) return 13;
    if ([tabID isEqualToString:@"course"]) return 14;
    if ([tabID isEqualToString:@"minigame"]) return 15;
    return 0;
}

static NSString *ymTitleForTabID(NSString *tabID) {
    if ([tabID isEqualToString:@"history"]) return LOC(@"HISTORY_TAB");
    if ([tabID isEqualToString:@"gaming"]) return LOC(@"GAMING_TAB");
    if ([tabID isEqualToString:@"sports"]) return LOC(@"SPORTS_TAB");
    if ([tabID isEqualToString:@"notifications"]) return LOC(@"NOTI_TAB");
    if ([tabID isEqualToString:@"news"]) return LOC(@"NEWS_TAB");
    if ([tabID isEqualToString:@"music"]) return LOC(@"MUSIC_TAB");
    if ([tabID isEqualToString:@"watchlater"]) return LOC(@"WATCH_LATER_TAB");
    if ([tabID isEqualToString:@"playlist"]) return LOC(@"PLAYLIST_TAB");
    if ([tabID isEqualToString:@"like"]) return LOC(@"LIKE_TAB");
    if ([tabID isEqualToString:@"live"]) return LOC(@"LIVE_TAB");
    if ([tabID isEqualToString:@"post"]) return LOC(@"POST_TAB");
    if ([tabID isEqualToString:@"video"]) return LOC(@"VIDEO_TAB");
    if ([tabID isEqualToString:@"movie"]) return LOC(@"MOVIE_TAB");
    if ([tabID isEqualToString:@"course"]) return LOC(@"COURSE_TAB");
    if ([tabID isEqualToString:@"minigame"]) return LOC(@"MINIGAME_TAB");
    return nil;
}

%hook YTPivotBarView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    NSArray *savedOrder = [[NSUserDefaults standardUserDefaults] arrayForKey:TabOrder];
    if (savedOrder.count > 0) {
        NSMutableArray <YTIPivotBarSupportedRenderers *> *items = [renderer itemsArray];

        // Build lookup: pivotIdentifier -> renderer item
        NSMutableDictionary<NSString *, YTIPivotBarSupportedRenderers *> *lookup = [NSMutableDictionary dictionary];
        for (YTIPivotBarSupportedRenderers *item in items) {
            NSString *pID = [[item pivotBarItemRenderer] pivotIdentifier];
            NSString *pID2 = [[item pivotBarIconOnlyItemRenderer] pivotIdentifier];
            if (pID) lookup[pID] = item;
            if (pID2) lookup[pID2] = item;
        }

        // Build ordered array from saved data
        NSMutableArray *ordered = [NSMutableArray array];
        for (NSDictionary *entry in savedOrder) {
            NSString *tabID = entry[@"id"];
            BOOL enabled = [entry[@"enabled"] boolValue];
            if (!enabled) continue;

            NSString *pivotID = ymPivotIDForTabID(tabID);
            if (!pivotID) continue;

            YTIPivotBarSupportedRenderers *existing = lookup[pivotID];
            if (existing) {
                [ordered addObject:existing];
            } else {
                // Custom tab not in YouTube's default items — create it
                NSInteger iconType = ymIconTypeForTabID(tabID);
                NSString *title = ymTitleForTabID(tabID);
                if (iconType > 0 && title) {
                    YTIPivotBarSupportedRenderers *newTab = [%c(YTIPivotBarRenderer) pivotSupportedRenderersWithBrowseId:pivotID title:title iconType:iconType];
                    if (newTab) [ordered addObject:newTab];
                }
            }
        }
        // Replace items with ordered set
        [items removeAllObjects];
        [items addObjectsFromArray:ordered];
    }
    %orig(renderer);
}
%end

// Hide Tab Bar Indicators
%hook YTPivotBarIndicatorView
- (void)setFillColor:(UIColor *)arg1 {
    UIColor *temp = [UIColor clearColor];
    IS_ENABLED(HideTabIndi) ? %orig(temp) : %orig;
}
- (void)setBorderColor:(UIColor *)arg1 {
    UIColor *temp = [UIColor clearColor];
    IS_ENABLED(HideTabIndi) ? %orig(temp) : %orig;
}
%end

static BOOL isGestureRegistered = NO;
// Hide Tab Labels + long-press on the first tab to open Manage Tabs
%hook YTPivotBarItemView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    %orig;
    if (IS_ENABLED(HideTabLabels)) {
        [self.navigationButton setTitle:@"" forState:UIControlStateNormal];
        [self.navigationButton setSizeWithPaddingAndInsets:NO];
    }
    // Attach long-press gesture once per view; the action handler checks the
    // current pivotIdentifier at fire time, so cell reuse / pivot bar refresh
    // can rebind the same view to a different tab safely.
    static const void *kYMLongPressKey = &kYMLongPressKey;
    if (!objc_getAssociatedObject(self, kYMLongPressKey) && !isGestureRegistered) {
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]
            initWithTarget:self action:@selector(ymOpenManageTabs:)];
        longPress.minimumPressDuration = 0.4;
        [self addGestureRecognizer:longPress];
        objc_setAssociatedObject(self, kYMLongPressKey, longPress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        isGestureRegistered = YES;
    }
}

%new
- (void)ymOpenManageTabs:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    YMPresentTabOrderModally(nil);
}
%end

// Startup Tab
BOOL isTabSelected = NO;
%hook YTPivotBarViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    sbUpdateOverlayInsetForPivotBar();
    if (!isTabSelected) {
        // Build pivot identifiers from enabled tabs (skip Create — matches Settings.x segment logic)
        NSMutableArray *pivotIdentifiers = [NSMutableArray array];
        NSArray *savedOrder = [[NSUserDefaults standardUserDefaults] arrayForKey:TabOrder];
        if (savedOrder.count > 0) {
            for (NSDictionary *entry in savedOrder) {
                if (![entry[@"enabled"] boolValue]) continue;
                NSString *tabID = entry[@"id"];
                if ([tabID isEqualToString:@"create"]) continue;
                NSString *pivot = ymPivotIDForTabID(tabID);
                if (pivot) [pivotIdentifiers addObject:pivot];
            }
        }
        if (pivotIdentifiers.count == 0) {
            pivotIdentifiers = [@[@"FEwhat_to_watch", @"FEshorts", @"FEsubscriptions", @"FElibrary"] mutableCopy];
        }

        NSInteger tabIndex = INTFORVAL(DefaultTab);
        if (tabIndex < 0) tabIndex = 0;
        if (tabIndex >= (NSInteger)pivotIdentifiers.count) tabIndex = MAX(0, (NSInteger)pivotIdentifiers.count - 1);
        [self selectItemWithPivotIdentifier:pivotIdentifiers[tabIndex]];
        isTabSelected = YES;
    }
}
// Translucent tab bar
- (BOOL)isFrostedPivotBarPermitted {
    if (INTFORVAL(UseFrostedTabBar) == 1) {
        return YES;
    } else if (INTFORVAL(UseFrostedTabBar) == 2) {
        return NO;
    }
    return %orig;
}
%end

// Recompute SB overlay safe-area inset whenever YouTube shows or hides the pivot bar
// (e.g. entering/exiting fullscreen player). This keeps the SponsorBlock skip pill
// and download progress pill anchored above the tabbar when visible, and at the
// device safe-area bottom when the tabbar is hidden.
%hook YTAppViewController
- (void)hidePivotBar {
    %orig;
    sbUpdateOverlayInsetForPivotBar();
}
- (void)showPivotBar {
    %orig;
    sbUpdateOverlayInsetForPivotBar();
}
%end

%hook YTAppViewControllerImpl
- (void)hidePivotBar {
    %orig;
    sbUpdateOverlayInsetForPivotBar();
}
- (void)showPivotBar {
    %orig;
    sbUpdateOverlayInsetForPivotBar();
}
%end

#import "Headers.h"

static NSString * const kYMLibraryPivotIdentifier = @"YouModDownloadLibrary";

// Tab icons
%hook YTAppPivotBarItemStyle
- (UIImage *)pivotBarItemIconImageWithIconType:(int)type color:(UIColor *)color useNewIcons:(BOOL)isNew selected:(BOOL)isSelected {
    if (type >= 1 && type <= 18) {
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
        else if (type == 16) imageName = isSelected ? @"icons/fashion_selected" : @"icons/fashion";
        else if (type == 17) imageName = isSelected ? @"icons/learning_selected" : @"icons/learning";
        else if (type == 18) imageName = isSelected ? @"icons/download_selected" : @"icons/download";
        YTAssetLoader *al = [[%c(YTAssetLoader) alloc] initWithBundle:YouModBundle()];
        return [al imageNamed:imageName];
    }
    return %orig;
}
%end

static NSString *ymPivotIDForTabID(NSString *tabID) {
    if ([tabID isEqualToString:@"home"]) return [%c(YTIBrowseRequest) browseIDForWhatToWatch];
    else if ([tabID isEqualToString:@"shorts"]) return @"FEshorts";
    else if ([tabID isEqualToString:@"create"]) return @"FEuploads";
    else if ([tabID isEqualToString:@"subscriptions"]) return [%c(YTIBrowseRequest) browseIDForSubscriptionsTab];
    else if ([tabID isEqualToString:@"library"]) return [%c(YTIBrowseRequest) browseIDForLibraryTab];
    else if ([tabID isEqualToString:@"history"]) return [%c(YTIBrowseRequest) browseIDForHistory];
    else if ([tabID isEqualToString:@"gaming"]) return [%c(YTIBrowseRequest) browseIDForGamingDestination];
    else if ([tabID isEqualToString:@"sports"]) return [%c(YTIBrowseRequest) browseIDForSportsDestination];
    else if ([tabID isEqualToString:@"notifications"]) return [%c(YTIBrowseRequest) browseIDForNotificationsInbox];
    else if ([tabID isEqualToString:@"news"]) return @"UCYfdidRxbB8Qhf0Nx7ioOYw"; // FEnews_destination
    else if ([tabID isEqualToString:@"music"]) return @"UC-9-kyTW8ZkZNDHQJ6FgpwQ";
    else if ([tabID isEqualToString:@"watchlater"]) return @"VLWL";
    else if ([tabID isEqualToString:@"playlist"]) return @"FEplaylist_aggregation";
    else if ([tabID isEqualToString:@"like"]) return @"VLLL";
    else if ([tabID isEqualToString:@"live"]) return @"UC4R8DWoMoI7CAwX8_LjQHig";
    else if ([tabID isEqualToString:@"post"]) return @"FEpost_home";
    else if ([tabID isEqualToString:@"video"]) return @"UC3qapbGAd2-S75NkBY3XWww";
    else if ([tabID isEqualToString:@"movie"]) return @"FEstorefront";
    else if ([tabID isEqualToString:@"course"]) return @"FEcourses";
    else if ([tabID isEqualToString:@"minigame"]) return @"FEmini_app_destination";
    else if ([tabID isEqualToString:@"fashion"]) return @"UCrpQ4p1Ql_hG8rKXIKM1MOQ";
    else if ([tabID isEqualToString:@"learning"]) return [%c(YTIBrowseRequest) browseIDForLearningDestination];
    return nil;
}

static NSInteger ymIconTypeForTabID(NSString *tabID) {
    if ([tabID isEqualToString:@"history"]) return 1;
    else if ([tabID isEqualToString:@"gaming"]) return 2;
    else if ([tabID isEqualToString:@"sports"]) return 3;
    else if ([tabID isEqualToString:@"notifications"]) return 4;
    else if ([tabID isEqualToString:@"news"]) return 5;
    else if ([tabID isEqualToString:@"music"]) return 6;
    else if ([tabID isEqualToString:@"watchlater"]) return 7;
    else if ([tabID isEqualToString:@"playlist"]) return 8;
    else if ([tabID isEqualToString:@"like"]) return 9;
    else if ([tabID isEqualToString:@"live"]) return 10;
    else if ([tabID isEqualToString:@"post"]) return 11;
    else if ([tabID isEqualToString:@"video"]) return 12;
    else if ([tabID isEqualToString:@"movie"]) return 13;
    else if ([tabID isEqualToString:@"course"]) return 14;
    else if ([tabID isEqualToString:@"minigame"]) return 15;
    else if ([tabID isEqualToString:@"fashion"]) return 16;
    else if ([tabID isEqualToString:@"learning"]) return 17;
    return 0;
}

static NSString *ymTitleForTabID(NSString *tabID) {
    if ([tabID isEqualToString:@"history"]) return LOC(@"HISTORY_TAB");
    else if ([tabID isEqualToString:@"gaming"]) return LOC(@"GAMING_TAB");
    else if ([tabID isEqualToString:@"sports"]) return LOC(@"SPORTS_TAB");
    else if ([tabID isEqualToString:@"notifications"]) return LOC(@"NOTI_TAB");
    else if ([tabID isEqualToString:@"news"]) return LOC(@"NEWS_TAB");
    else if ([tabID isEqualToString:@"music"]) return LOC(@"MUSIC_TAB");
    else if ([tabID isEqualToString:@"watchlater"]) return LOC(@"WATCH_LATER_TAB");
    else if ([tabID isEqualToString:@"playlist"]) return LOC(@"PLAYLIST_TAB");
    else if ([tabID isEqualToString:@"like"]) return LOC(@"LIKE_TAB");
    else if ([tabID isEqualToString:@"live"]) return LOC(@"LIVE_TAB");
    else if ([tabID isEqualToString:@"post"]) return LOC(@"POST_TAB");
    else if ([tabID isEqualToString:@"video"]) return LOC(@"VIDEO_TAB");
    else if ([tabID isEqualToString:@"movie"]) return LOC(@"MOVIE_TAB");
    else if ([tabID isEqualToString:@"course"]) return LOC(@"COURSE_TAB");
    else if ([tabID isEqualToString:@"minigame"]) return LOC(@"MINIGAME_TAB");
    else if ([tabID isEqualToString:@"fashion"]) return LOC(@"FASHION_TAB");
    else if ([tabID isEqualToString:@"learning"]) return LOC(@"LEARNING_TAB");
    return nil;
}

%hook YTPivotBarView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    NSMutableArray <YTIPivotBarSupportedRenderers *> *items = [renderer itemsArray];
    NSArray *savedOrder = [[NSUserDefaults standardUserDefaults] arrayForKey:TabOrder];
    if (savedOrder.count > 0) {
        // Build lookup: pivotIdentifier -> renderer item
        NSMutableDictionary<NSString *, YTIPivotBarSupportedRenderers *> *lookup = [NSMutableDictionary dictionary];
        for (YTIPivotBarSupportedRenderers *item in items) {
            NSString *pID = [[item pivotBarItemRenderer] pivotIdentifier];
            NSString *pID2 = [[item pivotBarIconOnlyItemRenderer] pivotIdentifier];
            if (pID) lookup[pID] = item;
            else if (pID2) lookup[pID2] = item;
        }

        // Build ordered array from saved data
        NSMutableArray *ordered = [NSMutableArray array];
        for (NSDictionary *entry in savedOrder) {
            NSString *tabID = entry[@"id"];
            // The download tab is ordered here like the rest, but its on/off
            // state always comes from the Downloading settings (DownloadLibraryTab).
            BOOL isDownloadTab = [tabID isEqualToString:@"download"];
            BOOL enabled = isDownloadTab ? IS_ENABLED(DownloadLibraryTab) : [entry[@"enabled"] boolValue];
            if (!enabled) continue;

            NSString *pivotID = isDownloadTab ? kYMLibraryPivotIdentifier : ymPivotIDForTabID(tabID);
            if (!pivotID) continue;

            YTIPivotBarSupportedRenderers *existing = lookup[pivotID];
            if (existing) {
                [ordered addObject:existing];
            } else {
                // Custom tab not in YouTube's default items — create it
                NSInteger iconType = isDownloadTab ? 18 : ymIconTypeForTabID(tabID);
                NSString *title = isDownloadTab ? LOC(@"DOWNLOAD_LIBRARY_TAB") : ymTitleForTabID(tabID);
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
    if (IS_ENABLED(DownloadLibraryTab)) {
        BOOL alreadyPresent = NO;
        for (YTIPivotBarSupportedRenderers *item in items) {
            NSString *pID = [[item pivotBarItemRenderer] pivotIdentifier] ?: [[item pivotBarIconOnlyItemRenderer] pivotIdentifier];
            if ([pID isEqualToString:kYMLibraryPivotIdentifier]) { alreadyPresent = YES; break; }
        }
        if (!alreadyPresent) {
            YTIPivotBarSupportedRenderers *libraryTab = [%c(YTIPivotBarRenderer) pivotSupportedRenderersWithBrowseId:kYMLibraryPivotIdentifier title:LOC(@"DOWNLOAD_LIBRARY_TAB") iconType:18];
            if (libraryTab) [items addObject:libraryTab];
        }
    }
    %orig(renderer);
}
%end

// Hide Tab Bar Indicators
%hook YTPivotBarIndicatorView
- (void)setFillColor:(UIColor *)arg {
    if (IS_ENABLED(HideTabIndi)) arg = [UIColor clearColor];
    %orig(arg);
}
- (void)setBorderColor:(UIColor *)arg {
    if (IS_ENABLED(HideTabIndi)) arg = [UIColor clearColor];
    %orig(arg);
}
%end

static NSString *YMExtractYouTubeVideoID(NSString *urlString) {
    if (!urlString || urlString.length == 0) return nil;

    NSString *cleanString = [urlString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (cleanString.length == 11 && ![cleanString containsString:@"/"] && ![cleanString containsString:@"?"]) return cleanString;

    NSString *extractedID = nil;
    NSURL *url = [NSURL URLWithString:cleanString];

    if (url) {
        if ([url.host containsString:@"youtu.be"]) {
            NSString *path = [url.path stringByReplacingOccurrencesOfString:@"/" withString:@""];
            if (path.length >= 11) extractedID = [path substringToIndex:11];
        } else if ([url.host containsString:@"youtube.com"]) {
            if ([url.path containsString:@"/shorts/"] || [url.path containsString:@"/live/"] || [url.path containsString:@"/clip/"]) {
                NSString *lastPath = [url.path lastPathComponent];
                if ([lastPath containsString:@"?"]) lastPath = [[lastPath componentsSeparatedByString:@"?"] firstObject];
                if (lastPath.length >= 11) extractedID = [lastPath substringToIndex:11];
            } else {
                NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
                for (NSURLQueryItem *item in components.queryItems) {
                    if ([item.name isEqualToString:@"v"] && item.value.length >= 11) {
                        extractedID = [item.value substringToIndex:11];
                        break;
                    }
                }
            }
        }
    }

    if (!extractedID) {
        NSError *error = nil;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(?:v=|\\/(?:shorts|live|clip)\\/|youtu\\.be\\/)([a-zA-Z0-9_-]{11})"
                                                                                options:NSRegularExpressionCaseInsensitive
                                                                                  error:&error];
        NSTextCheckingResult *match = [regex firstMatchInString:cleanString options:0 range:NSMakeRange(0, cleanString.length)];
        if (match && match.numberOfRanges > 1) extractedID = [cleanString substringWithRange:[match rangeAtIndex:1]];
    }

    return (extractedID && extractedID.length == 11) ? extractedID : nil;
}

static NSString *gLastOpenedVideoID = nil;

static void YMOpenLinkFromClipboard(UIViewController *presentingVC, BOOL isRuntime) {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    
    if (![pasteboard hasStrings]) return;

    NSString *rawString = [pasteboard.string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *videoID = YMExtractYouTubeVideoID(rawString);

    if (!videoID || videoID.length == 0) return;
    else if (gLastOpenedVideoID && [gLastOpenedVideoID isEqualToString:videoID] && IS_ENABLED(AutoOpenLink) && !isRuntime) return;

    NSString *schemeURLString = [NSString stringWithFormat:@"youtube://%@", videoID];
    NSURL *targetURL = [NSURL URLWithString:schemeURLString];

    if ([[UIApplication sharedApplication] canOpenURL:targetURL]) {
        gLastOpenedVideoID = [videoID copy];
        [[UIApplication sharedApplication] openURL:targetURL options:@{} completionHandler:nil];
    }
}

static BOOL isGestureRegistered = NO;
// Hide Tab Labels + long-press on the first tab to open Manage Tabs
%hook YTPivotBarItemView
- (void)setRenderer:(YTIPivotBarItemRenderer *)renderer {
    if (IS_ENABLED(HideTabLabels)) {
        renderer.title = nil;
        [self.navigationButton setSizeWithPaddingAndInsets:NO];
    }
    %orig;
    if (!isGestureRegistered) {
        UIContextMenuInteraction *interaction = [[UIContextMenuInteraction alloc] initWithDelegate:(id<UIContextMenuInteractionDelegate>)self];
        [self addInteraction:interaction];
        isGestureRegistered = YES;
    }
}
%new
- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location {
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu * _Nullable(NSArray<UIMenuElement *> * _Nonnull suggestedActions) {
        UIAction *whitelistAction = nil;
        if (IS_ENABLED(SBEnabled)) {
            whitelistAction = [UIAction actionWithTitle:LOC(@"SB_WHITELIST_MANAGE")
                                                 image:[UIImage systemImageNamed:@"shield"]
                                            identifier:nil
                                               handler:^(__kindof UIAction * _Nonnull action) {
                YMSBPresentWhitelistManager();
            }];
        }
        UIAction *tabBarAction = [UIAction actionWithTitle:LOC(@"MANAGE_TABS")
                                                     image:[UIImage systemImageNamed:@"dock.rectangle"]
                                                identifier:nil
                                                   handler:^(__kindof UIAction * _Nonnull action) {
            YMPresentTabOrderModally(nil);
        }];
        UIAction *openLinkAction = [UIAction actionWithTitle:LOC(@"OPEN_LINK")
                                               image:[UIImage systemImageNamed:@"link"]
                                          identifier:nil
                                             handler:^(__kindof UIAction * _Nonnull action) {
            UIViewController *topVC = YouModTopViewController(nil);
            YMOpenLinkFromClipboard(topVC, YES);
        }];
        UIAction *sleepTimerAction = nil;
        NSInteger sleepEntry = INTFORVAL(SleepTimerEntry);
        if (sleepEntry == 1 || sleepEntry == 3) { // tab bar / both
            sleepTimerAction = [UIAction actionWithTitle:LOC(@"SLEEP_TIMER")
                                                   image:[UIImage systemImageNamed:@"moon"]
                                              identifier:nil
                                                 handler:^(__kindof UIAction * _Nonnull action) {
                YMSleepTimerPresentPicker(self);
            }];
        }
        NSMutableArray<UIMenuElement *> *menuChildren = [NSMutableArray array];
        if (whitelistAction) [menuChildren addObject:whitelistAction];
        if (sleepTimerAction) [menuChildren addObject:sleepTimerAction];
        [menuChildren addObjectsFromArray:@[tabBarAction, openLinkAction]];
        return [UIMenu menuWithTitle:@"" children:menuChildren];
    }];
}
%end

// Startup Tab
static BOOL isTabSelected = NO;
%hook YTPivotBarViewController
- (void)selectItemWithPivotBarItem:(id)item {
    if ([[item pivotIdentifier] isEqualToString:kYMLibraryPivotIdentifier]) {
        [self cacheCurrentViewControllers];
        [self updateViewsWithSelectedPivotIdentifier:kYMLibraryPivotIdentifier];
        UIViewController *libraryVC = YouModDownloadLibraryViewController(self);
        [[self delegate] didTapPivotBarItem:item withViewControllers:@[libraryVC] animated:YES];
        return;
    }
    %orig(item);
}
// Startup-tab support: the Download tab has no native browse destination, so when the
// saved Default Tab resolves to it, present the download library exactly like a real
// tap instead of letting YouTube resolve a pivot identifier it doesn't know.
- (void)selectItemWithPivotIdentifier:(id)pivotIdentifier {
    if ([pivotIdentifier isKindOfClass:[NSString class]] && [(NSString *)pivotIdentifier isEqualToString:kYMLibraryPivotIdentifier]) {
        [self cacheCurrentViewControllers];
        [self updateViewsWithSelectedPivotIdentifier:kYMLibraryPivotIdentifier];
        UIViewController *libraryVC = YouModDownloadLibraryViewController(self);
        YTIPivotBarSupportedRenderers *item = [%c(YTIPivotBarRenderer) pivotSupportedRenderersWithBrowseId:kYMLibraryPivotIdentifier title:LOC(@"DOWNLOAD_LIBRARY_TAB") iconType:18];
        [[self delegate] didTapPivotBarItem:item withViewControllers:@[libraryVC] animated:YES];
        return;
    }
    %orig;
}
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    sbUpdateOverlayInsetForPivotBar();
    if (IS_ENABLED(ShortsOnly) && !isTabSelected) {
        [self selectItemWithPivotIdentifier:@"FEshorts"];
        isTabSelected = YES;
        return;
    }
    if (!isTabSelected) {
        // Build pivot identifiers from enabled tabs (skip Create — matches Settings.x segment logic).
        // Mirrors the real bar: the Download tab follows the Downloading settings, and when the
        // saved order has no entry for it yet, it sits at the end of the bar.
        NSMutableArray *pivotIdentifiers = [NSMutableArray array];
        NSArray *savedOrder = [[NSUserDefaults standardUserDefaults] arrayForKey:TabOrder];
        if (savedOrder.count > 0) {
            BOOL downloadInOrder = NO;
            for (NSDictionary *entry in savedOrder) {
                NSString *tabID = entry[@"id"];
                BOOL isDownloadTab = [tabID isEqualToString:@"download"];
                BOOL enabled = isDownloadTab ? IS_ENABLED(DownloadLibraryTab) : [entry[@"enabled"] boolValue];
                if (!enabled) continue;
                if ([tabID isEqualToString:@"create"]) continue;
                if (isDownloadTab) {
                    [pivotIdentifiers addObject:kYMLibraryPivotIdentifier];
                    downloadInOrder = YES;
                    continue;
                }
                NSString *pivot = ymPivotIDForTabID(tabID);
                if (pivot) [pivotIdentifiers addObject:pivot];
            }
            if (!downloadInOrder && IS_ENABLED(DownloadLibraryTab)) {
                [pivotIdentifiers addObject:kYMLibraryPivotIdentifier];
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
    if (INTFORVAL(UseFrostedTabBar) == 1) return YES;
    else if (INTFORVAL(UseFrostedTabBar) == 2) return NO;
    return %orig;
}
%end

%hook YTAppDelegate
- (void)sceneDidBecomeActive:(UIScene *)scene {
    %orig;
    if (IS_ENABLED(AutoOpenLink)) {
        UIViewController *topVC = YouModTopViewController(nil);
        YMOpenLinkFromClipboard(topVC, NO);
    }
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

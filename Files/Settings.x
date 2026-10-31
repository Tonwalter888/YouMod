// Settings.x
// Thanks to the original codes from YTUHD by PoomSmart - https://github.com/PoomSmart/YTUHD/blob/0e735616fd8fc6546339da7fdc78466f16f23ffd/Settings.x
#import "Headers.h"

#define TweakName @"YouMod"

#define YMLOC(x) [YouModBundle() localizedStringForKey:x value:nil table:nil]
#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)

static const NSInteger TweakSection = 'ytmo';

static NSString *GetCacheSize() { // YTLite - @dayanch96
    NSString *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    NSArray *filesArray = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:cachePath error:nil];
    unsigned long long int folderSize = 0;
    for (NSString *fileName in filesArray) {
        NSString *filePath = [cachePath stringByAppendingPathComponent:fileName];
        NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
        folderSize += [fileAttributes fileSize];
    }
    NSByteCountFormatter *formatter = [[NSByteCountFormatter alloc] init];
    formatter.countStyle = NSByteCountFormatterCountStyleFile;
    return [formatter stringFromByteCount:folderSize];
}

#pragma mark - Custom YouMod home page

// Custom YouMod home page rows, built in -updateYouModSectionWithEntry: and cached
// here. Tapping the "YouMod" cell in YouTube's settings pushes this page.
static NSArray<YMSettingsItem *> *gYMYouModHomeItems = nil;

// Push the cached home page (footer variant shows the version footer). settingsVC
// owns the navigation stack; parentResponder seeds YouTube's theming DI.
static void YMPushYouModHome(id settingsVC, id parentResponder) {
    if (!gYMYouModHomeItems || !settingsVC) return;
    YMPushSubSettingsWithFooter(TweakName, gYMYouModHomeItems, settingsVC, parentResponder);
}

// "Tab bar" sub-page items (image list built from the enabled tabs).
// Shared by the search registration and the home row.
static NSArray<YMSettingsItem *> *YMTabBarItems(id settingsVC, id parentResponder) {
    NSDictionary *tabYTIconMap = @{@"home": @(65), @"shorts": @(769), @"subscriptions": @(66), @"library": @(61)};
    NSDictionary *tabBundleIconMap = @{@"history": @"icons/history", @"gaming": @"icons/gaming", @"sports": @"icons/sports", @"notifications": @"icons/noti", @"news": @"icons/news", @"music": @"icons/music", @"watchlater": @"icons/watchlater", @"playlist": @"icons/playlist", @"like": @"icons/like", @"live": @"icons/live", @"post": @"icons/post", @"video": @"icons/video", @"movie": @"icons/movie", @"course": @"icons/course", @"minigame": @"icons/minigame", @"fashion": @"icons/fashion", @"learning": @"icons/learning", @"download": @"icons/download"};
    YTAssetLoader *assetLoader = [[%c(YTAssetLoader) alloc] initWithBundle:YouModBundle()];

    NSMutableArray<UIImage *> *defaultTabImages = [NSMutableArray array];
    NSArray *savedOrder = [[NSUserDefaults standardUserDefaults] arrayForKey:TabOrder];
    if (savedOrder.count > 0) {
        BOOL downloadInOrder = NO;
        for (NSDictionary *entry in savedOrder) {
            NSString *tabID = entry[@"id"];
            BOOL isDownloadTab = [tabID isEqualToString:@"download"];
            BOOL enabled = isDownloadTab ? IS_ENABLED(DownloadLibraryTab) : [entry[@"enabled"] boolValue];
            if (!enabled) continue;
            if ([tabID isEqualToString:@"create"]) continue;
            if (isDownloadTab) downloadInOrder = YES;
            NSNumber *ytIconType = tabYTIconMap[tabID];
            if (ytIconType) {
                UIImage *img = YouModYTIconImage([ytIconType intValue], YES, [UIColor whiteColor]);
                if (img) [defaultTabImages addObject:img];
            } else {
                NSString *bundleName = tabBundleIconMap[tabID];
                if (bundleName) {
                    UIImage *img = [assetLoader imageNamed:bundleName];
                    if (img) {
                        UIImage *whiteImg = [img imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
                        [defaultTabImages addObject:whiteImg];
                    }
                }
            }
        }
        if (!downloadInOrder && IS_ENABLED(DownloadLibraryTab)) {
            UIImage *img = [assetLoader imageNamed:@"icons/download"];
            if (img) {
                UIImage *whiteImg = [img imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
                [defaultTabImages addObject:whiteImg];
            }
        }
    }
    if (defaultTabImages.count == 0) {
        NSArray *fallbackIcons = @[@(65), @(769), @(66), @(61)];
        for (NSNumber *iconType in fallbackIcons) {
            UIImage *img = YouModYTIconImage([iconType intValue], YES, [UIColor whiteColor]);
            if (img) [defaultTabImages addObject:img];
        }
    }

    return @[
        YMImageSegment(YMLOC(@"DEFAULT_TAB"), DefaultTab, defaultTabImages, 0),
        YMTextSegment(YMLOC(@"FORSTED_TAB_BAR"), UseFrostedTabBar, (@[YMLOC(@"DEFAULT"),YMLOC(@"ENABLED"), YMLOC(@"DISABLED")]), 0),
        YMToggle(YMLOC(@"HIDE_TAB_INDI"), YMLOC(@"HIDE_TAB_INDI_DESC"), HideTabIndi),
        YMToggle(YMLOC(@"HIDE_TAB_LABELS"), YMLOC(@"HIDE_TAB_LABELS_DESC"), HideTabLabels),
        YMNavAction(YMLOC(@"MANAGE_TABS"), YMLOC(@"MANAGE_TABS_DESC"), ^(UIViewController *vc) {
            (void)vc;
            YMPushTabOrder(settingsVC, parentResponder);
        }),
    ];
}

// "Preferences" sub-page items (import/export/cache + update/cache toggles).
// Shared by the search registration and the home row.
static NSArray<YMSettingsItem *> *YMPreferencesItems(void) {
    return @[
        YMHeader(YMLOC(@"PERFER")),
        YMAction(YMLOC(@"IMPORT"), YMLOC(@"IMPORT_DESC"), ^(UIViewController *vc) {
            Class alertClass = NSClassFromString(@"YTAlertView");
            YTAlertView *alertView = [alertClass confirmationDialogWithAction:^{
                [[YouModPrefsManager sharedManager] importYouModSettingsFromVC:vc];
            } actionTitle:YMLOC(@"YES")];
            alertView.title = YMLOC(@"WARNING");
            alertView.subtitle = YMLOC(@"OVERRIDE");
            alertView.shouldDismissOnBackgroundTap = YES;
            [alertView show];
        }),
        YMAction(YMLOC(@"EXPORT"), YMLOC(@"EXPORT_DESC"), ^(UIViewController *vc) {
            [[YouModPrefsManager sharedManager] exportYouModSettingsFromVC:vc];
        }),
        YMAction(YMLOC(@"RESTORE"), YMLOC(@"RESTORE_DESC"), ^(UIViewController *vc) {
            [[YouModPrefsManager sharedManager] restoreYouModDefaults];
        }),
        YMHeader(YMLOC(@"UPDATE")),
        YMToggle(YMLOC(@"CHECK_UPDATES"), YMLOC(@"CHECK_UPDATES_DESC"), NotifyUpdates),
        YMAction(YMLOC(@"CHECK_UPDATES_NOW"), YMLOC(@"CHECK_UPDATES_NOW_DESC"), ^(UIViewController *vc) {
            (void)vc;
            YouModCheckForUpdateManually();
        }),
        YMHeader(YMLOC(@"CACHE")),
        YMAction(YMLOC(@"CLEARCACHE"), GetCacheSize(), ^(UIViewController *vc) {
            __weak UIViewController *weakVC = vc;
            NSString *clearTitle = YMLOC(@"CLEARCACHE");
            dispatch_async(dispatch_get_main_queue(), ^{
                __strong UIViewController *strongVC = weakVC;
                if (!strongVC) return;
                if ([strongVC respondsToSelector:@selector(items)] && [strongVC respondsToSelector:@selector(tableView)]) {
                    NSArray *items = [(id)strongVC items];
                    for (id item in items) {
                        if ([[item title] isEqualToString:clearTitle]) {
                            [item setSubtitle:@""];
                            break;
                        }
                    }
                    UITableView *tableView = [(id)strongVC tableView];
                    [tableView reloadData];
                    for (UITableViewCell *cell in tableView.visibleCells) {
                        if ([cell.textLabel.text isEqualToString:clearTitle]) {
                            UIActivityIndicatorView *indicator = [cell viewWithTag:0xC0FFEE];
                            if (!indicator) {
                                indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
                                indicator.tag = 0xC0FFEE;
                                [indicator startAnimating];
                                cell.accessoryView = indicator;
                            }
                            cell.detailTextLabel.text = @"";
                            break;
                        }
                    }
                }
            });

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSString *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
                [[NSFileManager defaultManager] removeItemAtPath:cachePath error:nil];
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong UIViewController *strongVC = weakVC;
                    if (!strongVC) return;
                    if ([strongVC respondsToSelector:@selector(tableView)]) {
                        UITableView *tableView = [(id)strongVC tableView];
                        for (UITableViewCell *cell in tableView.visibleCells) {
                            if ([cell.textLabel.text isEqualToString:YMLOC(@"CLEARCACHE")]) {
                                cell.accessoryView = nil;
                                break;
                            }
                        }
                    }
                    if ([strongVC respondsToSelector:@selector(items)] && [strongVC respondsToSelector:@selector(tableView)]) {
                        NSArray *items = [(id)strongVC items];
                        for (id item in items) {
                            if ([[item title] isEqualToString:clearTitle]) {
                                [item setSubtitle:@"0 KB"];
                                break;
                            }
                        }
                        [[(id)strongVC tableView] reloadData];
                    }
                });
            });
        }),
        YMToggle(YMLOC(@"AUTO_CLEARCACHE"), YMLOC(@"AUTO_CLEARCACHE_DESC"), AutoClearCache),
    ];
}

%hook YTSettingsGroupData

- (NSArray <NSNumber *> *)orderedCategories {
    if (self.type != 1 || class_getClassMethod(objc_getClass("YTSettingsGroupData"), @selector(tweaks))) {
        return %orig;
    }
    NSArray *temp = %orig;
    NSMutableArray *mutableCategories = temp.mutableCopy;
    [mutableCategories insertObject:@(TweakSection) atIndex:0];
    return mutableCategories.copy;
}

%end

%hook YTAppSettingsPresentationData

+ (NSArray <NSNumber *> *)settingsCategoryOrder {
    NSArray <NSNumber *> *order = %orig;
    NSUInteger insertIndex = [order indexOfObject:@(1)];
    if (insertIndex != NSNotFound) {
        NSMutableArray <NSNumber *> *mutableOrder = [order mutableCopy];
        [mutableOrder insertObject:@(TweakSection) atIndex:insertIndex + 1];
        order = mutableOrder.copy;
    }
    return order;
}

%end

%hook YTSettingsSectionItemManager

%new(v@:@)
- (void)updateYouModSectionWithEntry:(id)entry {
    (void)entry;
    YTSettingsViewController *settingsViewController = [self valueForKey:@"_settingsViewControllerDelegate"];

    // No native rows — the "YouMod" row opens the home page (didSelectItemAtIndex
    // hook below). This method only builds the sub-group item arrays for home + search.

    // Downloading
    NSArray<YMSettingsItem *> *downloadingItems = @[
            YMToggle(YMLOC(@"DOWNLOAD_MANAGER"), YMLOC(@"DOWNLOAD_MANAGER_DESC"), DownloadManager),
            [YMTextSegment(YMLOC(@"DOWNLOAD_BUTTON_POSITION"), DownloadButtonPosition, (@[YMLOC(@"UNDER_THE_PLAYER"), YMLOC(@"OVERLAY"), YMLOC(@"BOTH")]), 0) visibleWhenBoolKey:DownloadManager],
            YMToggle(YMLOC(@"ADD_SHORTS_DOWNLOAD"), YMLOC(@"ADD_SHORTS_DOWNLOAD_DESC"), AddDownloadToShorts),
            [YMToggle(YMLOC(@"HIDE_AUTO_DUBBED_DOWNLOADS"), YMLOC(@"HIDE_AUTO_DUBBED_DOWNLOADS_DESC"), HideAutoDubbedDownloads) visibleWhenAnyBoolKey:@[DownloadManager, AddDownloadToShorts]],
            YMToggle(YMLOC(@"DOWNLOAD_LIBRARY_TAB"), YMLOC(@"DOWNLOAD_LIBRARY_TAB_DESC"), DownloadLibraryTab),
            YMToggle(YMLOC(@"DOWNLOAD_COMMENT"), YMLOC(@"DOWNLOAD_COMMENT_DESC"), DownloadComment),
            YMToggle(YMLOC(@"DOWNLOAD_POST"), YMLOC(@"DOWNLOAD_POST_DESC"), DownloadPost),
    ];
    YMRegisterSettingsGroup(YMLOC(@"DOWNLOADING"), downloadingItems);

    // Appearance
    NSArray<YMSettingsItem *> *appearanceItems = @[
            YMToggle(YMLOC(@"OLED_THEME"), YMLOC(@"OLED_THEME_DESC"), OLEDTheme),
            YMToggle(YMLOC(@"OLED_KEYBOARD"), YMLOC(@"OLED_KEYBOARD_DESC"), OLEDKeyboard),
    ];
    YMRegisterSettingsGroup(YMLOC(@"APPEARANCE"), appearanceItems);

    // Navigation bar
    NSArray<YMSettingsItem *> *navbarItems = @[
            YMToggle(YMLOC(@"STICKY_NAVBAR"), YMLOC(@"STICKY_NAVBAR_DESC"), StickyNavBar),
            YMToggle(YMLOC(@"HIDE_NOTIFICATION_BUTTON"), YMLOC(@"HIDE_NOTIFICATION_BUTTON_DESC"), HideNoti),
            YMToggle(YMLOC(@"HIDE_SEARCH_BUTTON"), YMLOC(@"HIDE_SEARCH_BUTTON_DESC"), HideSearch),
            YMToggle(YMLOC(@"HIDE_VOICE_SEARCH_BUTTON"), YMLOC(@"HIDE_VOICE_SEARCH_BUTTON_DESC"), HideVoiceSearch),
            YMToggle(YMLOC(@"HIDE_CAST_BUTTON_NAVBAR"), YMLOC(@"HIDE_CAST_BUTTON_NAVBAR_DESC"), HideCastButtonNav),
            YMToggle(YMLOC(@"HIDE_MESSAGES_BUTTON"), YMLOC(@"HIDE_MESSAGES_BUTTON_DESC"), HideMessages),
            YMToggle(YMLOC(@"HIDE_MORE_BUTTON_NAV"), YMLOC(@"HIDE_MORE_BUTTON_NAV_DESC"), HideMoreButtonNav),
            YMPicker(YMLOC(@"NAVIGATION_ICON"), YMLOC(@"NAVIGATION_ICON_DESC"), YTLogoIndex, (@[YMLOC(@"DEFAULT"), YMLOC(@"PREMIUM"), YMLOC(@"YOUTUBE"), YMLOC(@"REMOVE_YTLOGO")]), 0),
    ];
    YMRegisterSettingsGroup(YMLOC(@"NAVBAR"), navbarItems);

    // Feed
    NSArray<YMSettingsItem *> *feedItems = @[
            YMToggle(YMLOC(@"REMOVE_ADS"), YMLOC(@"REMOVE_ADS_DESC"), RemoveAds),
            YMToggle(YMLOC(@"HIDE_SUBBAR"), YMLOC(@"HIDE_SUBBAR_DESC"), HideSubbar),
            YMToggle(YMLOC(@"HIDE_HORI_SHELF"), YMLOC(@"HIDE_HORI_SHELF_DESC"), HideHoriShelf),
            YMToggle(YMLOC(@"HIDE_MUSIC_PLAYLISTS"), YMLOC(@"HIDE_MUSIC_PLAYLISTS_DESC"), HideGenMusicShelf),
            YMToggle(YMLOC(@"HIDE_SURVEYS"), YMLOC(@"HIDE_SURVEYS_DESC"), HideSurveys),
            YMToggle(YMLOC(@"HIDE_FEED_POST"), YMLOC(@"HIDE_FEED_POST_DESC"), HideFeedPost),
            YMToggle(YMLOC(@"HIDE_PLAYABLES"), YMLOC(@"HIDE_PLAYABLES_DESC"), HidePlayables),
            YMToggle(YMLOC(@"HIDE_SHORTS_SHELF"), YMLOC(@"HIDE_SHORTS_SHELF_DESC"), HideShortsShelf),
            YMToggle(YMLOC(@"KEEP_SHORTS_SUBSCRIPT"), YMLOC(@"KEEP_SHORTS_SUBSCRIPT_DESC"), KeepShortsSubscript),
            YMToggle(YMLOC(@"HIDE_SEARCH_HISTORY"), YMLOC(@"HIDE_SEARCH_HISTORY_DESC"), HideSearchHis),
            YMToggle(YMLOC(@"HIDE_SPONSOR_BUTTON"), YMLOC(@"HIDE_SPONSOR_BUTTON_DESC"), HideSponsorButton),
    ];
    YMRegisterSettingsGroup(YMLOC(@"FEED"), feedItems);

    // Player
    NSArray<YMSettingsItem *> *playerItems = @[
            YMPicker(YMLOC(@"QUALITY_WIFI"), YMLOC(@"QUALITY_WIFI_DESC"), WifiQualityIndex, (@[YMLOC(@"DEFAULT"), YMLOC(@"BEST"), @"2160p", @"1440p", @"1080p", @"720p", @"480p", @"360p", @"240p", @"144p"]), 0),
            YMPicker(YMLOC(@"QUALITY_CELLULAR"), YMLOC(@"QUALITY_CELLULAR_DESC"), CellQualityIndex, (@[YMLOC(@"DEFAULT"), YMLOC(@"BEST"), @"2160p", @"1440p", @"1080p", @"720p", @"480p", @"360p", @"240p", @"144p"]), 0),
            YMPicker(YMLOC(@"QUALITY_LOW_POWER"), YMLOC(@"QUALITY_LOW_POWER_DESC"), LowPowerQualityIndex, (@[YMLOC(@"DEFAULT"), YMLOC(@"BEST"), @"2160p", @"1440p", @"1080p", @"720p", @"480p", @"360p", @"240p", @"144p"]), 0),
            YMTextSegment(YMLOC(@"AUDIO_TRACK"), AudioTrack, (@[YMLOC(@"DEFAULT"), YMLOC(@"ORIGINAL"), YMLOC(@"SELECT_MANUALLY")]), 0),
            [YMPicker(YMLOC(@"AUDIO_TRACK_SELECT"), YMLOC(@"AUDIO_TRACK_SELECT_DESC"), AudioTrackLangIndex, getAllSystemLanguageTitles(), 0) visibleWhenKey:AudioTrack equals:2],
            [YMToggle(YMLOC(@"NO_AUTO_DUBBED"), YMLOC(@"NO_AUTO_DUBBED_DESC"), NoDubbedAudioTrack) visibleWhenKey:AudioTrack equals:2],
            YMTextSegment(YMLOC(@"CAPTION_TRACK"), CaptionTrack, (@[YMLOC(@"DEFAULT"), YMLOC(@"DISABLED"), YMLOC(@"SELECT_MANUALLY")]), 0),
            [YMPicker(YMLOC(@"CAPTION_TRACK_SELECT"), YMLOC(@"CAPTION_TRACK_SELECT_DESC"), CaptionTrackLangIndex, getAllSystemLanguageTitles(), 0) visibleWhenKey:CaptionTrack equals:2],
            [YMToggle(YMLOC(@"DISABLES_CAPTION_TRACK"), YMLOC(@"DISABLES_CAPTION_TRACK_DESC"), DisablesCaptionTrack) visibleWhenKey:CaptionTrack equals:2],
            YMHeader(@""),
            YMToggle(YMLOC(@"NO_AUTO_TRANSLATED_TITLES"), YMLOC(@"NO_AUTO_TRANSLATED_TITLES_DESC"), NoTranslatedTitles),
            YMToggle(YMLOC(@"HOLD_TO_SPEED"), YMLOC(@"HOLD_TO_SPEED_DESC"), HoldToSpeedEnabled),
            [YMSlider(YMLOC(@"PLAYBACK_SPEED"), nil, HoldToSpeedRate, 0.25, 10.0, 0.25, 2.0) visibleWhenBoolKey:HoldToSpeedEnabled],
            [YMToggle(YMLOC(@"LOCK_SPEED"), YMLOC(@"LOCK_SPEED_DESC"), LockSpeed) visibleWhenBoolKey:HoldToSpeedEnabled],
            YMHeader(YMLOC(@"INTERFACE")),
            YMNavAction(YMLOC(@"MANAGE_OVERLAY_BUTTONS"), YMLOC(@"MANAGE_OVERLAY_BUTTONS_DESC"), ^(UIViewController *vc) {
                (void)vc;
                YMPushOverlayButtonOrder(settingsViewController, [self parentResponder]);
            }),
            YMPicker(YMLOC(@"SLEEP_TIMER_ENTRY"), YMLOC(@"SLEEP_TIMER_ENTRY_DESC"), SleepTimerEntry, (@[YMLOC(@"DISABLED"), YMLOC(@"SLEEP_TIMER_ENTRY_TABBAR"), YMLOC(@"SLEEP_TIMER_ENTRY_OVERLAY"), YMLOC(@"SLEEP_TIMER_ENTRY_BOTH")]), 0),
            YMToggle(YMLOC(@"HIDE_AUTOPLAY"), YMLOC(@"HIDE_AUTOPLAY_DESC"), HideAutoPlayToggle),
            YMToggle(YMLOC(@"HIDE_FULL_VID_TITLE"), YMLOC(@"HIDE_FULL_VID_TITLE_DESC"), HideFullvidTitle),
            YMToggle(YMLOC(@"HIDE_CAPTIONS_BUTTON"), YMLOC(@"HIDE_CAPTIONS_BUTTON_DESC"), HideCaptionsButton),
            YMToggle(YMLOC(@"HIDE_CAST_BUTTON_PLAYER"), YMLOC(@"HIDE_CAST_BUTTON_PLAYER_DESC"), HideCastButtonPlayer),
            YMToggle(YMLOC(@"HIDE_NEXT_AND_PREV_BUTTON"), YMLOC(@"HIDE_NEXT_AND_PREV_BUTTON_DESC"), HideNextAndPrevButtons),
            [YMToggle(YMLOC(@"REPLACE_PREVNEXT_BUTTONS"), YMLOC(@"REPLACE_PREVNEXT_BUTTONS_DESC"), ReplacePrevNextButtons) visibleWhenBoolKey:HideNextAndPrevButtons equals:NO],
            YMToggle(YMLOC(@"REMOVE_AMBIANT"), YMLOC(@"REMOVE_AMBIANT_DESC"), RemoveAmbiant),
            YMToggle(YMLOC(@"REMOVE_DARK_OVERLAY"), YMLOC(@"REMOVE_DARK_OVERLAY_DESC"), RemoveDarkOverlay),
            YMToggle(YMLOC(@"HIDE_END_SCREEN"), YMLOC(@"HIDE_END_SCREEN_DESC"), HideEndScreenCards),
            YMToggle(YMLOC(@"HIDE_SUGGESTED_VIDEO"), YMLOC(@"HIDE_SUGGESTED_VIDEO_DESC"), HideSuggestedVideo),
            YMToggle(YMLOC(@"HIDE_PAID_OVERLAY"), YMLOC(@"HIDE_PAID_OVERLAY_DESC"), HidePaidPromoOverlay),
            YMToggle(YMLOC(@"HIDE_WATERMARK"), YMLOC(@"HIDE_WATERMARK_DESC"), HideWaterMark),
            YMToggle(YMLOC(@"HIDE_FULLSCREEN_ACTIONS"), YMLOC(@"HIDE_FULLSCREEN_ACTIONS_DESC"), HideFullAction),
            YMToggle(YMLOC(@"FORCE_SEEKBAR"), YMLOC(@"FORCE_SEEKBAR_DESC"), AlwaysShowSeekbar),
            YMToggle(YMLOC(@"DISABLES_SHOW_REMAINING"), YMLOC(@"DISABLES_SHOW_REMAINING_DESC"), DisablesShowRemaining),
            YMToggle(YMLOC(@"ALWAYS_SHOW_REMAINING"), YMLOC(@"ALWAYS_SHOW_REMAINING_DESC"), AlwaysShowRemaining),
            YMToggle(YMLOC(@"SHOW_REMAINING_EXTRA"), YMLOC(@"SHOW_REMAINING_EXTRA_DESC"), ShowExtraTimeRemaining),
            [YMToggle(YMLOC(@"USES_24_HOURS_TIME"), YMLOC(@"USES_24_HOURS_TIME_DESC"), Uses24HoursTime) visibleWhenBoolKey:ShowExtraTimeRemaining], 
            YMToggle(YMLOC(@"OLD_QUALITY_PICKER"), YMLOC(@"OLD_QUALITY_PICKER_DESC"), OldQualityPicker),
            YMToggle(YMLOC(@"EXTRA_SPEED"), YMLOC(@"EXTRA_SPEED_DESC"), ExtraSpeed),
            YMToggle(YMLOC(@"PORTRAIT_FULLSCREEN"), YMLOC(@"PORTRAIT_FULLSCREEN_DESC"), PortFull),
            YMToggle(YMLOC(@"HIDE_RELATED_VIDEOS"), YMLOC(@"HIDE_RELATED_VIDEOS_DESC"), HideRelatedVideos),
            YMToggle(YMLOC(@"HIDE_COMMENTS_SECTION"), YMLOC(@"HIDE_COMMENTS_SECTION_DESC"), HideCommentsSection),
            YMToggle(YMLOC(@"HIDE_COMMENTS_PREVIEW"), YMLOC(@"HIDE_COMMENTS_PREVIEW_DESC"), HideCommentsPreview),
            YMPicker(YMLOC(@"DRC_AUDIO_OPTIONS"), YMLOC(@"DRC_AUDIO_OPTIONS_DESC"), AutoDRCAudioIndex, (@[YMLOC(@"DEFAULT"), YMLOC(@"ENABLED"), YMLOC(@"DISABLED")]), 0),
            YMToggle(YMLOC(@"REMOVE_VIDEO_LIKE_BUTTON"), YMLOC(@"REMOVE_VIDEO_LIKE_BUTTON_DESC"), RemoveVideoLikeButton),
            YMToggle(YMLOC(@"REMOVE_VIDEO_DISLIKE_BUTTON"), YMLOC(@"REMOVE_VIDEO_DISLIKE_BUTTON_DESC"), RemoveVideoDislikeButton),
            YMToggle(YMLOC(@"REMOVE_VIDEO_SHARE_BUTTON"), YMLOC(@"REMOVE_VIDEO_SHARE_BUTTON_DESC"), RemoveVideoShareButton),
            YMToggle(YMLOC(@"REMOVE_VIDEO_SAVE_BUTTON"), YMLOC(@"REMOVE_VIDEO_SAVE_BUTTON_DESC"), RemoveVideoSaveButton),
            YMToggle(YMLOC(@"REMOVE_VIDEO_DOWNLOAD_BUTTON"), YMLOC(@"REMOVE_VIDEO_DOWNLOAD_BUTTON_DESC"), RemoveVideoDownloadButton),
            YMToggle(YMLOC(@"REMOVE_VIDEO_CLIP_BUTTON"), YMLOC(@"REMOVE_VIDEO_CLIP_BUTTON_DESC"), RemoveVideoClipButton),
            YMToggle(YMLOC(@"REMOVE_VIDEO_REMIX_BUTTON"), YMLOC(@"REMOVE_VIDEO_REMIX_BUTTON_DESC"), RemoveVideoRemixButton),
            YMToggle(YMLOC(@"REMOVE_VIDEO_LIVE_CHAT_BUTTON"), YMLOC(@"REMOVE_VIDEO_LIVE_CHAT_BUTTON_DESC"), RemoveVideoLiveChatButton),
            YMHeader(YMLOC(@"CONTROL_CENTER")),
            YMToggle(YMLOC(@"SKIP_BACKWARD"), YMLOC(@"SKIP_BACKWARD_DESC"), SkipBackwardEnabled),
            [YMSlider(YMLOC(@"REWIND_SECONDS"), nil, RewindSeconds, 5, 60, 5, 10) visibleWhenBoolKey:SkipBackwardEnabled],
            YMToggle(YMLOC(@"SKIP_FORWARD"), YMLOC(@"SKIP_FORWARD_DESC"), SkipForwardEnabled),
            [YMSlider(YMLOC(@"FORWARD_SECONDS"), nil, ForwardSeconds, 5, 60, 5, 10) visibleWhenBoolKey:SkipForwardEnabled],
            YMHeader(YMLOC(@"PLAYER_ACTIONS")),
            YMToggle(YMLOC(@"FIX_PLAYBACK_ISSUES"), YMLOC(@"FIX_PLAYBACK_ISSUES_DESC"), FixPlaybackIssues),
            YMPicker(YMLOC(@"DEFAULT_SPEED"), YMLOC(@"DEFAULT_SPEED_DESC"), AutoSpeedIndex, (@[YMLOC(@"DISABLED"), @"0.25x", @"0.5x", @"0.75x", @"1x", @"1.25x", @"1.5x", @"1.75x", @"2x", @"3x", @"4x", @"5x"]), 0),
            YMToggle(YMLOC(@"FORCE_MINIPLAYER"), YMLOC(@"FORCE_MINIPLAYER_DESC"), ForceMiniPlayer),
            YMToggle(YMLOC(@"HIDE_CONTENT_WARNING"), YMLOC(@"HIDE_CONTENT_WARNING_DESC"), HideContentWarning),
            YMToggle(YMLOC(@"STOP_AUTOPLAY_VIDEO"), YMLOC(@"STOP_AUTOPLAY_VIDEO_DESC"), StopAutoplayVideo),
            YMToggle(YMLOC(@"AUTO_FULLSCREEN"), YMLOC(@"AUTO_FULLSCREEN_DESC"), AutoFullScreen),
            YMToggle(YMLOC(@"AUTO_EXIT_FULLSCREEN"), YMLOC(@"AUTO_EXIT_FULLSCREEN_DESC"), AutoExitFullScreen),
            YMToggle(YMLOC(@"AUTO_FEED_MUTE"), YMLOC(@"AUTO_FEED_MUTE_DESC"), AutoFeedMute),
            YMHeader(YMLOC(@"GESTURE_HEADER")),
            YMToggle(YMLOC(@"GESTURES"), YMLOC(@"GESTURES_DESC"), GestureControls),
            [YMPicker(YMLOC(@"GESTURE_AREA"), YMLOC(@"GESTURE_AREA_DESC"), GestureActivationArea, (@[@"10%", @"15%", @"20%", @"25%", @"30%", @"35%", @"40%", @"45%", @"50%"]), 1) visibleWhenBoolKey:GestureControls],
            [YMPicker(YMLOC(@"LEFT_SIDE_GESTURE"), nil, LeftSideGesture, (@[YMLOC(@"GESTURE_NONE"), YMLOC(@"GESTURE_BRIGHTNESS"), YMLOC(@"GESTURE_VOLUME"), YMLOC(@"GESTURE_SPEED")]), 1) visibleWhenBoolKey:GestureControls],
            [YMPicker(YMLOC(@"RIGHT_SIDE_GESTURE"), nil, RightSideGesture, (@[YMLOC(@"GESTURE_NONE"), YMLOC(@"GESTURE_BRIGHTNESS"), YMLOC(@"GESTURE_VOLUME"), YMLOC(@"GESTURE_SPEED")]), 2) visibleWhenBoolKey:GestureControls],
            [YMToggle(YMLOC(@"GESTURE_HUD"), YMLOC(@"GESTURE_HUD_DESC"), GestureHUD) visibleWhenBoolKey:GestureControls],
            [[YMPicker(YMLOC(@"GESTURE_HUD_SIZE"), YMLOC(@"GESTURE_HUD_SIZE_DESC"), GestureHUDSize, (@[YMLOC(@"SMALL"), YMLOC(@"NORMAL"), YMLOC(@"LARGE"), YMLOC(@"EXTRALARGE"), YMLOC(@"MAX")]), 1) visibleWhenBoolKey:GestureControls] visibleWhenBoolKey:GestureHUD],
            [[YMPicker(YMLOC(@"GESTURE_HUD_POSITION"), YMLOC(@"GESTURE_HUD_POSITION_DESC"), GestureHUDPosition, (@[YMLOC(@"TOP"), YMLOC(@"MIDDLE"), YMLOC(@"BOTTOM")]), 0) visibleWhenBoolKey:GestureControls] visibleWhenBoolKey:GestureHUD], 
            YMHeader(@""),
            YMToggle(YMLOC(@"TAP_TO_SEEK"), YMLOC(@"TAP_TO_SEEK_DESC"), TapToSeek),
            YMToggle(YMLOC(@"SEEK_ON_OVERLAY"), YMLOC(@"SEEK_ON_OVERLAY_DESC"), SeekOnOverlay),
            YMToggle(YMLOC(@"PAUSE_TWO_FINGERS"), YMLOC(@"PAUSE_TWO_FINGERS_DESC"), PauseTwoFingers),
            YMToggle(YMLOC(@"PAUSE_ON_OVERLAY"), YMLOC(@"PAUSE_ON_OVERLAY_DESC"), PauseOnOverlay),
            YMToggle(YMLOC(@"COPY_TIMESTAMP_ON_PAUSE"), YMLOC(@"COPY_TIMESTAMP_ON_PAUSE_DESC"), CopyWithTimestampOnPause),
            YMToggle(YMLOC(@"DISABLES_DOUBLE_TAP"), YMLOC(@"DISABLES_DOUBLE_TAP_DESC"), DisablesDoubleTap),
            YMToggle(YMLOC(@"DISABLES_LONG_HOLD"), YMLOC(@"DISABLES_LONG_HOLD_DESC"), DisablesLongHold),
            YMToggle(YMLOC(@"DISABLES_ZOOM"), YMLOC(@"DISABLES_ZOOM_DESC"), DisablesFreeZoom),
            YMToggle(YMLOC(@"DISABLES_SNAP_TO_CHAPTER"), YMLOC(@"DISABLES_SNAP_TO_CHAPTER_DESC"), DontSnapToChapter),
            YMToggle(YMLOC(@"DISABLES_ENGAGE_PANEL"), YMLOC(@"DISABLES_ENGAGE_PANEL_DESC"), DisablesEngagementPanel),
    ];
    YMRegisterSettingsGroup(YMLOC(@"PLAYER"), playerItems);

    // Shorts
    NSArray<YMSettingsItem *> *shortsItems = @[
            YMTextSegment(YMLOC(@"SHORTS_ACTION"), ShortsActionIndex, (@[YMLOC(@"LOOP"), YMLOC(@"SKIP_TO_NEXT_SHORTS"), YMLOC(@"PAUSE_SHORTS")]), 0),
            YMPicker(YMLOC(@"DEFAULT_SPEED_SHORTS"), YMLOC(@"DEFAULT_SPEED_SHORTS_DESC"), ShortsAutoSpeedIndex, (@[YMLOC(@"DISABLED"), @"0.25x", @"0.5x", @"0.75x", @"1x", @"1.25x", @"1.5x", @"1.75x", @"2x", @"3x", @"4x", @"5x"]), 0),
            YMToggle(YMLOC(@"ENABLES_SHORTS_QUALITY"), YMLOC(@"ENABLES_SHORTS_QUALITY_DESC"), EnablesShortsQuality),
            YMToggle(YMLOC(@"SHOW_SHORTS_SEEKBAR"), YMLOC(@"SHOW_SHORTS_SEEKBAR_DESC"), ShowShortsSeekbar),
            YMToggle(YMLOC(@"SHORTS_ONLY"), YMLOC(@"SHORTS_ONLY_DESC"), ShortsOnly),
            YMToggle(YMLOC(@"SHORTS_FULLSCREEN"), YMLOC(@"SHORTS_FULLSCREEN_DESC"), FullScreenShorts),
            YMToggle(YMLOC(@"REMOVE_LIVE_SHORTS"), YMLOC(@"REMOVE_LIVE_SHORTS_DESC"), RemoveShortsLive),
            YMToggle(YMLOC(@"REMOVE_POSTS_SHORTS"), YMLOC(@"REMOVE_POSTS_SHORTS_DESC"), RemoveShortsPosts),
            YMHeader(YMLOC(@"INTERFACE")),
            YMToggle(YMLOC(@"HIDE_SHORTS_TOPBAR"), YMLOC(@"HIDE_SHORTS_TOPBAR_DESC"), HideShortsTopbar),
            YMToggle(YMLOC(@"HIDE_SHORTS_SUBBAR"), YMLOC(@"HIDE_SHORTS_SUBBAR_DESC"), HideShortsSubbar),
            YMToggle(YMLOC(@"HIDE_SHORTS_PRODUCT"), YMLOC(@"HIDE_SHORTS_PRODUCT_DESC"), HideShortsProducts),
            YMToggle(YMLOC(@"HIDE_SHORTS_RECBAR"), YMLOC(@"HIDE_SHORTS_RECBAR_DESC"), HideShortsRecbar),
            YMToggle(YMLOC(@"REMOVE_SHORTS_SUB_BUTTON"), YMLOC(@"REMOVE_SHORTS_SUB_BUTTON_DESC"), RemoveShortsSubButton),
            YMToggle(YMLOC(@"HIDE_SHORTS_DISCLOSURE"), YMLOC(@"HIDE_SHORTS_DISCLOSURE_DESC"), RemoveShortsDisclosure),
            YMToggle(YMLOC(@"REMOVE_SHORTS_COMMENT_BAR"), YMLOC(@"REMOVE_SHORTS_COMMENT_BAR_DESC"), RemoveShortsCommentBar),
            YMToggle(YMLOC(@"REMOVE_SHORTS_RELATED_BUTTONS"), YMLOC(@"REMOVE_SHORTS_RELATED_BUTTONS_DESC"), RemoveShortsRelatedButtons),
            YMToggle(YMLOC(@"REMOVE_SHORTS_LIKE_BUTTON"), YMLOC(@"REMOVE_SHORTS_LIKE_BUTTON_DESC"), RemoveShortsLikeButton),
            YMToggle(YMLOC(@"REMOVE_SHORTS_COMMENT_BUTTON"), YMLOC(@"REMOVE_SHORTS_COMMENT_BUTTON_DESC"), RemoveShortsCommentButton),
            YMToggle(YMLOC(@"REMOVE_SHORTS_SAVE_BUTTON"), YMLOC(@"REMOVE_SHORTS_SAVE_BUTTON_DESC"), RemoveShortsSaveButton),
            YMToggle(YMLOC(@"REMOVE_SHORTS_SHARE_BUTTON"), YMLOC(@"REMOVE_SHORTS_SHARE_BUTTON_DESC"), RemoveShortsShareButton),
            YMToggle(YMLOC(@"REMOVE_SHORTS_REMIX_BUTTON"), YMLOC(@"REMOVE_SHORTS_REMIX_BUTTON_DESC"), RemoveShortsRemixButton),
            YMToggle(YMLOC(@"REMOVE_SHORTS_SOUNDMETADATA_BUTTON"), YMLOC(@"REMOVE_SHORTS_SOUNDMETADATA_BUTTON_DESC"), RemoveShortsSoundMetadataButton),
            YMToggle(YMLOC(@"REMOVE_SHORTS_PAUSED_SUB_BUTTON"), YMLOC(@"REMOVE_SHORTS_PAUSED_SUB_BUTTON_DESC"), RemoveShortsPausedSubButton),
            YMToggle(YMLOC(@"REMOVE_SHORTS_PAUSED_LIVE_BUTTON"), YMLOC(@"REMOVE_SHORTS_PAUSED_LIVE_BUTTON_DESC"), RemoveShortsPausedLiveButton),
            YMToggle(YMLOC(@"REMOVE_SHORTS_PAUSED_LENS_BUTTON"), YMLOC(@"REMOVE_SHORTS_PAUSED_LENS_BUTTON_DESC"), RemoveShortsPausedLensButton),
            YMToggle(YMLOC(@"REMOVE_SHORTS_PAUSED_TRENDS_BUTTON"), YMLOC(@"REMOVE_SHORTS_PAUSED_TRENDS_BUTTON_DESC"), RemoveShortsPausedTrendsButton),
    ];
    YMRegisterSettingsGroup(YMLOC(@"SHORTS"), shortsItems);

    // Tab bar
    NSArray<YMSettingsItem *> *tabbarItems = YMTabBarItems(settingsViewController, [self parentResponder]);
    YMRegisterSettingsGroup(YMLOC(@"TABBAR"), tabbarItems);

    // Miscellaneous
    NSArray<YMSettingsItem *> *miscItems = @[
            YMToggle(YMLOC(@"BACKGROUND_PLAYBACK"), YMLOC(@"BACKGROUND_PLAYBACK_DESC"), BackgroundPlayback),
            YMToggle(YMLOC(@"DISABLES_SHORTS_PIP"), YMLOC(@"DISABLES_SHORTS_PIP_DESC"), DisablesShortsPiP),
            YMToggle(YMLOC(@"DISABLE_HINTS"), YMLOC(@"DISABLE_HINTS_DESC"), DisableHints),
            YMToggle(YMLOC(@"BLOCK_UPGRADE_DIALOGS"), YMLOC(@"BLOCK_UPGRADE_DIALOGS_DESC"), BlockUpgradeDialogs),
            YMToggle(YMLOC(@"ARE_YOU_THERE_DIALOG"), YMLOC(@"ARE_YOU_THERE_DIALOG_DESC"), HideAreYouThereDialog),
            YMToggle(YMLOC(@"FIXES_SLOW_MINIPLAYER"), YMLOC(@"FIXES_SLOW_MINIPLAYER_DESC"), FixesSlowMiniPlayer),
            YMToggle(YMLOC(@"DISABLES_NEW_MINIPLAYER"), YMLOC(@"DISABLES_NEW_MINIPLAYER_DESC"), DisablesNewMiniPlayer),
            YMToggle(YMLOC(@"DISABLES_SNACK_BAR"), YMLOC(@"DISABLES_SNACK_BAR_DESC"), DisablesSnackBar),
            YMToggle(YMLOC(@"HIDE_LIKE_DISLIKE_VOTES"), YMLOC(@"HIDE_LIKE_DISLIKE_VOTES_DESC"), HideLikeDislikeVotes),
            YMToggle(YMLOC(@"HIDE_COMMU_GUIDE"), YMLOC(@"HIDE_COMMU_GUIDE_DESC"), HideCommuGuide),
            YMToggle(YMLOC(@"HIDE_ENGAGEMENT_SUBBAR"), YMLOC(@"HIDE_ENGAGEMENT_SUBBAR_DESC"), HideEngagementSubbar),
            YMToggle(YMLOC(@"HIDE_INFO_BUTTON_PANEL"), YMLOC(@"HIDE_INFO_BUTTON_PANEL_DESC"), HideInfoButtonPanel),
            YMToggle(YMLOC(@"HIDE_COMMUNITY_BUTTON_PANEL"), YMLOC(@"HIDE_COMMUNITY_BUTTON_PANEL_DESC"), HideCommunityButtonPanel),
            YMToggle(YMLOC(@"HIDE_SORT_FILTER_PANEL"), YMLOC(@"HIDE_SORT_FILTER_PANEL_DESC"), HideSortFilerPanel),
            YMToggle(YMLOC(@"FLOATING_KEYBOARD"), YMLOC(@"FLOATING_KEYBOARD_DESC"), FloatingKeyboard),
            YMToggle(YMLOC(@"DISABLES_RTL"), YMLOC(@"DISABLES_RTL_DESC"), DisablesRTL),
            YMHeader(@""),
            YMPicker(YMLOC(@"STARTUP_ANIMATION"), YMLOC(@"STARTUP_ANIMATION_DESC"), StartupAnimation, (@[YMLOC(@"DEFAULT"), YMLOC(@"STARTUP_ANIMATION_SHOW"), YMLOC(@"DISABLED"), YMLOC(@"SELECT_MANUALLY")]), 0),
            [YMAction(YMLOC(@"STARTUP_VIDEO_PICK"), YMLOC(@"STARTUP_VIDEO_PICK_DESC"), ^(UIViewController *vc) {
                YMStartupVideoPresentPicker(vc);
            }) visibleWhenKey:StartupAnimation equals:3],
            [[YMAction(YMLOC(@"STARTUP_VIDEO_DELETE"), YMLOC(@"STARTUP_VIDEO_DELETE_DESC"), ^(UIViewController *vc) {
                YMStartupVideoDelete(vc);
            }) visibleWhenKey:StartupAnimation equals:3] visibleWhen:^BOOL(__unused NSUserDefaults *defaults) {
                return YMStartupVideoFileExists();
            }],
            [YMToggle(YMLOC(@"HIDE_STARTUP_ANIMATIONS"), YMLOC(@"HIDE_STARTUP_ANIMATIONS_DESC"), HideStartupAni) visibleWhenKey:StartupAnimation equals:0],
            YMHeader(@""),
            YMTextSegment(YMLOC(@"DEVICE_UI"), DeviceUIIndex, (@[YMLOC(@"DEFAULT"), @"iPad", @"iPhone"]), 0),
            YMToggle(YMLOC(@"AUTO_OPEN_LINK"), YMLOC(@"AUTO_OPEN_LINK_DESC"), AutoOpenLink),
            YMHeader(YMLOC(@"FLYOUT_MENU")),
            YMToggle(YMLOC(@"REMOVE_PLAY_IN_NEXT_QUEUE_OPTION"), YMLOC(@"REMOVE_PLAY_IN_NEXT_QUEUE_OPTION_DESC"), RemovePlayInNextQueueOption),
            YMToggle(YMLOC(@"REMOVE_PLAY_IN_LAST_QUEUE_OPTION"), YMLOC(@"REMOVE_PLAY_IN_LAST_QUEUE_OPTION_DESC"), RemoveAddToLastQueueOption),
            YMToggle(YMLOC(@"REMOVE_DOWNLOAD_OPTION"), YMLOC(@"REMOVE_DOWNLOAD_OPTION_DESC"), RemoveDownloadOption),
            YMToggle(YMLOC(@"REMOVE_WATCH_LATER_OPTION"), YMLOC(@"REMOVE_WATCH_LATER_OPTION_DESC"), RemoveWatchLaterOption),
            YMToggle(YMLOC(@"REMOVE_SAVE_OPTION"), YMLOC(@"REMOVE_SAVE_OPTION_DESC"), RemoveSaveOption),
            YMToggle(YMLOC(@"REMOVE_REMOVE_FROM_PLAYLIST_OPTION"), YMLOC(@"REMOVE_REMOVE_FROM_PLAYLIST_OPTION_DESC"), RemoveRemoveFromPlaylistOption),
            YMToggle(YMLOC(@"REMOVE_SHARE_OPTION"), YMLOC(@"REMOVE_SHARE_OPTION_DESC"), RemoveShareOption),
            YMToggle(YMLOC(@"REMOVE_NOT_INTERESTED_OPTION"), YMLOC(@"REMOVE_NOT_INTERESTED_OPTION_DESC"), RemoveNotInterestedOption),
            YMToggle(YMLOC(@"REMOVE_DONT_RECOMMEND_OPTION"), YMLOC(@"REMOVE_DONT_RECOMMEND_OPTION_DESC"), RemoveDontRecommendOption),
            YMToggle(YMLOC(@"REMOVE_INFO_OPTION"), YMLOC(@"REMOVE_INFO_OPTION_DESC"), RemoveInfoOption),
            YMToggle(YMLOC(@"REMOVE_FILTER_OPTION"), YMLOC(@"REMOVE_FILTER_OPTION_DESC"), RemoveFilterOption),
            YMToggle(YMLOC(@"REMOVE_REPORT_OPTION"), YMLOC(@"REMOVE_REPORT_OPTION_DESC"), RemoveReportOption),
            YMToggle(YMLOC(@"REMOVE_YOUTUBE_MUSIC_OPTION"), YMLOC(@"REMOVE_YOUTUBE_MUSIC_OPTION_DESC"), RemoveYouTubeMusicOption),
            YMToggle(YMLOC(@"REMOVE_FEED_BACK_OPTION"), YMLOC(@"REMOVE_FEED_BACK_OPTION_DESC"), RemoveFeedBackOption),
            YMToggle(YMLOC(@"REMOVE_CAST_OPTION"), YMLOC(@"REMOVE_CAST_OPTION_DESC"), RemoveCastOption),
            YMToggle(YMLOC(@"REMOVE_SHUFFLE_OPTION"), YMLOC(@"REMOVE_SHUFFLE_OPTION_DESC"), RemoveShuffleOption),
            YMToggle(YMLOC(@"REMOVE_UN_SUB_OPTION"), YMLOC(@"REMOVE_UN_SUB_OPTION_DESC"), RemoveUnSubOption),
            YMToggle(YMLOC(@"REMOVE_HIDE_FROM_PLAYLIST_OPTION"), YMLOC(@"REMOVE_HIDE_FROM_PLAYLIST_OPTION_DESC"), RemoveHideFromPlaylistOption),
            YMToggle(YMLOC(@"REMOVE_HELP_OPTION"), YMLOC(@"REMOVE_HELP_OPTION_DESC"), RemoveHelpOption),
            YMToggle(YMLOC(@"REMOVE_NOTIFY_OPTION"), YMLOC(@"REMOVE_NOTIFY_OPTION_DESC"), RemoveNotifyOption),
            YMToggle(YMLOC(@"REMOVE_CLEARSCREEN_OPTION"), YMLOC(@"REMOVE_CLEARSCREEN_OPTION_DESC"), RemoveClearScreenOption),
    ];
    YMRegisterSettingsGroup(YMLOC(@"MISCELLANEOUS"), miscItems);

    // Preferences (import/export/cache actions + update/cache toggles).
    NSArray<YMSettingsItem *> *prefItems = YMPreferencesItems();
    YMRegisterSettingsGroup(YMLOC(@"PERFER_HEADER"), prefItems);

    // ---- Custom YouMod home page ----
    // Cached here; the "YouMod" cell tap pushes it. Section rows are tall icon rows,
    // then the Developer block and Preferences.
    NSMutableArray<YMSettingsItem *> *homeItems = [NSMutableArray array];

    // Section rows — nav rows pushing their sub-page.
    [homeItems addObject:[YMNavAction(YMLOC(@"DOWNLOADING"), nil, ^(UIViewController *vc) {
        (void)vc;
        YMPushSubSettings(YMLOC(@"DOWNLOADING"), downloadingItems, settingsViewController, [self parentResponder]);
    }) withIconType:57]];
    [homeItems addObject:[YMNavAction(YMLOC(@"APPEARANCE"), nil, ^(UIViewController *vc) {
        (void)vc;
        YMPushSubSettings(YMLOC(@"APPEARANCE"), appearanceItems, settingsViewController, [self parentResponder]);
    }) withIconType:921]];
    [homeItems addObject:[YMNavAction(YMLOC(@"NAVBAR"), nil, ^(UIViewController *vc) {
        (void)vc;
        YMPushSubSettings(YMLOC(@"NAVBAR"), navbarItems, settingsViewController, [self parentResponder]);
    }) withIconType:60]];
    [homeItems addObject:[YMNavAction(YMLOC(@"FEED"), nil, ^(UIViewController *vc) {
        (void)vc;
        YMPushSubSettings(YMLOC(@"FEED"), feedItems, settingsViewController, [self parentResponder]);
    }) withIconType:193]];
    [homeItems addObject:[YMNavAction(YMLOC(@"PLAYER"), nil, ^(UIViewController *vc) {
        (void)vc;
        YMPushSubSettings(YMLOC(@"PLAYER"), playerItems, settingsViewController, [self parentResponder]);
    }) withIconType:658]];
    [homeItems addObject:[YMNavAction(YMLOC(@"SHORTS"), nil, ^(UIViewController *vc) {
        (void)vc;
        YMPushSubSettings(YMLOC(@"SHORTS"), shortsItems, settingsViewController, [self parentResponder]);
    }) withIconType:769]];
    [homeItems addObject:[YMNavAction(YMLOC(@"TABBAR"), nil, ^(UIViewController *vc) {
        (void)vc;
        YMPushSubSettings(YMLOC(@"TABBAR"), tabbarItems, settingsViewController, [self parentResponder]);
    }) withIconType:66]];
    [homeItems addObject:[YMNavAction(YMLOC(@"MISCELLANEOUS"), nil, ^(UIViewController *vc) {
        (void)vc;
        YMPushSubSettings(YMLOC(@"MISCELLANEOUS"), miscItems, settingsViewController, [self parentResponder]);
    }) withIconType:1101]];
    [homeItems addObject:[YMNavAction(@"SponsorBlock", nil, ^(UIViewController *vc) {
        (void)vc;
        YMPushSponsorBlockSettings(settingsViewController);
    }) withIconType:610]];
    [homeItems addObject:[YMNavAction(YMLOC(@"PERFER_HEADER"), nil, ^(UIViewController *vc) {
        (void)vc;
        YMPushSubSettings(YMLOC(@"PERFER_HEADER"), prefItems, settingsViewController, [self parentResponder]);
    }) withIconType:530]];

    // Developer block (GitHub).
    [homeItems addObject:YMHeader(YMLOC(@"DEV_HEADER"))];
    [homeItems addObject:YMDeveloper(@"Tonwalter888", YMLOC(@"DEV_ROLE_AUTHOR"), @"https://github.com/Tonwalter888", @"https://github.com/Tonwalter888")];
    [homeItems addObject:YMDeveloper(@"G Rohit", YMLOC(@"DEV_ROLE_COLLABORATOR"), @"https://github.com/grohit1810", @"https://github.com/grohit1810")];
    [homeItems addObject:YMDeveloper(@"ZomkaDEV", YMLOC(@"DEV_ROLE_COLLABORATOR"), @"https://github.com/ZomkaDEV", @"https://github.com/ZomkaDEV")];
    // GitHub links.
    [homeItems addObject:YMAction(YMLOC(@"NEW_ISSUES"), YMLOC(@"NEW_ISSUES_DESC"), ^(UIViewController *vc) {
        (void)vc;
        [%c(YTUIUtils) openURL:[NSURL URLWithString:@"https://github.com/Tonwalter888/YouMod/issues/new/choose"]];
    })];
    [homeItems addObject:YMAction(YMLOC(@"SOURCE_CODES"), YMLOC(@"SOURCE_CODES_DESC"), ^(UIViewController *vc) {
        (void)vc;
        [%c(YTUIUtils) openURL:[NSURL URLWithString:@"https://github.com/Tonwalter888/YouMod"]];
    })];

    gYMYouModHomeItems = [homeItems copy];

    // The native section itself is empty — the "YouMod" cell opens the home page.
    if ([settingsViewController respondsToSelector:@selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:)]) {
        YTIIcon *icon = [%c(YTIIcon) new];
        icon.iconType = YT_TUNE;
        [settingsViewController setSectionItems:nil forCategory:TweakSection title:TweakName icon:icon titleDescription:nil headerHidden:NO];
    } else
        [settingsViewController setSectionItems:nil forCategory:TweakSection title:TweakName titleDescription:nil headerHidden:NO];
}

- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if (category == TweakSection) {
        [self updateYouModSectionWithEntry:entry];
        return;
    }
    %orig;
}

%end

// Tapping the (empty) "YouMod" row opens the custom home page right here; %orig is
// skipped so YouTube never drills into the empty section.
%hook YTSettingsSectionController

- (void)didSelectItemAtIndex:(NSInteger)index fromView:(UIView *)view {
    NSArray<YTSettingsSectionItem *> *items = self.items;
    if (index >= 0 && index < (NSInteger)items.count && [items[index].title isEqualToString:TweakName]) {
        UIViewController *sectionVC = [self valueForKey:@"_sectionControllerDelegate"];
        YTSettingsViewController *settingsVC = (YTSettingsViewController *)sectionVC.parentViewController;
        id parentResponder = [sectionVC valueForKey:@"_parentResponder"];
        YMPushYouModHome(settingsVC, parentResponder);
        return;
    }
    %orig;
}

%end

%ctor {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:@{
        HoldToSpeedEnabled: @NO,
        AutoClearCache: @YES,
        NotifyUpdates: @YES,
        YTLogoIndex: @1,
        BackgroundPlayback: @YES,
        DownloadManager: @YES,
        DownloadLibraryTab: @YES,
        SBButtonKey: @YES,
        DisableHints: @YES,
        RewindSeconds: @10.0,
        ForwardSeconds: @10.0
    }];
    %init;
}

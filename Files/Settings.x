// Settings.x
// Thanks to the original codes from YTUHD by PoomSmart - https://github.com/PoomSmart/YTUHD/blob/0e735616fd8fc6546339da7fdc78466f16f23ffd/Settings.x
#import "Headers.h"

#define TweakName @"YouMod"

#define LOC(x) [tweakBundle localizedStringForKey:x value:nil table:nil]
#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)

static const NSInteger TweakSection = 'ytmo';

@class YMSettingsItem;
extern void YMPushSubSettings(NSString *title, NSArray<YMSettingsItem *> *items, id settingsVC, id parentResponder);
extern YMSettingsItem *YMToggle(NSString *title, NSString *subtitle, NSString *key);
extern YMSettingsItem *YMSlider(NSString *title, NSString *subtitle, NSString *key, float min, float max, float step, float defaultValue);
extern YMSettingsItem *YMPicker(NSString *title, NSString *subtitle, NSString *key, NSArray<NSString *> *options, NSInteger defaultValue);
extern YMSettingsItem *YMAction(NSString *title, NSString *subtitle, void (^action)(UIViewController *vc));
extern YMSettingsItem *YMHeader(NSString *title);
extern YMSettingsItem *YMSegment(NSString *title, NSString *key, NSArray<NSNumber *> *icons, NSInteger defaultValue);
extern YMSettingsItem *YMTextSegment(NSString *title, NSString *key, NSArray<NSString *> *labels, NSInteger defaultValue);
extern YMSettingsItem *YMImageSegment(NSString *title, NSString *key, NSArray<UIImage *> *images, NSInteger defaultValue);
extern void YMPushTabOrder(id settingsVC, id parentResponder);

@interface YTSettingsSectionItemManager (YouMod)
- (void)updateYouModSectionWithEntry:(id)entry;
- (void)updateSponsorBlockSectionWithEntry:(id)entry;
@end

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
    NSMutableArray <YTSettingsSectionItem *> *sectionItems = [NSMutableArray array];
    NSBundle *tweakBundle = YouModBundle();
    Class YTSettingsSectionItemClass = %c(YTSettingsSectionItem);
    YTSettingsViewController *settingsViewController = [self valueForKey:@"_settingsViewControllerDelegate"];

    // Tweak Version (at the top)
    // Thanks to the original codes from YTweaks by fosterbarnes - https://github.com/fosterbarnes/YTweaks/blob/e921591a89b87256a2b37c4788bd99282f70d9c2/Settings.x
    YTSettingsSectionItem *tweakVersion = [YTSettingsSectionItemClass itemWithTitle:@"YouMod v2.0.0"
        titleDescription:nil
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            return NO;
        }];
    [sectionItems addObject:tweakVersion];

    // Section 0
    // Github
    YTSettingsSectionItem *github = [YTSettingsSectionItemClass itemWithTitle:nil
        titleDescription:@"Github"
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            return NO;
        }];
    [sectionItems addObject:github];

    // Issues
    YTSettingsSectionItem *issues = [YTSettingsSectionItemClass itemWithTitle:LOC(@"NEW_ISSUES")
        titleDescription:LOC(@"NEW_ISSUES_DESC") // Found bug or Feature request -> Report Issues
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            return [%c(YTUIUtils) openURL:[NSURL URLWithString:@"https://github.com/Tonwalter888/YouMod/issues/new/choose"]];
        }
    ];
    [sectionItems addObject:issues];

    // Sources codes
    YTSettingsSectionItem *sourceCodes = [YTSettingsSectionItemClass itemWithTitle:LOC(@"SOURCE_CODES")
        titleDescription:LOC(@"SOURCE_CODES_DESC") // Take a look
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            return [%c(YTUIUtils) openURL:[NSURL URLWithString:@"https://github.com/Tonwalter888/YouMod"]];
        }
    ];
    [sectionItems addObject:sourceCodes];

    // ?
    YTSettingsSectionItem *blank = [YTSettingsSectionItemClass itemWithTitle:nil
        titleDescription:LOC(@"EXTRA")
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            return NO;
        }];
    [sectionItems addObject:blank];

    // Fix playback issues
    YTSettingsSectionItem *fixPlaybackissues = [YTSettingsSectionItemClass switchItemWithTitle:LOC(@"FIX_PLAYBACK_ISSUES")
        titleDescription:LOC(@"FIX_PLAYBACK_ISSUES_DESC")
        accessibilityIdentifier:nil
        switchOn:IS_ENABLED(FixPlaybackIssues)
        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:FixPlaybackIssues];
            return YES;
        }
        settingItemId:0];
    [sectionItems addObject:fixPlaybackissues];

    // TODO: Center YT logo (not yet implemented)
    // [sectionItems addObject: YMToggle(LOC(@"CENTER_YT_LOGO"), LOC(@"CENTER_YT_LOGO_DESC"), CenterYTLogo)];

    // Settings
    YTSettingsSectionItem *settings = [YTSettingsSectionItemClass itemWithTitle:nil
        titleDescription:LOC(@"SETTINGS")
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            return NO;
        }];
    [sectionItems addObject:settings];

    // Section 1
    // Downloading
    YTSettingsSectionItem *downloadinggroup = [YTSettingsSectionItemClass itemWithTitle:LOC(@"DOWNLOADING") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        YMPushSubSettings(LOC(@"DOWNLOADING"), @[
            YMToggle(LOC(@"DOWNLOAD_MANAGER"), LOC(@"DOWNLOAD_MANAGER_DESC"), DownloadManager),
            YMToggle(LOC(@"DOWNLOAD_SAVE_PHOTOS"), LOC(@"DOWNLOAD_SAVE_PHOTOS_DESC"), DownloadSaveToPhotos),
            YMTextSegment(LOC(@"AUDIO_TRACK"), AudioPreferIndex, (@[LOC(@"SHOW_OPTIONS"), LOC(@"ORIGINAL"), LOC(@"ENGLISH")]), 0),
            YMToggle(LOC(@"ADD_SHORTS_DOWNLOAD"), LOC(@"ADD_SHORTS_DOWNLOAD_DESC"), AddDownloadToShorts),
            YMToggle(LOC(@"FIX_DOWNLOAD"), LOC(@"FIX_DOWNLOAD_DESC"), DownloadFix),
            YMPicker(LOC(@"DOWNLOAD_SERVER"), LOC(@"CHOOSE_DOWNLOAD_SERVER"), DownloadServerIndex, (@[LOC(@"SERVER_EUROPRE1"), LOC(@"SERVER_ASIA1")]), 0),
            YMToggle(LOC(@"DOWNLOAD_COMMENT"), LOC(@"DOWNLOAD_COMMENT_DESC"), DownloadComment),
            YMToggle(LOC(@"DOWNLOAD_POST"), LOC(@"DOWNLOAD_POST_DESC"), DownloadPost),
        ], settingsViewController, [self parentResponder]);
        return YES;
    }];
    YTIIcon *downloadIcon = [%c(YTIIcon) new];
    downloadIcon.iconType = 57;
    downloadinggroup.settingIcon = downloadIcon;
    [sectionItems addObject:downloadinggroup];

    // Section 2
    // Appearance
    YTSettingsSectionItem *appergroup = [YTSettingsSectionItemClass itemWithTitle:LOC(@"APPEARANCE") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        YMPushSubSettings(LOC(@"APPEARANCE"), @[
            YMToggle(LOC(@"OLED_THEME"), LOC(@"OLED_THEME_DESC"), OLEDTheme),
            YMToggle(LOC(@"OLED_KEYBOARD"), LOC(@"OLED_KEYBOARD_DESC"), OLEDKeyboard),
        ], settingsViewController, [self parentResponder]);
        return YES;
    }];
    YTIIcon *icon0 = [%c(YTIIcon) new];
    icon0.iconType = 921;
    appergroup.settingIcon = icon0;
    [sectionItems addObject:appergroup];

    // Section 3
    // Navigation bar
    YTSettingsSectionItem *navbargroup = [YTSettingsSectionItemClass itemWithTitle:LOC(@"NAVBAR") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        YMPushSubSettings(LOC(@"NAVBAR"), @[
            YMToggle(LOC(@"STICKY_NAVBAR"), LOC(@"STICKY_NAVBAR_DESC"), StickyNavBar),
            YMToggle(LOC(@"HIDE_YT_LOGO"), LOC(@"HIDE_YT_LOGO_DESC"), HideYTLogo),
            YMToggle(LOC(@"PREMIUM_LOGO"), LOC(@"PREMIUM_LOGO_DESC"), YTPremiumLogo),
            YMToggle(LOC(@"HIDE_NOTIFICATION_BUTTON"), LOC(@"HIDE_NOTIFICATION_BUTTON_DESC"), HideNoti),
            YMToggle(LOC(@"HIDE_SEARCH_BUTTON"), LOC(@"HIDE_SEARCH_BUTTON_DESC"), HideSearch),
            YMToggle(LOC(@"HIDE_VOICE_SEARCH_BUTTON"), LOC(@"HIDE_VOICE_SEARCH_BUTTON_DESC"), HideVoiceSearch),
            YMToggle(LOC(@"HIDE_CAST_BUTTON_NAVBAR"), LOC(@"HIDE_CAST_BUTTON_NAVBAR_DESC"), HideCastButtonNav),
        ], settingsViewController, [self parentResponder]);
        return YES;
    }];
    YTIIcon *icon1 = [%c(YTIIcon) new];
    icon1.iconType = 60;
    navbargroup.settingIcon = icon1;
    [sectionItems addObject:navbargroup];

    // Section 4
    // Feed
    YTSettingsSectionItem *feedgroup = [YTSettingsSectionItemClass itemWithTitle:LOC(@"FEED") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        YMPushSubSettings(LOC(@"FEED"), @[
            YMToggle(LOC(@"HIDE_SUBBAR"), LOC(@"HIDE_SUBBAR_DESC"), HideSubbar),
            YMToggle(LOC(@"HIDE_HORI_SHELF"), LOC(@"HIDE_HORI_SHELF_DESC"), HideHoriShelf),
            YMToggle(LOC(@"HIDE_MUSIC_PLAYLISTS"), LOC(@"HIDE_MUSIC_PLAYLISTS_DESC"), HideGenMusicShelf),
            YMToggle(LOC(@"HIDE_SURVEYS"), LOC(@"HIDE_SURVEYS_DESC"), HideSurveys),
            YMToggle(LOC(@"HIDE_FEED_POST"), LOC(@"HIDE_FEED_POST_DESC"), HideFeedPost),
            YMToggle(LOC(@"HIDE_PLAYABLES"), LOC(@"HIDE_PLAYABLES_DESC"), HidePlayables),
            YMToggle(LOC(@"HIDE_SHORTS_SHELF"), LOC(@"HIDE_SHORTS_SHELF_DESC"), HideShortsShelf),
            YMToggle(LOC(@"KEEP_SHORTS_SUBSCRIPT"), LOC(@"KEEP_SHORTS_SUBSCRIPT_DESC"), KeepShortsSubscript),
            YMToggle(LOC(@"HIDE_SEARCH_HISTORY"), LOC(@"HIDE_SEARCH_HISTORY_DESC"), HideSearchHis),
        ], settingsViewController, [self parentResponder]);
        return YES;
    }];
    YTIIcon *icon2 = [%c(YTIIcon) new];
    icon2.iconType = 193;
    feedgroup.settingIcon = icon2;
    [sectionItems addObject:feedgroup];

    // Section 5
    // Player
    YTSettingsSectionItem *playergroup = [YTSettingsSectionItemClass itemWithTitle:LOC(@"PLAYER") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        YMPushSubSettings(LOC(@"PLAYER"), @[
            YMPicker(LOC(@"QUALITY_WIFI"), LOC(@"QUALITY_WIFI_DESC"), WifiQualityIndex, (@[LOC(@"DEFAULT"), LOC(@"BEST"), @"2160p60", @"2160p", @"1440p60", @"1440p", @"1080p60", @"1080p", @"720p60", @"720p", @"480p", @"360p", @"240p", @"144p"]), 0),
            YMPicker(LOC(@"QUALITY_CELLULAR"), LOC(@"QUALITY_CELLULAR_DESC"), CellQualityIndex, (@[LOC(@"DEFAULT"), LOC(@"BEST"), @"2160p60", @"2160p", @"1440p60", @"1440p", @"1080p60", @"1080p", @"720p60", @"720p", @"480p", @"360p", @"240p", @"144p"]), 0),
            YMPicker(LOC(@"QUALITY_LOW_POWER"), LOC(@"QUALITY_LOW_POWER_DESC"), LowPowerQualityIndex, (@[LOC(@"DEFAULT"), LOC(@"BEST"), @"2160p60", @"2160p", @"1440p60", @"1440p", @"1080p60", @"1080p", @"720p60", @"720p", @"480p", @"360p", @"240p", @"144p"]), 0),
            YMTextSegment(LOC(@"AUDIO_TRACK"), AudioTrack, (@[LOC(@"DEFAULT"), LOC(@"ORIGINAL"), LOC(@"SELECT_MANUALLY")]), 0),
            YMPicker(LOC(@"AUDIO_TRACK_SELECT"), LOC(@"AUDIO_TRACK_SELECT_DESC"), AudioTrackLangIndex, getAllSystemLanguageTitles(), 0),
            YMToggle(LOC(@"NO_AUTO_DUBBED"), LOC(@"NO_AUTO_DUBBED_DESC"), NoDubbedAudioTrack),
            YMTextSegment(LOC(@"CAPTION_TRACK"), CaptionTrack, (@[LOC(@"DEFAULT"), LOC(@"DISABLED"), LOC(@"SELECT_MANUALLY")]), 0),
            YMPicker(LOC(@"CAPTION_TRACK_SELECT"), LOC(@"CAPTION_TRACK_SELECT_DESC"), CaptionTrackLangIndex, getAllSystemLanguageTitles(), 0),
            YMToggle(LOC(@"DISABLES_CAPTION_TRACK"), LOC(@"DISABLES_CAPTION_TRACK_DESC"), DisablesCaptionTrack),
            YMHeader(@""),
            YMPicker(LOC(@"HOLD_TO_SPEED"), LOC(@"HOLD_TO_SPEED_DESC"), HoldToSpeedIndex, (@[LOC(@"DEFAULT"), @"0.25x", @"0.5x", @"0.75x", @"1x", @"1.25x", @"1.5x", @"1.75x", @"2x", @"3x", @"4x", @"5x"]), 0),
            YMToggle(LOC(@"LOCK_SPEED"), LOC(@"LOCK_SPEED_DESC"), LockSpeed),
            YMHeader(LOC(@"INTERFACE")),
            YMToggle(LOC(@"MUTE_BUTTON"), LOC(@"MUTE_BUTTON_DESC"), MuteButton),
            YMToggle(LOC(@"SPEED_BUTTON"), LOC(@"SPEED_BUTTON_DESC"), SpeedButton),
            YMToggle(LOC(@"QUALITY_BUTTON"), LOC(@"QUALITY_BUTTON_DESC"), QualityButton),
            YMToggle(LOC(@"SHARE_BUTTON"), LOC(@"SHARE_BUTTON_DESC"), ShareButton),
            YMToggle(LOC(@"LOOP_BUTTON"), LOC(@"LOOP_BUTTON_DESC"), LoopButton),
            YMToggle(LOC(@"CAPTION_BUTTON"), LOC(@"CAPTION_BUTTON_DESC"), CaptionButton),
            YMToggle(LOC(@"HIDE_AUTOPLAY"), LOC(@"HIDE_AUTOPLAY_DESC"), HideAutoPlayToggle),
            YMToggle(LOC(@"HIDE_FULL_VID_TITLE"), LOC(@"HIDE_FULL_VID_TITLE_DESC"), HideFullvidTitle),
            YMToggle(LOC(@"HIDE_CAPTIONS_BUTTON"), LOC(@"HIDE_CAPTIONS_BUTTON_DESC"), HideCaptionsButton),
            YMToggle(LOC(@"HIDE_CAST_BUTTON_PLAYER"), LOC(@"HIDE_CAST_BUTTON_PLAYER_DESC"), HideCastButtonPlayer),
            YMToggle(LOC(@"HIDE_NEXT_AND_PREV_BUTTON"), LOC(@"HIDE_NEXT_AND_PREV_BUTTON_DESC"), HideNextAndPrevButtons),
            YMToggle(LOC(@"REPLACE_PREVNEXT_BUTTONS"), LOC(@"REPLACE_PREVNEXT_BUTTONS_DESC"), ReplacePrevNextButtons),
            YMToggle(LOC(@"REMOVE_AMBIANT"), LOC(@"REMOVE_AMBIANT_DESC"), RemoveAmbiant),
            YMToggle(LOC(@"REMOVE_DARK_OVERLAY"), LOC(@"REMOVE_DARK_OVERLAY_DESC"), RemoveDarkOverlay),
            YMToggle(LOC(@"HIDE_END_SCREEN"), LOC(@"HIDE_END_SCREEN_DESC"), HideEndScreenCards),
            YMToggle(LOC(@"HIDE_SUGGESTED_VIDEO"), LOC(@"HIDE_SUGGESTED_VIDEO_DESC"), HideSuggestedVideo),
            YMToggle(LOC(@"HIDE_PAID_OVERLAY"), LOC(@"HIDE_PAID_OVERLAY_DESC"), HidePaidPromoOverlay),
            YMToggle(LOC(@"HIDE_WATERMARK"), LOC(@"HIDE_WATERMARK_DESC"), HideWaterMark),
            YMToggle(LOC(@"HIDE_FULLSCREEN_ACTIONS"), LOC(@"HIDE_FULLSCREEN_ACTIONS_DESC"), HideFullAction),
            YMToggle(LOC(@"FORCE_SEEKBAR"), LOC(@"FORCE_SEEKBAR_DESC"), AlwaysShowSeekbar),
            YMToggle(LOC(@"DISABLES_SHOW_REMAINING"), LOC(@"DISABLES_SHOW_REMAINING_DESC"), DisablesShowRemaining),
            YMToggle(LOC(@"ALWAYS_SHOW_REMAINING"), LOC(@"ALWAYS_SHOW_REMAINING_DESC"), AlwaysShowRemaining),
            YMToggle(LOC(@"SHOW_REMAINING_EXTRA"), LOC(@"SHOW_REMAINING_EXTRA_DESC"), ShowExtraTimeRemaining),
            YMToggle(LOC(@"USES_24_HOURS_TIME"), LOC(@"USES_24_HOURS_TIME_DESC"), Uses24HoursTime),
            YMToggle(LOC(@"OLD_QUALITY_PICKER"), LOC(@"OLD_QUALITY_PICKER_DESC"), OldQualityPicker),
            YMToggle(LOC(@"EXTRA_SPEED"), LOC(@"EXTRA_SPEED_DESC"), ExtraSpeed),
            // YMToggle(LOC(@"USE_ANOTHER_MINIPLAYER"), LOC(@"USE_ANOTHER_MINIPLAYER_DESC"), UseAnotherMiniplayer),
            YMToggle(LOC(@"PORTRAIT_FULLSCREEN"), LOC(@"PORTRAIT_FULLSCREEN_DESC"), PortFull),
            YMToggle(LOC(@"HIDE_COMMENTS_SECTION"), LOC(@"HIDE_COMMENTS_SECTION_DESC"), HideCommentsSection),
            YMToggle(LOC(@"HIDE_COMMENTS_PREVIEW"), LOC(@"HIDE_COMMENTS_PREVIEW_DESC"), HideCommentsPreview),
            YMHeader(LOC(@"CONTROL_CENTER")),
            YMToggle(LOC(@"SKIP_BACKWARD"), LOC(@"SKIP_BACKWARD_DESC"), SkipBackwardEnabled),
            YMSlider(LOC(@"REWIND_SECONDS"), nil, RewindSeconds, 5, 60, 5, 10),
            YMToggle(LOC(@"SKIP_FORWARD"), LOC(@"SKIP_FORWARD_DESC"), SkipForwardEnabled),
            YMSlider(LOC(@"FORWARD_SECONDS"), nil, ForwardSeconds, 5, 60, 5, 10),
            YMHeader(LOC(@"PLAYER_ACTIONS")),
            YMPicker(LOC(@"DEFAULT_SPEED"), LOC(@"DEFAULT_SPEED_DESC"), AutoSpeedIndex, (@[LOC(@"DISABLED"), @"0.25x", @"0.5x", @"0.75x", @"1x", @"1.25x", @"1.5x", @"1.75x", @"2x", @"3x", @"4x", @"5x"]), 0),
            YMToggle(LOC(@"FORCE_MINIPLAYER"), LOC(@"FORCE_MINIPLAYER_DESC"), ForceMiniPlayer),
            YMToggle(LOC(@"HIDE_CONTENT_WARNING"), LOC(@"HIDE_CONTENT_WARNING_DESC"), HideContentWarning),
            YMToggle(LOC(@"STOP_AUTOPLAY_VIDEO"), LOC(@"STOP_AUTOPLAY_VIDEO_DESC"), StopAutoplayVideo),
            YMToggle(LOC(@"AUTO_FULLSCREEN"), LOC(@"AUTO_FULLSCREEN_DESC"), AutoFullScreen),
            YMToggle(LOC(@"AUTO_EXIT_FULLSCREEN"), LOC(@"AUTO_EXIT_FULLSCREEN_DESC"), AutoExitFullScreen),
            YMHeader(LOC(@"GESTURE_HEADER")),
            YMToggle(LOC(@"GESTURES"), LOC(@"GESTURES_DESC"), GestureControls),
            YMPicker(LOC(@"GESTURE_AREA"), LOC(@"GESTURE_AREA_DESC"), GestureActivationArea, (@[@"10%", @"15%", @"20%", @"25%", @"30%", @"35%", @"40%", @"45%", @"50%"]), 1),
            YMPicker(LOC(@"LEFT_SIDE_GESTURE"), nil, LeftSideGesture, (@[LOC(@"GESTURE_NONE"), LOC(@"GESTURE_BRIGHTNESS"), LOC(@"GESTURE_VOLUME"), LOC(@"GESTURE_SPEED")]), 1),
            YMPicker(LOC(@"RIGHT_SIDE_GESTURE"), nil, RightSideGesture, (@[LOC(@"GESTURE_NONE"), LOC(@"GESTURE_BRIGHTNESS"), LOC(@"GESTURE_VOLUME"), LOC(@"GESTURE_SPEED")]), 2),
            YMToggle(LOC(@"GESTURE_HUD"), LOC(@"GESTURE_HUD_DESC"), GestureHUD),
            YMPicker(LOC(@"GESTURE_HUD_SIZE"), LOC(@"GESTURE_HUD_SIZE_DESC"), GestureHUDSize, (@[LOC(@"SMALL"), LOC(@"NORMAL"), LOC(@"LARGE"), LOC(@"EXTRALARGE"), LOC(@"MAX")]), 1),
            YMPicker(LOC(@"GESTURE_HUD_POSITION"), LOC(@"GESTURE_HUD_POSITION_DESC"), GestureHUDPosition, (@[LOC(@"TOP"), LOC(@"MIDDLE"), LOC(@"BOTTOM")]), 0),
            YMHeader(@""),
            YMToggle(LOC(@"TAP_TO_SEEK"), LOC(@"TAP_TO_SEEK_DESC"), TapToSeek),
            YMToggle(LOC(@"SEEK_ON_OVERLAY"), LOC(@"SEEK_ON_OVERLAY_DESC"), SeekOnOverlay),
            YMToggle(LOC(@"PAUSE_TWO_FINGERS"), LOC(@"PAUSE_TWO_FINGERS_DESC"), PauseTwoFingers),
            YMToggle(LOC(@"PAUSE_ON_OVERLAY"), LOC(@"PAUSE_ON_OVERLAY_DESC"), PauseOnOverlay),
            YMToggle(LOC(@"COPY_TIMESTAMP_ON_PAUSE"), LOC(@"COPY_TIMESTAMP_ON_PAUSE_DESC"), CopyWithTimestampOnPause),
            YMToggle(LOC(@"DISABLES_DOUBLE_TAP"), LOC(@"DISABLES_DOUBLE_TAP_DESC"), DisablesDoubleTap),
            YMToggle(LOC(@"DISABLES_LONG_HOLD"), LOC(@"DISABLES_LONG_HOLD_DESC"), DisablesLongHold),
            YMToggle(LOC(@"DISABLES_ZOOM"), LOC(@"DISABLES_ZOOM_DESC"), DisablesFreeZoom),
            YMToggle(LOC(@"DISABLES_SNAP_TO_CHAPTER"), LOC(@"DISABLES_SNAP_TO_CHAPTER_DESC"), DontSnapToChapter),
            YMToggle(LOC(@"DISABLES_ENGAGE_PANEL"), LOC(@"DISABLES_ENGAGE_PANEL_DESC"), DisablesEngagementPanel),
        ], settingsViewController, [self parentResponder]);
        return YES;
    }];
    YTIIcon *icon3 = [%c(YTIIcon) new];
    icon3.iconType = 658;
    playergroup.settingIcon = icon3;
    [sectionItems addObject:playergroup];

    // Section 6
    // Shorts
    YTSettingsSectionItem *shortsgroup = [YTSettingsSectionItemClass itemWithTitle:LOC(@"SHORTS") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        YMPushSubSettings(LOC(@"SHORTS"), @[
            YMTextSegment(LOC(@"SHORTS_ACTION"), ShortsActionIndex, (@[LOC(@"LOOP"), LOC(@"SKIP_TO_NEXT_SHORTS"), LOC(@"PAUSE_SHORTS")]), 0),
            YMToggle(LOC(@"ENABLES_SHORTS_QUALITY"), LOC(@"ENABLES_SHORTS_QUALITY_DESC"), EnablesShortsQuality),
            YMToggle(LOC(@"SHOW_SHORTS_SEEKBAR"), LOC(@"SHOW_SHORTS_SEEKBAR_DESC"), ShowShortsSeekbar),
            YMToggle(LOC(@"SHORTS_ONLY"), LOC(@"SHORTS_ONLY_DESC"), ShortsOnly),
            YMToggle(LOC(@"SHORTS_FULLSCREEN"), LOC(@"SHORTS_FULLSCREEN_DESC"), FullScreenShorts),
            YMToggle(LOC(@"REMOVE_LIVE_SHORTS"), LOC(@"REMOVE_LIVE_SHORTS_DESC"), RemoveShortsLive),
            YMToggle(LOC(@"REMOVE_POSTS_SHORTS"), LOC(@"REMOVE_POSTS_SHORTS_DESC"), RemoveShortsPosts),
            YMHeader(LOC(@"INTERFACE")),
            YMToggle(LOC(@"HIDE_SHORTS_PRODUCT"), LOC(@"HIDE_SHORTS_PRODUCT_DESC"), HideShortsProducts),
            YMToggle(LOC(@"HIDE_SHORTS_RECBAR"), LOC(@"HIDE_SHORTS_RECBAR_DESC"), HideShortsRecbar),
        ], settingsViewController, [self parentResponder]);
        return YES;
    }];
    YTIIcon *icon4 = [%c(YTIIcon) new];
    icon4.iconType = 769;
    shortsgroup.settingIcon = icon4;
    [sectionItems addObject:shortsgroup];

    // Section 7
    // Tab bar
    YTSettingsSectionItem *tabgroup = [YTSettingsSectionItemClass itemWithTitle:LOC(@"TABBAR") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        // Build dynamic image list from enabled tabs (standard + custom)
        NSDictionary *tabYTIconMap = @{@"home": @(65), @"shorts": @(769), @"subscriptions": @(66), @"library": @(61)};
        NSDictionary *tabBundleIconMap = @{@"history": @"icons/history", @"gaming": @"icons/gaming", @"sports": @"icons/sports", @"notifications": @"icons/noti", @"news": @"icons/news", @"music": @"icons/music", @"watchlater": @"icons/watchlater", @"playlist": @"icons/playlist", @"like": @"icons/like", @"live": @"icons/live", @"post": @"icons/post", @"video": @"icons/video", @"movie": @"icons/movie", @"course": @"icons/course", @"minigame": @"icons/minigame"};
        NSBundle *ymBundle = [NSBundle bundleWithPath:[[NSBundle mainBundle] pathForResource:@"YouMod" ofType:@"bundle"]];
        YTAssetLoader *assetLoader = [[%c(YTAssetLoader) alloc] initWithBundle:ymBundle];

        NSMutableArray<UIImage *> *defaultTabImages = [NSMutableArray array];
        NSArray *savedOrder = [[NSUserDefaults standardUserDefaults] arrayForKey:TabOrder];
        if (savedOrder.count > 0) {
            for (NSDictionary *entry in savedOrder) {
                if (![entry[@"enabled"] boolValue]) continue;
                NSString *tabID = entry[@"id"];
                if ([tabID isEqualToString:@"create"]) continue;
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
        }
        if (defaultTabImages.count == 0) {
            NSArray *fallbackIcons = @[@(65), @(769), @(66), @(61)];
            for (NSNumber *iconType in fallbackIcons) {
                UIImage *img = YouModYTIconImage([iconType intValue], YES, [UIColor whiteColor]);
                if (img) [defaultTabImages addObject:img];
            }
        }

        YMPushSubSettings(LOC(@"TABBAR"), @[
            YMImageSegment(LOC(@"DEFAULT_TAB"), DefaultTab, defaultTabImages, 0),
            YMTextSegment(LOC(@"FORSTED_TAB_BAR"), UseFrostedTabBar, (@[LOC(@"DEFAULT"),LOC(@"ENABLED"), LOC(@"DISABLED")]), 0),
            YMToggle(LOC(@"HIDE_TAB_INDI"), LOC(@"HIDE_TAB_INDI_DESC"), HideTabIndi),
            YMToggle(LOC(@"HIDE_TAB_LABELS"), LOC(@"HIDE_TAB_LABELS_DESC"), HideTabLabels),
            YMAction(LOC(@"MANAGE_TABS"), LOC(@"MANAGE_TABS_DESC"), ^(UIViewController *vc) {
                (void)vc;
                YMPushTabOrder(settingsViewController, [self parentResponder]);
            }),
        ], settingsViewController, [self parentResponder]);
        return YES;
    }];
    YTIIcon *icon5 = [%c(YTIIcon) new];
    icon5.iconType = 66;
    tabgroup.settingIcon = icon5;
    [sectionItems addObject:tabgroup];

    // Section 8
    // Miscellaneous
    YTSettingsSectionItem *othergroup = [YTSettingsSectionItemClass itemWithTitle:LOC(@"MISCELLANEOUS") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        YMPushSubSettings(LOC(@"MISCELLANEOUS"), @[
            YMToggle(LOC(@"BACKGROUND_PLAYBACK"), LOC(@"BACKGROUND_PLAYBACK_DESC"), BackgroundPlayback),
            YMToggle(LOC(@"DISABLES_SHORTS_PIP"), LOC(@"DISABLES_SHORTS_PIP_DESC"), DisablesShortsPiP),
            YMToggle(LOC(@"DISABLE_HINTS"), LOC(@"DISABLE_HINTS_DESC"), DisableHints),
            YMToggle(LOC(@"BLOCK_UPGRADE_DIALOGS"), LOC(@"BLOCK_UPGRADE_DIALOGS_DESC"), BlockUpgradeDialogs),
            YMToggle(LOC(@"ARE_YOU_THERE_DIALOG"), LOC(@"ARE_YOU_THERE_DIALOG_DESC"), HideAreYouThereDialog),
            YMToggle(LOC(@"FIXES_SLOW_MINIPLAYER"), LOC(@"FIXES_SLOW_MINIPLAYER_DESC"), FixesSlowMiniPlayer),
            YMToggle(LOC(@"DISABLES_NEW_MINIPLAYER"), LOC(@"DISABLES_NEW_MINIPLAYER_DESC"), DisablesNewMiniPlayer),
            YMToggle(LOC(@"DISABLES_SNACK_BAR"), LOC(@"DISABLES_SNACK_BAR_DESC"), DisablesSnackBar),
            YMToggle(LOC(@"HIDE_STARTUP_ANIMATIONS"), LOC(@"HIDE_STARTUP_ANIMATIONS_DESC"), HideStartupAni),
            YMToggle(LOC(@"HIDE_LIKE_DISLIKE_VOTES"), LOC(@"HIDE_LIKE_DISLIKE_VOTES_DESC"), HideLikeDislikeVotes),
            YMToggle(LOC(@"HIDE_COMMU_GUIDE"), LOC(@"HIDE_COMMU_GUIDE_DESC"), HideCommuGuide),
            YMToggle(LOC(@"FLOATING_KEYBOARD"), LOC(@"FLOATING_KEYBOARD_DESC"), FloatingKeyboard),
            YMToggle(LOC(@"DISABLES_RTL"), LOC(@"DISABLES_RTL_DESC"), DisablesRTL),
            YMHeader(@""),
            YMTextSegment(LOC(@"DEVICE_UI"), DeviceUIIndex, (@[LOC(@"DEFAULT"), LOC(@"iPad"), LOC(@"iPhone")]), 0),
            YMToggle(LOC(@"AUTO_OPEN_LINK"), LOC(@"AUTO_OPEN_LINK_DESC"), AutoOpenLink),
            YMHeader(LOC(@"FLYOUT_MENU")),
            YMToggle(LOC(@"REMOVE_PLAY_IN_NEXT_QUEUE_OPTION"), LOC(@"REMOVE_PLAY_IN_NEXT_QUEUE_OPTION_DESC"), RemovePlayInNextQueueOption),
            YMToggle(LOC(@"REMOVE_DOWNLOAD_OPTION"), LOC(@"REMOVE_DOWNLOAD_OPTION_DESC"), RemoveDownloadOption),
            YMToggle(LOC(@"REMOVE_WATCH_LATER_OPTION"), LOC(@"REMOVE_WATCH_LATER_OPTION_DESC"), RemoveWatchLaterOption),
            YMToggle(LOC(@"REMOVE_SAVE_OPTION"), LOC(@"REMOVE_SAVE_OPTION_DESC"), RemoveSaveOption),
            YMToggle(LOC(@"REMOVE_REMOVE_FROM_PLAYLIST_OPTION"), LOC(@"REMOVE_REMOVE_FROM_PLAYLIST_OPTION_DESC"), RemoveRemoveFromPlaylistOption),
            YMToggle(LOC(@"REMOVE_SHARE_OPTION"), LOC(@"REMOVE_SHARE_OPTION_DESC"), RemoveShareOption),
            YMToggle(LOC(@"REMOVE_NOT_INTERESTED_OPTION"), LOC(@"REMOVE_NOT_INTERESTED_OPTION_DESC"), RemoveNotInterestedOption),
            YMToggle(LOC(@"REMOVE_DONT_RECOMMEND_OPTION"), LOC(@"REMOVE_DONT_RECOMMEND_OPTION_DESC"), RemoveDontRecommendOption),
            YMToggle(LOC(@"REMOVE_INFO_OPTION"), LOC(@"REMOVE_INFO_OPTION_DESC"), RemoveInfoOption),
            YMToggle(LOC(@"REMOVE_FILTER_OPTION"), LOC(@"REMOVE_FILTER_OPTION_DESC"), RemoveFilterOption),
            YMToggle(LOC(@"REMOVE_REPORT_OPTION"), LOC(@"REMOVE_REPORT_OPTION_DESC"), RemoveReportOption),
            YMToggle(LOC(@"REMOVE_YOUTUBE_MUSIC_OPTION"), LOC(@"REMOVE_YOUTUBE_MUSIC_OPTION_DESC"), RemoveYouTubeMusicOption),
            YMToggle(LOC(@"REMOVE_FEED_BACK_OPTION"), LOC(@"REMOVE_FEED_BACK_OPTION_DESC"), RemoveFeedBackOption),
            YMToggle(LOC(@"REMOVE_CAST_OPTION"), LOC(@"REMOVE_CAST_OPTION_DESC"), RemoveCastOption),
            YMToggle(LOC(@"REMOVE_SHUFFLE_OPTION"), LOC(@"REMOVE_SHUFFLE_OPTION_DESC"), RemoveShuffleOption),
            YMToggle(LOC(@"REMOVE_UN_SUB_OPTION"), LOC(@"REMOVE_UN_SUB_OPTION_DESC"), RemoveUnSubOption),
            YMToggle(LOC(@"REMOVE_HIDE_FROM_PLAYLIST_OPTION"), LOC(@"REMOVE_HIDE_FROM_PLAYLIST_OPTION_DESC"), RemoveHideFromPlaylistOption),
            YMToggle(LOC(@"REMOVE_HELP_OPTION"), LOC(@"REMOVE_HELP_OPTION_DESC"), RemoveHelpOption),
            YMToggle(LOC(@"REMOVE_NOTIFY_OPTION"), LOC(@"REMOVE_NOTIFY_OPTION_DESC"), RemoveNotifyOption),
            YMToggle(LOC(@"REMOVE_CLEARSCREEN_OPTION"), LOC(@"REMOVE_CLEARSCREEN_OPTION_DESC"), RemoveClearScreenOption),
        ], settingsViewController, [self parentResponder]);
        return YES;
    }];
    YTIIcon *icon6 = [%c(YTIIcon) new];
    icon6.iconType = 1101;
    othergroup.settingIcon = icon6;
    [sectionItems addObject:othergroup];

    // Section: SponsorBlock
    YTSettingsSectionItem *sponsorblockgroup = [YTSettingsSectionItemClass itemWithTitle:@"SponsorBlock" accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        [self updateSponsorBlockSectionWithEntry:entry];
        return YES;
    }];
    YTIIcon *iconSB = [%c(YTIIcon) new];
    iconSB.iconType = 610;
    sponsorblockgroup.settingIcon = iconSB;
    [sectionItems addObject:sponsorblockgroup];

    // Section 9
    // Perferences
    YTSettingsSectionItem *perfgroup = [YTSettingsSectionItemClass itemWithTitle:LOC(@"PERFER_HEADER") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        YMPushSubSettings(LOC(@"PERFER_HEADER"), @[
            YMHeader(LOC(@"PERFER")),
            YMAction(LOC(@"IMPORT"), LOC(@"IMPORT_DESC"), ^(UIViewController *vc) {
                Class alertClass = NSClassFromString(@"YTAlertView");
                YTAlertView *alertView = [alertClass confirmationDialogWithAction:^{
                    [[YouModPrefsManager sharedManager] importYouModSettingsFromVC:vc];
                } actionTitle:LOC(@"YES")];
                alertView.title = LOC(@"WARNING");
                alertView.subtitle = LOC(@"OVERRIDE");
                [alertView show];
            }),
            YMAction(LOC(@"EXPORT"), LOC(@"EXPORT_DESC"), ^(UIViewController *vc) {
                [[YouModPrefsManager sharedManager] exportYouModSettingsFromVC:vc];
            }),
            YMAction(LOC(@"RESTORE"), LOC(@"RESTORE_DESC"), ^(UIViewController *vc) {
                [[YouModPrefsManager sharedManager] restoreYouModDefaults];
            }),
            YMHeader(LOC(@"CACHE")),
            YMAction(LOC(@"CLEARCACHE"), GetCacheSize(), ^(UIViewController *vc) {
                __weak UIViewController *weakVC = vc;
                NSString *clearTitle = LOC(@"CLEARCACHE");
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
                                if ([cell.textLabel.text isEqualToString:LOC(@"CLEARCACHE")]) {
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
            YMToggle(LOC(@"AUTO_CLEARCACHE"), LOC(@"AUTO_CLEARCACHE_DESC"), AutoClearCache),
        ], settingsViewController, [self parentResponder]);
        return YES;
    }];
    YTIIcon *icon7 = [%c(YTIIcon) new];
    icon7.iconType = 530;
    perfgroup.settingIcon = icon7;
    [sectionItems addObject:perfgroup];

    if ([settingsViewController respondsToSelector:@selector(setSectionItems:forCategory:title:icon:titleDescription:headerHidden:)]) {
        YTIIcon *icon = [%c(YTIIcon) new];
        icon.iconType = YT_TUNE;
        [settingsViewController setSectionItems:sectionItems forCategory:TweakSection title:TweakName icon:icon titleDescription:nil headerHidden:NO];
    } else
        [settingsViewController setSectionItems:sectionItems forCategory:TweakSection title:TweakName titleDescription:nil headerHidden:NO];
}

- (void)updateSectionForCategory:(NSUInteger)category withEntry:(id)entry {
    if (category == TweakSection) {
        [self updateYouModSectionWithEntry:entry];
        return;
    }
    %orig;
}

%end

%ctor {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        AutoClearCache: @YES,
        YTPremiumLogo: @YES,
        HideCastButtonNav: @YES,
        HideCastButtonPlayer: @YES,
        BackgroundPlayback: @YES,
        DownloadManager: @YES,
        DownloadSaveToPhotos: @YES,
        DisableHints: @YES,
        RewindSeconds: @10.0,
        ForwardSeconds: @10.0,
    }];
    %init;
}

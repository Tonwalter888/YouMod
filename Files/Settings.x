// Settings.x
// Thanks to the original codes from YTUHD by PoomSmart - https://github.com/PoomSmart/YTUHD/blob/0e735616fd8fc6546339da7fdc78466f16f23ffd/Settings.x
#import "Headers.h"

#define TweakName @"YouMod"

#define YMLOC(x) [YouModBundle() localizedStringForKey:x value:nil table:nil]
#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)

static const NSInteger TweakSection = 'ytmo';

@interface YMSettingsItem : NSObject
- (instancetype)visibleWhenKey:(NSString *)key equals:(NSInteger)value; // show row only while INTFORVAL(key)==value
- (instancetype)visibleWhenBoolKey:(NSString *)key equals:(BOOL)value;
- (instancetype)visibleWhenBoolKey:(NSString *)key;
- (instancetype)visibleWhenKey:(NSString *)key isGreaterThan:(NSInteger)value;
@end
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
extern void YMRegisterSettingsGroup(NSString *title, NSArray<YMSettingsItem *> *items);
extern void YMPushSettingsSearch(id settingsVC, id parentResponder);

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
    YTSettingsSectionItem *issues = [YTSettingsSectionItemClass itemWithTitle:YMLOC(@"NEW_ISSUES")
        titleDescription:YMLOC(@"NEW_ISSUES_DESC") // Found bug or Feature request -> Report Issues
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            return [%c(YTUIUtils) openURL:[NSURL URLWithString:@"https://github.com/Tonwalter888/YouMod/issues/new/choose"]];
        }
    ];
    [sectionItems addObject:issues];

    // Sources codes
    YTSettingsSectionItem *sourceCodes = [YTSettingsSectionItemClass itemWithTitle:YMLOC(@"SOURCE_CODES")
        titleDescription:YMLOC(@"SOURCE_CODES_DESC") // Take a look
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            return [%c(YTUIUtils) openURL:[NSURL URLWithString:@"https://github.com/Tonwalter888/YouMod"]];
        }
    ];
    [sectionItems addObject:sourceCodes];

    // ?
    YTSettingsSectionItem *blank = [YTSettingsSectionItemClass itemWithTitle:nil
        titleDescription:YMLOC(@"EXTRA")
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            return NO;
        }];
    [sectionItems addObject:blank];

    // Fix playback issues
    YTSettingsSectionItem *fixPlaybackissues = [YTSettingsSectionItemClass switchItemWithTitle:YMLOC(@"FIX_PLAYBACK_ISSUES")
        titleDescription:YMLOC(@"FIX_PLAYBACK_ISSUES_DESC")
        accessibilityIdentifier:nil
        switchOn:IS_ENABLED(FixPlaybackIssues)
        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:FixPlaybackIssues];
            return YES;
        }
        settingItemId:0];
    [sectionItems addObject:fixPlaybackissues];

    // TODO: Center YT logo (not yet implemented)
    // [sectionItems addObject: YMToggle(YMLOC(@"CENTER_YT_LOGO"), YMLOC(@"CENTER_YT_LOGO_DESC"), CenterYTLogo)];

    // Settings
    YTSettingsSectionItem *settings = [YTSettingsSectionItemClass itemWithTitle:nil
        titleDescription:YMLOC(@"SETTINGS")
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            return NO;
        }];
    [sectionItems addObject:settings];

    // Search — opens the global settings search page. The top-level list is YouTube's
    // native settings collection view, which we can't attach a live search bar to
    // without triggering YouTube's own search mode (it hijacks the pane), so global
    // search lives on a pushed page whose own search bar is focused on appear.
    // No settingIcon: YouTube already uses the magnifier (YT_SEARCH) for the Navbar
    // row, so an icon here would duplicate it. The row's title carries the meaning.
    YTSettingsSectionItem *search = [YTSettingsSectionItemClass itemWithTitle:YMLOC(@"SEARCH")
        titleDescription:YMLOC(@"SEARCH_DESC")
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            YMPushSettingsSearch(settingsViewController, [self parentResponder]);
            return YES;
        }];
    [sectionItems addObject:search];

    // Section 1
    // Downloading
    NSArray<YMSettingsItem *> *downloadingItems = @[
            YMToggle(YMLOC(@"DOWNLOAD_MANAGER"), YMLOC(@"DOWNLOAD_MANAGER_DESC"), DownloadManager),
            YMToggle(YMLOC(@"DOWNLOAD_SAVE_PHOTOS"), YMLOC(@"DOWNLOAD_SAVE_PHOTOS_DESC"), DownloadSaveToPhotos),
            YMTextSegment(YMLOC(@"AUDIO_TRACK"), AudioPreferIndex, (@[YMLOC(@"SHOW_OPTIONS"), YMLOC(@"ORIGINAL"), YMLOC(@"ENGLISH")]), 0),
            YMToggle(YMLOC(@"ADD_SHORTS_DOWNLOAD"), YMLOC(@"ADD_SHORTS_DOWNLOAD_DESC"), AddDownloadToShorts),
            YMPicker(YMLOC(@"DOWNLOAD_METHOD"), YMLOC(@"DOWNLOAD_METHOD_DESC"), DownloadMethod, (@[YMLOC(@"METHOD_DIRECT"), YMLOC(@"METHOD_SERVER"), YMLOC(@"METHOD_ONDEVICE")]), 0),
            [YMPicker(YMLOC(@"DOWNLOAD_SERVER"), YMLOC(@"CHOOSE_DOWNLOAD_SERVER"), DownloadServerIndex, (@[YMLOC(@"SERVER_EUROPRE1"), YMLOC(@"SERVER_ASIA1")]), 0) visibleWhenKey:DownloadMethod equals:1],
            YMToggle(YMLOC(@"DOWNLOAD_COMMENT"), YMLOC(@"DOWNLOAD_COMMENT_DESC"), DownloadComment),
            YMToggle(YMLOC(@"DOWNLOAD_POST"), YMLOC(@"DOWNLOAD_POST_DESC"), DownloadPost),
    ];
    YMRegisterSettingsGroup(YMLOC(@"DOWNLOADING"), downloadingItems);
    YTSettingsSectionItem *downloadinggroup = [YTSettingsSectionItemClass itemWithTitle:YMLOC(@"DOWNLOADING") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        YMPushSubSettings(YMLOC(@"DOWNLOADING"), downloadingItems, settingsViewController, [self parentResponder]);
        return YES;
    }];
    YTIIcon *downloadIcon = [%c(YTIIcon) new];
    downloadIcon.iconType = 57;
    downloadinggroup.settingIcon = downloadIcon;
    [sectionItems addObject:downloadinggroup];

    // Section 2
    // Appearance
    NSArray<YMSettingsItem *> *appearanceItems = @[
            YMToggle(YMLOC(@"OLED_THEME"), YMLOC(@"OLED_THEME_DESC"), OLEDTheme),
            YMToggle(YMLOC(@"OLED_KEYBOARD"), YMLOC(@"OLED_KEYBOARD_DESC"), OLEDKeyboard),
    ];
    YMRegisterSettingsGroup(YMLOC(@"APPEARANCE"), appearanceItems);
    YTSettingsSectionItem *appergroup = [YTSettingsSectionItemClass itemWithTitle:YMLOC(@"APPEARANCE") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        YMPushSubSettings(YMLOC(@"APPEARANCE"), appearanceItems, settingsViewController, [self parentResponder]);
        return YES;
    }];
    YTIIcon *icon0 = [%c(YTIIcon) new];
    icon0.iconType = 921;
    appergroup.settingIcon = icon0;
    [sectionItems addObject:appergroup];

    // Section 3
    // Navigation bar
    NSArray<YMSettingsItem *> *navbarItems = @[
            YMToggle(YMLOC(@"STICKY_NAVBAR"), YMLOC(@"STICKY_NAVBAR_DESC"), StickyNavBar),
            YMToggle(YMLOC(@"HIDE_NOTIFICATION_BUTTON"), YMLOC(@"HIDE_NOTIFICATION_BUTTON_DESC"), HideNoti),
            YMToggle(YMLOC(@"HIDE_SEARCH_BUTTON"), YMLOC(@"HIDE_SEARCH_BUTTON_DESC"), HideSearch),
            YMToggle(YMLOC(@"HIDE_VOICE_SEARCH_BUTTON"), YMLOC(@"HIDE_VOICE_SEARCH_BUTTON_DESC"), HideVoiceSearch),
            YMToggle(YMLOC(@"HIDE_CAST_BUTTON_NAVBAR"), YMLOC(@"HIDE_CAST_BUTTON_NAVBAR_DESC"), HideCastButtonNav),
            YMPicker(YMLOC(@"NAVIGATION_ICON"), YMLOC(@"NAVIGATION_ICON_DESC"), YTLogoIndex, (@[YMLOC(@"DEFAULT"), YMLOC(@"PREMIUM"), YMLOC(@"YOUTUBE"), YMLOC(@"REMOVE_YTLOGO")]), 0),
    ];
    YMRegisterSettingsGroup(YMLOC(@"NAVBAR"), navbarItems);
    YTSettingsSectionItem *navbargroup = [YTSettingsSectionItemClass itemWithTitle:YMLOC(@"NAVBAR") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        YMPushSubSettings(YMLOC(@"NAVBAR"), navbarItems, settingsViewController, [self parentResponder]);
        return YES;
    }];
    YTIIcon *icon1 = [%c(YTIIcon) new];
    icon1.iconType = 60;
    navbargroup.settingIcon = icon1;
    [sectionItems addObject:navbargroup];

    // Section 4
    // Feed
    NSArray<YMSettingsItem *> *feedItems = @[
            YMToggle(YMLOC(@"HIDE_SUBBAR"), YMLOC(@"HIDE_SUBBAR_DESC"), HideSubbar),
            YMToggle(YMLOC(@"HIDE_HORI_SHELF"), YMLOC(@"HIDE_HORI_SHELF_DESC"), HideHoriShelf),
            YMToggle(YMLOC(@"HIDE_MUSIC_PLAYLISTS"), YMLOC(@"HIDE_MUSIC_PLAYLISTS_DESC"), HideGenMusicShelf),
            YMToggle(YMLOC(@"HIDE_SURVEYS"), YMLOC(@"HIDE_SURVEYS_DESC"), HideSurveys),
            YMToggle(YMLOC(@"HIDE_FEED_POST"), YMLOC(@"HIDE_FEED_POST_DESC"), HideFeedPost),
            YMToggle(YMLOC(@"HIDE_PLAYABLES"), YMLOC(@"HIDE_PLAYABLES_DESC"), HidePlayables),
            YMToggle(YMLOC(@"HIDE_SHORTS_SHELF"), YMLOC(@"HIDE_SHORTS_SHELF_DESC"), HideShortsShelf),
            YMToggle(YMLOC(@"KEEP_SHORTS_SUBSCRIPT"), YMLOC(@"KEEP_SHORTS_SUBSCRIPT_DESC"), KeepShortsSubscript),
            YMToggle(YMLOC(@"HIDE_SEARCH_HISTORY"), YMLOC(@"HIDE_SEARCH_HISTORY_DESC"), HideSearchHis),
    ];
    YMRegisterSettingsGroup(YMLOC(@"FEED"), feedItems);
    YTSettingsSectionItem *feedgroup = [YTSettingsSectionItemClass itemWithTitle:YMLOC(@"FEED") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        YMPushSubSettings(YMLOC(@"FEED"), feedItems, settingsViewController, [self parentResponder]);
        return YES;
    }];
    YTIIcon *icon2 = [%c(YTIIcon) new];
    icon2.iconType = 193;
    feedgroup.settingIcon = icon2;
    [sectionItems addObject:feedgroup];

    // Section 5
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
            YMPicker(YMLOC(@"HOLD_TO_SPEED"), YMLOC(@"HOLD_TO_SPEED_DESC"), HoldToSpeedIndex, (@[YMLOC(@"DEFAULT"), @"0.25x", @"0.5x", @"0.75x", @"1x", @"1.25x", @"1.5x", @"1.75x", @"2x", @"3x", @"4x", @"5x"]), 0),
            [YMToggle(YMLOC(@"LOCK_SPEED"), YMLOC(@"LOCK_SPEED_DESC"), LockSpeed) visibleWhenKey:HoldToSpeedIndex isGreaterThan:0],
            YMHeader(YMLOC(@"INTERFACE")),
            YMToggle(YMLOC(@"MUTE_BUTTON"), YMLOC(@"MUTE_BUTTON_DESC"), MuteButton),
            YMToggle(YMLOC(@"SPEED_BUTTON"), YMLOC(@"SPEED_BUTTON_DESC"), SpeedButton),
            YMToggle(YMLOC(@"QUALITY_BUTTON"), YMLOC(@"QUALITY_BUTTON_DESC"), QualityButton),
            YMToggle(YMLOC(@"SHARE_BUTTON"), YMLOC(@"SHARE_BUTTON_DESC"), ShareButton),
            YMToggle(YMLOC(@"LOOP_BUTTON"), YMLOC(@"LOOP_BUTTON_DESC"), LoopButton),
            YMToggle(YMLOC(@"CAPTION_BUTTON"), YMLOC(@"CAPTION_BUTTON_DESC"), CaptionButton),
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
            // YMToggle(YMLOC(@"USE_ANOTHER_MINIPLAYER"), YMLOC(@"USE_ANOTHER_MINIPLAYER_DESC"), UseAnotherMiniplayer),
            YMToggle(YMLOC(@"PORTRAIT_FULLSCREEN"), YMLOC(@"PORTRAIT_FULLSCREEN_DESC"), PortFull),
            YMToggle(YMLOC(@"HIDE_RELATED_VIDEOS"), YMLOC(@"HIDE_RELATED_VIDEOS_DESC"), HideRelatedVideos),
            YMToggle(YMLOC(@"HIDE_COMMENTS_SECTION"), YMLOC(@"HIDE_COMMENTS_SECTION_DESC"), HideCommentsSection),
            YMToggle(YMLOC(@"HIDE_COMMENTS_PREVIEW"), YMLOC(@"HIDE_COMMENTS_PREVIEW_DESC"), HideCommentsPreview),
            YMPicker(YMLOC(@"DRC_AUDIO_OPTIONS"), YMLOC(@"DRC_AUDIO_OPTIONS_DESC"), AutoDRCAudioIndex, (@[YMLOC(@"DEFAULT"), YMLOC(@"ENABLED"), YMLOC(@"DISABLED")]), 0),
            YMHeader(YMLOC(@"CONTROL_CENTER")),
            YMToggle(YMLOC(@"SKIP_BACKWARD"), YMLOC(@"SKIP_BACKWARD_DESC"), SkipBackwardEnabled),
            [YMSlider(YMLOC(@"REWIND_SECONDS"), nil, RewindSeconds, 5, 60, 5, 10) visibleWhenBoolKey:SkipBackwardEnabled],
            YMToggle(YMLOC(@"SKIP_FORWARD"), YMLOC(@"SKIP_FORWARD_DESC"), SkipForwardEnabled),
            [YMSlider(YMLOC(@"FORWARD_SECONDS"), nil, ForwardSeconds, 5, 60, 5, 10) visibleWhenBoolKey:SkipForwardEnabled],
            YMHeader(YMLOC(@"PLAYER_ACTIONS")),
            YMPicker(YMLOC(@"DEFAULT_SPEED"), YMLOC(@"DEFAULT_SPEED_DESC"), AutoSpeedIndex, (@[YMLOC(@"DISABLED"), @"0.25x", @"0.5x", @"0.75x", @"1x", @"1.25x", @"1.5x", @"1.75x", @"2x", @"3x", @"4x", @"5x"]), 0),
            YMToggle(YMLOC(@"FORCE_MINIPLAYER"), YMLOC(@"FORCE_MINIPLAYER_DESC"), ForceMiniPlayer),
            YMToggle(YMLOC(@"HIDE_CONTENT_WARNING"), YMLOC(@"HIDE_CONTENT_WARNING_DESC"), HideContentWarning),
            YMToggle(YMLOC(@"STOP_AUTOPLAY_VIDEO"), YMLOC(@"STOP_AUTOPLAY_VIDEO_DESC"), StopAutoplayVideo),
            YMToggle(YMLOC(@"AUTO_FULLSCREEN"), YMLOC(@"AUTO_FULLSCREEN_DESC"), AutoFullScreen),
            YMToggle(YMLOC(@"AUTO_EXIT_FULLSCREEN"), YMLOC(@"AUTO_EXIT_FULLSCREEN_DESC"), AutoExitFullScreen),
            YMHeader(YMLOC(@"GESTURE_HEADER")),
            YMToggle(YMLOC(@"GESTURES"), YMLOC(@"GESTURES_DESC"), GestureControls),
            [YMPicker(YMLOC(@"GESTURE_AREA"), YMLOC(@"GESTURE_AREA_DESC"), GestureActivationArea, (@[@"10%", @"15%", @"20%", @"25%", @"30%", @"35%", @"40%", @"45%", @"50%"]), 1) visibleWhenBoolKey:GestureControls],
            [YMPicker(YMLOC(@"LEFT_SIDE_GESTURE"), nil, LeftSideGesture, (@[YMLOC(@"GESTURE_NONE"), YMLOC(@"GESTURE_BRIGHTNESS"), YMLOC(@"GESTURE_VOLUME"), YMLOC(@"GESTURE_SPEED")]), 1) visibleWhenBoolKey:GestureControls],
            [YMPicker(YMLOC(@"RIGHT_SIDE_GESTURE"), nil, RightSideGesture, (@[YMLOC(@"GESTURE_NONE"), YMLOC(@"GESTURE_BRIGHTNESS"), YMLOC(@"GESTURE_VOLUME"), YMLOC(@"GESTURE_SPEED")]), 2) visibleWhenBoolKey:GestureControls],
            [YMToggle(YMLOC(@"GESTURE_HUD"), YMLOC(@"GESTURE_HUD_DESC"), GestureHUD) visibleWhenBoolKey:GestureControls],
            [YMPicker(YMLOC(@"GESTURE_HUD_SIZE"), YMLOC(@"GESTURE_HUD_SIZE_DESC"), GestureHUDSize, (@[YMLOC(@"SMALL"), YMLOC(@"NORMAL"), YMLOC(@"LARGE"), YMLOC(@"EXTRALARGE"), YMLOC(@"MAX")]), 1) visibleWhenBoolKey:GestureHUD],
            [YMPicker(YMLOC(@"GESTURE_HUD_POSITION"), YMLOC(@"GESTURE_HUD_POSITION_DESC"), GestureHUDPosition, (@[YMLOC(@"TOP"), YMLOC(@"MIDDLE"), YMLOC(@"BOTTOM")]), 0) visibleWhenBoolKey:GestureHUD], 
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
    YTSettingsSectionItem *playergroup = [YTSettingsSectionItemClass itemWithTitle:YMLOC(@"PLAYER") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        YMPushSubSettings(YMLOC(@"PLAYER"), playerItems, settingsViewController, [self parentResponder]);
        return YES;
    }];
    YTIIcon *icon3 = [%c(YTIIcon) new];
    icon3.iconType = 658;
    playergroup.settingIcon = icon3;
    [sectionItems addObject:playergroup];

    // Section 6
    // Shorts
    NSArray<YMSettingsItem *> *shortsItems = @[
            YMTextSegment(YMLOC(@"SHORTS_ACTION"), ShortsActionIndex, (@[YMLOC(@"LOOP"), YMLOC(@"SKIP_TO_NEXT_SHORTS"), YMLOC(@"PAUSE_SHORTS")]), 0),
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
            YMToggle(YMLOC(@"REMOVE_SHORTS_LIKE_BUTTON"), YMLOC(@"REMOVE_SHORTS_LIKE_BUTTON_DESC"), RemoveShortsLikeButton),
            YMToggle(YMLOC(@"REMOVE_SHORTS_COMMENT_BUTTON"), YMLOC(@"REMOVE_SHORTS_COMMENT_BUTTON_DESC"), RemoveShortsCommentButton),
            YMToggle(YMLOC(@"REMOVE_SHORTS_REMIX_BUTTON"), YMLOC(@"REMOVE_SHORTS_REMIX_BUTTON_DESC"), RemoveShortsShareButton),
            YMToggle(YMLOC(@"REMOVE_SHORTS_SOUNDMETADATA_BUTTON"), YMLOC(@"REMOVE_SHORTS_SOUNDMETADATA_BUTTON_DESC"), RemoveShortsSoundMetadataButton),
    ];
    YMRegisterSettingsGroup(YMLOC(@"SHORTS"), shortsItems);
    YTSettingsSectionItem *shortsgroup = [YTSettingsSectionItemClass itemWithTitle:YMLOC(@"SHORTS") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        YMPushSubSettings(YMLOC(@"SHORTS"), shortsItems, settingsViewController, [self parentResponder]);
        return YES;
    }];
    YTIIcon *icon4 = [%c(YTIIcon) new];
    icon4.iconType = 769;
    shortsgroup.settingIcon = icon4;
    [sectionItems addObject:shortsgroup];

    // Section 7
    // Tab bar
    YTSettingsSectionItem *tabgroup = [YTSettingsSectionItemClass itemWithTitle:YMLOC(@"TABBAR") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        // Build dynamic image list from enabled tabs (standard + custom)
        NSDictionary *tabYTIconMap = @{@"home": @(65), @"shorts": @(769), @"subscriptions": @(66), @"library": @(61)};
        NSDictionary *tabBundleIconMap = @{@"history": @"icons/history", @"gaming": @"icons/gaming", @"sports": @"icons/sports", @"notifications": @"icons/noti", @"news": @"icons/news", @"music": @"icons/music", @"watchlater": @"icons/watchlater", @"playlist": @"icons/playlist", @"like": @"icons/like", @"live": @"icons/live", @"post": @"icons/post", @"video": @"icons/video", @"movie": @"icons/movie", @"course": @"icons/course", @"minigame": @"icons/minigame", @"fashion": @"icons/fashion", @"learning": @"icons/learning"};
        YTAssetLoader *assetLoader = [[%c(YTAssetLoader) alloc] initWithBundle:YouModBundle()];

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

        YMPushSubSettings(YMLOC(@"TABBAR"), @[
            YMImageSegment(YMLOC(@"DEFAULT_TAB"), DefaultTab, defaultTabImages, 0),
            YMTextSegment(YMLOC(@"FORSTED_TAB_BAR"), UseFrostedTabBar, (@[YMLOC(@"DEFAULT"),YMLOC(@"ENABLED"), YMLOC(@"DISABLED")]), 0),
            YMToggle(YMLOC(@"HIDE_TAB_INDI"), YMLOC(@"HIDE_TAB_INDI_DESC"), HideTabIndi),
            YMToggle(YMLOC(@"HIDE_TAB_LABELS"), YMLOC(@"HIDE_TAB_LABELS_DESC"), HideTabLabels),
            YMAction(YMLOC(@"MANAGE_TABS"), YMLOC(@"MANAGE_TABS_DESC"), ^(UIViewController *vc) {
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
    NSArray<YMSettingsItem *> *miscItems = @[
            YMToggle(YMLOC(@"BACKGROUND_PLAYBACK"), YMLOC(@"BACKGROUND_PLAYBACK_DESC"), BackgroundPlayback),
            YMToggle(YMLOC(@"DISABLES_SHORTS_PIP"), YMLOC(@"DISABLES_SHORTS_PIP_DESC"), DisablesShortsPiP),
            YMToggle(YMLOC(@"DISABLE_HINTS"), YMLOC(@"DISABLE_HINTS_DESC"), DisableHints),
            YMToggle(YMLOC(@"BLOCK_UPGRADE_DIALOGS"), YMLOC(@"BLOCK_UPGRADE_DIALOGS_DESC"), BlockUpgradeDialogs),
            YMToggle(YMLOC(@"ARE_YOU_THERE_DIALOG"), YMLOC(@"ARE_YOU_THERE_DIALOG_DESC"), HideAreYouThereDialog),
            YMToggle(YMLOC(@"FIXES_SLOW_MINIPLAYER"), YMLOC(@"FIXES_SLOW_MINIPLAYER_DESC"), FixesSlowMiniPlayer),
            YMToggle(YMLOC(@"DISABLES_NEW_MINIPLAYER"), YMLOC(@"DISABLES_NEW_MINIPLAYER_DESC"), DisablesNewMiniPlayer),
            YMToggle(YMLOC(@"DISABLES_SNACK_BAR"), YMLOC(@"DISABLES_SNACK_BAR_DESC"), DisablesSnackBar),
            YMToggle(YMLOC(@"HIDE_STARTUP_ANIMATIONS"), YMLOC(@"HIDE_STARTUP_ANIMATIONS_DESC"), HideStartupAni),
            YMToggle(YMLOC(@"HIDE_LIKE_DISLIKE_VOTES"), YMLOC(@"HIDE_LIKE_DISLIKE_VOTES_DESC"), HideLikeDislikeVotes),
            YMToggle(YMLOC(@"HIDE_COMMU_GUIDE"), YMLOC(@"HIDE_COMMU_GUIDE_DESC"), HideCommuGuide),
            YMToggle(YMLOC(@"FLOATING_KEYBOARD"), YMLOC(@"FLOATING_KEYBOARD_DESC"), FloatingKeyboard),
            YMToggle(YMLOC(@"DISABLES_RTL"), YMLOC(@"DISABLES_RTL_DESC"), DisablesRTL),
            YMHeader(@""),
            YMTextSegment(YMLOC(@"DEVICE_UI"), DeviceUIIndex, (@[YMLOC(@"DEFAULT"), YMLOC(@"iPad"), YMLOC(@"iPhone")]), 0),
            YMToggle(YMLOC(@"AUTO_OPEN_LINK"), YMLOC(@"AUTO_OPEN_LINK_DESC"), AutoOpenLink),
            YMHeader(YMLOC(@"FLYOUT_MENU")),
            YMToggle(YMLOC(@"REMOVE_PLAY_IN_NEXT_QUEUE_OPTION"), YMLOC(@"REMOVE_PLAY_IN_NEXT_QUEUE_OPTION_DESC"), RemovePlayInNextQueueOption),
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
    YTSettingsSectionItem *othergroup = [YTSettingsSectionItemClass itemWithTitle:YMLOC(@"MISCELLANEOUS") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        YMPushSubSettings(YMLOC(@"MISCELLANEOUS"), miscItems, settingsViewController, [self parentResponder]);
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
    YTSettingsSectionItem *perfgroup = [YTSettingsSectionItemClass itemWithTitle:YMLOC(@"PERFER_HEADER") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        YMPushSubSettings(YMLOC(@"PERFER_HEADER"), @[
            YMHeader(YMLOC(@"PERFER")),
            YMAction(YMLOC(@"IMPORT"), YMLOC(@"IMPORT_DESC"), ^(UIViewController *vc) {
                Class alertClass = NSClassFromString(@"YTAlertView");
                YTAlertView *alertView = [alertClass confirmationDialogWithAction:^{
                    [[YouModPrefsManager sharedManager] importYouModSettingsFromVC:vc];
                } actionTitle:YMLOC(@"YES")];
                alertView.title = YMLOC(@"WARNING");
                alertView.subtitle = YMLOC(@"OVERRIDE");
                [alertView show];
            }),
            YMAction(YMLOC(@"EXPORT"), YMLOC(@"EXPORT_DESC"), ^(UIViewController *vc) {
                [[YouModPrefsManager sharedManager] exportYouModSettingsFromVC:vc];
            }),
            YMAction(YMLOC(@"RESTORE"), YMLOC(@"RESTORE_DESC"), ^(UIViewController *vc) {
                [[YouModPrefsManager sharedManager] restoreYouModDefaults];
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
        DownloadMethod: @2,
        YTLogoIndex: @1,
        HideCastButtonNav: @YES,
        HideCastButtonPlayer: @YES,
        BackgroundPlayback: @YES,
        DownloadManager: @YES,
        DownloadSaveToPhotos: @YES,
        SBButtonKey: @YES,
        DisableHints: @YES,
        RewindSeconds: @10.0,
        ForwardSeconds: @10.0,
    }];
    %init;
}

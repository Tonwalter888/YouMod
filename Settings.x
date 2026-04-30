// Settings.x
// Thanks to the original codes from YTUHD by PoomSmart - https://github.com/PoomSmart/YTUHD/blob/0e735616fd8fc6546339da7fdc78466f16f23ffd/Settings.x
#import "Headers.h"

#define TweakName @"YouMod"

#define LOC(x) [tweakBundle localizedStringForKey:x value:nil table:nil]
#define STRINGIFY(x) #x
#define TOSTRING(x) STRINGIFY(x)

static const NSInteger TweakSection = 'ytmo';

@interface YTSettingsSectionItemManager (YouMod)
- (void)updateYouModSectionWithEntry:(id)entry;
@end

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

// Basic switch item - YTLitePlus
#define BASIC_SWITCH(title, description, key) \
    [YTSettingsSectionItemClass switchItemWithTitle:title \
        titleDescription:description \
        accessibilityIdentifier:nil \
        switchOn:IS_ENABLED(key) \
        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) { \
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:key]; \
            return YES; \
        } \
        settingItemId:0]

%hook YTSettingsGroupData

- (NSArray <NSNumber *> *)orderedCategories {
    if (self.type != 1 || class_getClassMethod(objc_getClass("YTSettingsGroupData"), @selector(tweaks)))
        return %orig;
    NSMutableArray *mutableCategories = %orig.mutableCopy;
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
    YTSettingsSectionItem *tweakVersion = [YTSettingsSectionItemClass itemWithTitle:@"YouMod v1.1.0"
        titleDescription:nil
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            return NO;
        }];
    [sectionItems addObject:tweakVersion];

    // Note
    YTSettingsSectionItem *note = [YTSettingsSectionItemClass itemWithTitle:LOC(@"NOTE")
        titleDescription:nil
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            return NO;
        }];
    [sectionItems addObject:note];

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

    /*
    // Center YT logo
    YTSettingsSectionItem *centerytlogo = [YTSettingsSectionItemClass switchItemWithTitle:LOC(@"CENTER_YT_LOGO")
        titleDescription:LOC(@"CENTER_YT_LOGO_DESC") // Set center logo
        accessibilityIdentifier:nil
        switchOn:IS_ENABLED(CenterYTLogo)
        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:CenterYTLogo];
            return YES;
        }
        settingItemId:0];
    [sectionItems addObject:centerytlogo];
    */

    // Section 1
    // Appearance
    YTSettingsSectionItem *apper = [YTSettingsSectionItemClass itemWithTitle:nil
        titleDescription:LOC(@"APPEARANCE")
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            return NO;
        }];
    [sectionItems addObject:apper];

    // OLED keyboard
    YTSettingsSectionItem *oledkeyboard = [YTSettingsSectionItemClass switchItemWithTitle:LOC(@"OLED_KEYBOARD")
        titleDescription:LOC(@"OLED_KEYBOARD_DESC")
        accessibilityIdentifier:nil
        switchOn:IS_ENABLED(OLEDKeyboard)
        switchBlock:^BOOL (YTSettingsCell *cell, BOOL enabled) {
            [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:OLEDKeyboard];
            return YES;
        }
        settingItemId:0];
    [sectionItems addObject:oledkeyboard];

    // Settings
    YTSettingsSectionItem *settings = [YTSettingsSectionItemClass itemWithTitle:nil
        titleDescription:LOC(@"SETTINGS")
        accessibilityIdentifier:nil
        detailTextBlock:nil
        selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
            return NO;
        }];
    [sectionItems addObject:settings];

    // Section 2
    // Navigation bar
    YTSettingsSectionItem *navbargroup = [YTSettingsSectionItemClass itemWithTitle:LOC(@"NAVBAR") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        NSArray <YTSettingsSectionItem *> *rows = @[
            BASIC_SWITCH(LOC(@"HIDE_YT_LOGO"), LOC(@"HIDE_YT_LOGO_DESC"), HideYTLogo),
            BASIC_SWITCH(LOC(@"PREMIUM_LOGO"), LOC(@"PREMIUM_LOGO_DESC"), YTPremiumLogo),
            BASIC_SWITCH(LOC(@"HIDE_NOTIFICATION_BUTTON"), LOC(@"HIDE_NOTIFICATION_BUTTON_DESC"), HideNoti),
            BASIC_SWITCH(LOC(@"HIDE_SEARCH_BUTTON"), LOC(@"HIDE_SEARCH_BUTTON_DESC"), HideSearch),
            BASIC_SWITCH(LOC(@"HIDE_VOICE_SEARCH_BUTTON"), LOC(@"HIDE_VOICE_SEARCH_BUTTON_DESC"), HideVoiceSearch),
            BASIC_SWITCH(LOC(@"HIDE_CAST_BUTTON_NAVBAR"), LOC(@"HIDE_CAST_BUTTON_NAVBAR_DESC"), HideCastButtonNav),
        ];        
        YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:LOC(@"NAVBAR") pickerSectionTitle:nil rows:rows selectedItemIndex:0 parentResponder:[self parentResponder]];
        [settingsViewController pushViewController:picker];
        return YES;
    }];
    YTIIcon *icon1 = [%c(YTIIcon) new];
    icon1.iconType = 60;
    navbargroup.settingIcon = icon1;
    [sectionItems addObject:navbargroup];

    // Section 3
    // Feed
    YTSettingsSectionItem *feedgroup = [YTSettingsSectionItemClass itemWithTitle:LOC(@"FEED") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        NSArray <YTSettingsSectionItem *> *rows = @[
            BASIC_SWITCH(LOC(@"HIDE_SUBBAR"), LOC(@"HIDE_SUBBAR_DESC"), HideSubbar),
            BASIC_SWITCH(LOC(@"HIDE_MUSIC_PLAYLISTS"), LOC(@"HIDE_MUSIC_PLAYLISTS_DESC"), HideGenMusicShelf),
            BASIC_SWITCH(LOC(@"HIDE_FEED_POST"), LOC(@"HIDE_FEED_POST_DESC"), HideFeedPost),
            // BASIC_SWITCH(LOC(@"HIDE_SHORTS_SHELF"), LOC(@"HIDE_SHORTS_SHELF_DESC"), HideShortsShelf),
            BASIC_SWITCH(LOC(@"HIDE_SEARCH_HISTORY"), LOC(@"HIDE_SEARCH_HISTORY_DESC"), HideSearchHis),
            BASIC_SWITCH(LOC(@"HIDE_SUB_BUTTON"), LOC(@"HIDE_SUB_BUTTON_DESC"), HideSubButton),
            BASIC_SWITCH(LOC(@"HIDE_SHOP_BUTTON"), LOC(@"HIDE_SHOP_BUTTON_DESC"), HideShoppingButton),
            BASIC_SWITCH(LOC(@"HIDE_MEMBER_BUTTON"), LOC(@"HIDE_MEMBER_BUTTON_DESC"), HideMemberButton),
        ];        
        YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:LOC(@"FEED") pickerSectionTitle:nil rows:rows selectedItemIndex:0 parentResponder:[self parentResponder]];
        [settingsViewController pushViewController:picker];
        return YES;
    }];
    YTIIcon *icon2 = [%c(YTIIcon) new];
    icon2.iconType = 193;
    feedgroup.settingIcon = icon2;
    [sectionItems addObject:feedgroup];

    // Section 4
    // Player
    YTSettingsSectionItem *playergroup = [YTSettingsSectionItemClass itemWithTitle:LOC(@"PLAYER") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        NSArray <YTSettingsSectionItem *> *rows = @[
            BASIC_SWITCH(LOC(@"HIDE_AUTOPLAY"), LOC(@"HIDE_AUTOPLAY_DESC"), HideAutoPlayToggle),
            BASIC_SWITCH(LOC(@"HIDE_CAPTIONS_BUTTON"), LOC(@"HIDE_CAPTIONS_BUTTON_DESC"), HideCaptionsButton),
            BASIC_SWITCH(LOC(@"HIDE_CAST_BUTTON_PLAYER"), LOC(@"HIDE_CAST_BUTTON_PLAYER_DESC"), HideCastButtonPlayer),
            BASIC_SWITCH(LOC(@"HIDE_PREV_BUTTON"), LOC(@"HIDE_PREV_BUTTON_DESC"), HidePrevButton),
            BASIC_SWITCH(LOC(@"HIDE_NEXT_BUTTON"), LOC(@"HIDE_NEXT_BUTTON_DESC"), HideNextButton),
            BASIC_SWITCH(LOC(@"REMOVE_DARK_OVERLAY"), LOC(@"REMOVE_DARK_OVERLAY_DESC"), RemoveDarkOverlay),
            BASIC_SWITCH(LOC(@"HIDE_END_SCREEN"), LOC(@"HIDE_END_SCREEN_DESC"), HideEndScreenCards),
            BASIC_SWITCH(LOC(@"HIDE_SUGGESTED_VIDEO"), LOC(@"HIDE_SUGGESTED_VIDEO_DESC"), HideSuggestedVideo),
            BASIC_SWITCH(LOC(@"HIDE_PAID_OVERLAY"), LOC(@"HIDE_PAID_OVERLAY_DESC"), HidePaidPromoOverlay),
            BASIC_SWITCH(LOC(@"HIDE_WATERMARK"), LOC(@"HIDE_WATERMARK_DESC"), HideWaterMark),
            BASIC_SWITCH(LOC(@"GESTURES"), LOC(@"GESTURES_DESC"), GestureControls),
            BASIC_SWITCH(LOC(@"DISABLES_DOUBLE_TAP"), LOC(@"DISABLES_DOUBLE_TAP_DESC"), DisablesDoubleTap),
            BASIC_SWITCH(LOC(@"DISABLES_LONG_HOLD"), LOC(@"DISABLES_LONG_HOLD_DESC"), DisablesLongHold),
            BASIC_SWITCH(LOC(@"AUTO_EXIT_FULLSCREEN"), LOC(@"AUTO_EXIT_FULLSCREEN_DESC"), AutoExitFullScreen),
            BASIC_SWITCH(LOC(@"DISABLES_SHOW_REMAINING"), LOC(@"DISABLES_SHOW_REMAINING_DESC"), DisablesShowRemaining),
            BASIC_SWITCH(LOC(@"ALWAYS_SHOW_REMAINING"), LOC(@"ALWAYS_SHOW_REMAINING_DESC"), AlwaysShowRemaining),
            BASIC_SWITCH(LOC(@"HIDE_FULLSCREEN_ACTIONS"), LOC(@"HIDE_FULLSCREEN_ACTIONS_DESC"), HideFullAction),
            BASIC_SWITCH(LOC(@"HIDE_FULL_VID_TITLE"), LOC(@"HIDE_FULL_VID_TITLE_DESC"), HideFullvidTitle),
            BASIC_SWITCH(LOC(@"STOP_AUTOPLAY_VIDEO"), LOC(@"STOP_AUTOPLAY_VIDEO_DESC"), StopAutoplayVideo),
            BASIC_SWITCH(LOC(@"HIDE_CONTENT_WARNING"), LOC(@"HIDE_CONTENT_WARNING_DESC"), HideContentWarning),
            BASIC_SWITCH(LOC(@"AUTO_FULLSCREEN"), LOC(@"AUTO_FULLSCREEN_DESC"), AutoFullScreen),
            BASIC_SWITCH(LOC(@"PORTRAIT_FULLSCREEN"), LOC(@"PORTRAIT_FULLSCREEN_DESC"), PortFull),
            BASIC_SWITCH(LOC(@"OLD_QUALITY_PICKER"), LOC(@"OLD_QUALITY_PICKER_DESC"), OldQualityPicker),
            BASIC_SWITCH(LOC(@"EXTRA_SPEED"), LOC(@"EXTRA_SPEED_DESC"), ExtraSpeed),
            BASIC_SWITCH(LOC(@"HIDE_LIKE_BUTTON"), LOC(@"HIDE_LIKE_BUTTON_DESC"), HideLikeButton),
            BASIC_SWITCH(LOC(@"HIDE_DISLIKE_BUTTON"), LOC(@"HIDE_DISLIKE_BUTTON_DESC"), HideDisLikeButton),
            BASIC_SWITCH(LOC(@"HIDE_SHARE_BUTTON"), LOC(@"HIDE_SHARE_BUTTON_DESC"), HideShareButton),
            BASIC_SWITCH(LOC(@"HIDE_DOWNLOAD_BUTTON"), LOC(@"HIDE_DOWNLOAD_BUTTON_DESC"), HideDownloadButton),
            BASIC_SWITCH(LOC(@"HIDE_CLIP_BUTTON"), LOC(@"HIDE_CLIP_BUTTON_DESC"), HideClipButton),
            BASIC_SWITCH(LOC(@"HIDE_REMIX_BUTTON"), LOC(@"HIDE_REMIX_BUTTON_DESC"), HideRemixButton),
            BASIC_SWITCH(LOC(@"HIDE_SAVE_BUTTON"), LOC(@"HIDE_SAVE_BUTTON_DESC"), HideSaveButton),
        ];        
        YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:LOC(@"PLAYER") pickerSectionTitle:nil rows:rows selectedItemIndex:0 parentResponder:[self parentResponder]];
        [settingsViewController pushViewController:picker];
        return YES;
    }];
    YTIIcon *icon3 = [%c(YTIIcon) new];
    icon3.iconType = 658;
    playergroup.settingIcon = icon3;
    [sectionItems addObject:playergroup];

    // Section 5
    // Shorts
    YTSettingsSectionItem *shortsgroup = [YTSettingsSectionItemClass itemWithTitle:LOC(@"SHORTS") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        NSArray <YTSettingsSectionItem *> *rows = @[
            BASIC_SWITCH(LOC(@"HIDE_SHORTS_LIKE_BUTTON"), LOC(@"HIDE_SHORTS_LIKE_BUTTON_DESC"), HideShortsLikeButton),
            BASIC_SWITCH(LOC(@"HIDE_SHORTS_DISLIKE_BUTTON"), LOC(@"HIDE_SHORTS_DISLIKE_BUTTON_DESC"), HideShortsDisLikeButton),
            BASIC_SWITCH(LOC(@"HIDE_SHORTS_COMMENT_BUTTON"), LOC(@"HIDE_SHORTS_COMMENT_BUTTON_DESC"), HideShortsCommentButton),
            BASIC_SWITCH(LOC(@"HIDE_SHORTS_SHARE_BUTTON"), LOC(@"HIDE_SHORTS_SHARE_BUTTON_DESC"), HideShortsShareButton),
            BASIC_SWITCH(LOC(@"HIDE_SHORTS_REMIX_BUTTON"), LOC(@"HIDE_SHORTS_REMIX_BUTTON_DESC"), HideShortsRemixButton),
            BASIC_SWITCH(LOC(@"HIDE_METADATA_BUTTON"), LOC(@"HIDE_METADATA_BUTTON_DESC"), HideShortsMetaButton),
            BASIC_SWITCH(LOC(@"HIDE_SHORTS_PRODUCT"), LOC(@"HIDE_SHORTS_PRODUCT_DESC"), HideShortsProducts),
            BASIC_SWITCH(LOC(@"HIDE_SHORTS_RECBAR"), LOC(@"HIDE_SHORTS_RECBAR_DESC"), HideShortsRecbar),
            BASIC_SWITCH(LOC(@"HIDE_SHORTS_COMMIT"), LOC(@"HIDE_SHORTS_COMMIT_DESC"), HideShortsCommit),
            BASIC_SWITCH(LOC(@"HIDE_SHORTS_SUBSCRIPT_BUTTON"), LOC(@"HIDE_SHORTS_SUBSCRIPT_BUTTON_DESC"), HideShortsSubscriptButton),
            BASIC_SWITCH(LOC(@"HIDE_SHORTS_LIVE_BUTTON"), LOC(@"HIDE_SHORTS_LIVE_BUTTON_DESC"), HideShortsLiveButton),
            BASIC_SWITCH(LOC(@"HIDE_SHORTS_LENS_BUTTON"), LOC(@"HIDE_SHORTS_LENS_BUTTON_DESC"), HideShortsLensButton),
            BASIC_SWITCH(LOC(@"HIDE_SHORTS_TRENDS_BUTTON"), LOC(@"HIDE_SHORTS_TRENDS_BUTTON_DESC"), HideShortsTrendsButton),
            BASIC_SWITCH(LOC(@"HIDE_SHORTS_TO_VIDEO"), LOC(@"HIDE_SHORTS_TO_VIDEO_DESC"), HideShortsToVideo),
            BASIC_SWITCH(LOC(@"ENABLES_SHORTS_QUALITY"), LOC(@"ENABLES_SHORTS_QUALITY_DESC"), EnablesShortsQuality),
            BASIC_SWITCH(LOC(@"SHOW_SHORTS_SEEKBAR"), LOC(@"SHOW_SHORTS_SEEKBAR_DESC"), ShowShortsSeekbar),
        ];        
        YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:LOC(@"SHORTS") pickerSectionTitle:nil rows:rows selectedItemIndex:0 parentResponder:[self parentResponder]];
        [settingsViewController pushViewController:picker];
        return YES;
    }];
    YTIIcon *icon4 = [%c(YTIIcon) new];
    icon4.iconType = 769;
    shortsgroup.settingIcon = icon4;
    [sectionItems addObject:shortsgroup];

    // Section 6
    // Tab bar
    YTSettingsSectionItem *tabgroup = [YTSettingsSectionItemClass itemWithTitle:LOC(@"TABBAR") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        NSArray <YTSettingsSectionItem *> *rows = @[
            [YTSettingsSectionItemClass itemWithTitle:LOC(@"DEFAULT_TAB")
            titleDescription:LOC(@"DEFAULT_TAB_DESC")
            accessibilityIdentifier:nil
            detailTextBlock:^NSString *() {
                switch (INTFORVAL(DefaultTab)) {
                    case 1:
                        return LOC(@"Shorts");
                    case 2:
                        return LOC(@"SUBSCRIPT_NAME");
                    case 3:
                        return LOC(@"LIB_NAME");
                    case 0:
                    default:
                        return LOC(@"HOME_NAME");
                }
            }
            selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                NSArray <YTSettingsSectionItem *> *rows = @[
                    [YTSettingsSectionItemClass checkmarkItemWithTitle:LOC(@"HOME_NAME") titleDescription:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:DefaultTab];
                        [settingsViewController reloadData];
                        return YES;
                    }],
                    [YTSettingsSectionItemClass checkmarkItemWithTitle:LOC(@"Shorts") titleDescription:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                        [[NSUserDefaults standardUserDefaults] setInteger:1 forKey:DefaultTab];
                        [settingsViewController reloadData];
                        return YES;
                    }],
                    [YTSettingsSectionItemClass checkmarkItemWithTitle:LOC(@"SUBSCRIPT_NAME") titleDescription:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                        [[NSUserDefaults standardUserDefaults] setInteger:2 forKey:DefaultTab];
                        [settingsViewController reloadData];
                        return YES;
                    }],
                    [YTSettingsSectionItemClass checkmarkItemWithTitle:LOC(@"LIB_NAME") titleDescription:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                        [[NSUserDefaults standardUserDefaults] setInteger:3 forKey:DefaultTab];
                        [settingsViewController reloadData];
                        return YES;
                    }]
                ];
                YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:LOC(@"DEFAULT_TAB") pickerSectionTitle:nil rows:rows selectedItemIndex:INTFORVAL(DefaultTab) parentResponder:[self parentResponder]];
                [settingsViewController pushViewController:picker];
                return YES;
            }],
            BASIC_SWITCH(LOC(@"HIDE_TAB_INDI"), LOC(@"HIDE_TAB_INDI_DESC"), HideTabIndi),
            BASIC_SWITCH(LOC(@"HIDE_TAB_LABELS"), LOC(@"HIDE_TAB_LABELS_DESC"), HideTabLabels),
            BASIC_SWITCH(LOC(@"HIDE_HOME_TAB"), LOC(@"HIDE_HOME_TAB_DESC"), HideHomeTab),
            BASIC_SWITCH(LOC(@"HIDE_SHORTS_TAB"), LOC(@"HIDE_SHORTS_TAB_DESC"), HideShortsTab),
            BASIC_SWITCH(LOC(@"HIDE_CREATE_BUTTON"), LOC(@"HIDE_CREATE_BUTTON_DESC"), HideCreateButton),
            BASIC_SWITCH(LOC(@"HIDE_SUBSCRIPT_TAB"), LOC(@"HIDE_SUBSCRIPT_TAB_DESC"), HideSubscriptTab),
        ];        
        YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:LOC(@"TABBAR") pickerSectionTitle:nil rows:rows selectedItemIndex:0 parentResponder:[self parentResponder]];
        [settingsViewController pushViewController:picker];
        return YES;
    }];
    YTIIcon *icon5 = [%c(YTIIcon) new];
    icon5.iconType = 66;
    tabgroup.settingIcon = icon5;
    [sectionItems addObject:tabgroup];

    // Section 7
    // Miscellaneous
    YTSettingsSectionItem *othergroup = [YTSettingsSectionItemClass itemWithTitle:LOC(@"MISCELLANEOUS") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        NSArray <YTSettingsSectionItem *> *rows = @[
            BASIC_SWITCH(LOC(@"BACKGROUND_PLAYBACK"), LOC(@"BACKGROUND_PLAYBACK_DESC"), BackgroundPlayback),
            BASIC_SWITCH(LOC(@"DISABLES_SHORTS_PIP"), LOC(@"DISABLES_SHORTS_PIP_DESC"), DisablesShortsPiP),
            BASIC_SWITCH(LOC(@"BLOCK_UPGRADE_DIALOGS"), LOC(@"BLOCK_UPGRADE_DIALOGS_DESC"), BlockUpgradeDialogs),
            BASIC_SWITCH(LOC(@"ARE_YOU_THERE_DIALOG"), LOC(@"ARE_YOU_THERE_DIALOG_DESC"), HideAreYouThereDialog),
            BASIC_SWITCH(LOC(@"FIXES_SLOW_MINIPLAYER"), LOC(@"FIXES_SLOW_MINIPLAYER_DESC"), FixesSlowMiniPlayer),
            BASIC_SWITCH(LOC(@"DISABLES_NEW_MINIPLAYER"), LOC(@"DISABLES_NEW_MINIPLAYER_DESC"), DisablesNewMiniPlayer),
            BASIC_SWITCH(LOC(@"DISABLES_SNACK_BAR"), LOC(@"DISABLES_SNACK_BAR_DESC"), DisablesSnackBar),
            BASIC_SWITCH(LOC(@"HIDE_STARTUP_ANIMATIONS"), LOC(@"HIDE_STARTUP_ANIMATIONS_DESC"), HideStartupAni),
            BASIC_SWITCH(LOC(@"HIDE_PLAY_IN_NEXT_QUEUE"), LOC(@"HIDE_PLAY_IN_NEXT_QUEUE_DESC"), HidePlayInNextQueue),
            BASIC_SWITCH(LOC(@"HIDE_LIKE_DISLIKE_VOTES"), LOC(@"HIDE_LIKE_DISLIKE_VOTES_DESC"), HideLikeDislikeVotes),
        ];        
        YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:LOC(@"MISCELLANEOUS") pickerSectionTitle:nil rows:rows selectedItemIndex:0 parentResponder:[self parentResponder]];
        [settingsViewController pushViewController:picker];
        return YES;
    }];
    YTIIcon *icon6 = [%c(YTIIcon) new];
    icon6.iconType = 1101;
    othergroup.settingIcon = icon6;
    [sectionItems addObject:othergroup];

    // Section 8
    // Perferences
    YTSettingsSectionItem *perfgroup = [YTSettingsSectionItemClass itemWithTitle:LOC(@"PERFER_HEADER") accessibilityIdentifier:nil detailTextBlock:nil selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
        NSArray <YTSettingsSectionItem *> *rows = @[
            [YTSettingsSectionItemClass itemWithTitle:nil
                titleDescription:LOC(@"PERFER")
                accessibilityIdentifier:nil
                detailTextBlock:nil
                selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                    return NO;
                }
            ],
            [YTSettingsSectionItemClass itemWithTitle:LOC(@"IMPORT")
                titleDescription:LOC(@"IMPORT_DESC")
                accessibilityIdentifier:nil
                detailTextBlock:nil
                selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                    YTAlertView *alertView = [%c(YTAlertView) confirmationDialogWithAction:^{
                        [[YouModPrefsManager sharedManager] importYouModSettingsFromVC:settingsViewController];
                    } actionTitle:LOC(@"YES")];
                    alertView.title = LOC(@"WARNING");
                    alertView.subtitle = LOC(@"OVERRIDE");
                    [alertView show];
                    return YES;
                }
            ],
            [YTSettingsSectionItemClass itemWithTitle:LOC(@"EXPORT")
                titleDescription:LOC(@"EXPORT_DESC")
                accessibilityIdentifier:nil
                detailTextBlock:nil
                selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                    [[YouModPrefsManager sharedManager] exportYouModSettingsFromVC:settingsViewController];
                    return YES;
                }
            ],
            [YTSettingsSectionItemClass itemWithTitle:LOC(@"RESTORE")
                titleDescription:LOC(@"RESTORE_DESC")
                accessibilityIdentifier:nil
                detailTextBlock:nil
                selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                    [[YouModPrefsManager sharedManager] restoreYouModDefaults];
                    return YES;
                }
            ],
            [YTSettingsSectionItemClass itemWithTitle:nil
                titleDescription:LOC(@"CACHE")
                accessibilityIdentifier:nil
                detailTextBlock:nil
                selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                    return NO;
                }
            ],
            [YTSettingsSectionItemClass itemWithTitle:LOC(@"CLEARCACHE")
                titleDescription:GetCacheSize()
                accessibilityIdentifier:nil
                detailTextBlock:nil
                selectBlock:^BOOL (YTSettingsCell *cell, NSUInteger arg1) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        NSString *cachePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
                        [[NSFileManager defaultManager] removeItemAtPath:cachePath error:nil];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[%c(YTToastResponderEvent) eventWithMessage:LOC(@"DONE") firstResponder:[self parentResponder]] send];
                        });
                    });
                    return YES;
                }
            ],
            BASIC_SWITCH(LOC(@"AUTO_CLEARCACHE"), LOC(@"AUTO_CLEARCACHE_DESC"), AutoClearCache),
        ];        
        YTSettingsPickerViewController *picker = [[%c(YTSettingsPickerViewController) alloc] initWithNavTitle:LOC(@"PERFER_HEADER") pickerSectionTitle:nil rows:rows selectedItemIndex:0 parentResponder:[self parentResponder]];
        [settingsViewController pushViewController:picker];
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
        HideCreateButton: @YES,
        HideCastButtonNav: @YES,
        HideCastButtonPlayer: @YES,
        BackgroundPlayback: @YES,
    }];
    %init;
}
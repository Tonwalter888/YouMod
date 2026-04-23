// All Codes are adapt from YTLite and uYouEnhanced + Some of my research
#import <YouTubeHeader/_ASDisplayView.h>
#import <YouTubeHeader/YTInlinePlayerBarContainerView.h>
#import <YouTubeHeader/YTPlayerBarController.h>
#import "Headers.h"

// Navigation Bar

// YouTube Premium logo
%hook YTHeaderLogoController
- (void)setTopbarLogoRenderer:(YTITopbarLogoRenderer *)renderer {
    if (!IS_ENABLED(YTPremiumLogo)) {
        %orig;
        return;
    }
    // Modify the type of the icon before setting the renderer
    YTIIcon *icon = renderer.iconImage;
    if (icon) {
        icon.iconType = 537;
    }
    %orig(renderer);
}
// For when spoofing before 18.34.5
- (void)setPremiumLogo:(BOOL)arg { IS_ENABLED(YTPremiumLogo) ? %orig(YES) : %orig; }
- (BOOL)isPremiumLogo { return IS_ENABLED(YTPremiumLogo) ? YES : %orig; }
%end

%hook YTHeaderLogoControllerImpl
- (void)setTopbarLogoRenderer:(YTITopbarLogoRenderer *)renderer {
    if (!IS_ENABLED(YTPremiumLogo)) {
        %orig;
        return;
    }
    // Modify the type of the icon before setting the renderer
    YTIIcon *icon = renderer.iconImage;
    if (icon) {
        icon.iconType = 537;
    }
    %orig(renderer);
}
// For when spoofing before 18.34.5
- (void)setPremiumLogo:(BOOL)arg { IS_ENABLED(YTPremiumLogo) ? %orig(YES) : %orig; }
- (BOOL)isPremiumLogo { return IS_ENABLED(YTPremiumLogo) ? YES : %orig; }
%end

// Hide Navigation Bar Buttons
%hook YTRightNavigationButtons
- (void)layoutSubviews {
    %orig;
    if (IS_ENABLED(HideNoti)) self.notificationButton.hidden = YES;
    if (IS_ENABLED(HideSearch)) self.searchButton.hidden = YES;
    for (UIView *subview in self.subviews) {
        if (IS_ENABLED(HideVoiceSearch) && [subview.accessibilityLabel isEqualToString:NSLocalizedString(@"search.voice.access", nil)]) subview.hidden = YES;
        if (IS_ENABLED(HideCastButtonNav) && [subview.accessibilityIdentifier isEqualToString:@"id.mdx.playbackroute.button"]) subview.hidden = YES;
    }
}
%end

%hook YTHeaderLogoController
- (YTHeaderLogoController *)init {
    return IS_ENABLED(HideYTLogo) ? NULL : %orig;
}
%end

%hook YTHeaderLogoControllerImpl
- (YTHeaderLogoController *)init {
    return IS_ENABLED(HideYTLogo) ? NULL : %orig;
}
%end

%hook YTNavigationBarTitleView
- (void)layoutSubviews {
    %orig;
    if (self.subviews.count > 1 && [self.subviews[1].accessibilityIdentifier isEqualToString:@"id.yoodle.logo"] && IS_ENABLED(HideYTLogo)) {
        self.subviews[1].hidden = YES;
    }
}
/*
- (void)setShouldCenterNavBarTitleView:(BOOL)center {
    if (IS_ENABLED(CenterYTLogo)) {
        center = YES;
    }
    %orig(center);
    [self alignCustomViewToCenterOfWindow];
}
- (BOOL)shouldCenterNavBarTitleView {
    return IS_ENABLED(CenterYTLogo) ? YES : %orig;
}
*/
%end

// Hide Subbar
%hook YTMySubsFilterHeaderView
- (void)setChipFilterView:(id)arg1 { if (!(IS_ENABLED(HideSubbar))) %orig; }
%end

%hook YTHeaderContentComboView
- (void)enableSubheaderBarWithView:(id)arg1 { if (!(IS_ENABLED(HideSubbar))) %orig; }
- (void)setFeedHeaderScrollMode:(int)arg1 { IS_ENABLED(HideSubbar) ? %orig(0) : %orig; }
%end

%hook YTChipCloudCell
- (void)layoutSubviews {
    if (self.superview && IS_ENABLED(HideSubbar)) {
        [self removeFromSuperview];
    } %orig;
}
%end

%hook YTIElementRenderer
- (NSData *)elementData {
    NSString *description = [self description];
    NSArray *shortsToRemove = @[@"shorts_shelf.eml", @"shorts_video_cell.eml", @"6Shorts", @"eml.shorts-shelf"];
    for (NSString *shorts in shortsToRemove) {
        if (IS_ENABLED(HideShortsShelf) && [description containsString:shorts] && ![description containsString:@"history*"]) {
            return nil;
        }
    }
    return %orig;
}
%end

// I ran out of ideas
%hook _ASDisplayView

- (void)didMoveToWindow {
    %orig;
    if (IS_ENABLED(HideHoriShelf) && [self.accessibilityIdentifier isEqualToString:@"horizontal-video-shelf.view"]) self.hidden = YES;
	if (IS_ENABLED(HideGenMusicShelf) && [self.accessibilityIdentifier isEqualToString:@"feed_nudge.view"]) self.hidden = YES;
}

%end

%hook YTSearchViewController
- (void)viewDidLoad {
    %orig;
    if (IS_ENABLED(HideVoiceSearch)) {
        [self setValue:@(NO) forKey:@"_isVoiceSearchAllowed"];
    }
}
// - (void)setSuggestions:(id)arg1 {}
%end

/* idk this is a great feature to add or not
%hook YTPersonalizedSuggestionsCacheProvider
- (id)activeCache { return nil; }
%end
*/

/*
// Disable Fullscreen Actions
%hook YTFullscreenActionsView
- (BOOL)enabled { return ytlBool(@"noFullscreenActions") ? NO : YES; }
- (void)setEnabled:(BOOL)arg1 { ytlBool(@"noFullscreenActions") ? %orig(NO) : %orig; }
%end

// Dont Show Related Videos on Finish
%hook YTFullscreenEngagementOverlayController
- (void)setRelatedVideosVisible:(BOOL)arg1 { ytlBool(@"noRelatedVids") ? %orig(NO) : %orig; }
%end
*/

%hook YTMainAppControlsOverlayView
// Hide autoplay Switch
- (void)setAutoplaySwitchButtonRenderer:(id)arg1 { if (!IS_ENABLED(HideAutoPlayToggle)) %orig; }
// Hide captions Button
- (void)setClosedCaptionsOrSubtitlesButtonAvailable:(BOOL)arg1 { if (!IS_ENABLED(HideCaptionsButton)) %orig; }
// Hide cast button
- (id)playbackRouteButton { return IS_ENABLED(HideCastButtonPlayer) ? nil : %orig; }
- (void)setPreviousButtonHidden:(BOOL)arg { if (!IS_ENABLED(HidePrevButton)) %orig; }
- (void)setNextButtonHidden:(BOOL)arg { if (!IS_ENABLED(HideNextButton)) %orig; }

// TEST
- (BOOL)titleViewHidden {
    return YES;
}

// Will disable this if this doesn't work
- (void)layoutSubviews {
	%orig;
    [[self valueForKey:@"_previousButtonView"] setBackgroundColor:nil];
    [[self valueForKey:@"_nextButtonView"] setBackgroundColor:nil];
    [[self valueForKey:@"_seekBackwardAccessibilityButtonView"] setBackgroundColor:nil];
    [[self valueForKey:@"_seekForwardAccessibilityButtonView"] setBackgroundColor:nil];
    [[self valueForKey:@"_playPauseButton"] setBackgroundColor:nil];
}
%end

%hook YTColdConfig
- (BOOL)isLandscapeEngagementPanelEnabled {
    return NO;
}
%end

// Remove Dark Background in Overlay
%hook YTMainAppVideoPlayerOverlayView
- (void)setBackgroundVisible:(BOOL)arg1 isGradientBackground:(BOOL)arg2 { IS_ENABLED(RemoveDarkOverlay) ? %orig(NO, arg2) : %orig; }
// Hide Watermarks
- (BOOL)isWatermarkEnabled { return IS_ENABLED(HideWaterMark) ? NO : %orig; }
- (void)setWatermarkEnabled:(BOOL)arg { IS_ENABLED(HideWaterMark) ? %orig(NO) : %orig; }
- (id)playbackRouteButton { return IS_ENABLED(HideCastButtonPlayer) ? nil : %orig; }
%end

// No Endscreen Cards
%hook YTCreatorEndscreenView
- (void)setHidden:(BOOL)arg1 { IS_ENABLED(HideEndScreenCards) ? %orig(YES) : %orig; }
- (void)setHoverCardHidden:(BOOL)arg { IS_ENABLED(HideEndScreenCards) ? %orig(YES) : %orig; }
- (void)setHoverCardRenderer:(id)arg { if (!IS_ENABLED(HideEndScreenCards)) %orig; }
%end

%hook YTMainAppVideoPlayerOverlayViewController
// Disable Double Tap To Seek
- (BOOL)allowDoubleTapToSeekGestureRecognizer { return IS_ENABLED(DisablesDoubleTap) ? NO : %orig; }
// Disable long hold
- (BOOL)allowLongPressGestureRecognizerInView:(id)arg { return IS_ENABLED(DisablesLongHold) ? NO : %orig; }
%end

// Remove Watermarks
%hook YTAnnotationsViewController
- (void)loadFeaturedChannelWatermark { if (!IS_ENABLED(HideWaterMark)) %orig; }
%end

// Exit Fullscreen on Finish
%hook YTWatchFlowController
- (BOOL)shouldExitFullScreenOnFinish { return IS_ENABLED(AutoExitFullScreen) ? YES : %orig; }
%end


%hook YTHotConfig
- (BOOL)enableOmitAdvancedMenuInShortsVideoQualityPicker { return YES; }
- (BOOL)enableShortsVideoQualityPicker { return YES; }
- (BOOL)iosEnableImmersiveLivePlayerVideoQuality { return YES; }
- (BOOL)iosEnableShortsPlayerVideoQuality { return YES; }
- (BOOL)iosEnableShortsPlayerVideoQualityRestartVideo { return YES; }
- (BOOL)iosEnableSimplerTitleInShortsVideoQualityPicker { return YES; }
%end

%hook YTShortsPlayerViewController
- (BOOL)shouldAlwaysEnablePlayerBar { return YES; }
- (BOOL)shouldEnablePlayerBarOnlyOnPause { return NO; }
%end

%hook YTReelPlayerViewController
- (BOOL)shouldAlwaysEnablePlayerBar { return YES; }
- (BOOL)shouldEnablePlayerBarOnlyOnPause { return NO; }
%end

%hook YTReelPlayerViewControllerSub
- (BOOL)shouldAlwaysEnablePlayerBar { return YES; }
- (BOOL)shouldEnablePlayerBarOnlyOnPause { return NO; }
%end

%hook YTColdConfig
- (BOOL)iosEnableVideoPlayerScrubber { return YES; }
- (BOOL)mobileShortsTablnlinedExpandWatchOnDismiss { return YES; }
%end

%hook YTHotConfig
- (BOOL)enablePlayerBarForVerticalVideoWhenControlsHiddenInFullscreen { return YES; }
%end

%hook YTColdConfig
- (BOOL)mainAppCoreClientIosEnableStartupAnimation {  // Works!
    return NO;
}
%end

%hook YTHeaderView
- (BOOL)stickyNavHeaderEnabled { return YES; } 
%end

/*
%hook YTColdConfig
- (BOOL)removeNextPaddleForAllVideos { 
    return YES; 
}
- (BOOL)removePreviousPaddleForAllVideos { 
    return YES; 
}
%end
*/

// Always use remaining time in the video player - @bhackel
%hook YTPlayerBarController
// When a new video is played, enable time remaining flag
- (void)setActiveSingleVideo:(id)arg1 {
    %orig;
    // Get the player bar view
    YTInlinePlayerBarContainerView *playerBar = self.playerBar;
    if (playerBar) {
        // Enable the time remaining flag
        playerBar.shouldDisplayTimeRemaining = YES;
    }
}
%end

// Disable toggle time remaining - @bhackel
%hook YTInlinePlayerBarContainerView
- (void)setShouldDisplayTimeRemaining:(BOOL)arg1 {
    %orig(YES);
}
%end

// อื่นๆ
// Prevent YouTube from asking to update the app
%hook YTGlobalConfig
- (BOOL)shouldBlockUpgradeDialog { return YES; }
- (BOOL)shouldShowUpgradeDialog { return NO; }
- (BOOL)shouldShowUpgrade { return NO; }
- (BOOL)shouldForceUpgrade { return NO; }
%end

// Prevent YouTube from asking "Are you there?"
%hook YTColdConfig
- (BOOL)enableYouthereCommandsOnIos { return NO; }
%end

%hook YTYouThereController
- (BOOL)shouldShowYouTherePrompt { return NO; }
- (void)showYouTherePrompt {}
%end

%hook YTYouThereControllerImpl
- (BOOL)shouldShowYouTherePrompt { return NO; }
- (void)showYouTherePrompt {}
%end

/*
%group SlowMiniPlayer
%hook YTColdConfig
- (BOOL)enableIosFloatingMiniplayerDoubleTapToResize { return NO; }
%end
%end

%group OldMiniPlayer
%hook YTColdConfig
- (BOOL)enableIosFloatingMiniplayer { return NO; }
%end

%hook YTColdConfigWatchPlayerClientGlobalConfigImpl
- (BOOL)enableIosFloatingMiniplayer { return NO; }
%end
%end
*/

// Disables Snackbar
%hook GOOHUDManagerInternal
- (id)sharedInstance { return nil; }
- (void)showMessageMainThread:(id)arg {}
- (void)activateOverlay:(id)arg {}
- (void)displayHUDViewForMessage:(id)arg {}
%end

/*
// Try to disable Shorts PiP
%group DisablesShortsPiP
%hook YTColdConfig
- (BOOL)shortsPlayerGlobalConfigEnableReelsPictureInPicture { return NO; }
- (BOOL)shortsPlayerGlobalConfigEnableReelsPictureInPictureIos { return NO; }
%end

%hook YTHotConfig
- (BOOL)shortsPlayerGlobalConfigEnableReelsPictureInPictureAllowedFromPlayer { return NO; }
%end

%hook YTReelModel
- (BOOL)isPiPSupported { return NO; }
%end

%hook YTReelPlayerViewController
- (BOOL)isPictureInPictureAllowed { return NO; }
%end

%hook YTReelWatchRootViewController
- (void)switchToPictureInPicture {}
%end
%end
*/

// Disable Fullscreen Actions
%hook YTFullscreenActionsView
- (BOOL)enabled { return NO; }
- (void)setEnabled:(BOOL)arg1 { %orig(NO); }
%end

/*
%hook YTInlinePlayerBarContainerView
- (void)setPlayerBarAlpha:(CGFloat)alpha { %orig(1.0); } // Force seek bar i guess
%end
*/

/*
// Forcibly Enable Miniplayer
%hook YTWatchMiniBarViewController
- (void)updateMiniBarPlayerStateFromRenderer {}
%end

%hook YTWatchFloatingMiniplayerViewController
- (void)updateMiniBarPlayerStateFromRenderer {}
%end

// Portrait Fullscreen
%hook YTWatchViewController
- (unsigned long long)allowedFullScreenOrientations { return PortraitFullscreen() ? UIInterfaceOrientationMaskAllButUpsideDown; }
%end

// Disable Autoplay
%hook YTPlaybackConfig
- (void)setStartPlayback:(BOOL)arg1 { NoAutoPlay() ? %orig(NO); }
%end
*/

// Skip Content Warning (https://github.com/qnblackcat/uYouPlus/blob/main/uYouPlus.xm#L452-L454)
%hook YTPlayabilityResolutionUserActionUIController
- (void)showConfirmAlert { [self confirmAlertDidPressConfirm]; }
%end

%hook YTPlayabilityResolutionUserActionUIControllerImpl
- (void)showConfirmAlert { [self confirmAlertDidPressConfirm]; }
%end

// Dont Show Related Videos on Finish
%hook YTFullscreenEngagementOverlayController
- (void)setRelatedVideosVisible:(BOOL)arg1 { %orig(NO); }
%end

%hook YTFullscreenEngagementOverlayView
- (void)setRelatedVideosView:(id)arg {}
%end

// Disable Snap To Chapter (https://github.com/qnblackcat/uYouPlus/blob/main/uYouPlus.xm#L457-464)
// %hook YTSegmentableInlinePlayerBarView
// - (void)didMoveToWindow { %orig; if (ytlBool(@"dontSnapToChapter")) self.enableSnapToChapter = NO; }
// %end

%hook YTModularPlayerBarController
- (void)setEnableSnapToChapter:(BOOL)arg { %orig(NO); }
%end

// Disable Hints
%hook YTSettings
- (BOOL)areHintsDisabled { return YES; }
- (void)setHintsDisabled:(BOOL)arg1 { %orig(YES); }
%end

%hook YTSettingsImpl
- (BOOL)areHintsDisabled { return YES; }
- (void)setHintsDisabled:(BOOL)arg1 { %orig(YES); }
%end

%hook YTUserDefaults
- (BOOL)areHintsDisabled { return YES; }
- (void)setHintsDisabled:(BOOL)arg1 { %orig(YES); }
%end

/* Wait for now
%hook YTPlayerViewController
- (void)loadWithPlayerTransition:(id)arg1 playbackConfig:(id)arg2 {
    %orig;
    if (ytlBool(@"autoFullscreen")) [self performSelector:@selector(autoFullscreen) withObject:nil afterDelay:0.75];
    if (ytlBool(@"shortsToRegular")) [self performSelector:@selector(shortsToRegular) withObject:nil afterDelay:0.75];
    if (ytlBool(@"disableAutoCaptions")) [self performSelector:@selector(turnOffCaptions) withObject:nil afterDelay:1.0];
}

%new
- (void)autoFullscreen {
    YTWatchController *watchController = [self valueForKey:@"_UIDelegate"];
    [watchController showFullScreen];
}

%new
- (void)shortsToRegular {
    if (self.contentVideoID != nil && [self.parentViewController isKindOfClass:NSClassFromString(@"YTShortsPlayerViewController")]) {
        NSString *vidLink = [NSString stringWithFormat:@"vnd.youtube://%@", self.contentVideoID];
        if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:vidLink]]) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:vidLink] options:@{} completionHandler:nil];
        }
    }
}

%new
- (void)turnOffCaptions {
    if ([self.view.superview isKindOfClass:NSClassFromString(@"YTWatchView")]) {
        [self setActiveCaptionTrack:nil];
    }
}

- (void)singleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;

    addEndTime(self, video, time);
    autoSkipShorts(self, video, time);
}

- (void)potentiallyMutatedSingleVideo:(YTSingleVideoController *)video currentVideoTimeDidChange:(YTSingleVideoTime *)time {
    %orig;

    addEndTime(self, video, time);
    autoSkipShorts(self, video, time);
}
%end

// Fix Playlist Mini-bar Height For Small Screens
%hook YTPlaylistMiniBarView
- (void)setFrame:(CGRect)frame {
    if (frame.size.height < 54.0) frame.size.height = 54.0;
    %orig(frame);
}
%end
*/

// Remove "Play next in queue" from the menu @PoomSmart (https://github.com/qnblackcat/uYouPlus/issues/1138#issuecomment-1606415080)
%hook YTMenuItemVisibilityHandler
- (BOOL)shouldShowServiceItemRenderer:(YTIMenuConditionalServiceItemRenderer *)renderer {
    if (renderer.icon.iconType == 251) {
        return NO;
    } return %orig;
}
%end

%hook YTMenuItemVisibilityHandlerImpl
- (BOOL)shouldShowServiceItemRenderer:(YTIMenuConditionalServiceItemRenderer *)renderer {
    if (renderer.icon.iconType == 251) {
        return NO;
    } return %orig;
}
%end

/*
// Remove Download button from the menu
%hook YTDefaultSheetController
- (void)addAction:(YTActionSheetAction *)action {
    NSString *identifier = [action valueForKey:@"_accessibilityIdentifier"];

    NSDictionary *actionsToRemove = @{
        @"7": @(ytlBool(@"removeDownloadMenu")),
        @"1": @(ytlBool(@"removeWatchLaterMenu")),
        @"3": @(ytlBool(@"removeSaveToPlaylistMenu")),
        @"5": @(ytlBool(@"removeShareMenu")),
        @"12": @(ytlBool(@"removeNotInterestedMenu")),
        @"31": @(ytlBool(@"removeDontRecommendMenu")),
        @"58": @(ytlBool(@"removeReportMenu"))
    };

    if (![actionsToRemove[identifier] boolValue]) {
        %orig;
    }
}
%end
*/

%hook YTPivotBarView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    NSMutableArray <YTIPivotBarSupportedRenderers *> *items = [renderer itemsArray];
    NSMutableIndexSet *indicesToRemove = [NSMutableIndexSet indexSet];
    // Loop through every item in the bar
    for (NSUInteger i = 0; i < items.count; i++) {
        YTIPivotBarSupportedRenderers *item = items[i];
        NSString *pID = [[item pivotBarItemRenderer] pivotIdentifier];
        NSString *pID2 = [[item pivotBarIconOnlyItemRenderer] pivotIdentifier];
        if ([pID isEqualToString:@"FEwhat_to_watch"] && IS_ENABLED(HideHomeTab)) {
             [indicesToRemove addIndex:i];
        }
        if ([pID isEqualToString:@"FEshorts"] && IS_ENABLED(HideShortsTab)) {
            [indicesToRemove addIndex:i];
        }
        if ([pID2 isEqualToString:@"FEuploads"] && IS_ENABLED(HideCreateButton)) {
            [indicesToRemove addIndex:i];
        }
        if ([pID isEqualToString:@"FEsubscriptions"] && IS_ENABLED(HideSubscriptTab)) {
            [indicesToRemove addIndex:i];
        }
    }
    // Remove them all at once so the layout doesn't break
    [items removeObjectsAtIndexes:indicesToRemove];
    %orig(renderer);
}
%end

// Hide Tab Bar Indicators
%hook YTPivotBarIndicatorView
- (void)setFillColor:(id)arg1 { IS_ENABLED(HideTabIndi) ? %orig([UIColor clearColor]) : %orig; }
- (void)setBorderColor:(id)arg1  { IS_ENABLED(HideTabIndi) ? %orig([UIColor clearColor]) : %orig; }
%end

// Hide Tab Labels
%hook YTPivotBarItemView
- (void)setRenderer:(YTIPivotBarRenderer *)renderer {
    %orig;
    if (IS_ENABLED(HideTabLabels)) {
        [self.navigationButton setTitle:@"" forState:UIControlStateNormal];
        [self.navigationButton setSizeWithPaddingAndInsets:NO];
    }
}
%end

/* Needs to make the settings for this first 
// Startup Tab
BOOL isTabSelected = NO;
%hook YTPivotBarViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!isTabSelected) {
        NSArray *pivotIdentifiers = @[@"FEwhat_to_watch", @"FEexplore", @"FEshorts", @"FEsubscriptions", @"FElibrary"];
        [self selectItemWithPivotIdentifier:pivotIdentifiers[ytlInt(@"pivotIndex")]];
        isTabSelected = YES;
    }
}
%end
*/

// Thanks to aricloverEXTRA for all of these logics!
// YTHidePlayerButtons 1.0.0 - made by @aricloverEXTRA
static NSDictionary<NSString *, NSString *> *HideToggleMap(void) {
    static NSDictionary<NSString *, NSString *> *map = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            // identifiers
            @"id.video.like.button": @"YouModHideLikeButton", // Like button
            @"id.video.dislike.button": @"YouModHideDisLikeButton", // Dislike button
            @"id.video.share.button": @"YouModHideShareButton", // Share button
            @"id.ui.add_to.offline.button": @"YouModHideDownloadButton", // Download button
            @"clip_button.eml": @"YouModHideClipButton", // Clip button
            @"id.video.remix.button": @"YouModHideRemixButton", // Remix button
            @"id.video.add_to.button": @"YouModHideSaveButton", // Save to playlist button
            @"id.ui.carousel_header": @"YouModHideRemixButton" // Comment section - TEST
            /*
            Extra keys
            id.reel_multi_format_link = Shorts -> full video
            id.reel_like_button
            id.reel_dislike_button
            id.reel_comment_button
            id.reel_share_button
            id.reel_remix_button
            id.reel_pivot_button Sound metadate in shorts
            id.ui.video_metadata_carousel -> Preview comments in full video
            */
        };
    });
    return map;
}
static BOOL shouldHideForKey(NSString *key) {
    if (!key) return NO;
    NSString *pref = HideToggleMap()[key];
    if (!pref) return NO;
    return IS_ENABLED(pref);
}
static void safeHideView(id view) {
    if (!view) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if ([view respondsToSelector:@selector(setHidden:)]) {
                [view setHidden:YES];
                return;
            }
            if ([view isKindOfClass:[UIView class]]) {
                ((UIView *)view).hidden = YES;
                return;
            }
        } @catch (NSException *ex) {
            NSLog(@"[HidePlayerButtons] safeHideView exception: %@", ex);
        }
    });
}
static BOOL inspectAndHideIfMatch(id view) {
    if (!view) return NO;
    @try {
        NSString *accId = nil;
        if ([view respondsToSelector:@selector(accessibilityIdentifier)]) {
            @try { accId = [view accessibilityIdentifier]; } @catch (NSException *e) { accId = nil; }
            if (accId && shouldHideForKey(accId)) {
                safeHideView(view);
                return YES;
            }
        }
        NSString *accLabel = nil;
        if ([view respondsToSelector:@selector(accessibilityLabel)]) {
            @try { accLabel = [view accessibilityLabel]; } @catch (NSException *e) { accLabel = nil; }
            if (accLabel && shouldHideForKey(accLabel)) {
                safeHideView(view);
                return YES;
            }
        }
        NSString *desc = nil;
        @try { desc = [[view description] copy]; } @catch (NSException *e) { desc = nil; }
        if (desc) {
            for (NSString *key in HideToggleMap().allKeys) {
                if ([desc containsString:key] && shouldHideForKey(key)) {
                    safeHideView(view);
                    return YES;
                }
            }
        }
    } @catch (NSException *ex) {
        NSLog(@"[HidePlayerButtons] inspectAndHideIfMatch exception: %@", ex);
    }
    return NO;
}
static void traverseAndHideViews(UIView *root) {
    if (!root) return;
    @try {
        inspectAndHideIfMatch(root);
        NSArray<UIView *> *subs = nil;
        @try { subs = root.subviews; } @catch (NSException *e) { subs = nil; }
        if (subs && subs.count) {
            for (UIView *sv in subs) {
                if ([sv isKindOfClass:[UIView class]]) {
                    traverseAndHideViews(sv);
                }
            }
        }
    } @catch (NSException *ex) {
        NSLog(@"[HidePlayerButtons] traverseAndHideViews exception: %@", ex);
    }
}
static void hideButtonsInActionBarIfNeeded(id collectionView) {
    if (!collectionView) return;
    @try {
        // Ensure the collectionView has accessibilityIdentifier and we only operate on the action bar
        NSString *accId = nil;
        if ([collectionView respondsToSelector:@selector(accessibilityIdentifier)]) {
            @try { accId = [collectionView accessibilityIdentifier]; } @catch (NSException *e) { accId = nil; }
        }
        if (!accId) return;
        if (![accId isEqualToString:@"id.video.scrollable_action_bar"]) return;
        NSArray *cells = nil;
        if ([collectionView respondsToSelector:@selector(visibleCells)]) {
            @try { cells = [collectionView visibleCells]; } @catch (NSException *e) { cells = nil; }
        }
        if (!cells || cells.count == 0) {
            @try { cells = [collectionView subviews]; } @catch (NSException *e) { cells = nil; }
        }
        if (!cells || cells.count == 0) return;
        for (id cell in cells) {
            if ([cell isKindOfClass:[UIView class]]) {
                traverseAndHideViews((UIView *)cell);
            } else {
                @try {
                    if ([cell respondsToSelector:@selector(view)]) {
                        id view = [cell performSelector:@selector(view)];
                        if ([view isKindOfClass:[UIView class]]) {
                            traverseAndHideViews((UIView *)view);
                        }
                    } else if ([cell respondsToSelector:@selector(node)]) {
                        NSString *desc = nil;
                        @try { desc = [cell description]; } @catch (NSException *e) { desc = nil; }
                        if (desc) {
                            // Not ideal to act on description, but we keep this non-destructive: only log for debugging
                            // Uncomment logging for debug builds if needed.
                            // NSLog(@"[HidePlayerButtons] Non-UIView cell description: %@", desc);
                        }
                    }
                } @catch (NSException *ex) {
                    NSLog(@"[HidePlayerButtons] Exception handling non-UIView cell: %@", ex);
                }
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"[HidePlayerButtons] hideButtonsInActionBarIfNeeded exception: %@", exception);
    }
}
%hook ASCollectionView
- (id)nodeForItemAtIndexPath:(NSIndexPath *)indexPath {
    id node = %orig;
    id weakSelf = (id)self;
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            hideButtonsInActionBarIfNeeded(weakSelf);
        } @catch (NSException *e) {
            NSLog(@"[HidePlayerButtons] async hide exception: %@", e);
        }
    });
    return node;
}
- (void)nodesDidRelayout:(NSArray *)nodes {
    %orig;
    id weakSelf = (id)self;
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            hideButtonsInActionBarIfNeeded(weakSelf);
        } @catch (NSException *e) {
            NSLog(@"[HidePlayerButtons] relayout hide exception: %@", e);
        }
    });
}
%end
#import "Headers.h"

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
- (void)setPremiumLogo:(BOOL)arg { 
    BOOL temp = IS_ENABLED(YTPremiumLogo) ? YES : arg;
    %orig(temp);
}
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
- (void)setPremiumLogo:(BOOL)arg { 
    BOOL temp = IS_ENABLED(YTPremiumLogo) ? YES : arg;
    %orig(temp);
}
- (BOOL)isPremiumLogo { return IS_ENABLED(YTPremiumLogo) ? YES : %orig; }
%end

// Hide Navigation Bar Buttons
%hook YTRightNavigationButtons
- (void)didMoveToWindow {
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
- (id)init {
    return IS_ENABLED(HideYTLogo) ? nil : %orig;
}
%end

%hook YTHeaderLogoControllerImpl
- (id)init {
    return IS_ENABLED(HideYTLogo) ? nil : %orig;
}
%end

%hook YTNavigationBarTitleView
- (void)didMoveToWindow {
    %orig;
    if (IS_ENABLED(HideYTLogo)) {
        for (UIView *sub in self.subviews) {
            if ([sub.accessibilityIdentifier isEqualToString:@"id.yoodle.logo"] || [sub.accessibilityIdentifier isEqualToString:@"id.youtube.logo"]) {
                [sub removeFromSuperview];
                break;
            }
        }
    }
}
%end

%hook YTHeaderView
- (BOOL)stickyNavHeaderEnabled { 
    if (IS_ENABLED(StickyNavBar)) [self setStickyNavHeaderEnabled:YES];
    return IS_ENABLED(StickyNavBar) ? YES : %orig;
}
%end
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
    BOOL temp = YES;
    IS_ENABLED(YTPremiumLogo) ? %orig(temp) : %orig;
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
    BOOL temp = YES;
    IS_ENABLED(YTPremiumLogo) ? %orig(temp) : %orig;
}
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
- (void)layoutSubviews {
    %orig;
    if (self.subviews.count > 1 && [self.subviews[1].accessibilityIdentifier isEqualToString:@"id.youtube.logo"] && IS_ENABLED(HideYTLogo)) {
        self.subviews[1].hidden = YES;
    }
}
%end

%hook YTHeaderView
- (BOOL)stickyNavHeaderEnabled { return IS_ENABLED(StickyNavBar) ? YES : %orig; }
- (void)setStickyNavHeaderEnabled:(BOOL)arg { 
    BOOL temp = YES;
    IS_ENABLED(StickyNavBar) ? %orig(temp) : %orig;
}
%end
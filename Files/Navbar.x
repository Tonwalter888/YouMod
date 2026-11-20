#import "Headers.h"

// YouTube Premium logo
%hook YTHeaderLogoController
- (void)setTopbarLogoRenderer:(YTITopbarLogoRenderer *)renderer {
    if (INTFORVAL(YTLogoIndex) == 1 || INTFORVAL(YTLogoIndex) == 2) {
        // Modify the type of the icon before setting the renderer
        YTIIcon *icon = renderer.iconImage;
        if (icon) {
            if (INTFORVAL(YTLogoIndex) == 1) {
                icon.iconType = 537;
                self.premiumLogo = YES;
            } else if (INTFORVAL(YTLogoIndex) == 2) {
                icon.iconType = 158;
                self.premiumLogo = NO;
            }
        }
    }
    %orig(renderer);
}
%end

%hook YTHeaderLogoControllerImpl
- (void)setTopbarLogoRenderer:(YTITopbarLogoRenderer *)renderer {
    if (INTFORVAL(YTLogoIndex) == 1 || INTFORVAL(YTLogoIndex) == 2) {
        // Modify the type of the icon before setting the renderer
        YTIIcon *icon = renderer.iconImage;
        if (icon) {
            if (INTFORVAL(YTLogoIndex) == 1) {
                icon.iconType = 537;
                self.premiumLogo = YES;
            } else if (INTFORVAL(YTLogoIndex) == 2) {
                icon.iconType = 158;
                self.premiumLogo = NO;
            }
        }
    }
    %orig(renderer);
}
%end

// Hide Navigation Bar Buttons
%hook YTRightNavigationButtons
- (void)layoutSubviews {
    %orig;
    if (IS_ENABLED(HideNoti) && self.notificationButton != nil) self.notificationButton.hidden = YES;
    if (IS_ENABLED(HideSearch) && self.searchButton != nil) self.searchButton.hidden = YES;
    if (IS_ENABLED(HideMessages) && [self respondsToSelector:@selector(connectionsInboxButton)] && self.connectionsInboxButton != nil) self.connectionsInboxButton.hidden = YES;
    if (IS_ENABLED(HideCastButtonNav) && self.MDXButton != nil) self.MDXButton.hidden = YES;
    for (YTQTMButton *button in self.visibleButtons) {
        if (IS_ENABLED(HideVoiceSearch) && [button.accessibilityLabel isEqualToString:NSLocalizedString(@"search.voice.access", nil)]) button.hidden = YES;
        else if (IS_ENABLED(HideShareButtonNav)) {
            YTIButtonRenderer *renderer = [button valueForKey:@"_buttonRenderer"];
            if (renderer == nil) continue;
            else if (renderer.icon.iconType == YT_SETTINGS_SHARE_CAIRO) button.hidden = YES;
        }
    }
}
%end

%hook YTNavigationBarTitleView
- (void)setCustomView:(UIView *)view {
    if (INTFORVAL(YTLogoIndex) == 3 && view && [view.accessibilityIdentifier isEqualToString:@"id.youtube.logo"]) return;
    %orig;
}
%end

%hook YTHeaderView
- (void)setAdjacentSubheaderView:(UIView *)view { 
    if (IS_ENABLED(StickyNavBar) && view) self.stickyNavHeaderEnabled = YES;
    %orig;
}
%end
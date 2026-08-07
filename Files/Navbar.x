#import "Headers.h"

// YouTube Premium logo
%hook YTHeaderLogoController
- (void)setTopbarLogoRenderer:(YTITopbarLogoRenderer *)renderer {
    if (INTFORVAL(YTLogoIndex) == 0) {
        %orig;
        return;
    }
    // Modify the type of the icon before setting the renderer
    YTIIcon *icon = renderer.iconImage;
    if (icon) {
        if (INTFORVAL(YTLogoIndex) == 1) {
            icon.iconType = 537;
        } else if (INTFORVAL(YTLogoIndex) == 2) {
            icon.iconType = 158;
        }
    }
    %orig(renderer);
}
// For when spoofing before 18.34.5
- (void)setPremiumLogo:(BOOL)arg { 
    if (INTFORVAL(YTLogoIndex) == 1) {
        arg = YES;
    } else if (INTFORVAL(YTLogoIndex) == 2) {
        arg = NO;
    }
    %orig(arg);
}
- (BOOL)isPremiumLogo { 
    if (INTFORVAL(YTLogoIndex) == 1) {
        return YES;
    } else if (INTFORVAL(YTLogoIndex) == 2) {
        return NO;
    }
    return %orig;
}
%end

%hook YTHeaderLogoControllerImpl
- (void)setTopbarLogoRenderer:(YTITopbarLogoRenderer *)renderer {
    if (INTFORVAL(YTLogoIndex) == 0) {
        %orig;
        return;
    }
    // Modify the type of the icon before setting the renderer
    YTIIcon *icon = renderer.iconImage;
    if (icon) {
        if (INTFORVAL(YTLogoIndex) == 1) {
            icon.iconType = 537;
        } else if (INTFORVAL(YTLogoIndex) == 2) {
            icon.iconType = 158;
        }
    }
    %orig(renderer);
}
// For when spoofing before 18.34.5
- (void)setPremiumLogo:(BOOL)arg { 
    if (INTFORVAL(YTLogoIndex) == 1) {
        arg = YES;
    } else if (INTFORVAL(YTLogoIndex) == 2) {
        arg = NO;
    }
    %orig(arg);
}
- (BOOL)isPremiumLogo { 
    if (INTFORVAL(YTLogoIndex) == 1) {
        return YES;
    } else if (INTFORVAL(YTLogoIndex) == 2) {
        return NO;
    }
    return %orig;
}
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
    return INTFORVAL(YTLogoIndex) == 3 ? nil : %orig;
}
%end

%hook YTHeaderLogoControllerImpl
- (id)init {
    return INTFORVAL(YTLogoIndex) == 3 ? nil : %orig;
}
%end

%hook YTNavigationBarTitleView
- (void)didMoveToWindow {
    %orig;
    if (INTFORVAL(YTLogoIndex) == 3) {
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
    if (IS_ENABLED(StickyNavBar)) {
        [self setStickyNavHeaderEnabled:YES];
        return YES;
    }
    return %orig;
}
%end
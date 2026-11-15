#import "Headers.h"

// Hide Subbar
%hook YTHeaderContentComboView
- (void)enableSubheaderBarWithView:(UIView *)view { if (!IS_ENABLED(HideSubbar)) %orig; }
- (void)setFeedHeaderScrollMode:(int)mode { %orig(IS_ENABLED(HideSubbar) ? 0 : mode); }
%end

// Hide voice search button
%hook YTSearchViewController
- (void)viewDidLoad {
    %orig;
    if (IS_ENABLED(HideVoiceSearch)) [self setValue:@(NO) forKey:@"_isVoiceSearchAllowed"];
}
- (void)setSuggestions:(id)arg1 { if (!IS_ENABLED(HideSearchHis)) %orig; }
%end

// Hide search history and suggestions
%hook YTPersonalizedSuggestionsCacheProvider
- (id)activeCache { return IS_ENABLED(HideSearchHis) ? nil : %orig; }
%end

// Hide related videos in the feed
%hook YTWatchNextResultsViewController
- (void)setVisibleSections:(NSInteger)sections {
    if ([self.parentViewController isKindOfClass:%c(YTWatchNextResponseViewController)] && IS_ENABLED(HideRelatedVideos)) {
        sections = 1;
    }
    %orig(sections);
}
%end

// Original (untranslated) titles: the server ships the original alongside the auto-translated one.
%hook YTIVideoWithContextRenderer
- (YTIFormattedString *)title {
    if (IS_ENABLED(NoTranslatedTitles) && [self hasUntranslatedTitle]) {
        YTIFormattedString *original = [self untranslatedTitle];
        if (original) return original;
    }
    return %orig;
}
%end
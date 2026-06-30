#import "Headers.h"

// Hide Subbar
%hook YTHeaderContentComboView
- (void)enableSubheaderBarWithView:(id)arg1 { if (!IS_ENABLED(HideSubbar)) %orig; }
- (void)setFeedHeaderScrollMode:(int)arg1 { IS_ENABLED(HideSubbar) ? %orig(0) : %orig; }
%end

// Hide voice search button
%hook YTSearchViewController
- (void)viewDidLoad {
    %orig;
    if (IS_ENABLED(HideVoiceSearch)) {
        [self setValue:@(NO) forKey:@"_isVoiceSearchAllowed"];
    }
}
- (void)setSuggestions:(id)arg1 { if (!IS_ENABLED(HideSearchHis)) %orig; }
%end

// Hide search history and suggestions
%hook YTPersonalizedSuggestionsCacheProvider
- (id)activeCache { return IS_ENABLED(HideSearchHis) ? nil : %orig; }
%end

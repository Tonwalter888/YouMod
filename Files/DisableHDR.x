#import "Headers.h"

// Disables HDR — ported from YTUHD's Filter.x (https://github.com/Tonwalter888/YTUHD).
// Filters HDR variants out of every format list feeding ABR and the HLS stream
// selector, so playback and the quality menu only see SDR formats.

NSArray <MLFormat *> *filteredAlot(NSArray <MLFormat *> *sth) {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(MLFormat *format, NSDictionary *bindings) {
        if (![format isKindOfClass:%c(MLFormat)]) return YES;
        NSString *qualityLabel = [format qualityLabel];
        BOOL isHDR = [qualityLabel containsString:@"HDR"];
        if (IS_ENABLED(DisablesHDR)) {
            return !isHDR;
        }
        return YES;
    }];
    return [sth filteredArrayUsingPredicate:predicate];
}

%hook MLABRPolicy
- (void)setFormats:(NSArray *)formats { %orig(filteredAlot(formats)); }
%end

%hook HAMDefaultABRPolicy
- (NSArray *)filterFormats:(NSArray *)formats { return filteredAlot(%orig); }
- (id)getSelectableFormatDataAndReturnError:(NSError **)error {
    [self setValue:@(NO) forKey:@"_postponePreferredFormatFiltering"];
    return filteredAlot(%orig);
}
- (void)setFormats:(NSArray *)formats {
    [self setValue:@(YES) forKey:@"_postponePreferredFormatFiltering"];
    %orig(filteredAlot(formats));
}
%end

%hook MLHLSStreamSelector
- (void)didLoadHLSMasterPlaylist:(id)arg1 {
    %orig;
    // MLHLSRemotePlaylist : MLRemoteStream : MLFormat, so filteredAlot applies.
    MLHLSMasterPlaylist *playlist = [self valueForKey:@"_completeMasterPlaylist"];
    NSArray *remotePlaylists = [playlist remotePlaylists];
    [[self delegate] streamSelectorHasSelectableVideoFormats:filteredAlot(remotePlaylists)];
}
%end

%hook YTHotConfig
- (BOOL)iosPlayerClientSharedConfigDisableServerDrivenAbr { return YES; }
- (BOOL)iosPlayerClientSharedConfigPostponeCabrPreferredFormatFiltering { return YES; }
%end

%ctor {
    if (!IS_ENABLED(DisablesHDR)) return;
    %init;
}
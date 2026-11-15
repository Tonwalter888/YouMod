#import "Headers.h"

// Library helpers: data store, text/format, thumbnails and media info.
@implementation YMLibraryHelpers

+ (NSSet<NSString *> *)mediaExtensions {
    static NSSet<NSString *> *exts;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ exts = [NSSet setWithObjects:@"mp4", @"mkv", @"m4a", @"mka", nil]; });
    return exts;
}

// Every AVPlayer alive in the process, held weakly so entries vanish on dealloc without a hook.
+ (NSHashTable<AVPlayer *> *)liveAVPlayers {
    static NSHashTable<AVPlayer *> *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ table = [NSHashTable weakObjectsHashTable]; });
    return table;
}

+ (BOOL)isAudioOnlyExtension:(NSString *)extension {
    NSString *lower = extension.lowercaseString;
    return [lower isEqualToString:@"m4a"] || [lower isEqualToString:@"mka"];
}

static NSString * const kYMLibraryMetadataDefaultsKey = @"YouModDownloadLibraryMetadata";
static NSString * const kYMLibraryPlaylistsDefaultsKey = @"YouModDownloadLibraryPlaylists";
static NSString * const kYMLibraryTypeAll = @"All";
static NSString * const kYMLibraryTypeVideos = @"Videos";
static NSString * const kYMLibraryTypeShorts = @"Shorts";
static NSString * const kYMLibraryTypeAudio = @"Audio";
static NSString * const kYMLibraryTypePlaylists = @"Playlists";
static NSString * const kYMLibraryTypePrivate = @"Private";

+ (NSArray<NSString *> *)types {
    static NSArray *types;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ types = @[kYMLibraryTypeAll, kYMLibraryTypeVideos, kYMLibraryTypeShorts, kYMLibraryTypeAudio, kYMLibraryTypePlaylists, kYMLibraryTypePrivate]; });
    return types;
}

+ (NSString *)metadataKeyForURL:(NSURL *)url {
    return url.lastPathComponent ?: @"";
}

+ (NSDictionary *)metadataForURL:(NSURL *)url {
    NSDictionary *metadata = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kYMLibraryMetadataDefaultsKey];
    NSDictionary *entry = metadata[[YMLibraryHelpers metadataKeyForURL:url]];
    return [entry isKindOfClass:[NSDictionary class]] ? entry : @{};
}

+ (void)setMetadataForURL:(NSURL *)url entry:(NSDictionary *)entry {
    if (!url) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *metadata = [[defaults dictionaryForKey:kYMLibraryMetadataDefaultsKey] mutableCopy] ?: [NSMutableDictionary dictionary];
    NSString *key = [YMLibraryHelpers metadataKeyForURL:url];
    if (entry.count > 0) metadata[key] = entry;
    else [metadata removeObjectForKey:key];
    [defaults setObject:metadata forKey:kYMLibraryMetadataDefaultsKey];
}

+ (NSArray<NSDictionary *> *)playlists {
    NSArray *playlists = [[NSUserDefaults standardUserDefaults] arrayForKey:kYMLibraryPlaylistsDefaultsKey];
    return [playlists isKindOfClass:[NSArray class]] ? playlists : @[];
}

+ (void)savePlaylists:(NSArray<NSDictionary *> *)playlists {
    [[NSUserDefaults standardUserDefaults] setObject:playlists ?: @[] forKey:kYMLibraryPlaylistsDefaultsKey];
}

+ (BOOL)playlistLocked:(NSDictionary *)playlist {
    return [playlist[@"locked"] boolValue];
}

// Locked playlists only appear in the Private tab, so their names never leak into public UI.
+ (NSArray<NSDictionary *> *)playlistsMatchingLockState:(BOOL)locked {
    return [[self playlists] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *playlist, NSDictionary *bindings) {
        return [self playlistLocked:playlist] == locked;
    }]];
}

+ (NSString *)localizedText:(NSString *)key fallback:(NSString *)fallback {
    NSString *value = LOC(key);
    return [value isEqualToString:key] ? fallback : value;
}

+ (NSString *)displayTitleForFileName:(NSString *)baseName {
    NSRange range = [baseName rangeOfString:@" \\[[A-Za-z0-9_-]{11}\\]$" options:NSRegularExpressionSearch];
    if (range.location != NSNotFound) {
        return [baseName stringByReplacingCharactersInRange:range withString:@""];
    }
    return baseName;
}

+ (NSString *)videoIDForFileName:(NSString *)baseName {
    NSRange range = [baseName rangeOfString:@" \\[[A-Za-z0-9_-]{11}\\]$" options:NSRegularExpressionSearch];
    if (range.location == NSNotFound) return nil;
    return [baseName substringWithRange:NSMakeRange(range.location + 2, 11)];
}

+ (NSString *)formattedFileSize:(unsigned long long)bytes {
    NSByteCountFormatter *formatter = [NSByteCountFormatter new];
    formatter.countStyle = NSByteCountFormatterCountStyleFile;
    return [formatter stringFromByteCount:(long long)bytes];
}

+ (NSArray<NSURL *> *)fileURLsNewestFirst {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSURL *> *contents = [fm contentsOfDirectoryAtURL:YouModDownloadsDirectoryURL()
                                    includingPropertiesForKeys:@[NSURLContentModificationDateKey]
                                                       options:NSDirectoryEnumerationSkipsHiddenFiles
                                                         error:nil];
    NSSet<NSString *> *mediaExts = [YMLibraryHelpers mediaExtensions];
    contents = [contents filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSURL *url, NSDictionary *bindings) {
        return [mediaExts containsObject:url.pathExtension.lowercaseString];
    }]];
    return [contents sortedArrayUsingComparator:^NSComparisonResult(NSURL *a, NSURL *b) {
        NSDate *dateA = nil, *dateB = nil;
        [a getResourceValue:&dateA forKey:NSURLContentModificationDateKey error:nil];
        [b getResourceValue:&dateB forKey:NSURLContentModificationDateKey error:nil];
        return [(dateB ?: NSDate.distantPast) compare:(dateA ?: NSDate.distantPast)];
    }];
}

#pragma mark - Thumbnails

+ (NSURL *)siblingThumbnailURL:(NSURL *)fileURL {
    return [[fileURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"jpg"];
}

+ (NSURL *)thumbCacheDirectory {
    NSURL *caches = [[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *dir = [caches URLByAppendingPathComponent:@"YouMod_Thumbs" isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

+ (NSURL *)generatedThumbCacheURL:(NSURL *)fileURL {
    return [[[YMLibraryHelpers thumbCacheDirectory] URLByAppendingPathComponent:fileURL.lastPathComponent] URLByAppendingPathExtension:@"jpg"];
}

+ (UIImage *)thumbnailForVideoFile:(NSURL *)fileURL {
    NSData *real = [NSData dataWithContentsOfURL:[YMLibraryHelpers siblingThumbnailURL:fileURL]];
    if (real) return [UIImage imageWithData:real];

    NSURL *cacheURL = [YMLibraryHelpers generatedThumbCacheURL:fileURL];
    NSData *cached = [NSData dataWithContentsOfURL:cacheURL];
    if (cached) return [UIImage imageWithData:cached];

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:fileURL options:nil];
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    generator.appliesPreferredTrackTransform = YES;
    NSError *error = nil;
    CGImageRef cgImage = [generator copyCGImageAtTime:CMTimeMake(1, 1) actualTime:nil error:&error];
    if (!cgImage) return nil;
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    NSData *jpeg = UIImageJPEGRepresentation(image, 0.7);
    if (jpeg) [jpeg writeToURL:cacheURL atomically:YES];
    return image;
}

+ (void)deleteThumbnailsForFile:(NSURL *)fileURL {
    [[NSFileManager defaultManager] removeItemAtURL:[YMLibraryHelpers siblingThumbnailURL:fileURL] error:nil];
    [[NSFileManager defaultManager] removeItemAtURL:[YMLibraryHelpers generatedThumbCacheURL:fileURL] error:nil];
}

#pragma mark - Media info ("View Info")

+ (NSString *)fourCCString:(FourCharCode)code {
    char chars[5] = {
        (char)((code >> 24) & 0xFF),
        (char)((code >> 16) & 0xFF),
        (char)((code >> 8) & 0xFF),
        (char)(code & 0xFF),
        0,
    };
    for (int i = 0; i < 4; i++) if (chars[i] < 0x20 || chars[i] > 0x7E) chars[i] = '?';
    return [NSString stringWithUTF8String:chars];
}

+ (NSString *)mediaInfoStringForFile:(NSURL *)fileURL bytes:(unsigned long long)bytes {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:fileURL options:nil];
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [lines addObject:[NSString stringWithFormat:@"%@: %@", LOC(@"LIBRARY_INFO_SIZE"), [YMLibraryHelpers formattedFileSize:bytes]]];
    double durationSeconds = CMTimeGetSeconds(asset.duration);
    if (durationSeconds > 0) {
        [lines addObject:[NSString stringWithFormat:@"%@: %.0fs", LOC(@"LIBRARY_INFO_DURATION"), durationSeconds]];
    }
    [lines addObject:[NSString stringWithFormat:@"%@: %@", LOC(@"LIBRARY_INFO_CONTAINER"), fileURL.pathExtension.uppercaseString]];

    AVAssetTrack *videoTrack = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    if (videoTrack) {
        CGSize size = videoTrack.naturalSize;
        [lines addObject:[NSString stringWithFormat:@"%@: %.0fx%.0f", LOC(@"LIBRARY_INFO_RESOLUTION"), fabs(size.width), fabs(size.height)]];
        [lines addObject:[NSString stringWithFormat:@"%@: %.2f fps", LOC(@"LIBRARY_INFO_FRAMERATE"), videoTrack.nominalFrameRate]];
        NSArray *descs = videoTrack.formatDescriptions;
        if (descs.count > 0) {
            FourCharCode subtype = CMFormatDescriptionGetMediaSubType((__bridge CMFormatDescriptionRef)descs.firstObject);
            [lines addObject:[NSString stringWithFormat:@"%@: %@", LOC(@"LIBRARY_INFO_VIDEO_CODEC"), [YMLibraryHelpers fourCCString:subtype]]];
        }
        if (videoTrack.estimatedDataRate > 0) {
            [lines addObject:[NSString stringWithFormat:@"%@: %.0f kbps", LOC(@"LIBRARY_INFO_VIDEO_BITRATE"), videoTrack.estimatedDataRate / 1000.0]];
        }
    }
    AVAssetTrack *audioTrack = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
    if (audioTrack) {
        NSArray *descs = audioTrack.formatDescriptions;
        if (descs.count > 0) {
            FourCharCode subtype = CMFormatDescriptionGetMediaSubType((__bridge CMFormatDescriptionRef)descs.firstObject);
            [lines addObject:[NSString stringWithFormat:@"%@: %@", LOC(@"LIBRARY_INFO_AUDIO_CODEC"), [YMLibraryHelpers fourCCString:subtype]]];
        }
        if (audioTrack.estimatedDataRate > 0) {
            [lines addObject:[NSString stringWithFormat:@"%@: %.0f kbps", LOC(@"LIBRARY_INFO_AUDIO_BITRATE"), audioTrack.estimatedDataRate / 1000.0]];
        }
    }
    return [lines componentsJoinedByString:@"\n"];
}

@end

#pragma mark - Row model

@implementation YMLibraryRow

// YES when the row sits in any of the given playlists (drives hide-along-with-lock).
- (BOOL)isInAnyPlaylist:(NSArray<NSDictionary *> *)playlists {
    return [playlists indexOfObjectPassingTest:^BOOL(NSDictionary *playlist, NSUInteger idx, BOOL *stop) {
        return [self.playlistIDs containsObject:playlist[@"id"]];
    }] != NSNotFound;
}

@end

#pragma mark - Feed-style cell

@implementation YMLibraryVideoCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [YMLibraryStyle youTubeBackgroundColor];

        _thumbnailImageView = [UIImageView new];
        _thumbnailImageView.contentMode = UIViewContentModeScaleAspectFill;
        _thumbnailImageView.clipsToBounds = YES;
        _thumbnailImageView.layer.cornerRadius = 12.0;
        _thumbnailImageView.backgroundColor = [UIColor secondarySystemBackgroundColor];
        _thumbnailImageView.translatesAutoresizingMaskIntoConstraints = NO;

        _titleLabel = [UILabel new];
        _titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        _titleLabel.textColor = [UIColor labelColor];
        _titleLabel.numberOfLines = 2;
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

        _sizeLabel = [UILabel new];
        _sizeLabel.font = [UIFont systemFontOfSize:13];
        _sizeLabel.textColor = [UIColor secondaryLabelColor];
        _sizeLabel.translatesAutoresizingMaskIntoConstraints = NO;

        _menuButton = [%c(YTQTMButton) iconButton];
        // Rendered into an exact 24x24 canvas so the ellipsis never gets squished or cropped.
        [_menuButton setImage:YouModSymbolImageInCanvas(@"ellipsis", 24, 22, UIImageSymbolWeightMedium) forState:UIControlStateNormal];
        _menuButton.tintColor = [UIColor labelColor];
        [_menuButton enableNewTouchFeedback];
        [_menuButton addTarget:self action:@selector(menuTapped) forControlEvents:UIControlEventTouchUpInside];
        _menuButton.translatesAutoresizingMaskIntoConstraints = NO;

        _lockButton = [%c(YTQTMButton) iconButton];
        [_lockButton setImage:YouModSymbolImageInCanvas(@"lock.open", 24, 22, UIImageSymbolWeightMedium) forState:UIControlStateNormal];
        _lockButton.tintColor = [UIColor labelColor];
        [_lockButton enableNewTouchFeedback];
        [_lockButton addTarget:self action:@selector(lockTapped) forControlEvents:UIControlEventTouchUpInside];
        _lockButton.hidden = YES;
        _lockButton.translatesAutoresizingMaskIntoConstraints = NO;

        [self.contentView addSubview:_thumbnailImageView];
        [self.contentView addSubview:_titleLabel];
        [self.contentView addSubview:_sizeLabel];
        [self.contentView addSubview:_menuButton];
        [self.contentView addSubview:_lockButton];

        [NSLayoutConstraint activateConstraints:@[
            [_thumbnailImageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
            [_thumbnailImageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
            [_thumbnailImageView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
            [_thumbnailImageView.heightAnchor constraintEqualToAnchor:_thumbnailImageView.widthAnchor multiplier:9.0 / 16.0],

            [_titleLabel.topAnchor constraintEqualToAnchor:_thumbnailImageView.bottomAnchor constant:10],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:14],
            [_titleLabel.trailingAnchor constraintEqualToAnchor:_menuButton.leadingAnchor constant:-2],

            [_menuButton.centerYAnchor constraintEqualToAnchor:_titleLabel.firstBaselineAnchor],
            [_menuButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-6],
            [_menuButton.widthAnchor constraintEqualToConstant:28],
            [_menuButton.heightAnchor constraintEqualToConstant:28],

            // Same slot and metrics as the ellipsis: only one of the two is visible at a time.
            [_lockButton.centerYAnchor constraintEqualToAnchor:_titleLabel.firstBaselineAnchor],
            [_lockButton.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-6],
            [_lockButton.widthAnchor constraintEqualToConstant:28],
            [_lockButton.heightAnchor constraintEqualToConstant:28],

            [_sizeLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],
            [_sizeLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
            [_sizeLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
            [_sizeLabel.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-14],
        ]];
    }
    return self;
}

- (void)menuTapped {
    if (self.menuTappedHandler) self.menuTappedHandler(self.menuButton);
}

- (void)lockTapped {
    if (self.lockTappedHandler) self.lockTappedHandler(self.lockButton);
}

@end

#pragma mark - Grid layout

@implementation YMLibraryGridLayout

- (instancetype)init {
    self = [super init];
    if (self) {
        self.minimumLineSpacing = 12;
        self.minimumInteritemSpacing = 12;
        self.sectionInset = UIEdgeInsetsMake(12, 12, 12, 12);
    }
    return self;
}

- (void)prepareLayout {
    [super prepareLayout];
    CGFloat width = self.collectionView.bounds.size.width;
    NSInteger columns = width < 600 ? 1 : (width < 900 ? 2 : 3);
    CGFloat spacing = self.minimumInteritemSpacing * (columns - 1) + self.sectionInset.left + self.sectionInset.right;
    CGFloat itemWidth = floor((width - spacing) / columns);
    CGFloat itemHeight = (itemWidth * 9.0 / 16.0) + 80; // thumbnail aspect + text area
    self.itemSize = CGSizeMake(itemWidth, itemHeight);
}

- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds {
    return newBounds.size.width != self.collectionView.bounds.size.width;
}

@end

@implementation YMLibraryStyle

+ (UIColor *)youTubeBackgroundColor {
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection *traitCollection) {
        id palette = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [%c(YTCommonColorPalette) darkPalette]
            : [%c(YTCommonColorPalette) lightPalette];
        return [palette baseBackground];
    }];
}

@end

#pragma mark - Pausing other players

// Pauses YouTube's player (watch page, miniplayer, shorts) plus every AVPlayer in the process.
void YouModPauseAllPlayers(void) {
    [YouModCurrentPlayerViewController pause];
    [[[YMLibraryHelpers liveAVPlayers] allObjects] enumerateObjectsUsingBlock:^(AVPlayer *player, NSUInteger idx, BOOL *stop) {
        if (player.rate > 0) [player pause];
    }];
}

%hook AVPlayer
- (instancetype)initWithURL:(NSURL *)URL {
    AVPlayer *player = %orig;
    if (player) @synchronized([YMLibraryHelpers liveAVPlayers]) { [[YMLibraryHelpers liveAVPlayers] addObject:player]; }
    return player;
}
- (instancetype)initWithPlayerItem:(AVPlayerItem *)item {
    AVPlayer *player = %orig;
    if (player) @synchronized([YMLibraryHelpers liveAVPlayers]) { [[YMLibraryHelpers liveAVPlayers] addObject:player]; }
    return player;
}
%end

#pragma mark - Library player PiP restore

// Strong ref so the fullscreen player survives PiP (and library screen rebuilds).
static AVPlayerViewController *ymLibraryPlayerVC = nil;

// Restores the fullscreen player when the PiP expand button is tapped. The modal
// can be gone by then (e.g. the library screen was rebuilt while in PiP), so
// re-present onto the topmost view controller instead of leaving a blank screen.
@implementation YMLibraryPlayerPiPDelegate
- (void)playerViewController:(AVPlayerViewController *)playerViewController restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL restored))completionHandler {
    if (playerViewController.presentingViewController) {
        completionHandler(YES);
        return;
    }
    UIViewController *topVC = YouModTopViewController(nil);
    [topVC presentViewController:playerViewController animated:YES completion:^{
        completionHandler(YES);
    }];
}

+ (instancetype)sharedDelegate {
    static YMLibraryPlayerPiPDelegate *delegate;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ delegate = [YMLibraryPlayerPiPDelegate new]; });
    return delegate;
}
@end

#pragma mark - Pull-to-refresh control

static const CGFloat ymRefreshTriggerDistance = 56.0;
static const CGFloat ymRefreshHiddenTravel = 72.0; // how far the bubble sits above its resting spot

// Pull-to-refresh bubble for the library grid: a floating circle with an arrow that slides into
// view and rotates as the user drags down past the top, then spins while refreshing. Driven by the
// scroll delegate. Top edge only — rubber-banding at the bottom never triggers a refresh.
@implementation YMLibraryRefreshControl

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor secondarySystemBackgroundColor];
        self.layer.cornerRadius = 22;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.15;
        self.layer.shadowRadius = 4;
        self.layer.shadowOffset = CGSizeMake(0, 1);
        self.alpha = 0;

        self.iconView = [UIImageView new];
        self.iconView.image = YouModSymbolImageInCanvas(@"arrow.down", 24, 18, UIImageSymbolWeightMedium);
        self.iconView.tintColor = [UIColor secondaryLabelColor];
        self.iconView.contentMode = UIViewContentModeCenter;
        self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.iconView];

        [NSLayoutConstraint activateConstraints:@[
            [self.iconView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [self.iconView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [self.iconView.widthAnchor constraintEqualToConstant:24],
            [self.iconView.heightAnchor constraintEqualToConstant:24],
        ]];
    }
    return self;
}

// How far the user has dragged past the top edge (clamped so bottom rubber-banding reads as zero).
- (CGFloat)pullDistanceInScrollView:(UIScrollView *)scrollView {
    CGFloat topPull = -(scrollView.contentOffset.y + scrollView.adjustedContentInset.top);
    return MAX(topPull, 0);
}

- (void)draggingBeganInScrollView:(UIScrollView *)scrollView {
    self.pullArmed = NO;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (self.isRefreshing) return;
    CGFloat pull = [self pullDistanceInScrollView:scrollView];
    // Latch the gesture the moment the pull crosses the trigger distance (with a tick), so easing
    // the finger back slightly before lifting can't cancel it the way a release-only check did.
    if (!self.pullArmed && scrollView.isDragging && pull >= ymRefreshTriggerDistance) {
        self.pullArmed = YES;
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [feedback impactOccurred];
    }
    CGFloat progress = MIN(MAX(pull / ymRefreshTriggerDistance, 0), 1);
    // The bubble slides down into view and the arrow flips from down to up across the pull.
    self.transform = CGAffineTransformMakeTranslation(0, -ymRefreshHiddenTravel * (1 - progress));
    self.alpha = progress;
    self.iconView.transform = CGAffineTransformMakeRotation(progress * (CGFloat)M_PI);
}

// Called on finger-up: refresh when the pull crossed the trigger distance during this drag and the
// finger is still pulled down at release (rolling all the way back counts as a cancel).
- (void)draggingEndedInScrollView:(UIScrollView *)scrollView {
    if (self.isRefreshing) return;
    if (self.pullArmed && [self pullDistanceInScrollView:scrollView] >= ymRefreshTriggerDistance * 0.5) {
        [self beginRefreshing];
    }
    self.pullArmed = NO;
}

- (void)beginRefreshing {
    if (self.isRefreshing) return;
    self.refreshing = YES;

    // Park the bubble fully in view and spin the arrow; the scroll position stays put.
    self.transform = CGAffineTransformIdentity;
    self.alpha = 1.0;
    CABasicAnimation *spin = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
    spin.toValue = @((CGFloat)M_PI * 2.0);
    spin.duration = 0.8;
    spin.repeatCount = HUGE_VALF;
    [self.iconView.layer addAnimation:spin forKey:@"ymLibraryRefreshSpin"];

    if (self.onRefresh) self.onRefresh();
}

- (void)endRefreshing {
    if (!self.isRefreshing) return;
    self.refreshing = NO;
    [self.iconView.layer removeAnimationForKey:@"ymLibraryRefreshSpin"];
    self.iconView.transform = CGAffineTransformIdentity;
    [UIView animateWithDuration:0.3 animations:^{
        self.alpha = 0.0;
        self.transform = CGAffineTransformMakeTranslation(0, -ymRefreshHiddenTravel);
    }];
}

@end

#pragma mark - Library view controller

@implementation YMLibraryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = LOC(@"DOWNLOAD_LIBRARY_TAB");
    self.view.backgroundColor = [YMLibraryStyle youTubeBackgroundColor];
    self.allRows = [NSMutableArray array];
    self.rows = [NSMutableArray array];
    NSArray *types = [YMLibraryHelpers types];
    NSArray *sorts = @[@"Newest", @"Oldest", @"Largest", @"Smallest", @"A-Z", @"Z-A"];
    NSString *savedType = [[NSUserDefaults standardUserDefaults] stringForKey:@"YouModDownloadLibrarySelectedType"];
    NSString *savedSort = [[NSUserDefaults standardUserDefaults] stringForKey:@"YouModDownloadLibrarySelectedSort"];
    // Never restore the protected category from preferences without a fresh auth.
    self.selectedType = ([types containsObject:savedType] && ![savedType isEqualToString:kYMLibraryTypePrivate]) ? savedType : kYMLibraryTypeAll;
    self.selectedSort = [sorts containsObject:savedSort] ? savedSort : @"Newest";
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(libraryDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];

    // Keep the large header clear; the type selector below gets its own rounded glass pill.
    UIView *topBar = [UIView new];
    topBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:topBar];

    UIView *topBarSeparator = [UIView new];
    topBarSeparator.backgroundColor = [UIColor separatorColor];
    topBarSeparator.translatesAutoresizingMaskIntoConstraints = NO;
    [topBar addSubview:topBarSeparator];

    _searchBar = [UISearchBar new];
    _searchBar.delegate = self;
    _searchBar.placeholder = LOC(@"SEARCH");
    _searchBar.searchBarStyle = UISearchBarStyleMinimal;
    _searchBar.backgroundImage = [[UIImage alloc] init];
    _searchBar.tintColor = YouModAccentColor();
    _searchBar.translatesAutoresizingMaskIntoConstraints = NO;

    _sortButton = [%c(YTQTMButton) iconButton];
    [_sortButton setImage:[UIImage systemImageNamed:@"arrow.up.arrow.down"] forState:UIControlStateNormal];
    _sortButton.tintColor = [UIColor labelColor];
    _sortButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_sortButton addTarget:self action:@selector(updateSortMenu) forControlEvents:UIControlEventTouchUpInside];
    [_sortButton addTarget:self action:@selector(updateSortButtonAccessibilityLabel) forControlEvents:UIControlEventTouchUpInside];
    if (!YMHostBundleSupportsLiquidGlass()) [_sortButton enableNewTouchFeedback];
    else {
        @try {
            _sortButton.disableTouchResponse = YES;
        } @catch (id ex) {}
    }

    _selectButton = [%c(YTQTMButton) iconButton];
    [_selectButton setImage:[[YMIconProvider tabIcon:@"check_all" selected:NO] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    _selectButton.tintColor = [UIColor labelColor];
    _selectButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_selectButton addTarget:self action:@selector(selectButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    if (!YMHostBundleSupportsLiquidGlass()) [_selectButton enableNewTouchFeedback];
    else {
        @try {
            _selectButton.disableTouchResponse = YES;
        } @catch (id ex) {}
    }

    _settingsButton = [%c(YTQTMButton) iconButton];
    [_settingsButton setImage:YouModYTIconImage(44, NO, nil) forState:UIControlStateNormal];
    _settingsButton.tintColor = [UIColor labelColor];
    _settingsButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_settingsButton addTarget:self action:@selector(openSettingsTapped) forControlEvents:UIControlEventTouchUpInside];
    if (!YMHostBundleSupportsLiquidGlass()) [_settingsButton enableNewTouchFeedback];
    else {
        @try {
            _settingsButton.disableTouchResponse = YES;
        } @catch (id ex) {}
    }

    _selectionExitButton = [%c(YTQTMButton) iconButton];
    [_selectionExitButton setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    _selectionExitButton.tintColor = [UIColor labelColor];
    _selectionExitButton.hidden = YES;
    _selectionExitButton.translatesAutoresizingMaskIntoConstraints = NO;
    _selectionExitButton.accessibilityLabel = LOC(@"DONE");
    [_selectionExitButton addTarget:self action:@selector(exitSelectionMode) forControlEvents:UIControlEventTouchUpInside];
    if (!YMHostBundleSupportsLiquidGlass()) [_selectionExitButton enableNewTouchFeedback];
    else {
        @try {
            _selectionExitButton.disableTouchResponse = YES;
        } @catch (id ex) {}
    }

    _moreMenuButton = [%c(YTQTMButton) iconButton];
    [_moreMenuButton setImage:YouModSymbolImageInCanvas(@"ellipsis", 24, 22, UIImageSymbolWeightMedium) forState:UIControlStateNormal];
    _moreMenuButton.tintColor = [UIColor labelColor];
    _moreMenuButton.hidden = YES;
    _moreMenuButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_moreMenuButton addTarget:self action:@selector(showBulkActionsSheet) forControlEvents:UIControlEventTouchUpInside];
    if (!YMHostBundleSupportsLiquidGlass()) [_moreMenuButton enableNewTouchFeedback];
    else {
        @try {
            _moreMenuButton.disableTouchResponse = YES;
        } @catch (id ex) {}
    }

    _headerButtonStack = [[UIStackView alloc] initWithArrangedSubviews:@[_sortButton, _selectButton, _moreMenuButton, _selectionExitButton, _settingsButton]];
    _headerButtonStack.axis = UILayoutConstraintAxisHorizontal;
    _headerButtonStack.spacing = 6;
    _headerButtonStack.alignment = UIStackViewAlignmentCenter;
    _headerButtonStack.translatesAutoresizingMaskIntoConstraints = NO;
    if (YMHostBundleSupportsLiquidGlass()) {
        YouModApplyLiquidGlassToView(_headerButtonStack, YES);
        _headerButtonStack.layer.cornerRadius = 20;
        _headerButtonStack.layer.cornerCurve = kCACornerCurveContinuous;
    } else {
        _headerButtonStack.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
            return (trait.userInterfaceStyle == UIUserInterfaceStyleDark) ? [UIColor secondarySystemBackgroundColor] : [UIColor systemGray5Color];
        }];
        _headerButtonStack.layer.cornerRadius = 20;
        _headerButtonStack.layer.cornerCurve = kCACornerCurveContinuous;
        _headerButtonStack.layer.masksToBounds = YES;
    }
    [topBar addSubview:_searchBar];
    [topBar addSubview:_headerButtonStack];

    _typeGlassView = [UIView new];
    _typeGlassView.translatesAutoresizingMaskIntoConstraints = NO;
    // Fixed 42pt pill: pin the radius now since the helper's height/2 only
    // resolves after the first layout pass (matches the subheader clip curve).
    YouModApplyLiquidGlassToView(_typeGlassView, YES);
    _typeGlassView.layer.cornerRadius = 18;
    _typeGlassView.layer.cornerCurve = kCACornerCurveContinuous;
    [topBar addSubview:_typeGlassView];
    _typeGlassLeadingConstraint = [_typeGlassView.leadingAnchor constraintEqualToAnchor:topBar.leadingAnchor constant:14];
    _typeGlassTrailingConstraint = [_typeGlassView.trailingAnchor constraintEqualToAnchor:topBar.trailingAnchor constant:-14];

    _typeScrollView = [UIScrollView new];
    _typeScrollView.showsHorizontalScrollIndicator = NO;
    _typeScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    // Clip the regular scroll-view subheader to a continuous curve, independent of its glass backdrop.
    _typeScrollView.layer.cornerRadius = 18;
    _typeScrollView.layer.cornerCurve = kCACornerCurveContinuous;
    _typeScrollView.clipsToBounds = YES;
    _typeScrollView.panGestureRecognizer.enabled = NO;
    _typeScrollLeadingConstraint = [_typeScrollView.leadingAnchor constraintEqualToAnchor:topBar.leadingAnchor constant:16];
    _typeScrollTrailingConstraint = [_typeScrollView.trailingAnchor constraintEqualToAnchor:topBar.trailingAnchor constant:-16];
    _typeStackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    _typeStackView.axis = UILayoutConstraintAxisHorizontal;
    _typeStackView.spacing = 0;
    _typeStackView.alignment = UIStackViewAlignmentFill;
    _typeStackView.translatesAutoresizingMaskIntoConstraints = NO;
    [_typeScrollView addSubview:_typeStackView];
    [topBar addSubview:_typeScrollView];

    _playlistBackButton = [%c(YTQTMButton) iconButton];
    [_playlistBackButton setImage:[UIImage systemImageNamed:@"chevron.left"] forState:UIControlStateNormal];
    _playlistBackButton.tintColor = [UIColor labelColor];
    _playlistBackButton.accessibilityLabel = [YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_TYPE_PLAYLISTS" fallback:@"Back to playlists"];
    _playlistBackButton.translatesAutoresizingMaskIntoConstraints = NO;
    _playlistBackButton.hidden = YES;
    [_playlistBackButton addTarget:self action:@selector(backToPlaylistsTapped) forControlEvents:UIControlEventTouchUpInside];
    if (YMHostBundleSupportsLiquidGlass()) YouModApplyLiquidGlassToView(_playlistBackButton, YES);
    else [_playlistBackButton enableNewTouchFeedback];
    [topBar addSubview:_playlistBackButton];

    // Playlist create/delete actions live in their own glass pill pinned to the trailing end
    // of the type bar, floating above the scrolling chips.
    _playlistActionsView = [UIView new];
    _playlistActionsView.translatesAutoresizingMaskIntoConstraints = NO;
    _playlistActionsView.layer.zPosition = 1;
    _playlistActionsView.hidden = YES;
    // Fixed 36pt pill: pin the radius now since the helper's height/2 only
    // resolves after the first layout pass.
    YouModApplyLiquidGlassToView(_playlistActionsView, YES);
    _playlistActionsView.layer.cornerRadius = 18;
    _playlistActionsView.layer.cornerCurve = kCACornerCurveContinuous;
    [topBar addSubview:_playlistActionsView];

    _addPlaylistButton = [%c(YTQTMButton) iconButton];
    [_addPlaylistButton setImage:[[UIImage systemImageNamed:@"plus"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    _addPlaylistButton.tintColor = [UIColor labelColor];
    _addPlaylistButton.accessibilityLabel = [YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_CREATE_PLAYLIST" fallback:@"Create playlist"];
    [_addPlaylistButton addTarget:self action:@selector(createPlaylistTapped) forControlEvents:UIControlEventTouchUpInside];
    _addPlaylistButton.translatesAutoresizingMaskIntoConstraints = NO;
    if (!YMHostBundleSupportsLiquidGlass()) [_addPlaylistButton enableNewTouchFeedback];
    else {
        @try {
            _addPlaylistButton.disableTouchResponse = YES;
        } @catch (id ex) {}
    }

    _deletePlaylistButton = [%c(YTQTMButton) iconButton];
    [_deletePlaylistButton setImage:[[UIImage systemImageNamed:@"trash"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    _deletePlaylistButton.tintColor = [UIColor systemRedColor];
    _deletePlaylistButton.accessibilityLabel = [YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_DELETE_PLAYLIST" fallback:@"Delete playlist"];
    [_deletePlaylistButton addTarget:self action:@selector(deletePlaylistTapped) forControlEvents:UIControlEventTouchUpInside];
    _deletePlaylistButton.translatesAutoresizingMaskIntoConstraints = NO;
    if (!YMHostBundleSupportsLiquidGlass()) [_deletePlaylistButton enableNewTouchFeedback];
    else {
        @try {
            _deletePlaylistButton.disableTouchResponse = YES;
        } @catch (id ex) {}
    }

    UIStackView *playlistActionsStack = [[UIStackView alloc] initWithArrangedSubviews:@[_addPlaylistButton, _deletePlaylistButton]];
    playlistActionsStack.axis = UILayoutConstraintAxisHorizontal;
    playlistActionsStack.spacing = 4;
    playlistActionsStack.alignment = UIStackViewAlignmentCenter;
    playlistActionsStack.layoutMarginsRelativeArrangement = YES;
    playlistActionsStack.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(4, 6, 4, 6);
    playlistActionsStack.translatesAutoresizingMaskIntoConstraints = NO;
    [_playlistActionsView addSubview:playlistActionsStack];

    [self rebuildLibraryControls];

    UILayoutGuide *headerContentGuide = [UILayoutGuide new];
    [topBar addLayoutGuide:headerContentGuide];

    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:[YMLibraryGridLayout new]];
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    _collectionView.backgroundColor = [YMLibraryStyle youTubeBackgroundColor];
    _collectionView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    _collectionView.alwaysBounceVertical = YES; // lets the pull-to-refresh gesture work even with few or no items
    // The grid is clipped to the area below the header so scrolling videos never show up
    // behind the search bar or the type selector.
    _collectionView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    _collectionView.contentInset = UIEdgeInsetsZero;
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    [_collectionView registerClass:[YMLibraryVideoCell class] forCellWithReuseIdentifier:@"video"];
    [self.view addSubview:_collectionView];

    _refreshControl = [YMLibraryRefreshControl new];
    _refreshControl.translatesAutoresizingMaskIntoConstraints = NO;
    // Lives outside the clipped grid, parked just below the header; topBar covers it while it
    // slides down into place.
    [self.view addSubview:_refreshControl];
    [NSLayoutConstraint activateConstraints:@[
        [_refreshControl.topAnchor constraintEqualToAnchor:topBar.bottomAnchor constant:12],
        [_refreshControl.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_refreshControl.widthAnchor constraintEqualToConstant:44],
        [_refreshControl.heightAnchor constraintEqualToConstant:44],
    ]];
    [self.view bringSubviewToFront:topBar];
    __weak typeof(self) weakSelf = self;
    _refreshControl.onRefresh = ^{
        [weakSelf reloadWithCompletion:^{
            [weakSelf.refreshControl endRefreshing];
        }];
    };

    [NSLayoutConstraint activateConstraints:@[
        [topBar.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [topBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [topBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        // Header ends just below the type selector with a small gap (the old
        // fixed 174pt height left a device-dependent empty strip).
        [topBar.bottomAnchor constraintEqualToAnchor:_typeGlassView.bottomAnchor constant:10],

        [topBarSeparator.leadingAnchor constraintEqualToAnchor:topBar.leadingAnchor],
        [topBarSeparator.trailingAnchor constraintEqualToAnchor:topBar.trailingAnchor],
        [topBarSeparator.bottomAnchor constraintEqualToAnchor:topBar.bottomAnchor],
        [topBarSeparator.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],

        [headerContentGuide.topAnchor constraintEqualToAnchor:topBar.safeAreaLayoutGuide.topAnchor],
        [headerContentGuide.bottomAnchor constraintEqualToAnchor:topBar.bottomAnchor],
        [headerContentGuide.leadingAnchor constraintEqualToAnchor:topBar.leadingAnchor],
        [headerContentGuide.trailingAnchor constraintEqualToAnchor:topBar.trailingAnchor],

        [_searchBar.leadingAnchor constraintEqualToAnchor:headerContentGuide.leadingAnchor constant:14],
        [_searchBar.centerYAnchor constraintEqualToAnchor:headerContentGuide.topAnchor constant:26],
        [_searchBar.trailingAnchor constraintEqualToAnchor:_headerButtonStack.leadingAnchor constant:-6],

        [_headerButtonStack.trailingAnchor constraintEqualToAnchor:headerContentGuide.trailingAnchor constant:-14],
        [_headerButtonStack.centerYAnchor constraintEqualToAnchor:headerContentGuide.topAnchor constant:26],
        [_headerButtonStack.heightAnchor constraintEqualToConstant:40],

        [_sortButton.widthAnchor constraintEqualToConstant:40],
        [_sortButton.heightAnchor constraintEqualToConstant:40],
        [_selectButton.widthAnchor constraintEqualToConstant:40],
        [_selectButton.heightAnchor constraintEqualToConstant:40],
        [_selectionExitButton.widthAnchor constraintEqualToConstant:40],
        [_selectionExitButton.heightAnchor constraintEqualToConstant:40],
        [_moreMenuButton.widthAnchor constraintEqualToConstant:40],
        [_moreMenuButton.heightAnchor constraintEqualToConstant:40],
        [_settingsButton.widthAnchor constraintEqualToConstant:40],
        [_settingsButton.heightAnchor constraintEqualToConstant:40],

        [_typeGlassView.topAnchor constraintEqualToAnchor:headerContentGuide.topAnchor constant:58],
        _typeGlassLeadingConstraint,
        _typeGlassTrailingConstraint,
        [_typeGlassView.heightAnchor constraintEqualToConstant:36],

        [_typeScrollView.topAnchor constraintEqualToAnchor:headerContentGuide.topAnchor constant:58],
        _typeScrollLeadingConstraint,
        _typeScrollTrailingConstraint,
        [_typeScrollView.heightAnchor constraintEqualToConstant:36],
        [_typeStackView.topAnchor constraintEqualToAnchor:_typeScrollView.contentLayoutGuide.topAnchor],
        [_typeStackView.bottomAnchor constraintEqualToAnchor:_typeScrollView.contentLayoutGuide.bottomAnchor],
        [_typeStackView.leadingAnchor constraintEqualToAnchor:_typeScrollView.contentLayoutGuide.leadingAnchor],
        [_typeStackView.trailingAnchor constraintEqualToAnchor:_typeScrollView.contentLayoutGuide.trailingAnchor],
        [_typeStackView.heightAnchor constraintEqualToAnchor:_typeScrollView.frameLayoutGuide.heightAnchor],

        [_playlistBackButton.leadingAnchor constraintEqualToAnchor:topBar.leadingAnchor constant:14],
        [_playlistBackButton.centerYAnchor constraintEqualToAnchor:_typeScrollView.centerYAnchor],
        [_playlistBackButton.widthAnchor constraintEqualToConstant:36],
        [_playlistBackButton.heightAnchor constraintEqualToConstant:36],

        [_playlistActionsView.trailingAnchor constraintEqualToAnchor:topBar.trailingAnchor constant:-14],
        [_playlistActionsView.centerYAnchor constraintEqualToAnchor:_typeScrollView.centerYAnchor],
        [_playlistActionsView.heightAnchor constraintEqualToConstant:36],

        [playlistActionsStack.topAnchor constraintEqualToAnchor:_playlistActionsView.topAnchor],
        [playlistActionsStack.bottomAnchor constraintEqualToAnchor:_playlistActionsView.bottomAnchor],
        [playlistActionsStack.leadingAnchor constraintEqualToAnchor:_playlistActionsView.leadingAnchor],
        [playlistActionsStack.trailingAnchor constraintEqualToAnchor:_playlistActionsView.trailingAnchor],

        [_addPlaylistButton.widthAnchor constraintEqualToConstant:28],
        [_addPlaylistButton.heightAnchor constraintEqualToConstant:28],
        [_deletePlaylistButton.widthAnchor constraintEqualToConstant:28],
        [_deletePlaylistButton.heightAnchor constraintEqualToConstant:28],

        [_collectionView.topAnchor constraintEqualToAnchor:topBar.bottomAnchor],
        [_collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];

    _emptyLabel = [UILabel new];
    _emptyLabel.text = [self.selectedType isEqualToString:kYMLibraryTypePlaylists] ? [YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_NO_PLAYLISTS" fallback:@"No playlists yet"] : LOC(@"DOWNLOAD_LIBRARY_EMPTY");
    _emptyLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    _emptyLabel.textColor = [UIColor secondaryLabelColor];
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.hidden = YES;
    _emptyIconView.hidden = YES;
    _emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_emptyLabel];
    [NSLayoutConstraint activateConstraints:@[
        [_emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [_emptyLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:24],
        [_emptyLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-24],
    ]];

    _emptyIconView = [UIImageView new];
    _emptyIconView.image = [[YMIconProvider settingsIcon:@"download_settings"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    _emptyIconView.tintColor = [UIColor secondaryLabelColor];
    _emptyIconView.contentMode = UIViewContentModeScaleAspectFit;
    _emptyIconView.hidden = YES;
    _emptyIconView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_emptyIconView];
    [NSLayoutConstraint activateConstraints:@[
        [_emptyIconView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyIconView.bottomAnchor constraintEqualToAnchor:_emptyLabel.topAnchor constant:-12],
        [_emptyIconView.widthAnchor constraintEqualToConstant:56],
        [_emptyIconView.heightAnchor constraintEqualToConstant:56],
    ]];

    [self updateSearchBarTheme];
    [self reload];
}

- (NSString *)displayTitleForType:(NSString *)type {
    NSDictionary *labels = @{
        kYMLibraryTypeAll: @[@"DOWNLOAD_LIBRARY_TYPE_ALL", @"All"],
        kYMLibraryTypeVideos: @[@"DOWNLOAD_LIBRARY_TYPE_VIDEOS", @"Videos"],
        kYMLibraryTypeShorts: @[@"DOWNLOAD_LIBRARY_TYPE_SHORTS", @"Shorts"],
        kYMLibraryTypeAudio: @[@"DOWNLOAD_LIBRARY_TYPE_AUDIO", @"Audio"],
        kYMLibraryTypePlaylists: @[@"DOWNLOAD_LIBRARY_TYPE_PLAYLISTS", @"Playlists"],
        kYMLibraryTypePrivate: @[@"DOWNLOAD_LIBRARY_TYPE_PRIVATE", @"Private"],
    };
    NSArray *entry = labels[type];
    return entry ? [YMLibraryHelpers localizedText:entry[0] fallback:entry[1]] : type;
}

- (NSString *)displayTitleForSort:(NSString *)sort isSelected:(BOOL)selected {
    NSDictionary *labels = @{
        @"Newest": @[@"DOWNLOAD_LIBRARY_SORT_NEWEST", @"Newest"],
        @"Oldest": @[@"DOWNLOAD_LIBRARY_SORT_OLDEST", @"Oldest"],
        @"Largest": @[@"DOWNLOAD_LIBRARY_SORT_LARGEST", @"Largest"],
        @"Smallest": @[@"DOWNLOAD_LIBRARY_SORT_SMALLEST", @"Smallest"],
        @"A-Z": @[@"DOWNLOAD_LIBRARY_SORT_AZ", @"A-Z"],
        @"Z-A": @[@"DOWNLOAD_LIBRARY_SORT_ZA", @"Z-A"],
    };
    NSArray *entry = labels[sort];
    NSString *title = entry ? [YMLibraryHelpers localizedText:entry[0] fallback:entry[1]] : sort;
    // "<checkmark>  <text>" marks the selected option.
    return selected ? [@"\u2713 " stringByAppendingString:title] : title;
}

- (void)updateSortButtonAccessibilityLabel {
    NSString *selectedTitle = [self displayTitleForSort:self.selectedSort ?: @"Newest" isSelected:NO];
    _sortButton.accessibilityLabel = [NSString stringWithFormat:@"Sort by %@", selectedTitle];
}

- (void)updateSortMenu {
    NSArray<NSString *> *sorts = @[@"Newest", @"Oldest", @"Largest", @"Smallest", @"A-Z", @"Z-A"];
    id parentResponder = self.hostParentResponder ?: self;
    YTDefaultSheetController *sheet = [%c(YTDefaultSheetController) sheetControllerWithParentResponder:parentResponder];
    [sheet addHeaderWithTitle:nil subtitle:[YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_SORT_TITLE" fallback:@"Sort videos by"]];

    __weak typeof(self) weakSelf = self;
    [sorts enumerateObjectsUsingBlock:^(NSString *sort, NSUInteger idx, BOOL *stop) {
        BOOL selected = [sort isEqualToString:self.selectedSort];
        YTActionSheetAction *action = [%c(YTActionSheetAction) actionWithTitle:[self displayTitleForSort:sort isSelected:selected]
                                                                         style:0
                                                                       handler:^(__unused YTActionSheetAction *selectedAction) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.selectedSort = sort;
            [[NSUserDefaults standardUserDefaults] setObject:sort forKey:@"YouModDownloadLibrarySelectedSort"];
            [strongSelf updateSortButtonAccessibilityLabel];
            [strongSelf applyFiltersAndSort];
        }];
        [sheet addAction:action];
    }];
    [sheet presentFromView:self.sortButton animated:YES completion:nil];
}

- (void)rebuildLibraryControls {
    [self.typeStackView.arrangedSubviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    NSArray *types = [YMLibraryHelpers types];
    [types enumerateObjectsUsingBlock:^(NSString *type, NSUInteger idx, BOOL *stop) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = (NSInteger)idx;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        button.contentEdgeInsets = UIEdgeInsetsMake(5, 14, 5, 14);
#pragma clang diagnostic pop
        button.titleLabel.font = [UIFont systemFontOfSize:15 weight:[self.selectedType isEqualToString:type] ? UIFontWeightSemibold : UIFontWeightRegular];
        [button setTitle:[self displayTitleForType:type] forState:UIControlStateNormal];
        [button setTitleColor:[self.selectedType isEqualToString:type] ? [UIColor labelColor] : [UIColor secondaryLabelColor] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(libraryTypeTapped:) forControlEvents:UIControlEventTouchUpInside];
        button.layer.cornerRadius = 18;
        button.layer.cornerCurve = kCACornerCurveContinuous;
        button.clipsToBounds = YES;
        button.backgroundColor = [self.selectedType isEqualToString:type] ? [UIColor.secondarySystemFillColor colorWithAlphaComponent:0.82] : UIColor.clearColor;
        [self.typeStackView addArrangedSubview:button];
    }];

    // Playlist actions are only available on the playlists overview, not inside a playlist.
    BOOL inPlaylists = [self.selectedType isEqualToString:kYMLibraryTypePlaylists];
    BOOL viewingPlaylist = self.selectedPlaylistID.length > 0;
    BOOL wasBackHidden = self.playlistBackButton.hidden;
    BOOL wasActionsHidden = self.playlistActionsView.hidden;
    BOOL showBack = viewingPlaylist && !self.isSelectionMode;
    BOOL showActions = inPlaylists && !viewingPlaylist && !self.isSelectionMode;
    self.playlistBackButton.hidden = !showBack;
    self.playlistActionsView.hidden = !showActions;
    self.deletePlaylistButton.enabled = [YMLibraryHelpers playlistsMatchingLockState:NO].count > 0;
    if (showBack && wasBackHidden) {
        self.playlistBackButton.transform = CGAffineTransformMakeTranslation(-60, 0);
        [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.playlistBackButton.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
    if (showActions && wasActionsHidden) {
        self.playlistActionsView.transform = CGAffineTransformMakeTranslation(100, 0);
        [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.playlistActionsView.transform = CGAffineTransformIdentity;
        } completion:nil];
    }
    // Reserve leading space for the back button (playlist detail) and trailing space for the actions pill (overview).
    self.typeGlassLeadingConstraint.constant = viewingPlaylist ? 56 : 14;
    self.typeScrollLeadingConstraint.constant = viewingPlaylist ? 58 : 16;
    self.typeGlassTrailingConstraint.constant = inPlaylists && !viewingPlaylist ? -94 : -14;
    self.typeScrollTrailingConstraint.constant = inPlaylists && !viewingPlaylist ? -96 : -16;
    self.typeScrollView.contentInset = UIEdgeInsetsZero;

    [self updateSortButtonAccessibilityLabel];
}

- (void)refreshTypeSelection {
    [self rebuildLibraryControls];
    [self.view layoutIfNeeded];
    [self applyFiltersAndSort];
}

- (void)scrollToSelectedTypeAnimated:(BOOL)animated {
    NSArray *types = [YMLibraryHelpers types];
    NSUInteger idx = [types indexOfObject:self.selectedType ?: kYMLibraryTypeAll];
    if (idx == NSNotFound) idx = 0;
    __block CGFloat offset = 0;
    [[self.typeStackView.arrangedSubviews subarrayWithRange:NSMakeRange(0, idx)] enumerateObjectsUsingBlock:^(UIButton *btn, NSUInteger i, BOOL *stop) {
        offset += btn.intrinsicContentSize.width + 8;
    }];
    CGFloat maxOffset = self.typeScrollView.contentSize.width - self.typeScrollView.bounds.size.width;
    if (maxOffset < 0) maxOffset = 0;
    [self.typeScrollView setContentOffset:CGPointMake(MIN(offset, maxOffset), 0) animated:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self scrollToSelectedTypeAnimated:YES];
}

- (void)updateHeaderVisibility {
    self.sortButton.hidden = self.isSelectionMode;
    self.settingsButton.hidden = self.isSelectionMode;
    self.selectionExitButton.hidden = !self.isSelectionMode;
    self.moreMenuButton.hidden = !self.isSelectionMode;
    // Backdrop is visible whenever selection mode is off — regardless of playlist state.
    self.typeGlassView.alpha = self.isSelectionMode ? 0.0 : 1.0;
    self.typeScrollView.alpha = self.isSelectionMode ? 0.0 : 1.0;
}

- (void)updateSelectButtonIcon {
    if (!self.isSelectionMode) {
        [_selectButton setImage:[[YMIconProvider tabIcon:@"check_all" selected:NO] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        _selectButton.accessibilityLabel = LOC(@"LIBRARY_SELECT");
        return;
    }
    BOOL allSelected = self.selectedIndexPaths.count == self.rows.count && self.rows.count > 0;
    NSString *iconName = allSelected ? @"check" : @"check_all";
    [_selectButton setImage:[[YMIconProvider tabIcon:iconName selected:NO] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    _selectButton.accessibilityLabel = allSelected ? LOC(@"LIBRARY_DESELECT_ALL") : LOC(@"LIBRARY_SELECT_ALL");
}

- (void)selectButtonTapped {
    if (!self.isSelectionMode) {
        [self enterSelectionMode];
        return;
    }
    if (self.selectedIndexPaths.count == self.rows.count && self.rows.count > 0) {
        [self.selectedIndexPaths removeAllObjects];
    } else {
        [self.rows enumerateObjectsUsingBlock:^(__unused YMLibraryRow *row, NSUInteger i, BOOL *stop) {
            [self.selectedIndexPaths addObject:[NSIndexPath indexPathForItem:i inSection:0]];
        }];
    }
    [self.collectionView reloadData];
    [self updateSelectButtonIcon];
}

- (void)enterSelectionMode {
    self.isSelectionMode = YES;
    self.selectedIndexPaths = [NSMutableSet set];
    // Rebuild hides the playlist back button and the create/delete pill while selecting.
    [self rebuildLibraryControls];
    [self updateHeaderVisibility];
    [self updateSelectButtonIcon];
    [self applyFiltersAndSort];
}

- (void)exitSelectionMode {
    self.isSelectionMode = NO;
    self.selectedIndexPaths = nil;
    [self updateHeaderVisibility];
    [self updateSelectButtonIcon];
    [self refreshTypeSelection];
}

- (NSArray *)selectedRows {
    NSMutableArray *rows = [NSMutableArray array];
    [self.selectedIndexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, BOOL *stop) {
        if (indexPath.item < self.rows.count) [rows addObject:self.rows[indexPath.item]];
    }];
    return rows;
}

- (void)backToPlaylistsTapped {
    if (self.selectedPlaylistID.length == 0) return;
    self.selectedPlaylistID = nil;
    [self refreshTypeSelection];
}

- (void)libraryTypeTapped:(UIButton *)sender {
    NSArray *types = [YMLibraryHelpers types];
    if (sender.tag < 0 || sender.tag >= (NSInteger)types.count) return;
    NSString *newType = types[(NSUInteger)sender.tag];
    if ([newType isEqualToString:kYMLibraryTypePrivate]) {
        [self authenticateForPrivateLibrary];
        return;
    }
    if ([self.selectedType isEqualToString:kYMLibraryTypePrivate]) self.privateUnlocked = NO;
    if ([newType isEqualToString:kYMLibraryTypePlaylists] && [self.selectedType isEqualToString:kYMLibraryTypePlaylists]) self.selectedPlaylistID = nil;
    else if (![newType isEqualToString:kYMLibraryTypePlaylists]) self.selectedPlaylistID = nil;
    self.selectedType = newType;
    [[NSUserDefaults standardUserDefaults] setObject:self.selectedType forKey:@"YouModDownloadLibrarySelectedType"];
    [self refreshTypeSelection];
}

- (void)authenticateForPrivateLibrary {
    if (self.privateUnlocked) {
        [self selectPrivateLibrary];
        return;
    }
    if (self.isAuthenticatingPrivate) return;
    LAContext *context = [LAContext new];
    NSError *error = nil;
    if (![context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&error]) {
        YouModSendError([YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_PRIVATE_AUTH_UNAVAILABLE" fallback:@"Set up Face ID, Touch ID, or a device passcode to open Private."]);
        return;
    }
    self.isAuthenticatingPrivate = YES;
    self.privateAuthWasBackgrounded = NO;
    __weak typeof(self) weakSelf = self;
    [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication
            localizedReason:[YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_PRIVATE_AUTH_REASON" fallback:@"Authenticate to view private downloads"]
                      reply:^(BOOL success, NSError *authError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.isAuthenticatingPrivate = NO;
            BOOL backgrounded = strongSelf.privateAuthWasBackgrounded;
            strongSelf.privateAuthWasBackgrounded = NO;
            if (success && !backgrounded) {
                strongSelf.privateUnlocked = YES;
                [strongSelf selectPrivateLibrary];
            } else if (authError && authError.code != LAErrorUserCancel && authError.code != LAErrorAppCancel && authError.code != LAErrorSystemCancel) {
                YouModSendError([YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_PRIVATE_AUTH_FAILED" fallback:@"Authentication failed. Private downloads remain locked."]);
            }
        });
    }];
}

- (void)selectPrivateLibrary {
    self.selectedPlaylistID = nil;
    self.selectedType = kYMLibraryTypePrivate;
    [[NSUserDefaults standardUserDefaults] setObject:self.selectedType forKey:@"YouModDownloadLibrarySelectedType"];
    [self refreshTypeSelection];
}

- (void)libraryDidEnterBackground {
    self.privateUnlocked = NO;
    if (self.isAuthenticatingPrivate) self.privateAuthWasBackgrounded = YES;
    if ([self.selectedType isEqualToString:kYMLibraryTypePrivate]) {
        self.selectedType = kYMLibraryTypeAll;
        self.selectedPlaylistID = nil;
        [[NSUserDefaults standardUserDefaults] setObject:self.selectedType forKey:@"YouModDownloadLibrarySelectedType"];
        [self refreshTypeSelection];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
}

// Same treatment as the YouMod settings pages: the bar itself blends into the
// background and the rounded text field carries an adaptive glass effect.
- (void)updateSearchBarTheme {
    UISearchBar *sb = self.searchBar;
    if (!sb) return;
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    sb.backgroundColor = UIColor.clearColor;
    sb.barTintColor = UIColor.clearColor;
    UITextField *tf = sb.searchTextField;
    tf.textColor = dark ? [UIColor whiteColor] : [UIColor labelColor];
    tf.tintColor = sb.tintColor;
    tf.attributedPlaceholder = [[NSAttributedString alloc] initWithString:sb.placeholder ?: @"" attributes:@{NSForegroundColorAttributeName: [UIColor secondaryLabelColor]}];
    if (YMHostBundleSupportsLiquidGlass()) {
        tf.backgroundColor = UIColor.clearColor;
        YouModApplyLiquidGlassToView(tf, NO);
    } else {
        tf.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
            return (trait.userInterfaceStyle == UIUserInterfaceStyleDark) ? [UIColor secondarySystemBackgroundColor] : [UIColor systemGray5Color];
        }];
    }
    tf.layer.cornerRadius = YMCornerRadiusSearchBar;
    tf.layer.cornerCurve = kCACornerCurveContinuous;
    tf.layer.masksToBounds = YES;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // Keep the search field corner radius in sync with the liquid-glass helper.
    UITextField *tf = self.searchBar.searchTextField;
    tf.layer.cornerRadius = YMCornerRadiusSearchBar;
    tf.layer.cornerCurve = kCACornerCurveContinuous;
    tf.layer.masksToBounds = YES;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle) {
        YouModApplyLiquidGlassToView(self.typeGlassView, YES);
        YouModApplyLiquidGlassToView(self.playlistActionsView, YES);
        [self updateSearchBarTheme];
    }
}

- (void)openSettingsTapped {
    id parentResponder = self.hostParentResponder ?: self;
    static const uint64_t kApplicationSettingsEndpointField = 50078082;
    id endpoint = [[%c(YTIApplicationSettingsEndpoint) alloc] init];
    if ([endpoint respondsToSelector:NSSelectorFromString(@"setHack:")]) [endpoint setValue:@YES forKey:@"hack"];
    NSData *payload = [endpoint data];
    NSMutableData *wire = [NSMutableData data];
    uint64_t varints[] = {(kApplicationSettingsEndpointField << 3) | 2, payload.length}; // tag, length
    for (int i = 0; i < 2; i++) {
        uint64_t v = varints[i];
        while (v >= 0x80) {
            uint8_t byte = (uint8_t)(v | 0x80);
            [wire appendBytes:&byte length:1];
            v >>= 7;
        }
        uint8_t byte = (uint8_t)v;
        [wire appendBytes:&byte length:1];
    }
    [wire appendData:payload];
    YTICommand *command = [%c(YTICommand) goog_parseFromData:wire error:nil];
    if (!command) return;
    [[%c(YTCommandResponderEvent) eventWithCommand:command fromView:nil entry:nil sendClick:NO firstResponder:parentResponder] send];
}

- (void)reloadWithCompletion:(void (^)(void))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray<NSURL *> *files = [YMLibraryHelpers fileURLsNewestFirst];
        NSMutableArray<YMLibraryRow *> *rows = [NSMutableArray arrayWithCapacity:files.count];
        [files enumerateObjectsUsingBlock:^(NSURL *fileURL, NSUInteger idx, BOOL *stop) {
            NSNumber *size = nil;
            [fileURL getResourceValue:&size forKey:NSURLFileSizeKey error:nil];

            YMLibraryRow *row = [YMLibraryRow new];
            row.path = fileURL.path;
            row.title = [YMLibraryHelpers displayTitleForFileName:fileURL.lastPathComponent.stringByDeletingPathExtension];
            row.bytes = size.unsignedLongLongValue;
            row.sizeText = [YMLibraryHelpers formattedFileSize:row.bytes];
            row.isAudio = [YMLibraryHelpers isAudioOnlyExtension:fileURL.pathExtension];
            NSDictionary *metadata = [YMLibraryHelpers metadataForURL:fileURL];
            row.isShorts = [metadata[@"shorts"] boolValue] && !row.isAudio;
            row.isPrivate = [metadata[@"private"] boolValue];
            row.playlistIDs = [metadata[@"playlists"] isKindOfClass:[NSArray class]] ? metadata[@"playlists"] : @[];
            NSDate *modifiedDate = nil;
            [fileURL getResourceValue:&modifiedDate forKey:NSURLContentModificationDateKey error:nil];
            row.modifiedDate = modifiedDate ?: NSDate.distantPast;
            // Audio rows have no real artwork: the note icon fills a fixed 48pt canvas.
            row.thumbnail = row.isAudio
                ? YouModSymbolImageInCanvas(@"music.note", 48, 24, UIImageSymbolWeightRegular)
                : [YMLibraryHelpers thumbnailForVideoFile:fileURL];
            [rows addObject:row];
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.allRows = rows;
            [self applyFilter:self.searchBar.text];
            if (completion) completion();
        });
    });
}

- (void)reload {
    [self reloadWithCompletion:nil];
}

- (void)applyFilter:(NSString *)query {
    query = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL privateTab = [self.selectedType isEqualToString:kYMLibraryTypePrivate];
    BOOL viewingPlaylist = self.selectedPlaylistID.length > 0;
    // One list serves browsing and selection mode. Playlist rows lead each overview:
    // unlocked playlists on All/Playlists, locked playlists on Private.
    BOOL showPlaylistRows = (!privateTab || self.privateUnlocked) && !viewingPlaylist
        && ([self.selectedType isEqualToString:kYMLibraryTypeAll]
            || [self.selectedType isEqualToString:kYMLibraryTypePlaylists]
            || privateTab);

    NSMutableArray<YMLibraryRow *> *playlistRows = [NSMutableArray array];
    NSArray<NSDictionary *> *tabPlaylists = [YMLibraryHelpers playlistsMatchingLockState:privateTab];
    // A locked playlist hides along with its videos: any playlist claims on the public side,
    // only locked ones on the Private side.
    NSArray<NSDictionary *> *claimPlaylists = privateTab ? [YMLibraryHelpers playlistsMatchingLockState:YES] : [YMLibraryHelpers playlists];
    if (showPlaylistRows) {
        // Item counts in one pass: a locked playlist lists everything inside it, a regular
        // playlist only its non-private items.
        NSArray<YMLibraryRow *> *countedItems = privateTab ? self.allRows : [self.allRows filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(YMLibraryRow *item, NSDictionary *bindings) {
            return !item.isPrivate && item.playlistIDs.count > 0;
        }]];
        NSCountedSet<NSString *> *playlistItemIDs = [NSCountedSet setWithArray:[countedItems valueForKeyPath:@"@unionOfArrays.playlistIDs"]];
        [tabPlaylists enumerateObjectsUsingBlock:^(NSDictionary *playlist, NSUInteger idx, BOOL *stop) {
            NSString *name = playlist[@"name"] ?: @"";
            if (query.length > 0 && [name rangeOfString:query options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location == NSNotFound) return;
            NSString *playlistID = playlist[@"id"] ?: @"";
            NSUInteger itemCount = [playlistItemIDs countForObject:playlistID];
            YMLibraryRow *playlistRow = [YMLibraryRow new];
            playlistRow.isPlaylist = YES;
            playlistRow.isLocked = privateTab;
            playlistRow.playlistID = playlistID;
            playlistRow.title = name;
            playlistRow.bytes = itemCount;
            playlistRow.sizeText = [NSString stringWithFormat:[YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_PLAYLIST_ITEM_COUNT" fallback:@"%ld items"], (long)itemCount];
            playlistRow.thumbnail = YouModSymbolImageInCanvas(@"music.note.list", 48, 24, UIImageSymbolWeightRegular);
            playlistRow.modifiedDate = NSDate.distantPast;
            [playlistRows addObject:playlistRow];
        }];
        if ([self.selectedSort isEqualToString:@"A-Z"]) {
            [playlistRows sortUsingComparator:^NSComparisonResult(YMLibraryRow *a, YMLibraryRow *b) { return [a.title localizedCaseInsensitiveCompare:b.title]; }];
        } else if ([self.selectedSort isEqualToString:@"Z-A"]) {
            [playlistRows sortUsingComparator:^NSComparisonResult(YMLibraryRow *a, YMLibraryRow *b) { return [b.title localizedCaseInsensitiveCompare:a.title]; }];
        }
    }

    // Locked playlist views show everything inside them; videos inside a claimed playlist
    // hide from the flat lists.
    NSMutableArray<YMLibraryRow *> *filtered = [[self.allRows filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(YMLibraryRow *row, NSDictionary *bindings) {
        if (row.isPlaylist) return NO;
        BOOL typeMatches = YES;
        if (viewingPlaylist && privateTab) {
            typeMatches = [row.playlistIDs containsObject:self.selectedPlaylistID];
        } else {
            if (row.isPrivate != privateTab || (privateTab && !self.privateUnlocked)) return NO;
            if (viewingPlaylist) {
                typeMatches = [row.playlistIDs containsObject:self.selectedPlaylistID];
            } else {
                if ([row isInAnyPlaylist:claimPlaylists]) return NO;
                if ([self.selectedType isEqualToString:kYMLibraryTypeVideos]) typeMatches = !row.isAudio && !row.isShorts;
                else if ([self.selectedType isEqualToString:kYMLibraryTypeShorts]) typeMatches = row.isShorts;
                else if ([self.selectedType isEqualToString:kYMLibraryTypeAudio]) typeMatches = row.isAudio;
                else if ([self.selectedType isEqualToString:kYMLibraryTypePlaylists]) typeMatches = NO; // the overview lists playlists only
            }
        }
        BOOL searchMatches = query.length == 0 || [row.title rangeOfString:query options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location != NSNotFound;
        return typeMatches && searchMatches;
    }]] mutableCopy];
    [filtered sortUsingComparator:^NSComparisonResult(YMLibraryRow *a, YMLibraryRow *b) {
        if ([self.selectedSort isEqualToString:@"Oldest"]) return [a.modifiedDate compare:b.modifiedDate];
        if ([self.selectedSort isEqualToString:@"Largest"]) return a.bytes == b.bytes ? NSOrderedSame : (a.bytes > b.bytes ? NSOrderedAscending : NSOrderedDescending);
        if ([self.selectedSort isEqualToString:@"Smallest"]) return a.bytes == b.bytes ? NSOrderedSame : (a.bytes < b.bytes ? NSOrderedAscending : NSOrderedDescending);
        if ([self.selectedSort isEqualToString:@"A-Z"]) return [a.title localizedCaseInsensitiveCompare:b.title];
        if ([self.selectedSort isEqualToString:@"Z-A"]) return [b.title localizedCaseInsensitiveCompare:a.title];
        return [b.modifiedDate compare:a.modifiedDate];
    }];

    // Playlists always lead the grid; videos follow in sort order.
    NSMutableArray<YMLibraryRow *> *combined = [NSMutableArray arrayWithArray:playlistRows];
    [combined addObjectsFromArray:filtered];
    self.rows = combined;
    [self.collectionView reloadData];
    self.emptyLabel.text = ([self.selectedType isEqualToString:kYMLibraryTypePlaylists] && !viewingPlaylist) ? [YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_NO_PLAYLISTS" fallback:@"No playlists yet"] : LOC(@"DOWNLOAD_LIBRARY_EMPTY");
    self.emptyLabel.hidden = self.rows.count > 0;
    self.emptyIconView.hidden = self.rows.count > 0;
}

- (void)applyFiltersAndSort {
    [self applyFilter:self.searchBar.text];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self applyFilter:searchText];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:NO animated:YES];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = @"";
    [searchBar resignFirstResponder];
    [self applyFilter:@""];
}

- (void)createPlaylistTapped {
    [self createPlaylistTappedWithCompletion:nil];
}

- (void)createPlaylistTappedWithCompletion:(void (^)(NSString *playlistID))completion {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_CREATE_PLAYLIST" fallback:@"Create playlist"]
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = [YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_PLAYLIST_NAME" fallback:@"Playlist name"];
        field.autocapitalizationType = UITextAutocapitalizationTypeWords;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:LOC(@"CANCEL") style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:[YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_CREATE" fallback:@"Create"] style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (name.length == 0) return;
        if ([[YMLibraryHelpers playlists] indexOfObjectPassingTest:^BOOL(NSDictionary *playlist, NSUInteger idx, BOOL *stop) {
            return [playlist[@"name"] caseInsensitiveCompare:name] == NSOrderedSame;
        }] != NSNotFound) {
            YouModSendError([YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_PLAYLIST_EXISTS" fallback:@"A playlist with that name already exists"]);
            return;
        }
        NSString *pid = NSUUID.UUID.UUIDString;
        NSMutableArray *playlists = [[YMLibraryHelpers playlists] mutableCopy];
        NSMutableDictionary *entry = [@{@"id": pid, @"name": name} mutableCopy];
        // Playlists created from the Private tab start out locked (hidden there).
        if ([weakSelf.selectedType isEqualToString:kYMLibraryTypePrivate]) entry[@"locked"] = @YES;
        [playlists addObject:entry];
        [YMLibraryHelpers savePlaylists:playlists];
        if (completion) completion(pid);
        [weakSelf refreshTypeSelection];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)deletePlaylistTapped {
    // Locked playlists live behind the Private tab and are managed from there.
    NSArray<NSDictionary *> *playlists = [YMLibraryHelpers playlistsMatchingLockState:NO];
    if (playlists.count == 0) return;
    id parentResponder = self.hostParentResponder ?: self;
    YTDefaultSheetController *sheet = [%c(YTDefaultSheetController) sheetControllerWithParentResponder:parentResponder];
    [sheet addHeaderWithTitle:nil subtitle:[YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_DELETE_PLAYLIST" fallback:@"Delete playlist"]];
    __weak typeof(self) weakSelf = self;
    [playlists enumerateObjectsUsingBlock:^(NSDictionary *playlist, NSUInteger idx, BOOL *stop) {
        NSString *name = playlist[@"name"] ?: @"";
        NSString *playlistID = playlist[@"id"] ?: @"";
        [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:name
                                                        iconImage:YouModSymbolImageInCanvas(@"trash", 24, 22, UIImageSymbolWeightMedium)
                                                            style:0
                                                          handler:^(__unused YTActionSheetAction *action) {
            // Delete playlist directly — no confirmation.
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf deletePlaylistsWithIDs:@[playlistID]];
            [strongSelf refreshTypeSelection];
        }]];
    }];
    [sheet presentFromView:self.deletePlaylistButton animated:YES completion:nil];
}

- (void)togglePrivateForRow:(YMLibraryRow *)row {
    row.isPrivate = !row.isPrivate;
    NSURL *url = [NSURL fileURLWithPath:row.path];
    NSMutableDictionary *metadata = [[YMLibraryHelpers metadataForURL:url] mutableCopy];
    if (row.isPrivate) metadata[@"private"] = @YES;
    else [metadata removeObjectForKey:@"private"];
    [YMLibraryHelpers setMetadataForURL:url entry:metadata];
    [self applyFiltersAndSort];
}

// Toggles immediately — no confirmation; the playlist moves behind the Private tab.
- (void)toggleLockForPlaylistRow:(YMLibraryRow *)row {
    NSString *playlistID = row.playlistID;
    if (playlistID.length == 0) return;
    NSArray<NSDictionary *> *playlists = [YMLibraryHelpers playlists];
    NSUInteger index = [playlists indexOfObjectPassingTest:^BOOL(NSDictionary *entry, NSUInteger idx, BOOL *stop) {
        return [entry[@"id"] isEqualToString:playlistID];
    }];
    if (index == NSNotFound) return;
    BOOL nowLocked = ![YMLibraryHelpers playlistLocked:playlists[index]];
    [self setLocked:nowLocked forPlaylistID:playlistID];
    YouModShowPill([YMLibraryHelpers localizedText:nowLocked ? @"DOWNLOAD_LIBRARY_PLAYLIST_LOCKED" : @"DOWNLOAD_LIBRARY_PLAYLIST_UNLOCKED" fallback:nowLocked ? @"Playlist locked" : @"Playlist unlocked"], YES);
    [self applyFiltersAndSort];
}

// Sets a playlist's locked flag without touching the UI.
- (void)setLocked:(BOOL)locked forPlaylistID:(NSString *)playlistID {
    if (playlistID.length == 0) return;
    NSMutableArray<NSDictionary *> *playlists = [[YMLibraryHelpers playlists] mutableCopy];
    NSUInteger index = [playlists indexOfObjectPassingTest:^BOOL(NSDictionary *entry, NSUInteger idx, BOOL *stop) {
        return [entry[@"id"] isEqualToString:playlistID];
    }];
    if (index == NSNotFound) return;
    NSMutableDictionary *updated = [playlists[index] mutableCopy];
    if (locked) updated[@"locked"] = @YES;
    else [updated removeObjectForKey:@"locked"];
    playlists[index] = updated;
    [YMLibraryHelpers savePlaylists:playlists];
}

// Removes playlists and strips their IDs from every file's metadata.
- (void)deletePlaylistsWithIDs:(NSArray<NSString *> *)playlistIDs {
    if (playlistIDs.count == 0) return;
    NSSet<NSString *> *ids = [NSSet setWithArray:playlistIDs];
    NSMutableArray *updated = [[YMLibraryHelpers playlists] mutableCopy];
    NSIndexSet *matches = [updated indexesOfObjectsPassingTest:^BOOL(NSDictionary *entry, NSUInteger idx, BOOL *stop) {
        return [ids containsObject:entry[@"id"]];
    }];
    [updated removeObjectsAtIndexes:matches];
    [YMLibraryHelpers savePlaylists:updated];
    if ([ids containsObject:self.selectedPlaylistID]) self.selectedPlaylistID = nil;
    [self.allRows enumerateObjectsUsingBlock:^(YMLibraryRow *row, NSUInteger idx, BOOL *stop) {
        NSMutableArray *rowIDs = [row.playlistIDs mutableCopy] ?: [NSMutableArray array];
        NSUInteger before = rowIDs.count;
        [rowIDs removeObjectsInArray:playlistIDs];
        if (rowIDs.count == before) return;
        row.playlistIDs = rowIDs;
        NSMutableDictionary *metadata = [[YMLibraryHelpers metadataForURL:[NSURL fileURLWithPath:row.path]] mutableCopy];
        if (rowIDs.count > 0) metadata[@"playlists"] = rowIDs;
        else [metadata removeObjectForKey:@"playlists"];
        [YMLibraryHelpers setMetadataForURL:[NSURL fileURLWithPath:row.path] entry:metadata];
    }];
}

// A download lives in one playlist only: tapping assigns it, tapping the current one removes it.
- (void)showPlaylistPickerForRow:(YMLibraryRow *)row sourceView:(UIView *)sourceView {
    NSArray<NSDictionary *> *playlists = [YMLibraryHelpers playlistsMatchingLockState:[self.selectedType isEqualToString:kYMLibraryTypePrivate]];
    if (playlists.count == 0) {
        YTAlertView *alert = [%c(YTAlertView) confirmationDialogWithAction:^{
            [self createPlaylistTappedWithCompletion:^(NSString *playlistID) {
                row.playlistIDs = @[playlistID];
                NSMutableDictionary *metadata = [[YMLibraryHelpers metadataForURL:[NSURL fileURLWithPath:row.path]] mutableCopy];
                metadata[@"playlists"] = @[playlistID];
                [YMLibraryHelpers setMetadataForURL:[NSURL fileURLWithPath:row.path] entry:metadata];
                [self applyFiltersAndSort];
                YouModShowPill([YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_ADDED_TO_PLAYLIST" fallback:@"Added to playlist"], YES);
            }];
        } actionTitle:[YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_CREATE" fallback:@"Create"] cancelTitle:LOC(@"CANCEL")];
        alert.title = [YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_NO_PLAYLISTS" fallback:@"No playlists yet"];
        alert.subtitle = [YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_CREATE_PLAYLIST_FIRST" fallback:@"Create a playlist before adding downloads to it."];
        alert.shouldDismissOnBackgroundTap = YES;
        [alert show];
        return;
    }
    id parentResponder = self.hostParentResponder ?: self;
    YTDefaultSheetController *sheet = [%c(YTDefaultSheetController) sheetControllerWithParentResponder:parentResponder];
    [sheet addHeaderWithTitle:nil subtitle:[YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_ADD_TO_PLAYLIST" fallback:@"Add to playlist"]];
    NSString *currentID = row.playlistIDs.firstObject;
    __weak typeof(self) weakSelf = self;
    [playlists enumerateObjectsUsingBlock:^(NSDictionary *playlist, NSUInteger idx, BOOL *stop) {
        NSString *playlistID = playlist[@"id"] ?: @"";
        NSString *name = playlist[@"name"] ?: @"";
        BOOL isCurrent = playlistID.length > 0 && [playlistID isEqualToString:currentID];
        NSString *title = isCurrent ? [@"\u2713 " stringByAppendingString:name] : name;
        [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:title
                                                        style:0
                                                      handler:^(__unused YTActionSheetAction *action) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            row.playlistIDs = isCurrent ? @[] : @[playlistID];
            NSMutableDictionary *metadata = [[YMLibraryHelpers metadataForURL:[NSURL fileURLWithPath:row.path]] mutableCopy];
            if (row.playlistIDs.count > 0) metadata[@"playlists"] = row.playlistIDs;
            else [metadata removeObjectForKey:@"playlists"];
            [YMLibraryHelpers setMetadataForURL:[NSURL fileURLWithPath:row.path] entry:metadata];
            [strongSelf applyFiltersAndSort];
            if (!isCurrent) YouModShowPill([YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_ADDED_TO_PLAYLIST" fallback:@"Added to playlist"], YES);
        }]];
    }];
    [sheet presentFromView:sourceView animated:YES completion:nil];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.rows.count;
}

// The library view controller is the collection view's scroll delegate, so it feeds the refresh control.
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (scrollView == self.collectionView) [self.refreshControl draggingBeganInScrollView:scrollView];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView == self.collectionView) [self.refreshControl scrollViewDidScroll:scrollView];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (scrollView == self.collectionView) [self.refreshControl draggingEndedInScrollView:scrollView];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    YMLibraryVideoCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"video" forIndexPath:indexPath];
    YMLibraryRow *row = self.rows[indexPath.item];
    cell.titleLabel.text = row.title;
    cell.sizeLabel.text = row.sizeText;
    // Audio rows show a small centered icon on the placeholder fill; video rows fill the frame with their thumbnail.
    cell.thumbnailImageView.contentMode = (row.isAudio || row.isPlaylist) ? UIViewContentModeCenter : UIViewContentModeScaleAspectFill;
    cell.thumbnailImageView.image = row.thumbnail;
    cell.thumbnailImageView.tintColor = (row.isAudio || row.isPlaylist) ? [UIColor secondaryLabelColor] : nil;
    cell.menuButton.hidden = row.isPlaylist || self.isSelectionMode;
    cell.lockButton.hidden = !row.isPlaylist || self.isSelectionMode;
    if (row.isPlaylist) {
        [cell.lockButton setImage:YouModSymbolImageInCanvas(row.isLocked ? @"lock" : @"lock.open", 24, 22, UIImageSymbolWeightMedium) forState:UIControlStateNormal];
        cell.lockButton.accessibilityLabel = [YMLibraryHelpers localizedText:row.isLocked ? @"DOWNLOAD_LIBRARY_UNLOCK_PLAYLIST" : @"DOWNLOAD_LIBRARY_LOCK_PLAYLIST" fallback:row.isLocked ? @"Unlock playlist" : @"Lock playlist"];
    }
    BOOL showCheckbox = self.isSelectionMode;
    BOOL checked = [self.selectedIndexPaths containsObject:indexPath];
    cell.thumbnailImageView.alpha = showCheckbox ? 0.75 : 1.0;
    if (showCheckbox) {
        if (!cell.selectionBox) {
            cell.selectionBox = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 26, 26)];
            cell.selectionBox.layer.cornerRadius = 5;
            cell.selectionBox.layer.borderWidth = 2;
            cell.selectionBox.layer.borderColor = [UIColor whiteColor].CGColor;
            cell.selectionBox.translatesAutoresizingMaskIntoConstraints = NO;
            [cell.contentView addSubview:cell.selectionBox];
            [NSLayoutConstraint activateConstraints:@[
                [cell.selectionBox.centerXAnchor constraintEqualToAnchor:cell.thumbnailImageView.centerXAnchor],
                [cell.selectionBox.centerYAnchor constraintEqualToAnchor:cell.thumbnailImageView.centerYAnchor],
                [cell.selectionBox.widthAnchor constraintEqualToConstant:26],
                [cell.selectionBox.heightAnchor constraintEqualToConstant:26],
            ]];
        }
        if (!cell.selectionCheckView) {
            cell.selectionCheckView = [[UIImageView alloc] init];
            cell.selectionCheckView.image = [UIImage systemImageNamed:@"checkmark"];
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithWeight:UIImageSymbolWeightHeavy];
            cell.selectionCheckView.preferredSymbolConfiguration = config;
            cell.selectionCheckView.tintColor = [UIColor blackColor];
            cell.selectionCheckView.contentMode = UIViewContentModeScaleAspectFit;
            cell.selectionCheckView.translatesAutoresizingMaskIntoConstraints = NO;
            [cell.selectionBox addSubview:cell.selectionCheckView];
            [NSLayoutConstraint activateConstraints:@[
                [cell.selectionCheckView.centerXAnchor constraintEqualToAnchor:cell.selectionBox.centerXAnchor],
                [cell.selectionCheckView.centerYAnchor constraintEqualToAnchor:cell.selectionBox.centerYAnchor],
                [cell.selectionCheckView.widthAnchor constraintEqualToConstant:20],
                [cell.selectionCheckView.heightAnchor constraintEqualToConstant:20],
            ]];
        }
        cell.selectionBox.hidden = NO;
        cell.selectionBox.backgroundColor = checked ? [UIColor whiteColor] : [UIColor clearColor];
        cell.selectionCheckView.hidden = !checked;
    } else {
        cell.selectionBox.hidden = YES;
        cell.selectionCheckView.hidden = YES;
    }
    __weak typeof(self) weakSelf = self;
    cell.menuTappedHandler = ^(UIView *sourceView) {
        [weakSelf showActionSheetForRowAtIndexPath:indexPath sourceView:sourceView];
    };
    cell.lockTappedHandler = ^(UIView *sourceView) {
        [weakSelf toggleLockForPlaylistRow:row];
    };
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
    YMLibraryRow *row = self.rows[indexPath.item];
    if (self.isSelectionMode) {
        if ([self.selectedIndexPaths containsObject:indexPath]) [self.selectedIndexPaths removeObject:indexPath];
        else [self.selectedIndexPaths addObject:indexPath];
        [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
        [self updateSelectButtonIcon];
        return;
    }
    if (row.isPlaylist) {
        self.isEnteringPlaylist = YES;
        self.selectedPlaylistID = row.playlistID;
        [self refreshTypeSelection];
        self.isEnteringPlaylist = NO;
        return;
    }
    NSURL *fileURL = [NSURL fileURLWithPath:row.path];

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:fileURL options:nil];
    // The deprecated isPlayable flag reports NO for playable m4a audio, so decide from the
    // tracks the asset exposes: m4a/AAC has an audio track, mka/mkv containers expose none.
    BOOL playable = [asset tracksWithMediaType:AVMediaTypeVideo].count > 0
                 || [asset tracksWithMediaType:AVMediaTypeAudio].count > 0;
    if (playable) {
        // Stop everything else that is playing (YouTube's player and any AVPlayer) so it doesn't mix with the opened file.
        YouModPauseAllPlayers();
        AVPlayerViewController *playerVC = [AVPlayerViewController new];
        playerVC.allowsPictureInPicturePlayback = YES;
        playerVC.entersFullScreenWhenPlaybackBegins = YES;
        playerVC.player = [AVPlayer playerWithURL:fileURL];
        playerVC.delegate = [YMLibraryPlayerPiPDelegate sharedDelegate];
        ymLibraryPlayerVC = playerVC;
        [self presentViewController:playerVC animated:YES completion:^{
            [playerVC.player play];
        }];
    } else {
        YouModShareItem(fileURL, self, nil);
    }
}

// Options for a library item, presented as the YouTube-style bottom sheet from the ellipsis button.
- (void)showActionSheetForRowAtIndexPath:(NSIndexPath *)indexPath sourceView:(UIView *)sourceView {
    YMLibraryRow *row = self.rows[indexPath.item];
    NSURL *fileURL = [NSURL fileURLWithPath:row.path];
    id parentResponder = self.hostParentResponder ?: self;

    YTDefaultSheetController *sheet = [%c(YTDefaultSheetController) sheetControllerWithParentResponder:parentResponder];

    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:LOC(@"LIBRARY_RENAME")
                                                    iconImage:YouModSymbolImageInCanvas(@"pencil", 24, 22, UIImageSymbolWeightMedium)
                                                        style:0
                                                      handler:^(__unused YTActionSheetAction *action) {
        [self presentRenameDialogForRow:row];
    }]];
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:LOC(@"LIBRARY_SHARE")
                                                    iconImage:YouModSymbolImageInCanvas(@"square.and.arrow.up", 24, 22, UIImageSymbolWeightMedium)
                                                        style:0
                                                      handler:^(__unused YTActionSheetAction *action) {
        YouModShareItem(fileURL, self, sourceView);
    }]];
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:[YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_ADD_TO_PLAYLIST" fallback:@"Add to playlist"]
                                                    iconImage:YouModSymbolImageInCanvas(@"text.badge.plus", 24, 22, UIImageSymbolWeightMedium)
                                                        style:0
                                                      handler:^(__unused YTActionSheetAction *action) {
        [self showPlaylistPickerForRow:row sourceView:sourceView];
    }]];
    NSString *privateActionTitle = [YMLibraryHelpers localizedText:row.isPrivate ? @"DOWNLOAD_LIBRARY_MARK_PUBLIC" : @"DOWNLOAD_LIBRARY_MARK_PRIVATE" fallback:row.isPrivate ? @"Remove from Private" : @"Mark as Private"];
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:privateActionTitle
                                                    iconImage:YouModSymbolImageInCanvas(row.isPrivate ? @"lock.open" : @"lock", 24, 22, UIImageSymbolWeightMedium)
                                                        style:0
                                                      handler:^(__unused YTActionSheetAction *action) {
        [self togglePrivateForRow:row];
    }]];
    if (!row.isAudio) {
        [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:LOC(@"LIBRARY_SAVE_THUMBNAIL")
                                                        iconImage:YouModSymbolImageInCanvas(@"photo", 24, 22, UIImageSymbolWeightMedium)
                                                            style:0
                                                          handler:^(__unused YTActionSheetAction *action) {
            [self saveThumbnailToPhotosForRow:row];
        }]];
    }
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:LOC(@"LIBRARY_OPEN_VIDEO")
                                                    iconImage:YouModSymbolImageInCanvas(@"play.rectangle", 24, 22, UIImageSymbolWeightMedium)
                                                        style:0
                                                      handler:^(__unused YTActionSheetAction *action) {
        [self openOriginalVideoForRow:row];
    }]];
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:LOC(@"LIBRARY_VIEW_INFO")
                                                    iconImage:YouModSymbolImageInCanvas(@"info.circle", 24, 22, UIImageSymbolWeightMedium)
                                                        style:0
                                                      handler:^(__unused YTActionSheetAction *action) {
        [self presentInfoForRow:row];
    }]];
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:LOC(@"LIBRARY_DELETE")
                                                    iconImage:YouModSymbolImageInCanvas(@"trash", 24, 22, UIImageSymbolWeightMedium)
                                                        style:0
                                                      handler:^(__unused YTActionSheetAction *action) {
        [self deleteRowAtIndexPath:indexPath];
    }]];

    [sheet presentFromView:sourceView animated:YES completion:nil];
}

- (void)showBulkActionsSheet {
    if (self.selectedIndexPaths.count == 0) {
        YouModShowPill(LOC(@"LIBRARY_SELECT_ITEMS_FIRST"), NO);
        return;
    }
    NSArray<YMLibraryRow *> *selectedRows = [self selectedRows];
    __block BOOL hasVideos = NO;
    __block BOOL hasPublicItems = NO;
    __block BOOL hasPrivateItems = NO;
    [selectedRows enumerateObjectsUsingBlock:^(YMLibraryRow *row, NSUInteger idx, BOOL *stop) {
        if (!row.isPlaylist) hasVideos = YES;
        BOOL locked = row.isPlaylist ? row.isLocked : row.isPrivate;
        if (locked) hasPrivateItems = YES;
        else hasPublicItems = YES;
    }];
    id parentResponder = self.hostParentResponder ?: self;
    YTDefaultSheetController *sheet = [%c(YTDefaultSheetController) sheetControllerWithParentResponder:parentResponder];
    __weak typeof(self) weakSelf = self;
    // File actions need videos selected; "Add to playlist" is omitted in the Private tab.
    BOOL showAddToPlaylist = hasVideos && ![self.selectedType isEqualToString:kYMLibraryTypePrivate];
    if (hasVideos) {
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:LOC(@"LIBRARY_SHARE")
                                                    iconImage:YouModSymbolImageInCanvas(@"square.and.arrow.up", 24, 22, UIImageSymbolWeightMedium)
                                                        style:0
                                                      handler:^(__unused YTActionSheetAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSMutableArray *items = [NSMutableArray array];
        [[strongSelf selectedRows] enumerateObjectsUsingBlock:^(YMLibraryRow *row, NSUInteger idx, BOOL *stop) {
            if (row.isPlaylist) return;
            [items addObject:[NSURL fileURLWithPath:row.path]];
        }];
        if (items.count == 0) return;
        UIActivityViewController *vc = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
        YouModConfigureSharePopover(vc, strongSelf.moreMenuButton);
        [strongSelf presentViewController:vc animated:YES completion:nil];
    }]];
    if (showAddToPlaylist) {
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:[YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_ADD_TO_PLAYLIST" fallback:@"Add to playlist"]
                                                    iconImage:YouModSymbolImageInCanvas(@"text.badge.plus", 24, 22, UIImageSymbolWeightMedium)
                                                        style:0
                                                      handler:^(__unused YTActionSheetAction *action) {
        [weakSelf showBulkPlaylistPickerForSelectedRows];
    }]];
    }
    }
    // Covers playlists too (not video-gated): locks/unlocks them and flags videos private or public.
    if (hasPublicItems) {
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:[YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_MARK_PRIVATE" fallback:@"Mark as Private"]
                                                    iconImage:YouModSymbolImageInCanvas(@"lock", 24, 22, UIImageSymbolWeightMedium)
                                                        style:0
                                                      handler:^(__unused YTActionSheetAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSArray *rows = [[strongSelf selectedRows] copy];
        [rows enumerateObjectsUsingBlock:^(YMLibraryRow *row, NSUInteger idx, BOOL *stop) {
            if (row.isPlaylist) { [strongSelf setLocked:YES forPlaylistID:row.playlistID]; return; }
            if (!row.isPrivate) [strongSelf togglePrivateForRow:row];
        }];
        [strongSelf exitSelectionMode];
    }]];
    }
    if (hasPrivateItems) {
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:[YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_MARK_PUBLIC" fallback:@"Remove from Private"]
                                                    iconImage:YouModSymbolImageInCanvas(@"lock.open", 24, 22, UIImageSymbolWeightMedium)
                                                        style:0
                                                      handler:^(__unused YTActionSheetAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSArray *rows = [[strongSelf selectedRows] copy];
        [rows enumerateObjectsUsingBlock:^(YMLibraryRow *row, NSUInteger idx, BOOL *stop) {
            if (row.isPlaylist) { [strongSelf setLocked:NO forPlaylistID:row.playlistID]; return; }
            if (row.isPrivate) [strongSelf togglePrivateForRow:row];
        }];
        [strongSelf exitSelectionMode];
    }]];
    }
    if (hasVideos) {
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:LOC(@"LIBRARY_SAVE_THUMBNAIL")
                                                    iconImage:YouModSymbolImageInCanvas(@"photo", 24, 22, UIImageSymbolWeightMedium)
                                                        style:0
                                                      handler:^(__unused YTActionSheetAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSMutableArray *images = [NSMutableArray array];
        [[strongSelf selectedRows] enumerateObjectsUsingBlock:^(YMLibraryRow *row, NSUInteger idx, BOOL *stop) {
            if (!row.isPlaylist && !row.isAudio && row.thumbnail) [images addObject:row.thumbnail];
        }];
        if (images.count == 0) return;
        YouModRequestPhotoAccess(^(BOOL granted) {
            if (!granted) { YouModSendError(LOC(@"PHOTO_ACCESS_DENINED")); return; }
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [images enumerateObjectsUsingBlock:^(UIImage *img, NSUInteger idx, BOOL *stop) {
                    [PHAssetChangeRequest creationRequestForAssetFromImage:img];
                }];
            } completionHandler:^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    YouModShowPill(success ? LOC(@"SAVED_TO_PHOTOS") : (error.localizedDescription ?: LOC(@"SAVE_FAILED")), success);
                });
            }];
        });
    }]];
    }
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:LOC(@"LIBRARY_DELETE")
                                                    iconImage:YouModSymbolImageInCanvas(@"trash", 24, 22, UIImageSymbolWeightMedium)
                                                        style:0
                                                      handler:^(__unused YTActionSheetAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSArray *rows = [[strongSelf selectedRows] copy];
        NSMutableArray<NSString *> *playlistIDs = [NSMutableArray array];
        [rows enumerateObjectsUsingBlock:^(YMLibraryRow *row, NSUInteger idx, BOOL *stop) {
            // Playlists are removed from the playlist list; media rows delete their files.
            if (row.isPlaylist) {
                if (row.playlistID.length > 0) [playlistIDs addObject:row.playlistID];
                return;
            }
            NSURL *fileURL = [NSURL fileURLWithPath:row.path];
            [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
            [YMLibraryHelpers deleteThumbnailsForFile:fileURL];
            [YMLibraryHelpers setMetadataForURL:fileURL entry:nil];
            [strongSelf.allRows removeObject:row];
        }];
        [strongSelf deletePlaylistsWithIDs:playlistIDs];
        [strongSelf exitSelectionMode];
    }]];
    [sheet presentFromView:self.moreMenuButton animated:YES completion:nil];
}

// Bulk variant: the chosen playlist becomes each selected media row's only playlist;
// tapping the one they all share takes them back out.
- (void)showBulkPlaylistPickerForSelectedRows {
    NSArray *playlists = [YMLibraryHelpers playlistsMatchingLockState:[self.selectedType isEqualToString:kYMLibraryTypePrivate]];
    if (playlists.count == 0) {
        YTAlertView *alert = [%c(YTAlertView) confirmationDialogWithAction:^{
            [self createPlaylistTappedWithCompletion:^(NSString *playlistID) {
                [[self selectedRows] enumerateObjectsUsingBlock:^(YMLibraryRow *r, NSUInteger idx, BOOL *stop) {
                    // Playlist rows have no file to modify; only media rows get membership.
                    if (r.isPlaylist || r.path.length == 0) return;
                    r.playlistIDs = @[playlistID];
                    NSMutableDictionary *metadata = [[YMLibraryHelpers metadataForURL:[NSURL fileURLWithPath:r.path]] mutableCopy];
                    metadata[@"playlists"] = @[playlistID];
                    [YMLibraryHelpers setMetadataForURL:[NSURL fileURLWithPath:r.path] entry:metadata];
                }];
                [self applyFiltersAndSort];
                YouModShowPill([YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_ADDED_TO_PLAYLIST" fallback:@"Added to playlist"], YES);
            }];
        } actionTitle:[YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_CREATE" fallback:@"Create"] cancelTitle:LOC(@"CANCEL")];
        alert.title = [YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_NO_PLAYLISTS" fallback:@"No playlists yet"];
        alert.subtitle = [YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_CREATE_PLAYLIST_FIRST" fallback:@"Create a playlist before adding downloads to it."];
        alert.shouldDismissOnBackgroundTap = YES;
        [alert show];
        return;
    }
    // Ticked when every selected media row already lives in the playlist.
    NSArray<YMLibraryRow *> *selectedRows = [self selectedRows];
    NSUInteger mediaCount = [selectedRows indexesOfObjectsPassingTest:^BOOL(YMLibraryRow *row, NSUInteger idx, BOOL *stop) {
        return !row.isPlaylist && row.path.length > 0;
    }].count;

    id parentResponder = self.hostParentResponder ?: self;
    YTDefaultSheetController *sheet = [%c(YTDefaultSheetController) sheetControllerWithParentResponder:parentResponder];
    [sheet addHeaderWithTitle:nil subtitle:[YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_ADD_TO_PLAYLIST" fallback:@"Add to playlist"]];
    __weak typeof(self) weakSelf = self;
    [playlists enumerateObjectsUsingBlock:^(NSDictionary *playlist, NSUInteger idx, BOOL *stop) {
        NSString *pid = playlist[@"id"] ?: @"";
        NSString *name = playlist[@"name"] ?: @"";
        BOOL allIn = [selectedRows indexOfObjectPassingTest:^BOOL(YMLibraryRow *row, NSUInteger i, BOOL *s) {
            return !row.isPlaylist && row.path.length > 0 && ![row.playlistIDs containsObject:pid];
        }] == NSNotFound;
        BOOL isCurrent = mediaCount > 0 && allIn;
        NSString *title = isCurrent ? [@"\u2713 " stringByAppendingString:name] : name;
        [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:title
                                                        style:0
                                                      handler:^(__unused YTActionSheetAction *action) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [[strongSelf selectedRows] enumerateObjectsUsingBlock:^(YMLibraryRow *row, NSUInteger i, BOOL *s) {
                // Playlist rows have no file to modify; only media rows get membership.
                if (row.isPlaylist || row.path.length == 0) return;
                row.playlistIDs = isCurrent ? @[] : @[pid];
                NSMutableDictionary *metadata = [[YMLibraryHelpers metadataForURL:[NSURL fileURLWithPath:row.path]] mutableCopy];
                if (row.playlistIDs.count > 0) metadata[@"playlists"] = row.playlistIDs;
                else [metadata removeObjectForKey:@"playlists"];
                [YMLibraryHelpers setMetadataForURL:[NSURL fileURLWithPath:row.path] entry:metadata];
            }];
            [strongSelf applyFiltersAndSort];
            if (!isCurrent) YouModShowPill([YMLibraryHelpers localizedText:@"DOWNLOAD_LIBRARY_ADDED_TO_PLAYLIST" fallback:@"Added to playlist"], YES);
        }]];
    }];
    [sheet presentFromView:self.moreMenuButton animated:YES completion:nil];
}

// Rename dialog via a system alert: text field prefilled with the current name plus
// Cancel / Rename. The video ID suffix and file extension are preserved automatically.
- (void)presentRenameDialogForRow:(YMLibraryRow *)row {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LOC(@"LIBRARY_RENAME_TITLE")
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = [YMLibraryHelpers displayTitleForFileName:row.path.lastPathComponent.stringByDeletingPathExtension];
        field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.spellCheckingType = UITextSpellCheckingTypeNo;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:LOC(@"CANCEL") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:LOC(@"LIBRARY_RENAME") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        UITextField *field = alert.textFields.firstObject;
        NSString *newBase = [field.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (newBase.length == 0) {
            YouModSendError(LOC(@"LIBRARY_RENAME_EMPTY"));
            return;
        }
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if ([strongSelf applyRename:newBase toRow:row]) {
            YouModSendSuccess(LOC(@"LIBRARY_RENAMED"));
            [strongSelf.collectionView reloadData];
        } else {
            YouModSendError(LOC(@"LIBRARY_RENAME_FAILED"));
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

// Moves the media file (plus its sidecar thumbnail) and updates the row in place.
// Returns NO when the name didn't change or the file couldn't be moved.
- (BOOL)applyRename:(NSString *)newBase toRow:(YMLibraryRow *)row {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *directory = [row.path stringByDeletingLastPathComponent];
    NSString *videoID = [YMLibraryHelpers videoIDForFileName:row.path.lastPathComponent.stringByDeletingPathExtension];
    NSString *newBaseName = videoID ? [NSString stringWithFormat:@"%@ [%@]", newBase, videoID] : newBase;
    NSString *newPath = [[directory stringByAppendingPathComponent:newBaseName] stringByAppendingPathExtension:row.path.pathExtension];
    if (!newPath || [newPath isEqualToString:row.path]) return NO;
    if ([fm fileExistsAtPath:newPath]) return NO;

    if (![fm moveItemAtPath:row.path toPath:newPath error:nil]) return NO;

    // Follow along with the sibling .jpg and drop the stale generated-thumb cache entry.
    NSString *oldSibling = [[row.path stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpg"];
    NSString *newSibling = [[newPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpg"];
    if ([fm fileExistsAtPath:oldSibling]) [fm moveItemAtPath:oldSibling toPath:newSibling error:nil];
    [fm removeItemAtPath:[YMLibraryHelpers generatedThumbCacheURL:[NSURL fileURLWithPath:row.path]].path error:nil];

    NSURL *oldURL = [NSURL fileURLWithPath:row.path];
    NSURL *newURL = [NSURL fileURLWithPath:newPath];
    NSDictionary *metadata = [YMLibraryHelpers metadataForURL:oldURL];
    if (metadata.count > 0) [YMLibraryHelpers setMetadataForURL:newURL entry:metadata];
    [YMLibraryHelpers setMetadataForURL:oldURL entry:nil];

    row.path = newPath;
    row.title = newBase;
    return YES;
}

- (void)openOriginalVideoForRow:(YMLibraryRow *)row {
    NSString *videoID = [YMLibraryHelpers videoIDForFileName:row.path.lastPathComponent.stringByDeletingPathExtension];
    NSURL *youtubeURL = videoID ? [NSURL URLWithString:[NSString stringWithFormat:@"youtube://%@", videoID]] : nil;
    if (!youtubeURL || ![[UIApplication sharedApplication] canOpenURL:youtubeURL]) {
        YouModSendError(LOC(@"LIBRARY_NO_VIDEO_ID"));
        return;
    }
    [[UIApplication sharedApplication] openURL:youtubeURL options:@{} completionHandler:nil];
}

- (void)saveThumbnailToPhotosForRow:(YMLibraryRow *)row {
    UIImage *image = row.thumbnail;
    if (!image || row.isAudio) {
        YouModSendError(LOC(@"NO_THUMBNAIL_FOUND"));
        return;
    }
    YouModRequestPhotoAccess(^(BOOL granted) {
        if (!granted) {
            YouModSendError(LOC(@"PHOTO_ACCESS_DENINED"));
            return;
        }
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetChangeRequest creationRequestForAssetFromImage:image];
        } completionHandler:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    YouModSendSuccess(LOC(@"SAVED_TO_PHOTOS"));
                } else {
                    YouModSendError(error.localizedDescription ?: LOC(@"SAVE_FAILED"));
                }
            });
        }];
    });
}

- (void)presentInfoForRow:(YMLibraryRow *)row {
    NSURL *fileURL = [NSURL fileURLWithPath:row.path];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *info = [YMLibraryHelpers mediaInfoStringForFile:fileURL bytes:row.bytes];
        dispatch_async(dispatch_get_main_queue(), ^{
            YTAlertView *alertView = [%c(YTAlertView) infoDialog];
            alertView.title = row.title;
            alertView.subtitle = info;
            alertView.shouldDismissOnBackgroundTap = YES;
            [alertView show];
        });
    });
}

- (void)deleteRowAtIndexPath:(NSIndexPath *)indexPath {
    YMLibraryRow *row = self.rows[indexPath.item];
    if (row.isPlaylist) {
        [self deletePlaylistsWithIDs:row.playlistID.length > 0 ? @[row.playlistID] : @[]];
        [self applyFiltersAndSort];
        return;
    }
    NSURL *fileURL = [NSURL fileURLWithPath:row.path];
    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
    [YMLibraryHelpers deleteThumbnailsForFile:fileURL];
    [YMLibraryHelpers setMetadataForURL:fileURL entry:nil];
    [self.allRows removeObject:row];
    [self.rows removeObjectAtIndex:indexPath.item];
    [self.collectionView deleteItemsAtIndexPaths:@[indexPath]];
    self.emptyLabel.hidden = self.allRows.count > 0;
    self.emptyIconView.hidden = self.allRows.count > 0;
}

@end

#pragma mark - Entry point

UIViewController *YouModDownloadLibraryViewController(id hostParentResponder) {
    YMLibraryViewController *vc = [YMLibraryViewController new];
    vc.hostParentResponder = hostParentResponder;
    return vc;
}

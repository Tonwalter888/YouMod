#import "Headers.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <CoreMedia/CoreMedia.h>
#import <Photos/Photos.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import <math.h>

static NSSet<NSString *> *ymLibraryMediaExtensions(void) {
    static NSSet<NSString *> *exts;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ exts = [NSSet setWithObjects:@"mp4", @"mkv", @"m4a", @"mka", nil]; });
    return exts;
}

static BOOL ymIsAudioOnlyExtension(NSString *extension) {
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

static NSString *ymLibraryMetadataKeyForURL(NSURL *url) {
    return url.lastPathComponent ?: @"";
}

static NSDictionary *ymLibraryMetadataForURL(NSURL *url) {
    NSDictionary *metadata = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kYMLibraryMetadataDefaultsKey];
    NSDictionary *entry = metadata[ymLibraryMetadataKeyForURL(url)];
    return [entry isKindOfClass:[NSDictionary class]] ? entry : @{};
}

static void ymSetLibraryMetadataForURL(NSURL *url, NSDictionary *entry) {
    if (!url) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *metadata = [[defaults dictionaryForKey:kYMLibraryMetadataDefaultsKey] mutableCopy] ?: [NSMutableDictionary dictionary];
    NSString *key = ymLibraryMetadataKeyForURL(url);
    if (entry.count > 0) metadata[key] = entry;
    else [metadata removeObjectForKey:key];
    [defaults setObject:metadata forKey:kYMLibraryMetadataDefaultsKey];
}

static NSArray<NSDictionary *> *ymLibraryPlaylists(void) {
    NSArray *playlists = [[NSUserDefaults standardUserDefaults] arrayForKey:kYMLibraryPlaylistsDefaultsKey];
    return [playlists isKindOfClass:[NSArray class]] ? playlists : @[];
}

static void ymSaveLibraryPlaylists(NSArray<NSDictionary *> *playlists) {
    [[NSUserDefaults standardUserDefaults] setObject:playlists ?: @[] forKey:kYMLibraryPlaylistsDefaultsKey];
}

static NSString *ymLibraryText(NSString *key, NSString *fallback) {
    NSString *value = LOC(key);
    return [value isEqualToString:key] ? fallback : value;
}

static NSString *ymDisplayTitleForFileName(NSString *baseName) {
    NSRange range = [baseName rangeOfString:@" \\[[A-Za-z0-9_-]{11}\\]$" options:NSRegularExpressionSearch];
    if (range.location != NSNotFound) {
        return [baseName stringByReplacingCharactersInRange:range withString:@""];
    }
    return baseName;
}

static NSString *ymVideoIDForFileName(NSString *baseName) {
    NSRange range = [baseName rangeOfString:@" \\[[A-Za-z0-9_-]{11}\\]$" options:NSRegularExpressionSearch];
    if (range.location == NSNotFound) return nil;
    return [baseName substringWithRange:NSMakeRange(range.location + 2, 11)];
}

static NSString *ymFormattedFileSize(unsigned long long bytes) {
    NSByteCountFormatter *formatter = [NSByteCountFormatter new];
    formatter.countStyle = NSByteCountFormatterCountStyleFile;
    return [formatter stringFromByteCount:(long long)bytes];
}

static NSArray<NSURL *> *ymLibraryFileURLsNewestFirst(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSURL *> *contents = [fm contentsOfDirectoryAtURL:YouModDownloadsDirectoryURL()
                                    includingPropertiesForKeys:@[NSURLContentModificationDateKey]
                                                       options:NSDirectoryEnumerationSkipsHiddenFiles
                                                         error:nil];
    NSSet<NSString *> *mediaExts = ymLibraryMediaExtensions();
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

static NSURL *ymSiblingThumbnailURL(NSURL *fileURL) {
    return [[fileURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"jpg"];
}

static NSURL *ymThumbCacheDirectory(void) {
    NSURL *caches = [[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *dir = [caches URLByAppendingPathComponent:@"YouMod_Thumbs" isDirectory:YES];
    [[NSFileManager defaultManager] createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

static NSURL *ymGeneratedThumbCacheURL(NSURL *fileURL) {
    return [[ymThumbCacheDirectory() URLByAppendingPathComponent:fileURL.lastPathComponent] URLByAppendingPathExtension:@"jpg"];
}

static UIImage *ymThumbnailForVideoFile(NSURL *fileURL) {
    NSData *real = [NSData dataWithContentsOfURL:ymSiblingThumbnailURL(fileURL)];
    if (real) return [UIImage imageWithData:real];

    NSURL *cacheURL = ymGeneratedThumbCacheURL(fileURL);
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

static void ymDeleteThumbnailsForFile(NSURL *fileURL) {
    [[NSFileManager defaultManager] removeItemAtURL:ymSiblingThumbnailURL(fileURL) error:nil];
    [[NSFileManager defaultManager] removeItemAtURL:ymGeneratedThumbCacheURL(fileURL) error:nil];
}

#pragma mark - Media info ("View Info")

static NSString *ymFourCCString(FourCharCode code) {
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

static NSString *ymMediaInfoStringForFile(NSURL *fileURL, unsigned long long bytes) {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:fileURL options:nil];
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [lines addObject:[NSString stringWithFormat:@"%@: %@", LOC(@"LIBRARY_INFO_SIZE"), ymFormattedFileSize(bytes)]];
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
            [lines addObject:[NSString stringWithFormat:@"%@: %@", LOC(@"LIBRARY_INFO_VIDEO_CODEC"), ymFourCCString(subtype)]];
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
            [lines addObject:[NSString stringWithFormat:@"%@: %@", LOC(@"LIBRARY_INFO_AUDIO_CODEC"), ymFourCCString(subtype)]];
        }
        if (audioTrack.estimatedDataRate > 0) {
            [lines addObject:[NSString stringWithFormat:@"%@: %.0f kbps", LOC(@"LIBRARY_INFO_AUDIO_BITRATE"), audioTrack.estimatedDataRate / 1000.0]];
        }
    }
    return [lines componentsJoinedByString:@"\n"];
}

#pragma mark - Row model

@interface YMLibraryRow : NSObject
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, assign) unsigned long long bytes;
@property (nonatomic, copy) NSString *sizeText;
@property (nonatomic, strong) UIImage *thumbnail;
@property (nonatomic, assign) BOOL isAudio;
@property (nonatomic, assign) BOOL isShorts;
@property (nonatomic, assign) BOOL isPrivate;
@property (nonatomic, copy) NSArray<NSString *> *playlistIDs;
@property (nonatomic, strong) NSDate *modifiedDate;
@property (nonatomic, assign) BOOL isPlaylist;
@property (nonatomic, copy) NSString *playlistID;
@end
@implementation YMLibraryRow
@end

#pragma mark - Feed-style cell

@interface YMLibraryVideoCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *thumbnailImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *sizeLabel;
@property (nonatomic, strong) YTQTMButton *menuButton;
// Called with the button itself so the sheet can anchor its iPad popover.
@property (nonatomic, copy) void (^menuTappedHandler)(UIView *sourceView);
@end

@implementation YMLibraryVideoCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor systemBackgroundColor];

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
        // Rendered into an exact 24x24 canvas so the ellipsis never gets
        // squished or cropped inside the button's hit area.
        [_menuButton setImage:YouModSymbolImageInCanvas(@"ellipsis", 24, 22, UIImageSymbolWeightMedium) forState:UIControlStateNormal];
        _menuButton.tintColor = [UIColor labelColor];
        if ([_menuButton respondsToSelector:@selector(enableNewTouchFeedback)]) [_menuButton enableNewTouchFeedback];
        [_menuButton addTarget:self action:@selector(menuTapped) forControlEvents:UIControlEventTouchUpInside];
        _menuButton.translatesAutoresizingMaskIntoConstraints = NO;

        [self.contentView addSubview:_thumbnailImageView];
        [self.contentView addSubview:_titleLabel];
        [self.contentView addSubview:_sizeLabel];
        [self.contentView addSubview:_menuButton];

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

@end

#pragma mark - Grid layout

@interface YMLibraryGridLayout : UICollectionViewFlowLayout
@end

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

static UIColor *ymYouTubeBackgroundColor(void) {
    return [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection *traitCollection) {
        id palette = traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [%c(YTCommonColorPalette) darkPalette]
            : [%c(YTCommonColorPalette) lightPalette];
        return [palette baseBackground];
    }];
}

#pragma mark - Pausing other players

// Every AVPlayer alive in the process, held weakly so entries vanish on
// dealloc without needing a dealloc hook.
static NSHashTable<AVPlayer *> *ymLiveAVPlayers(void) {
    static NSHashTable<AVPlayer *> *table;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ table = [NSHashTable weakObjectsHashTable]; });
    return table;
}

// Pauses everything the app could be playing: YouTube's own player (watch
// page, miniplayer, shorts) plus any AVPlayer anywhere in the process.
static void ymPauseOtherPlayers(void) {
    [YouModCurrentPlayerViewController pause];
    for (AVPlayer *player in [ymLiveAVPlayers() allObjects]) {
        if (player.rate > 0) [player pause];
    }
}

%hook AVPlayer
- (instancetype)initWithURL:(NSURL *)URL {
    AVPlayer *player = %orig;
    if (player) @synchronized(ymLiveAVPlayers()) { [ymLiveAVPlayers() addObject:player]; }
    return player;
}
- (instancetype)initWithPlayerItem:(AVPlayerItem *)item {
    AVPlayer *player = %orig;
    if (player) @synchronized(ymLiveAVPlayers()) { [ymLiveAVPlayers() addObject:player]; }
    return player;
}
%end

#pragma mark - Pull-to-refresh control

static const CGFloat ymRefreshTriggerDistance = 64.0;
static const CGFloat ymRefreshHiddenTravel = 72.0; // how far the bubble sits above its resting spot

// Pull-to-refresh bubble for the library grid: a floating circle with an
// arrow that slides into view and rotates as the user drags down — from the
// top of the list or by overscrolling past the bottom — then spins while
// refreshing. Driven by the collection view's scroll delegate, which the
// view controller forwards below.
@interface YMLibraryRefreshControl : UIView
@property (nonatomic, copy) void (^onRefresh)(void);
@property (nonatomic, readonly, getter=isRefreshing) BOOL refreshing;
- (void)scrollViewDidScroll:(UIScrollView *)scrollView;
- (void)draggingEndedInScrollView:(UIScrollView *)scrollView;
- (void)beginRefreshing;
- (void)endRefreshing;
@end

@interface YMLibraryRefreshControl ()
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, assign, getter=isRefreshing) BOOL refreshing; // readwrite privately
@end

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

// How far past an edge the user has dragged: overshoot at the top or at the
// bottom of the list, whichever is larger. Clamping the bottom's max offset
// at the top resting point keeps short lists (smaller than the viewport)
// from reading as permanently overscrolled.
- (CGFloat)pullDistanceInScrollView:(UIScrollView *)scrollView {
    CGFloat topPull = -(scrollView.contentOffset.y + scrollView.adjustedContentInset.top);
    CGFloat maxOffset = scrollView.contentSize.height - scrollView.bounds.size.height + scrollView.adjustedContentInset.bottom;
    CGFloat bottomPull = scrollView.contentOffset.y - MAX(maxOffset, -scrollView.adjustedContentInset.top);
    return MAX(topPull, bottomPull);
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat pull = [self pullDistanceInScrollView:scrollView];
    CGFloat progress = MIN(MAX(pull / ymRefreshTriggerDistance, 0), 1);
    if (self.isRefreshing) return;
    // The bubble slides down into view and the arrow flips from pointing
    // down to pointing up across the pull.
    self.transform = CGAffineTransformMakeTranslation(0, -ymRefreshHiddenTravel * (1 - progress));
    self.alpha = progress;
    self.iconView.transform = CGAffineTransformMakeRotation(progress * (CGFloat)M_PI);
}

// Called on finger-up: refresh only when the pull is still past the
// threshold at release, so the bounce after a fast upward flick can't
// trigger it on its own.
- (void)draggingEndedInScrollView:(UIScrollView *)scrollView {
    if (self.isRefreshing) return;
    if ([self pullDistanceInScrollView:scrollView] >= ymRefreshTriggerDistance) {
        [self beginRefreshing];
    }
}

- (void)beginRefreshing {
    if (self.isRefreshing) return;
    self.refreshing = YES;

    // Park the bubble fully in view and spin the arrow continuously; the
    // scroll position stays wherever the user pulled from.
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

@interface YMLibraryViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UIScrollView *typeScrollView;
@property (nonatomic, strong) UIStackView *typeStackView;
@property (nonatomic, strong) UIScrollView *sortScrollView;
@property (nonatomic, strong) UIStackView *sortStackView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) YMLibraryRefreshControl *refreshControl;
@property (nonatomic, strong) NSMutableArray<YMLibraryRow *> *allRows; // unfiltered backing store
@property (nonatomic, strong) NSMutableArray<YMLibraryRow *> *rows;    // currently displayed (search-filtered)
@property (nonatomic, weak) id hostParentResponder;
@property (nonatomic, copy) NSString *selectedType;
@property (nonatomic, copy) NSString *selectedSort;
@property (nonatomic, copy) NSString *selectedPlaylistID;
@property (nonatomic, assign) BOOL privateUnlocked;
@property (nonatomic, assign) BOOL isAuthenticatingPrivate;
@property (nonatomic, assign) BOOL privateAuthWasBackgrounded;
@end

@implementation YMLibraryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = LOC(@"DOWNLOAD_LIBRARY_TAB");
    self.view.backgroundColor = ymYouTubeBackgroundColor();
    self.allRows = [NSMutableArray array];
    self.rows = [NSMutableArray array];
    NSArray *types = @[kYMLibraryTypeAll, kYMLibraryTypeVideos, kYMLibraryTypeShorts, kYMLibraryTypeAudio, kYMLibraryTypePlaylists, kYMLibraryTypePrivate];
    NSArray *sorts = @[@"Newest", @"Oldest", @"Largest", @"Smallest", @"A-Z", @"Z-A"];
    NSString *savedType = [[NSUserDefaults standardUserDefaults] stringForKey:@"YouModDownloadLibrarySelectedType"];
    NSString *savedSort = [[NSUserDefaults standardUserDefaults] stringForKey:@"YouModDownloadLibrarySelectedSort"];
    // Never restore the protected category from preferences without a fresh auth.
    self.selectedType = ([types containsObject:savedType] && ![savedType isEqualToString:kYMLibraryTypePrivate]) ? savedType : kYMLibraryTypeAll;
    self.selectedSort = [sorts containsObject:savedSort] ? savedSort : @"Newest";
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(libraryDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];

    UIView *topBar = [UIView new];
    topBar.backgroundColor = ymYouTubeBackgroundColor();
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
    _searchBar.tintColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.9 alpha:1.0];
    _searchBar.translatesAutoresizingMaskIntoConstraints = NO;

    YTQTMButton *settingsButton = [%c(YTQTMButton) iconButton];
    [settingsButton setImage:YouModYTIconImage(44, NO, nil) forState:UIControlStateNormal];
    settingsButton.tintColor = [UIColor labelColor];
    [settingsButton addTarget:self action:@selector(openSettingsTapped) forControlEvents:UIControlEventTouchUpInside];
    if ([settingsButton respondsToSelector:@selector(enableNewTouchFeedback)]) [settingsButton enableNewTouchFeedback];
    settingsButton.translatesAutoresizingMaskIntoConstraints = NO;
    YouModApplyLiquidGlassToView(settingsButton, YES);

    [topBar addSubview:_searchBar];
    [topBar addSubview:settingsButton];

    _typeScrollView = [UIScrollView new];
    _typeScrollView.showsHorizontalScrollIndicator = NO;
    _typeScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _typeStackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    _typeStackView.axis = UILayoutConstraintAxisHorizontal;
    _typeStackView.spacing = 20;
    _typeStackView.alignment = UIStackViewAlignmentCenter;
    _typeStackView.translatesAutoresizingMaskIntoConstraints = NO;
    [_typeScrollView addSubview:_typeStackView];
    [topBar addSubview:_typeScrollView];

    _sortScrollView = [UIScrollView new];
    _sortScrollView.showsHorizontalScrollIndicator = NO;
    _sortScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _sortStackView = [[UIStackView alloc] initWithFrame:CGRectZero];
    _sortStackView.axis = UILayoutConstraintAxisHorizontal;
    _sortStackView.spacing = 8;
    _sortStackView.alignment = UIStackViewAlignmentCenter;
    _sortStackView.translatesAutoresizingMaskIntoConstraints = NO;
    [_sortScrollView addSubview:_sortStackView];
    [topBar addSubview:_sortScrollView];

    [self rebuildLibraryControls];

    UILayoutGuide *headerContentGuide = [UILayoutGuide new];
    [topBar addLayoutGuide:headerContentGuide];

    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:[YMLibraryGridLayout new]];
    _collectionView.dataSource = self;
    _collectionView.delegate = self;
    _collectionView.backgroundColor = ymYouTubeBackgroundColor();
    _collectionView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    _collectionView.alwaysBounceVertical = YES; // lets the pull-to-refresh gesture work even with few or no items
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    [_collectionView registerClass:[YMLibraryVideoCell class] forCellWithReuseIdentifier:@"video"];
    [self.view addSubview:_collectionView];

    _refreshControl = [YMLibraryRefreshControl new];
    _refreshControl.translatesAutoresizingMaskIntoConstraints = NO;
    // Floating above the cells at any scroll position, hence the high zPosition.
    _refreshControl.layer.zPosition = 1000;
    [_collectionView addSubview:_refreshControl];
    [NSLayoutConstraint activateConstraints:@[
        [_refreshControl.topAnchor constraintEqualToAnchor:_collectionView.frameLayoutGuide.topAnchor constant:12],
        [_refreshControl.centerXAnchor constraintEqualToAnchor:_collectionView.frameLayoutGuide.centerXAnchor],
        [_refreshControl.widthAnchor constraintEqualToConstant:44],
        [_refreshControl.heightAnchor constraintEqualToConstant:44],
    ]];
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
        [topBar.heightAnchor constraintEqualToConstant:206],

        [topBarSeparator.leadingAnchor constraintEqualToAnchor:topBar.leadingAnchor],
        [topBarSeparator.trailingAnchor constraintEqualToAnchor:topBar.trailingAnchor],
        [topBarSeparator.bottomAnchor constraintEqualToAnchor:topBar.bottomAnchor],
        [topBarSeparator.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],

        [headerContentGuide.topAnchor constraintEqualToAnchor:topBar.safeAreaLayoutGuide.topAnchor],
        [headerContentGuide.bottomAnchor constraintEqualToAnchor:topBar.bottomAnchor],
        [headerContentGuide.leadingAnchor constraintEqualToAnchor:topBar.leadingAnchor],
        [headerContentGuide.trailingAnchor constraintEqualToAnchor:topBar.trailingAnchor],

        [_searchBar.leadingAnchor constraintEqualToAnchor:headerContentGuide.leadingAnchor],
        [_searchBar.centerYAnchor constraintEqualToAnchor:headerContentGuide.topAnchor constant:26],

        [settingsButton.leadingAnchor constraintEqualToAnchor:_searchBar.trailingAnchor constant:4],
        [settingsButton.trailingAnchor constraintEqualToAnchor:headerContentGuide.trailingAnchor constant:-14],
        [settingsButton.centerYAnchor constraintEqualToAnchor:_searchBar.centerYAnchor],
        [settingsButton.widthAnchor constraintEqualToConstant:40],
        [settingsButton.heightAnchor constraintEqualToConstant:40],

        [_typeScrollView.topAnchor constraintEqualToAnchor:headerContentGuide.topAnchor constant:52],
        [_typeScrollView.leadingAnchor constraintEqualToAnchor:topBar.leadingAnchor constant:16],
        [_typeScrollView.trailingAnchor constraintEqualToAnchor:topBar.trailingAnchor constant:-16],
        [_typeScrollView.heightAnchor constraintEqualToConstant:34],
        [_typeStackView.topAnchor constraintEqualToAnchor:_typeScrollView.contentLayoutGuide.topAnchor],
        [_typeStackView.bottomAnchor constraintEqualToAnchor:_typeScrollView.contentLayoutGuide.bottomAnchor],
        [_typeStackView.leadingAnchor constraintEqualToAnchor:_typeScrollView.contentLayoutGuide.leadingAnchor],
        [_typeStackView.trailingAnchor constraintEqualToAnchor:_typeScrollView.contentLayoutGuide.trailingAnchor],
        [_typeStackView.heightAnchor constraintEqualToAnchor:_typeScrollView.frameLayoutGuide.heightAnchor],

        [_sortScrollView.topAnchor constraintEqualToAnchor:_typeScrollView.bottomAnchor constant:8],
        [_sortScrollView.leadingAnchor constraintEqualToAnchor:topBar.leadingAnchor constant:16],
        [_sortScrollView.trailingAnchor constraintEqualToAnchor:topBar.trailingAnchor constant:-16],
        [_sortScrollView.heightAnchor constraintEqualToConstant:36],
        [_sortStackView.topAnchor constraintEqualToAnchor:_sortScrollView.contentLayoutGuide.topAnchor],
        [_sortStackView.bottomAnchor constraintEqualToAnchor:_sortScrollView.contentLayoutGuide.bottomAnchor],
        [_sortStackView.leadingAnchor constraintEqualToAnchor:_sortScrollView.contentLayoutGuide.leadingAnchor],
        [_sortStackView.trailingAnchor constraintEqualToAnchor:_sortScrollView.contentLayoutGuide.trailingAnchor],
        [_sortStackView.heightAnchor constraintEqualToAnchor:_sortScrollView.frameLayoutGuide.heightAnchor],

        [_collectionView.topAnchor constraintEqualToAnchor:topBar.bottomAnchor],
        [_collectionView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_collectionView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_collectionView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];

    _emptyLabel = [UILabel new];
    _emptyLabel.text = LOC(@"DOWNLOAD_LIBRARY_EMPTY");
    _emptyLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    _emptyLabel.textColor = [UIColor secondaryLabelColor];
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.hidden = YES;
    _emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_emptyLabel];
    [NSLayoutConstraint activateConstraints:@[
        [_emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [_emptyLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:24],
        [_emptyLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-24],
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
    return entry ? ymLibraryText(entry[0], entry[1]) : type;
}

- (NSString *)displayTitleForSort:(NSString *)sort {
    NSDictionary *labels = @{
        @"Newest": @[@"DOWNLOAD_LIBRARY_SORT_NEWEST", @"Newest"],
        @"Oldest": @[@"DOWNLOAD_LIBRARY_SORT_OLDEST", @"Oldest"],
        @"Largest": @[@"DOWNLOAD_LIBRARY_SORT_LARGEST", @"Largest"],
        @"Smallest": @[@"DOWNLOAD_LIBRARY_SORT_SMALLEST", @"Smallest"],
        @"A-Z": @[@"DOWNLOAD_LIBRARY_SORT_AZ", @"A-Z"],
        @"Z-A": @[@"DOWNLOAD_LIBRARY_SORT_ZA", @"Z-A"],
    };
    NSArray *entry = labels[sort];
    return entry ? ymLibraryText(entry[0], entry[1]) : sort;
}

- (UIButton *)libraryButtonWithTitle:(NSString *)title tag:(NSInteger)tag selector:(SEL)selector {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.tag = tag;
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    button.contentEdgeInsets = UIEdgeInsetsMake(7, 14, 7, 14);
    button.layer.cornerRadius = 18;
    button.clipsToBounds = YES;
    return button;
}

- (void)rebuildLibraryControls {
    [self.typeStackView.arrangedSubviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.sortStackView.arrangedSubviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    NSArray *types = @[kYMLibraryTypeAll, kYMLibraryTypeVideos, kYMLibraryTypeShorts, kYMLibraryTypeAudio, kYMLibraryTypePlaylists, kYMLibraryTypePrivate];
    [types enumerateObjectsUsingBlock:^(NSString *type, NSUInteger idx, BOOL *stop) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.tag = (NSInteger)idx;
        NSString *title = [self displayTitleForType:type];
        if ([type isEqualToString:kYMLibraryTypePlaylists] && self.selectedPlaylistID.length > 0) title = [NSString stringWithFormat:@"‹ %@", title];
        [button setTitle:title forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:15 weight:[self.selectedType isEqualToString:type] ? UIFontWeightSemibold : UIFontWeightRegular];
        [button setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(libraryTypeTapped:) forControlEvents:UIControlEventTouchUpInside];
        button.contentEdgeInsets = UIEdgeInsetsMake(2, 0, 4, 0);
        [self.typeStackView addArrangedSubview:button];
        if ([self.selectedType isEqualToString:type]) {
            UIView *indicator = [UIView new];
            indicator.backgroundColor = [UIColor labelColor];
            indicator.translatesAutoresizingMaskIntoConstraints = NO;
            [button addSubview:indicator];
            [NSLayoutConstraint activateConstraints:@[
                [indicator.leadingAnchor constraintEqualToAnchor:button.leadingAnchor],
                [indicator.trailingAnchor constraintEqualToAnchor:button.trailingAnchor],
                [indicator.bottomAnchor constraintEqualToAnchor:button.bottomAnchor],
                [indicator.heightAnchor constraintEqualToConstant:2],
            ]];
        }
        if ([type isEqualToString:kYMLibraryTypePlaylists]) {
            UIButton *addPlaylist = [UIButton buttonWithType:UIButtonTypeSystem];
            [addPlaylist setImage:[UIImage systemImageNamed:@"plus"] forState:UIControlStateNormal];
            addPlaylist.accessibilityLabel = ymLibraryText(@"DOWNLOAD_LIBRARY_CREATE_PLAYLIST", @"Create playlist");
            addPlaylist.hidden = ![self.selectedType isEqualToString:kYMLibraryTypePlaylists];
            [addPlaylist addTarget:self action:@selector(createPlaylistTapped) forControlEvents:UIControlEventTouchUpInside];
            addPlaylist.translatesAutoresizingMaskIntoConstraints = NO;
            [NSLayoutConstraint activateConstraints:@[[addPlaylist.widthAnchor constraintEqualToConstant:32], [addPlaylist.heightAnchor constraintEqualToConstant:32]]];
            [self.typeStackView addArrangedSubview:addPlaylist];

            UIButton *deletePlaylist = [UIButton buttonWithType:UIButtonTypeSystem];
            [deletePlaylist setImage:[UIImage systemImageNamed:@"trash"] forState:UIControlStateNormal];
            deletePlaylist.accessibilityLabel = ymLibraryText(@"DOWNLOAD_LIBRARY_DELETE_PLAYLIST", @"Delete playlist");
            deletePlaylist.enabled = ymLibraryPlaylists().count > 0;
            deletePlaylist.hidden = ![self.selectedType isEqualToString:kYMLibraryTypePlaylists];
            [deletePlaylist addTarget:self action:@selector(deletePlaylistTapped) forControlEvents:UIControlEventTouchUpInside];
            deletePlaylist.translatesAutoresizingMaskIntoConstraints = NO;
            [NSLayoutConstraint activateConstraints:@[[deletePlaylist.widthAnchor constraintEqualToConstant:32], [deletePlaylist.heightAnchor constraintEqualToConstant:32]]];
            [self.typeStackView addArrangedSubview:deletePlaylist];
        }
    }];

    NSArray *sorts = @[@"Newest", @"Oldest", @"Largest", @"Smallest", @"A-Z", @"Z-A"];
    [sorts enumerateObjectsUsingBlock:^(NSString *sort, NSUInteger idx, BOOL *stop) {
        UIButton *button = [self libraryButtonWithTitle:[self displayTitleForSort:sort] tag:(NSInteger)idx selector:@selector(librarySortTapped:)];
        BOOL selected = [self.selectedSort isEqualToString:sort];
        button.backgroundColor = selected ? [UIColor labelColor] : [UIColor secondarySystemBackgroundColor];
        [button setTitleColor:selected ? [UIColor systemBackgroundColor] : [UIColor labelColor] forState:UIControlStateNormal];
        [self.sortStackView addArrangedSubview:button];
    }];
}

- (void)libraryTypeTapped:(UIButton *)sender {
    NSArray *types = @[kYMLibraryTypeAll, kYMLibraryTypeVideos, kYMLibraryTypeShorts, kYMLibraryTypeAudio, kYMLibraryTypePlaylists, kYMLibraryTypePrivate];
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
    [self rebuildLibraryControls];
    [self applyFiltersAndSort];
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
        YouModSendError(ymLibraryText(@"DOWNLOAD_LIBRARY_PRIVATE_AUTH_UNAVAILABLE", @"Set up Face ID, Touch ID, or a device passcode to open Private."));
        return;
    }
    self.isAuthenticatingPrivate = YES;
    self.privateAuthWasBackgrounded = NO;
    __weak typeof(self) weakSelf = self;
    [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication
            localizedReason:ymLibraryText(@"DOWNLOAD_LIBRARY_PRIVATE_AUTH_REASON", @"Authenticate to view private downloads")
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
                YouModSendError(ymLibraryText(@"DOWNLOAD_LIBRARY_PRIVATE_AUTH_FAILED", @"Authentication failed. Private downloads remain locked."));
            }
        });
    }];
}

- (void)selectPrivateLibrary {
    self.selectedPlaylistID = nil;
    self.selectedType = kYMLibraryTypePrivate;
    [[NSUserDefaults standardUserDefaults] setObject:self.selectedType forKey:@"YouModDownloadLibrarySelectedType"];
    [self rebuildLibraryControls];
    [self applyFiltersAndSort];
}

- (void)libraryDidEnterBackground {
    self.privateUnlocked = NO;
    if (self.isAuthenticatingPrivate) self.privateAuthWasBackgrounded = YES;
    if ([self.selectedType isEqualToString:kYMLibraryTypePrivate]) {
        self.selectedType = kYMLibraryTypeAll;
        self.selectedPlaylistID = nil;
        [[NSUserDefaults standardUserDefaults] setObject:self.selectedType forKey:@"YouModDownloadLibrarySelectedType"];
        [self rebuildLibraryControls];
        [self applyFiltersAndSort];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
}

- (void)librarySortTapped:(UIButton *)sender {
    NSArray *sorts = @[@"Newest", @"Oldest", @"Largest", @"Smallest", @"A-Z", @"Z-A"];
    if (sender.tag < 0 || sender.tag >= (NSInteger)sorts.count) return;
    self.selectedSort = sorts[(NSUInteger)sender.tag];
    [[NSUserDefaults standardUserDefaults] setObject:self.selectedSort forKey:@"YouModDownloadLibrarySelectedSort"];
    [self rebuildLibraryControls];
    [self applyFiltersAndSort];
}

// Same treatment as the YouMod settings pages: the bar itself blends into the
// background and only the rounded text field carries a fill color.
- (void)updateSearchBarTheme {
    UISearchBar *sb = self.searchBar;
    if (!sb) return;
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UIColor *bgColor = dark ? [%c(YTColor) black3] : [UIColor systemBackgroundColor];
    sb.backgroundColor = bgColor;
    sb.barTintColor = bgColor;
    if ([sb respondsToSelector:@selector(searchTextField)]) {
        UITextField *tf = sb.searchTextField;
        tf.textColor = dark ? [UIColor whiteColor] : [UIColor labelColor];
        tf.backgroundColor = dark ? [UIColor colorWithWhite:0.15 alpha:1.0] : [UIColor colorWithWhite:0.94 alpha:1.0];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle) {
        [self updateSearchBarTheme];
    }
}

- (void)openSettingsTapped {
    id parentResponder = self.hostParentResponder ?: self;

    YTSettingsViewController *settingsVC = [[%c(YTSettingsViewController) alloc] initWithAccountID:nil parentResponder:parentResponder];
    if (!settingsVC) return;
    settingsVC.appearance = 1;

    YTNavigationController *nav = [[%c(YTNavigationController) alloc] initWithParentResponder:parentResponder];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [nav pushViewController:settingsVC animated:NO];

    YTPresentModalResponderEvent *event = [%c(YTPresentModalResponderEvent) eventWithViewController:nav animated:YES firstResponder:parentResponder];
    [event send];
}

- (void)reloadWithCompletion:(void (^)(void))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray<NSURL *> *files = ymLibraryFileURLsNewestFirst();
        NSMutableArray<YMLibraryRow *> *rows = [NSMutableArray arrayWithCapacity:files.count];
        for (NSURL *fileURL in files) {
            NSNumber *size = nil;
            [fileURL getResourceValue:&size forKey:NSURLFileSizeKey error:nil];

            YMLibraryRow *row = [YMLibraryRow new];
            row.path = fileURL.path;
            row.title = ymDisplayTitleForFileName(fileURL.lastPathComponent.stringByDeletingPathExtension);
            row.bytes = size.unsignedLongLongValue;
            row.sizeText = ymFormattedFileSize(row.bytes);
            row.isAudio = ymIsAudioOnlyExtension(fileURL.pathExtension);
            NSDictionary *metadata = ymLibraryMetadataForURL(fileURL);
            row.isShorts = [metadata[@"shorts"] boolValue] && !row.isAudio;
            row.isPrivate = [metadata[@"private"] boolValue];
            row.playlistIDs = [metadata[@"playlists"] isKindOfClass:[NSArray class]] ? metadata[@"playlists"] : @[];
            NSDate *modifiedDate = nil;
            [fileURL getResourceValue:&modifiedDate forKey:NSURLContentModificationDateKey error:nil];
            row.modifiedDate = modifiedDate ?: NSDate.distantPast;
            // Audio rows have no real artwork: render the note into a fixed
            // 48pt canvas so it stays a medium icon centered in the frame
            // instead of scaling up with the 16:9 thumbnail view.
            row.thumbnail = row.isAudio
                ? YouModSymbolImageInCanvas(@"music.note", 48, 24, UIImageSymbolWeightRegular)
                : ymThumbnailForVideoFile(fileURL);
            [rows addObject:row];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            self.allRows = rows;
            [self applyFilter:self.searchBar.text];
            self.emptyLabel.hidden = rows.count > 0;
            if (completion) completion();
        });
    });
}

- (void)reload {
    [self reloadWithCompletion:nil];
}

- (void)applyFilter:(NSString *)query {
    query = [query stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableArray<YMLibraryRow *> *filtered = [NSMutableArray array];
    if ([self.selectedType isEqualToString:kYMLibraryTypePlaylists] && self.selectedPlaylistID.length == 0) {
        for (NSDictionary *playlist in ymLibraryPlaylists()) {
            NSString *name = playlist[@"name"] ?: @"";
            if (query.length > 0 && [name rangeOfString:query options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location == NSNotFound) continue;
            NSString *playlistID = playlist[@"id"] ?: @"";
            NSUInteger itemCount = 0;
            for (YMLibraryRow *item in self.allRows) if (!item.isPrivate && [item.playlistIDs containsObject:playlistID]) itemCount++;
            YMLibraryRow *playlistRow = [YMLibraryRow new];
            playlistRow.isPlaylist = YES;
            playlistRow.playlistID = playlistID;
            playlistRow.title = name;
            playlistRow.bytes = itemCount;
            playlistRow.sizeText = [NSString stringWithFormat:ymLibraryText(@"DOWNLOAD_LIBRARY_PLAYLIST_ITEM_COUNT", @"%ld items"), (long)itemCount];
            playlistRow.thumbnail = YouModSymbolImageInCanvas(@"music.note.list", 48, 24, UIImageSymbolWeightRegular);
            playlistRow.modifiedDate = NSDate.distantPast;
            [filtered addObject:playlistRow];
        }
        if ([self.selectedSort isEqualToString:@"A-Z"]) {
            [filtered sortUsingComparator:^NSComparisonResult(YMLibraryRow *a, YMLibraryRow *b) { return [a.title localizedCaseInsensitiveCompare:b.title]; }];
        } else if ([self.selectedSort isEqualToString:@"Z-A"]) {
            [filtered sortUsingComparator:^NSComparisonResult(YMLibraryRow *a, YMLibraryRow *b) { return [b.title localizedCaseInsensitiveCompare:a.title]; }];
        }
        self.rows = filtered;
        [self.collectionView reloadData];
        self.emptyLabel.hidden = self.rows.count > 0;
        return;
    }
    for (YMLibraryRow *row in self.allRows) {
        BOOL privateTab = [self.selectedType isEqualToString:kYMLibraryTypePrivate];
        if (row.isPrivate != privateTab || (privateTab && !self.privateUnlocked)) continue;
        BOOL typeMatches = YES;
        if ([self.selectedType isEqualToString:kYMLibraryTypeVideos]) typeMatches = !row.isAudio && !row.isShorts;
        else if ([self.selectedType isEqualToString:kYMLibraryTypeShorts]) typeMatches = row.isShorts;
        else if ([self.selectedType isEqualToString:kYMLibraryTypeAudio]) typeMatches = row.isAudio;
        else if ([self.selectedType isEqualToString:kYMLibraryTypePlaylists]) typeMatches = [row.playlistIDs containsObject:self.selectedPlaylistID ?: @""];
        BOOL searchMatches = query.length == 0 || [row.title rangeOfString:query options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location != NSNotFound;
        if (typeMatches && searchMatches) [filtered addObject:row];
    }
    [filtered sortUsingComparator:^NSComparisonResult(YMLibraryRow *a, YMLibraryRow *b) {
        if ([self.selectedSort isEqualToString:@"Oldest"]) return [a.modifiedDate compare:b.modifiedDate];
        if ([self.selectedSort isEqualToString:@"Largest"]) return a.bytes == b.bytes ? NSOrderedSame : (a.bytes > b.bytes ? NSOrderedAscending : NSOrderedDescending);
        if ([self.selectedSort isEqualToString:@"Smallest"]) return a.bytes == b.bytes ? NSOrderedSame : (a.bytes < b.bytes ? NSOrderedAscending : NSOrderedDescending);
        if ([self.selectedSort isEqualToString:@"A-Z"]) return [a.title localizedCaseInsensitiveCompare:b.title];
        if ([self.selectedSort isEqualToString:@"Z-A"]) return [b.title localizedCaseInsensitiveCompare:a.title];
        return [b.modifiedDate compare:a.modifiedDate];
    }];
    self.rows = filtered;
    [self.collectionView reloadData];
    self.emptyLabel.hidden = self.rows.count > 0;
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
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:ymLibraryText(@"DOWNLOAD_LIBRARY_CREATE_PLAYLIST", @"Create playlist")
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = ymLibraryText(@"DOWNLOAD_LIBRARY_PLAYLIST_NAME", @"Playlist name");
        field.autocapitalizationType = UITextAutocapitalizationTypeWords;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:LOC(@"CANCEL") style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:ymLibraryText(@"DOWNLOAD_LIBRARY_CREATE", @"Create") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (name.length == 0) return;
        for (NSDictionary *playlist in ymLibraryPlaylists()) {
            if ([playlist[@"name"] caseInsensitiveCompare:name] == NSOrderedSame) {
                YouModSendError(ymLibraryText(@"DOWNLOAD_LIBRARY_PLAYLIST_EXISTS", @"A playlist with that name already exists"));
                return;
            }
        }
        NSMutableArray *playlists = [ymLibraryPlaylists() mutableCopy];
        [playlists addObject:@{@"id": NSUUID.UUID.UUIDString, @"name": name}];
        ymSaveLibraryPlaylists(playlists);
        [weakSelf rebuildLibraryControls];
        [weakSelf applyFiltersAndSort];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)deletePlaylistTapped {
    NSArray<NSDictionary *> *playlists = ymLibraryPlaylists();
    if (playlists.count == 0) return;
    UIAlertController *picker = [UIAlertController alertControllerWithTitle:ymLibraryText(@"DOWNLOAD_LIBRARY_DELETE_PLAYLIST", @"Delete playlist")
                                                                     message:nil
                                                              preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    for (NSDictionary *playlist in playlists) {
        NSString *name = playlist[@"name"] ?: @"";
        NSString *playlistID = playlist[@"id"] ?: @"";
        [picker addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
            UIAlertController *confirm = [UIAlertController alertControllerWithTitle:ymLibraryText(@"DOWNLOAD_LIBRARY_DELETE_PLAYLIST", @"Delete playlist")
                                                                             message:[NSString stringWithFormat:ymLibraryText(@"DOWNLOAD_LIBRARY_DELETE_PLAYLIST_CONFIRM", @"Delete ‘%@’? Downloaded files will stay in the library."), name]
                                                                      preferredStyle:UIAlertControllerStyleAlert];
            [confirm addAction:[UIAlertAction actionWithTitle:LOC(@"CANCEL") style:UIAlertActionStyleCancel handler:nil]];
            [confirm addAction:[UIAlertAction actionWithTitle:ymLibraryText(@"DELETE", @"Delete") style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *confirmAction) {
                NSMutableArray *updated = [ymLibraryPlaylists() mutableCopy];
                NSIndexSet *matches = [updated indexesOfObjectsPassingTest:^BOOL(NSDictionary *entry, NSUInteger idx, BOOL *stop) {
                    return [entry[@"id"] isEqualToString:playlistID];
                }];
                [updated removeObjectsAtIndexes:matches];
                ymSaveLibraryPlaylists(updated);
                if ([weakSelf.selectedPlaylistID isEqualToString:playlistID]) weakSelf.selectedPlaylistID = nil;
                for (YMLibraryRow *row in weakSelf.allRows) {
                    NSMutableArray *ids = [row.playlistIDs mutableCopy] ?: [NSMutableArray array];
                    [ids removeObject:playlistID];
                    row.playlistIDs = ids;
                    NSMutableDictionary *metadata = [ymLibraryMetadataForURL([NSURL fileURLWithPath:row.path]) mutableCopy];
                    if (ids.count > 0) metadata[@"playlists"] = ids;
                    else [metadata removeObjectForKey:@"playlists"];
                    ymSetLibraryMetadataForURL([NSURL fileURLWithPath:row.path], metadata);
                }
                [weakSelf rebuildLibraryControls];
                [weakSelf applyFiltersAndSort];
            }]];
            [weakSelf presentViewController:confirm animated:YES completion:nil];
        }]];
    }
    [picker addAction:[UIAlertAction actionWithTitle:LOC(@"CANCEL") style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = picker.popoverPresentationController;
    popover.sourceView = self.typeScrollView;
    popover.sourceRect = CGRectMake(CGRectGetMidX(self.typeScrollView.bounds), CGRectGetMidY(self.typeScrollView.bounds), 1, 1);
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)togglePrivateForRow:(YMLibraryRow *)row {
    row.isPrivate = !row.isPrivate;
    NSURL *url = [NSURL fileURLWithPath:row.path];
    NSMutableDictionary *metadata = [ymLibraryMetadataForURL(url) mutableCopy];
    if (row.isPrivate) metadata[@"private"] = @YES;
    else [metadata removeObjectForKey:@"private"];
    ymSetLibraryMetadataForURL(url, metadata);
    [self applyFiltersAndSort];
}

- (void)showPlaylistPickerForRow:(YMLibraryRow *)row sourceView:(UIView *)sourceView {
    NSArray<NSDictionary *> *playlists = ymLibraryPlaylists();
    if (playlists.count == 0) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:ymLibraryText(@"DOWNLOAD_LIBRARY_NO_PLAYLISTS", @"No playlists yet")
                                                                       message:ymLibraryText(@"DOWNLOAD_LIBRARY_CREATE_PLAYLIST_FIRST", @"Create a playlist before adding downloads to it.")
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:LOC(@"CANCEL") style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:ymLibraryText(@"DOWNLOAD_LIBRARY_CREATE", @"Create") style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            [self createPlaylistTapped];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    UIAlertController *picker = [UIAlertController alertControllerWithTitle:ymLibraryText(@"DOWNLOAD_LIBRARY_ADD_TO_PLAYLIST", @"Add to playlist")
                                                                     message:row.title
                                                              preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    for (NSDictionary *playlist in playlists) {
        NSString *playlistID = playlist[@"id"] ?: @"";
        NSString *name = playlist[@"name"] ?: @"";
        BOOL alreadyAdded = [row.playlistIDs containsObject:playlistID];
        NSString *title = alreadyAdded
            ? [NSString stringWithFormat:ymLibraryText(@"DOWNLOAD_LIBRARY_REMOVE_FROM_PLAYLIST", @"Remove from %@"), name]
            : name;
        [picker addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            NSMutableArray *ids = [row.playlistIDs mutableCopy] ?: [NSMutableArray array];
            if ([ids containsObject:playlistID]) [ids removeObject:playlistID];
            else [ids addObject:playlistID];
            row.playlistIDs = ids;
            NSMutableDictionary *metadata = [ymLibraryMetadataForURL([NSURL fileURLWithPath:row.path]) mutableCopy];
            if (ids.count > 0) metadata[@"playlists"] = ids;
            else [metadata removeObjectForKey:@"playlists"];
            ymSetLibraryMetadataForURL([NSURL fileURLWithPath:row.path], metadata);
            [weakSelf applyFiltersAndSort];
        }]];
    }
    [picker addAction:[UIAlertAction actionWithTitle:LOC(@"CANCEL") style:UIAlertActionStyleCancel handler:nil]];
    UIPopoverPresentationController *popover = picker.popoverPresentationController;
    popover.sourceView = sourceView ?: self.view;
    popover.sourceRect = sourceView ? sourceView.bounds : self.view.bounds;
    [self presentViewController:picker animated:YES completion:nil];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.rows.count;
}

// The library view controller is the collection view's scroll delegate, so
// it feeds the refresh control from here.
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
    // Audio rows show a small centered icon on the placeholder fill; video
    // rows fill the frame with their real thumbnail.
    cell.thumbnailImageView.contentMode = (row.isAudio || row.isPlaylist) ? UIViewContentModeCenter : UIViewContentModeScaleAspectFill;
    cell.thumbnailImageView.image = row.thumbnail;
    cell.thumbnailImageView.tintColor = (row.isAudio || row.isPlaylist) ? [UIColor secondaryLabelColor] : nil;
    cell.menuButton.hidden = row.isPlaylist;
    __weak typeof(self) weakSelf = self;
    cell.menuTappedHandler = ^(UIView *sourceView) {
        [weakSelf showActionSheetForRowAtIndexPath:indexPath sourceView:sourceView];
    };
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
    YMLibraryRow *row = self.rows[indexPath.item];
    if (row.isPlaylist) {
        self.selectedPlaylistID = row.playlistID;
        [self applyFiltersAndSort];
        return;
    }
    NSURL *fileURL = [NSURL fileURLWithPath:row.path];

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:fileURL options:nil];
    // The deprecated isPlayable flag reports NO for playable m4a audio, so
    // decide from the tracks the asset actually exposes: m4a/AAC exposes an
    // audio track, while mka/mkv containers expose none.
    BOOL playable = [asset tracksWithMediaType:AVMediaTypeVideo].count > 0
                 || [asset tracksWithMediaType:AVMediaTypeAudio].count > 0;
    if (playable) {
        // Stop everything else that is playing (YouTube's player and any
        // AVPlayer in the process) so it doesn't mix with the opened file.
        ymPauseOtherPlayers();
        AVPlayerViewController *playerVC = [AVPlayerViewController new];
        playerVC.player = [AVPlayer playerWithURL:fileURL];
        [self presentViewController:playerVC animated:YES completion:^{
            [playerVC.player play];
        }];
    } else {
        YouModShareItem(fileURL, self, nil);
    }
}

// Options for a library item, presented as the YouTube-style bottom sheet
// from the cell's ellipsis button.
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
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:ymLibraryText(@"DOWNLOAD_LIBRARY_ADD_TO_PLAYLIST", @"Add to playlist")
                                                    iconImage:YouModSymbolImageInCanvas(@"text.badge.plus", 24, 22, UIImageSymbolWeightMedium)
                                                        style:0
                                                      handler:^(__unused YTActionSheetAction *action) {
        [self showPlaylistPickerForRow:row sourceView:sourceView];
    }]];
    NSString *privateActionTitle = ymLibraryText(row.isPrivate ? @"DOWNLOAD_LIBRARY_MARK_PUBLIC" : @"DOWNLOAD_LIBRARY_MARK_PRIVATE",
                                                 row.isPrivate ? @"Remove from Private" : @"Mark as Private");
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

// Rename dialog via the system alert: a text field prefilled with the
// current name plus Cancel / Rename buttons. The video ID suffix (and the
// file extension) are preserved automatically.
- (void)presentRenameDialogForRow:(YMLibraryRow *)row {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LOC(@"LIBRARY_RENAME_TITLE")
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) weakSelf = self;
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = ymDisplayTitleForFileName(row.path.lastPathComponent.stringByDeletingPathExtension);
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

// Moves the media file (plus its sidecar thumbnail) and updates the row in
// place, so the collection view reflects the new name immediately.
// Returns NO when the name didn't change or the file couldn't be moved.
- (BOOL)applyRename:(NSString *)newBase toRow:(YMLibraryRow *)row {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *directory = [row.path stringByDeletingLastPathComponent];
    NSString *videoID = ymVideoIDForFileName(row.path.lastPathComponent.stringByDeletingPathExtension);
    NSString *newBaseName = videoID ? [NSString stringWithFormat:@"%@ [%@]", newBase, videoID] : newBase;
    NSString *newPath = [[directory stringByAppendingPathComponent:newBaseName] stringByAppendingPathExtension:row.path.pathExtension];
    if (!newPath || [newPath isEqualToString:row.path]) return NO;
    if ([fm fileExistsAtPath:newPath]) return NO;

    if (![fm moveItemAtPath:row.path toPath:newPath error:nil]) return NO;

    // Follow along with the sibling .jpg and drop the stale generated-thumb
    // cache entry (keyed by the old file name).
    NSString *oldSibling = [[row.path stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpg"];
    NSString *newSibling = [[newPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"jpg"];
    if ([fm fileExistsAtPath:oldSibling]) [fm moveItemAtPath:oldSibling toPath:newSibling error:nil];
    [fm removeItemAtPath:ymGeneratedThumbCacheURL([NSURL fileURLWithPath:row.path]).path error:nil];

    NSURL *oldURL = [NSURL fileURLWithPath:row.path];
    NSURL *newURL = [NSURL fileURLWithPath:newPath];
    NSDictionary *metadata = ymLibraryMetadataForURL(oldURL);
    if (metadata.count > 0) ymSetLibraryMetadataForURL(newURL, metadata);
    ymSetLibraryMetadataForURL(oldURL, nil);

    row.path = newPath;
    row.title = newBase;
    return YES;
}

- (void)openOriginalVideoForRow:(YMLibraryRow *)row {
    NSString *videoID = ymVideoIDForFileName(row.path.lastPathComponent.stringByDeletingPathExtension);
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
        NSString *info = ymMediaInfoStringForFile(fileURL, row.bytes);
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
    NSURL *fileURL = [NSURL fileURLWithPath:row.path];
    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:nil];
    ymDeleteThumbnailsForFile(fileURL);
    ymSetLibraryMetadataForURL(fileURL, nil);
    [self.allRows removeObject:row];
    [self.rows removeObjectAtIndex:indexPath.item];
    [self.collectionView deleteItemsAtIndexPaths:@[indexPath]];
    self.emptyLabel.hidden = self.allRows.count > 0;
}

@end

#pragma mark - Entry point

UIViewController *YouModDownloadLibraryViewController(id hostParentResponder) {
    YMLibraryViewController *vc = [YMLibraryViewController new];
    vc.hostParentResponder = hostParentResponder;
    return vc;
}

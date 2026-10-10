#import "Headers.h"
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <CoreMedia/CoreMedia.h>
#import <Photos/Photos.h>
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
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) YMLibraryRefreshControl *refreshControl;
@property (nonatomic, strong) NSMutableArray<YMLibraryRow *> *allRows; // unfiltered backing store
@property (nonatomic, strong) NSMutableArray<YMLibraryRow *> *rows;    // currently displayed (search-filtered)
@property (nonatomic, weak) id hostParentResponder;
@end

@implementation YMLibraryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = LOC(@"DOWNLOAD_LIBRARY_TAB");
    self.view.backgroundColor = ymYouTubeBackgroundColor();
    self.allRows = [NSMutableArray array];
    self.rows = [NSMutableArray array];

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

    [topBar addSubview:_searchBar];
    [topBar addSubview:settingsButton];

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
        [topBar.heightAnchor constraintEqualToConstant:106],

        [topBarSeparator.leadingAnchor constraintEqualToAnchor:topBar.leadingAnchor],
        [topBarSeparator.trailingAnchor constraintEqualToAnchor:topBar.trailingAnchor],
        [topBarSeparator.bottomAnchor constraintEqualToAnchor:topBar.bottomAnchor],
        [topBarSeparator.heightAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],

        [headerContentGuide.topAnchor constraintEqualToAnchor:topBar.safeAreaLayoutGuide.topAnchor],
        [headerContentGuide.bottomAnchor constraintEqualToAnchor:topBar.bottomAnchor],
        [headerContentGuide.leadingAnchor constraintEqualToAnchor:topBar.leadingAnchor],
        [headerContentGuide.trailingAnchor constraintEqualToAnchor:topBar.trailingAnchor],

        [_searchBar.leadingAnchor constraintEqualToAnchor:headerContentGuide.leadingAnchor],
        [_searchBar.centerYAnchor constraintEqualToAnchor:headerContentGuide.centerYAnchor],

        [settingsButton.leadingAnchor constraintEqualToAnchor:_searchBar.trailingAnchor constant:4],
        [settingsButton.trailingAnchor constraintEqualToAnchor:headerContentGuide.trailingAnchor constant:-14],
        [settingsButton.centerYAnchor constraintEqualToAnchor:_searchBar.centerYAnchor],
        [settingsButton.widthAnchor constraintEqualToConstant:35],
        [settingsButton.heightAnchor constraintEqualToConstant:35],

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
    if (query.length == 0) {
        self.rows = [self.allRows mutableCopy];
    } else {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"title CONTAINS[cd] %@", query];
        self.rows = [[self.allRows filteredArrayUsingPredicate:predicate] mutableCopy];
    }
    [self.collectionView reloadData];
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
    cell.thumbnailImageView.contentMode = row.isAudio ? UIViewContentModeCenter : UIViewContentModeScaleAspectFill;
    cell.thumbnailImageView.image = row.thumbnail;
    cell.thumbnailImageView.tintColor = row.isAudio ? [UIColor secondaryLabelColor] : nil;
    __weak typeof(self) weakSelf = self;
    cell.menuTappedHandler = ^(UIView *sourceView) {
        [weakSelf showActionSheetForRowAtIndexPath:indexPath sourceView:sourceView];
    };
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
    YMLibraryRow *row = self.rows[indexPath.item];
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
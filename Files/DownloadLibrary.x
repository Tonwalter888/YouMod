// DownloadLibrary.x — in-app "Downloads" page for files YouMod saved to
// Documents/YouMod_Downloads, similar to the offline library of the stock app.
//
// Every finished video/audio download gets a small sidecar (.meta/<file>.json:
// videoId, title, author, quality, audio track, date) and a thumbnail
// (.meta/<file>.jpg). Files downloaded before this feature existed are listed too:
// their title comes from the file name and the thumbnail from a video frame.
//
// Entry points: a button in the top navigation bar, the first row of the
// download menu, and an action in YouMod's Downloading settings.

#import "Headers.h"
#import <AVKit/AVKit.h>
#import <Photos/Photos.h>

#pragma mark - Strings (German / English)


#pragma mark - Storage

static NSURL *YMLibraryDirectory(void) {
    NSURL *docs = [NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *dir = [docs URLByAppendingPathComponent:@"YouMod_Downloads" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

static NSURL *YMLibraryMetaDirectory(void) {
    NSURL *dir = [YMLibraryDirectory() URLByAppendingPathComponent:@".meta" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return dir;
}

static NSURL *YMLibraryMetaURL(NSURL *fileURL) {
    return [YMLibraryMetaDirectory() URLByAppendingPathComponent:[fileURL.lastPathComponent stringByAppendingPathExtension:@"json"]];
}

static NSURL *YMLibraryCommentsURL(NSURL *fileURL) {
    return [YMLibraryMetaDirectory() URLByAppendingPathComponent:[fileURL.lastPathComponent stringByAppendingPathExtension:@"comments.json"]];
}

static NSURL *YMLibraryThumbURL(NSURL *fileURL) {
    return [YMLibraryMetaDirectory() URLByAppendingPathComponent:[fileURL.lastPathComponent stringByAppendingPathExtension:@"jpg"]];
}

static NSDictionary *YMLibraryReadMeta(NSURL *fileURL) {
    NSData *data = [NSData dataWithContentsOfURL:YMLibraryMetaURL(fileURL)];
    if (!data) return @{};
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [obj isKindOfClass:NSDictionary.class] ? obj : @{};
}

static void YMLibraryWriteMeta(NSURL *fileURL, NSDictionary *meta) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:meta options:NSJSONWritingPrettyPrinted error:nil];
    [data writeToURL:YMLibraryMetaURL(fileURL) atomically:YES];
}

static BOOL YMLibraryIsMediaFile(NSURL *url) {
    NSString *name = url.lastPathComponent;
    if ([name hasPrefix:@"."] || [name hasPrefix:@"Temp_"]) return NO;
    NSString *ext = url.pathExtension.lowercaseString;
    return [@[@"mp4", @"m4a", @"mov", @"m4v"] containsObject:ext];
}

static BOOL YMLibraryIsAudioFile(NSURL *url) {
    return [url.pathExtension.lowercaseString isEqualToString:@"m4a"];
}

#pragma mark - Recording metadata (called from Download.x)

static NSDictionary *gYMPendingMeta;

void YMLibrarySetPendingMetadata(NSDictionary *meta) {
    gYMPendingMeta = [meta copy];
}

NSDictionary *YMLibraryTakePendingMetadata(void) {
    NSDictionary *meta = gYMPendingMeta;
    gYMPendingMeta = nil;
    return meta ?: @{};
}

static void YMLibraryFetchThumbnail(NSURL *fileURL, NSString *videoId);

void YMLibraryRecordCompletedFile(NSURL *fileURL, BOOL isVideo, NSDictionary *meta) {
    if (!fileURL || !YMLibraryIsMediaFile(fileURL)) return;
    if (![fileURL.URLByDeletingLastPathComponent.path isEqualToString:YMLibraryDirectory().path]) return;
    NSMutableDictionary *m = [meta ?: @{} mutableCopy];
    m[@"kind"] = isVideo ? @"video" : @"audio";
    m[@"downloadedAt"] = @([NSDate date].timeIntervalSince1970);
    YMLibraryWriteMeta(fileURL, m);
    YMLibraryFetchThumbnail(fileURL, m[@"videoId"]);
    YMCommentsSaveSnapshot(m[@"videoId"], YMLibraryCommentsURL(fileURL)); // offline comments
}

#pragma mark - Thumbnails

static UIImage *YMLibraryFrameImage(NSURL *fileURL) {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:fileURL options:nil];
    AVAssetImageGenerator *gen = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    gen.appliesPreferredTrackTransform = YES;
    gen.maximumSize = CGSizeMake(640, 360);
    CGImageRef cg = [gen copyCGImageAtTime:CMTimeMakeWithSeconds(3, 600) actualTime:NULL error:nil];
    if (!cg) cg = [gen copyCGImageAtTime:kCMTimeZero actualTime:NULL error:nil];
    if (!cg) return nil;
    UIImage *img = [UIImage imageWithCGImage:cg];
    CGImageRelease(cg);
    return img;
}

static void YMLibraryFetchThumbnail(NSURL *fileURL, NSString *videoId) {
    NSURL *thumbURL = YMLibraryThumbURL(fileURL);
    if ([NSFileManager.defaultManager fileExistsAtPath:thumbURL.path]) return;
    if (videoId.length) {
        NSURL *remote = [NSURL URLWithString:[NSString stringWithFormat:@"https://i.ytimg.com/vi/%@/mqdefault.jpg", videoId]];
        [[NSURLSession.sharedSession dataTaskWithURL:remote completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
            NSInteger status = [resp isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)resp).statusCode : 0;
            if (data.length && status == 200 && [UIImage imageWithData:data]) {
                [data writeToURL:thumbURL atomically:YES];
            } else if (!YMLibraryIsAudioFile(fileURL)) {
                UIImage *img = YMLibraryFrameImage(fileURL);
                if (img) [UIImageJPEGRepresentation(img, 0.8) writeToURL:thumbURL atomically:YES];
            }
        }] resume];
    } else if (!YMLibraryIsAudioFile(fileURL)) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            UIImage *img = YMLibraryFrameImage(fileURL);
            if (img) [UIImageJPEGRepresentation(img, 0.8) writeToURL:thumbURL atomically:YES];
        });
    }
}

#pragma mark - Model

@interface YMLibraryItem : NSObject
@property (nonatomic, strong) NSURL *fileURL;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *author;
@property (nonatomic, copy) NSString *videoId;
@property (nonatomic, copy) NSString *channelId;
@property (nonatomic, copy) NSString *quality;
@property (nonatomic, copy) NSString *audioTrack;
@property (nonatomic, assign) BOOL isAudio;
@property (nonatomic, assign) unsigned long long size;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, assign) double duration; // seconds, 0 = unknown
@end
@implementation YMLibraryItem @end

static NSArray<YMLibraryItem *> *YMLibraryLoadItems(void) {
    NSArray *keys = @[NSURLFileSizeKey, NSURLCreationDateKey];
    NSArray<NSURL *> *urls = [NSFileManager.defaultManager contentsOfDirectoryAtURL:YMLibraryDirectory() includingPropertiesForKeys:keys options:NSDirectoryEnumerationSkipsHiddenFiles error:nil];
    NSMutableArray *items = [NSMutableArray array];
    for (NSURL *url in urls) {
        if (!YMLibraryIsMediaFile(url)) continue;
        NSDictionary *meta = YMLibraryReadMeta(url);
        NSDictionary *values = [url resourceValuesForKeys:keys error:nil];
        YMLibraryItem *item = [YMLibraryItem new];
        item.fileURL = url;
        item.title = [meta[@"title"] length] ? meta[@"title"] : url.lastPathComponent.stringByDeletingPathExtension;
        item.author = meta[@"author"];
        item.videoId = meta[@"videoId"];
        item.channelId = meta[@"channelId"];
        item.quality = meta[@"quality"];
        item.audioTrack = meta[@"audioTrack"];
        item.isAudio = meta[@"kind"] ? [meta[@"kind"] isEqualToString:@"audio"] : YMLibraryIsAudioFile(url);
        item.size = [values[NSURLFileSizeKey] unsignedLongLongValue];
        NSNumber *ts = meta[@"downloadedAt"];
        item.date = ts ? [NSDate dateWithTimeIntervalSince1970:ts.doubleValue] : (values[NSURLCreationDateKey] ?: [NSDate distantPast]);
        item.duration = [meta[@"duration"] doubleValue];
        [items addObject:item];
    }
    [items sortUsingComparator:^NSComparisonResult(YMLibraryItem *a, YMLibraryItem *b) { return [b.date compare:a.date]; }];
    return items;
}

static NSString *YMLibraryFormatDuration(double seconds) {
    if (seconds <= 0) return nil;
    long s = lround(seconds);
    if (s >= 3600) return [NSString stringWithFormat:@"%ld:%02ld:%02ld", s / 3600, (s / 60) % 60, s % 60];
    return [NSString stringWithFormat:@"%ld:%02ld", s / 60, s % 60];
}

static NSString *YMLibraryFormatSize(unsigned long long bytes) {
    return [NSByteCountFormatter stringFromByteCount:(long long)bytes countStyle:NSByteCountFormatterCountStyleFile];
}

#pragma mark - Cell

@interface YMLibraryCell : UITableViewCell
@property (nonatomic, strong) UIImageView *thumb;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) NSURL *representedURL;
@end

@implementation YMLibraryCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;
    _thumb = [UIImageView new];
    _thumb.contentMode = UIViewContentModeScaleAspectFill;
    _thumb.clipsToBounds = YES;
    _thumb.layer.cornerRadius = 8;
    _thumb.backgroundColor = UIColor.secondarySystemFillColor;
    _thumb.tintColor = UIColor.secondaryLabelColor;
    _thumb.translatesAutoresizingMaskIntoConstraints = NO;

    _durationLabel = [UILabel new];
    _durationLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightSemibold];
    _durationLabel.textColor = UIColor.whiteColor;
    _durationLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.75];
    _durationLabel.layer.cornerRadius = 4;
    _durationLabel.clipsToBounds = YES;
    _durationLabel.textAlignment = NSTextAlignmentCenter;
    _durationLabel.translatesAutoresizingMaskIntoConstraints = NO;

    _titleLabel = [UILabel new];
    _titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    _titleLabel.numberOfLines = 2;
    _titleLabel.textColor = UIColor.labelColor;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    _detailLabel = [UILabel new];
    _detailLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    _detailLabel.numberOfLines = 2;
    _detailLabel.textColor = UIColor.secondaryLabelColor;
    _detailLabel.translatesAutoresizingMaskIntoConstraints = NO;

    [self.contentView addSubview:_thumb];
    [_thumb addSubview:_durationLabel];
    [self.contentView addSubview:_titleLabel];
    [self.contentView addSubview:_detailLabel];

    UILayoutGuide *m = self.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_thumb.leadingAnchor constraintEqualToAnchor:m.leadingAnchor],
        [_thumb.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:8],
        [_thumb.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-8],
        [_thumb.widthAnchor constraintEqualToConstant:160],
        [_thumb.heightAnchor constraintEqualToConstant:90],
        [_durationLabel.trailingAnchor constraintEqualToAnchor:_thumb.trailingAnchor constant:-4],
        [_durationLabel.bottomAnchor constraintEqualToAnchor:_thumb.bottomAnchor constant:-4],
        [_durationLabel.heightAnchor constraintEqualToConstant:16],
        [_durationLabel.widthAnchor constraintGreaterThanOrEqualToConstant:36],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_thumb.trailingAnchor constant:12],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:m.trailingAnchor],
        [_titleLabel.topAnchor constraintEqualToAnchor:_thumb.topAnchor],
        [_detailLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_detailLabel.trailingAnchor constraintEqualToAnchor:_titleLabel.trailingAnchor],
        [_detailLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:4],
        [_detailLabel.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor constant:-8],
        [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:106],
    ]];
    return self;
}
@end

#pragma mark - Library view controller

@interface YMDownloadLibraryViewController : UITableViewController
@property (nonatomic, strong) NSArray<YMLibraryItem *> *items;
@property (nonatomic, strong) NSArray<NSDictionary *> *queueItems; // section 0
@property (nonatomic, strong) NSCache *thumbCache;
@property (nonatomic, strong) NSTimer *queueTimer;
@end

@implementation YMDownloadLibraryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = LOC(@"YM_DOWNLOADS");
    self.thumbCache = [NSCache new];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 106;
    [self.tableView registerClass:YMLibraryCell.class forCellReuseIdentifier:@"cell"];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(ym_close)];
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(ym_reload) forControlEvents:UIControlEventValueChanged];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self ym_reload];
    __weak typeof(self) weakSelf = self;
    self.queueTimer = [NSTimer scheduledTimerWithTimeInterval:1.5 repeats:YES block:^(NSTimer *t) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { [t invalidate]; return; }
        NSArray *now = YMDownloadQueueSnapshot();
        if (![now isEqualToArray:self.queueItems]) [self ym_reload]; // a job started/finished
    }];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.queueTimer invalidate];
    self.queueTimer = nil;
}

- (void)ym_close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)ym_reload {
    self.queueItems = YMDownloadQueueSnapshot();
    self.items = YMLibraryLoadItems();
    unsigned long long total = 0;
    for (YMLibraryItem *i in self.items) total += i.size;
    self.navigationItem.prompt = nil;
    UILabel *footer = [UILabel new];
    footer.text = self.items.count
        ? [NSString stringWithFormat:@"%lu %@ · %@", (unsigned long)self.items.count, LOC(@"YM_FILES"), YMLibraryFormatSize(total)]
        : LOC(@"YM_NO_DOWNLOADS_YET_DOWNLOAD_A_VIDEO_FROM_T");
    footer.numberOfLines = 0;
    footer.textAlignment = NSTextAlignmentCenter;
    footer.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    footer.textColor = UIColor.secondaryLabelColor;
    footer.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, self.items.count ? 44 : 120);
    self.tableView.tableFooterView = footer;
    [self.tableView reloadData];
    [self.refreshControl endRefreshing];
    // Fill in durations missing from the metadata (older files) in the background.
    for (YMLibraryItem *item in self.items) {
        if (item.duration > 0) continue;
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            AVURLAsset *asset = [AVURLAsset URLAssetWithURL:item.fileURL options:nil];
            double secs = CMTimeGetSeconds(asset.duration);
            if (!(secs > 0)) return;
            NSMutableDictionary *m = [YMLibraryReadMeta(item.fileURL) mutableCopy];
            m[@"duration"] = @(secs);
            YMLibraryWriteMeta(item.fileURL, m);
            dispatch_async(dispatch_get_main_queue(), ^{
                item.duration = secs;
                NSUInteger row = [self.items indexOfObject:item];
                if (row != NSNotFound && row < (NSUInteger)[self.tableView numberOfRowsInSection:1])
                    [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:1]] withRowAnimation:UITableViewRowAnimationNone];
            });
        });
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? self.queueItems.count : self.items.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (!self.queueItems.count) return nil;
    return section == 0 ? LOC(@"YM_QUEUE") : LOC(@"YM_DOWNLOADED");
}

- (UITableViewCell *)ym_queueCellForRow:(NSInteger)row {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"queue"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"queue"];
    NSDictionary *q = self.queueItems[row];
    BOOL active = [q[@"active"] boolValue];
    cell.textLabel.text = [q[@"title"] length] ? q[@"title"] : LOC(@"YM_UNTITLED_VIDEO");
    cell.textLabel.numberOfLines = 2;
    NSString *detail = q[@"detail"];
    NSString *state = active ? LOC(@"YM_DOWNLOADING") : [NSString stringWithFormat:LOC(@"YM_WAITING_POSITION"), (long)(active ? 0 : row + 1 - ([self.queueItems.firstObject[@"active"] boolValue] ? 1 : 0))];
    cell.detailTextLabel.text = detail.length ? [NSString stringWithFormat:@"%@\n%@", state, detail] : state;
    cell.detailTextLabel.numberOfLines = 2;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (active) {
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        [spinner startAnimating];
        cell.accessoryView = spinner;
        cell.imageView.image = nil;
    } else {
        cell.accessoryView = nil;
        cell.imageView.image = [UIImage systemImageNamed:@"clock"];
        cell.imageView.tintColor = UIColor.secondaryLabelColor;
    }
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) return [self ym_queueCellForRow:indexPath.row];
    YMLibraryCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    YMLibraryItem *item = self.items[indexPath.row];
    cell.titleLabel.text = item.title;

    NSMutableArray *line1 = [NSMutableArray array];
    if (item.author.length) [line1 addObject:item.author];
    NSMutableArray *line2 = [NSMutableArray array];
    if (item.isAudio) [line2 addObject:LOC(@"YM_AUDIO_ONLY")];
    else if (item.quality.length) [line2 addObject:item.quality];
    if (item.audioTrack.length) [line2 addObject:item.audioTrack];
    [line2 addObject:YMLibraryFormatSize(item.size)];
    [line2 addObject:[NSDateFormatter localizedStringFromDate:item.date dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterNoStyle]];
    NSString *l2 = [line2 componentsJoinedByString:@" · "];
    cell.detailLabel.text = line1.count ? [NSString stringWithFormat:@"%@\n%@", [line1 componentsJoinedByString:@" · "], l2] : l2;

    NSString *dur = YMLibraryFormatDuration(item.duration);
    cell.durationLabel.text = dur ? [NSString stringWithFormat:@" %@ ", dur] : nil;
    cell.durationLabel.hidden = dur == nil;

    cell.representedURL = item.fileURL;
    UIImage *cached = [self.thumbCache objectForKey:item.fileURL];
    if (cached) {
        cell.thumb.image = cached;
        cell.thumb.contentMode = UIViewContentModeScaleAspectFill;
    } else {
        cell.thumb.image = [UIImage systemImageNamed:item.isAudio ? @"music.note" : @"film"];
        cell.thumb.contentMode = UIViewContentModeCenter;
        NSURL *thumbURL = YMLibraryThumbURL(item.fileURL);
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            UIImage *img = [UIImage imageWithContentsOfFile:thumbURL.path];
            if (!img && !item.isAudio) {
                img = YMLibraryFrameImage(item.fileURL);
                if (img) [UIImageJPEGRepresentation(img, 0.8) writeToURL:thumbURL atomically:YES];
            }
            if (!img) return;
            [self.thumbCache setObject:img forKey:item.fileURL];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (![cell.representedURL isEqual:item.fileURL]) return;
                cell.thumb.image = img;
                cell.thumb.contentMode = UIViewContentModeScaleAspectFill;
            });
        });
    }
    return cell;
}

#pragma mark Actions

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0) return;
    [self ym_openWatch:self.items[indexPath.row]];
}

- (void)ym_openWatch:(YMLibraryItem *)item {
    NSMutableArray *parts = [NSMutableArray array];
    if (item.author.length) [parts addObject:item.author];
    if (item.isAudio) [parts addObject:LOC(@"YM_AUDIO_ONLY")];
    else if (item.quality.length) [parts addObject:item.quality];
    if (item.audioTrack.length) [parts addObject:item.audioTrack];
    NSString *dur = YMLibraryFormatDuration(item.duration);
    if (dur) [parts addObject:dur];
    [parts addObject:YMLibraryFormatSize(item.size)];
    [parts addObject:[NSDateFormatter localizedStringFromDate:item.date dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterNoStyle]];
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[@"fileURL"] = item.fileURL;
    info[@"title"] = item.title ?: @"";
    info[@"detail"] = [parts componentsJoinedByString:@" · "];
    info[@"isAudio"] = @(item.isAudio);
    info[@"thumbPath"] = YMLibraryThumbURL(item.fileURL).path;
    info[@"commentsURL"] = YMLibraryCommentsURL(item.fileURL);
    if (item.videoId.length) info[@"videoId"] = item.videoId;
    if (item.channelId.length) info[@"channelId"] = item.channelId;
    if (item.author.length) info[@"author"] = item.author;
    [self.navigationController pushViewController:YMCreateWatchViewController(info) animated:YES];
}

- (void)ym_play:(YMLibraryItem *)item {
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeMoviePlayback options:0 error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    AVPlayerViewController *pvc = [AVPlayerViewController new];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:item.fileURL];
    AVMutableMetadataItem *titleMeta = [AVMutableMetadataItem metadataItem];
    titleMeta.identifier = AVMetadataCommonIdentifierTitle;
    titleMeta.value = item.title;
    titleMeta.extendedLanguageTag = @"und";
    NSMutableArray *external = [NSMutableArray arrayWithObject:titleMeta];
    if (item.author.length) {
        AVMutableMetadataItem *artist = [AVMutableMetadataItem metadataItem];
        artist.identifier = AVMetadataCommonIdentifierArtist;
        artist.value = item.author;
        artist.extendedLanguageTag = @"und";
        [external addObject:artist];
    }
    playerItem.externalMetadata = external;
    pvc.player = [AVPlayer playerWithPlayerItem:playerItem];
    pvc.allowsPictureInPicturePlayback = YES;
    if (@available(iOS 14.2, *)) pvc.canStartPictureInPictureAutomaticallyFromInline = YES;
    pvc.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:pvc animated:YES completion:^{ [pvc.player play]; }];
}

- (void)ym_share:(YMLibraryItem *)item sourceView:(UIView *)view {
    UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:@[item.fileURL] applicationActivities:nil];
    avc.popoverPresentationController.sourceView = view ?: self.view;
    avc.popoverPresentationController.sourceRect = view ? view.bounds : CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1);
    [self presentViewController:avc animated:YES completion:nil];
}

- (void)ym_toast:(NSString *)message {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:a animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [a dismissViewControllerAnimated:YES completion:nil]; });
    }];
}

- (void)ym_saveToPhotos:(YMLibraryItem *)item {
    [PHPhotoLibrary requestAuthorizationForAccessLevel:PHAccessLevelAddOnly handler:^(PHAuthorizationStatus status) {
        if (status != PHAuthorizationStatusAuthorized && status != PHAuthorizationStatusLimited) {
            dispatch_async(dispatch_get_main_queue(), ^{ [self ym_toast:LOC(@"YM_NO_ACCESS_TO_PHOTOS")]; });
            return;
        }
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            [PHAssetCreationRequest creationRequestForAssetFromVideoAtFileURL:item.fileURL];
        } completionHandler:^(BOOL success, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self ym_toast:success ? LOC(@"YM_SAVED_TO_PHOTOS") : (error.localizedDescription ?: LOC(@"YM_SAVING_FAILED"))];
            });
        }];
    }];
}

- (void)ym_openInYouTube:(YMLibraryItem *)item {
    YMOpenVideoInApp(self.navigationController ?: self, item.videoId);
}

- (void)ym_confirmDelete:(YMLibraryItem *)item completion:(void (^)(BOOL deleted))completion {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:LOC(@"YM_DELETE_DOWNLOAD")
                                                               message:[NSString stringWithFormat:@"„%@“ %@", item.title, LOC(@"YM_WILL_BE_REMOVED_FROM_THIS_IPHONE_A_COPY")]
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:LOC(@"YM_CANCEL") style:UIAlertActionStyleCancel handler:^(UIAlertAction *x) { if (completion) completion(NO); }]];
    [a addAction:[UIAlertAction actionWithTitle:LOC(@"YM_DELETE") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x) {
        NSFileManager *fm = NSFileManager.defaultManager;
        [fm removeItemAtURL:item.fileURL error:nil];
        [fm removeItemAtURL:YMLibraryMetaURL(item.fileURL) error:nil];
        [fm removeItemAtURL:YMLibraryThumbURL(item.fileURL) error:nil];
        [fm removeItemAtURL:YMLibraryCommentsURL(item.fileURL) error:nil];
        [self.thumbCache removeObjectForKey:item.fileURL];
        if (completion) completion(YES);
        [self ym_reload];
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        NSDictionary *q = self.queueItems[indexPath.row];
        if ([q[@"active"] boolValue]) return [UISwipeActionsConfiguration configurationWithActions:@[]];
        NSUInteger queuedIndex = indexPath.row - ([self.queueItems.firstObject[@"active"] boolValue] ? 1 : 0);
        UIContextualAction *remove = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:LOC(@"YM_REMOVE") handler:^(UIContextualAction *a, UIView *v, void (^done)(BOOL)) {
            YMDownloadQueueRemoveAtIndex(queuedIndex);
            done(YES);
            [self ym_reload];
        }];
        return [UISwipeActionsConfiguration configurationWithActions:@[remove]];
    }
    YMLibraryItem *item = self.items[indexPath.row];
    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:LOC(@"YM_DELETE") handler:^(UIContextualAction *a, UIView *v, void (^done)(BOOL)) {
        [self ym_confirmDelete:item completion:done];
    }];
    del.image = [UIImage systemImageNamed:@"trash"];
    UIContextualAction *share = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:LOC(@"YM_SHARE") handler:^(UIContextualAction *a, UIView *v, void (^done)(BOOL)) {
        [self ym_share:item sourceView:[tableView cellForRowAtIndexPath:indexPath]];
        done(YES);
    }];
    share.image = [UIImage systemImageNamed:@"square.and.arrow.up"];
    share.backgroundColor = UIColor.systemBlueColor;
    UISwipeActionsConfiguration *cfg = [UISwipeActionsConfiguration configurationWithActions:@[del, share]];
    cfg.performsFirstActionWithFullSwipe = NO;
    return cfg;
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point {
    if (indexPath.section == 0) return nil;
    YMLibraryItem *item = self.items[indexPath.row];
    return [UIContextMenuConfiguration configurationWithIdentifier:nil previewProvider:nil actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggested) {
        NSMutableArray *actions = [NSMutableArray array];
        [actions addObject:[UIAction actionWithTitle:LOC(@"YM_PLAY") image:[UIImage systemImageNamed:@"play.fill"] identifier:nil handler:^(UIAction *a) { [self ym_openWatch:item]; }]];
        if (item.videoId.length)
            [actions addObject:[UIAction actionWithTitle:LOC(@"YM_OPEN_IN_YOUTUBE") image:[UIImage systemImageNamed:@"play.rectangle"] identifier:nil handler:^(UIAction *a) { [self ym_openInYouTube:item]; }]];
        if (item.channelId.length)
            [actions addObject:[UIAction actionWithTitle:LOC(@"YM_GO_TO_CHANNEL") image:[UIImage systemImageNamed:@"person.crop.circle"] identifier:nil handler:^(UIAction *a) { YMOpenChannelInApp(self.navigationController ?: self, item.channelId); }]];
        [actions addObject:[UIAction actionWithTitle:LOC(@"YM_SHARE") image:[UIImage systemImageNamed:@"square.and.arrow.up"] identifier:nil handler:^(UIAction *a) { [self ym_share:item sourceView:[tableView cellForRowAtIndexPath:indexPath]]; }]];
        if (!item.isAudio)
            [actions addObject:[UIAction actionWithTitle:LOC(@"YM_SAVE_TO_PHOTOS") image:[UIImage systemImageNamed:@"photo.on.rectangle"] identifier:nil handler:^(UIAction *a) { [self ym_saveToPhotos:item]; }]];
        UIAction *del = [UIAction actionWithTitle:LOC(@"YM_DELETE") image:[UIImage systemImageNamed:@"trash"] identifier:nil handler:^(UIAction *a) { [self ym_confirmDelete:item completion:nil]; }];
        del.attributes = UIMenuElementAttributesDestructive;
        [actions addObject:del];
        return [UIMenu menuWithTitle:@"" children:actions];
    }];
}

@end

#pragma mark - Presenting

void YMPresentDownloadLibrary(UIViewController *from) {
    UIViewController *presenter = from;
    if (!presenter) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *w in ((UIWindowScene *)scene).windows) if (w.isKeyWindow) presenter = w.rootViewController;
        }
    }
    presenter = YouModTopViewController(presenter);
    if (!presenter) return;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:[YMDownloadLibraryViewController new]];
    nav.navigationBar.prefersLargeTitles = YES;
    [presenter presentViewController:nav animated:YES completion:nil];
}

#pragma mark - Navigation bar button

// The stock buttons live in YTRightNavigationButtons, whose bounds (and those of
// some containers above it) only cover the stock buttons. A button placed left of
// them is visible but never receives touches. So the button is hosted by the
// nearest ancestor whose bounds really cover its position, and it mirrors the
// visibility of YTRightNavigationButtons (hidden / alpha / off-window).

#import <objc/runtime.h>

static const void *kYMLibraryButtonKey = &kYMLibraryButtonKey;

@interface YTRightNavigationButtons (YMLibrary)
- (void)ym_openLibrary:(UIButton *)sender;
- (void)ym_syncLibraryButton;
@end

static BOOL YMViewChainVisible(UIView *from, UIView *upTo) {
    for (UIView *v = from; v && v != upTo; v = v.superview)
        if (v.hidden || v.alpha < 0.01) return NO;
    return YES;
}

%hook YTRightNavigationButtons

- (void)layoutSubviews {
    %orig;
    [self ym_syncLibraryButton];
}

- (void)didMoveToWindow {
    %orig;
    [self ym_syncLibraryButton];
}

- (void)setHidden:(BOOL)hidden {
    %orig;
    [self ym_syncLibraryButton];
}

- (void)setAlpha:(CGFloat)alpha {
    %orig;
    [self ym_syncLibraryButton];
}

- (void)removeFromSuperview {
    UIButton *button = objc_getAssociatedObject(self, kYMLibraryButtonKey);
    [button removeFromSuperview];
    %orig;
}

%new
- (void)ym_syncLibraryButton {
    UIButton *button = objc_getAssociatedObject(self, kYMLibraryButtonKey);

    // Leftmost visible stock button decides where ours goes and how big it is.
    UIView *leftmost = nil;
    for (UIView *v in self.subviews) {
        if (v.hidden || v.alpha < 0.01 || v.bounds.size.width < 1) continue;
        if (!leftmost || CGRectGetMinX(v.frame) < CGRectGetMinX(leftmost.frame)) leftmost = v;
    }
    if (!IS_ENABLED(DownloadManager) || !self.window || !leftmost) { button.hidden = YES; return; }

    CGFloat side = MAX(leftmost.frame.size.width, 40);
    CGRect local = CGRectMake(CGRectGetMinX(leftmost.frame) - side, CGRectGetMidY(leftmost.frame) - side / 2, side, side);

    // Nearest ancestor whose bounds contain the button, so hit-testing reaches it.
    UIView *host = self.superview;
    while (host && !CGRectContainsRect(host.bounds, [self convertRect:local toView:host])) host = host.superview;
    if (!host) { button.hidden = YES; return; }

    if (!button) {
        button = [UIButton buttonWithType:UIButtonTypeSystem];
        UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular];
        [button setImage:[UIImage systemImageNamed:@"arrow.down.circle" withConfiguration:cfg] forState:UIControlStateNormal];
        button.tintColor = UIColor.labelColor;
        button.accessibilityLabel = LOC(@"YM_DOWNLOADS");
        [button addTarget:self action:@selector(ym_openLibrary:) forControlEvents:UIControlEventTouchUpInside];
        objc_setAssociatedObject(self, kYMLibraryButtonKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (button.superview != host) {
        [button removeFromSuperview];
        [host addSubview:button];
    }
    button.frame = [self convertRect:local toView:host];
    button.hidden = !YMViewChainVisible(self, host);
    button.alpha = self.alpha;
    [host bringSubviewToFront:button];
}

%new
- (void)ym_openLibrary:(UIButton *)sender {
    YMPresentDownloadLibrary(self.window.rootViewController);
}

%end

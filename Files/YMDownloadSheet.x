#import "Headers.h"

static NSString * const YMAudioOnlyTab = @"\x01Audio-only";

typedef NS_ENUM(NSInteger, YMDownloadSheetSection) {
    YMDownloadSheetSectionVideoCodec = 0,
    YMDownloadSheetSectionAudioCodec = 1,
    YMDownloadSheetSectionVideo = 2,
    YMDownloadSheetSectionAudio = 3,
    YMDownloadSheetSectionCaptions = 4,
};

@interface YMDownloadSheet () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, assign) YMDownloadDestination destination;
@property (nonatomic, copy) NSString *videoTitle;
@property (nonatomic, copy) NSString *videoID;
@property (nonatomic, strong) NSURL *thumbnailURL;
@property (nonatomic, copy) NSString *channelTitle;
@property (nonatomic, strong) NSArray<YMFormat *> *allFormats;
@property (nonatomic, strong) NSArray<YMCaptionTrack *> *captions;
@property (nonatomic, strong) NSArray<NSString *> *tabs;
@property (nonatomic, strong) NSArray<NSString *> *videoTabs;
@property (nonatomic, copy) NSString *selectedTab;
@property (nonatomic, strong) NSArray<NSString *> *audioCodecs;
@property (nonatomic, copy) NSString *selectedAudioCodec;
@property (nonatomic, strong) NSArray<YMFormat *> *audioRows;
@property (nonatomic, strong) NSMutableArray<YMFormat *> *selectedAudios;
@property (nonatomic, strong) NSArray<YMFormat *> *videoRows;
@property (nonatomic, strong) YMFormat *selectedVideo;
@property (nonatomic, strong) NSMutableArray<YMCaptionTrack *> *selectedCaptions;
@property (nonatomic, strong) NSArray<NSNumber *> *sections;
@property (nonatomic, strong) UISegmentedControl *videoCodecControl;
@property (nonatomic, strong) UISegmentedControl *audioCodecControl;
@property (nonatomic, strong) UILabel *codecHint;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIButton *downloadButton;
@end

@implementation YMDownloadSheet

+ (void)presentForPlayer:(YTPlayerViewController *)player
            destination:(YMDownloadDestination)destination
              presenter:(UIViewController *)presenter {
    NSArray<YMFormat *> *formats = YMFormatsFromPlayer(player);
    if (destination == YMDownloadDestinationPhotos) {
        formats = YMPhotosCompatibleFormats(formats);
    }
    if (formats.count > 0) {
        YMDownloadSheet *sheet = [YMDownloadSheet new];
        sheet.destination = destination;
        sheet.allFormats = formats;
        sheet.captions = YMCaptionTracksFromPlayer(player);
        sheet.videoTitle = YouModTitleForPlayer(player);
        sheet.videoID = YouModVideoIDForPlayer(player);
        sheet.thumbnailURL = YouModThumbnailURL(player);
        sheet.channelTitle = YouModAuthorForPlayer(player);
        [sheet presentFrom:presenter];
    } else {
        YouModSendError(LOC(@"NO_VID_AUDIO_STREAM_FOUND"));
    }
}

- (void)presentFrom:(UIViewController *)presenter {
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:self];
    nav.navigationBarHidden = YES;
    // Runtime OS check instead of @available: the Linux theos toolchain ships
    // no compiler-rt builtins lib, so __isOSVersionAtLeast can't be linked.
    if ([NSProcessInfo processInfo].operatingSystemVersion.majorVersion >= 15) {
        nav.sheetPresentationController.detents = @[[UISheetPresentationControllerDetent largeDetent]];
        nav.sheetPresentationController.prefersGrabberVisible = YES;
        nav.sheetPresentationController.preferredCornerRadius = 16.0;
    } else {
        nav.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    [presenter presentViewController:nav animated:YES completion:nil];
}

- (BOOL)isAudioOnly {
    return [self.selectedTab isEqualToString:YMAudioOnlyTab];
}

- (void)buildModel {
    self.videoTabs = YMVideoCodecsInFormats(self.allFormats);
    NSMutableArray<NSString *> *tabs = [self.videoTabs mutableCopy] ?: [NSMutableArray array];
    self.audioCodecs = YMAudioCodecsInFormats(self.allFormats);
    if (self.destination == YMDownloadDestinationFiles && self.audioCodecs.count > 0) {
        [tabs addObject:YMAudioOnlyTab];
    }
    self.tabs = tabs;
    self.selectedTab = tabs.firstObject;
    self.selectedAudioCodec = self.audioCodecs.firstObject;
    self.selectedAudios = [NSMutableArray array];
    self.selectedCaptions = [NSMutableArray array];
    [self rebuildRows];
}

- (void)rebuildRows {
    NSArray<YMFormat *> *audioRows = YMAudioTracksForCodec(self.allFormats, self.selectedAudioCodec);
    if (IS_ENABLED(HideAutoDubbedDownloads)) {
        NSMutableArray<YMFormat *> *filtered = [NSMutableArray array];
        for (YMFormat *audio in audioRows) if (!audio.isAutoDubbed) [filtered addObject:audio];
        if (filtered.count > 0) audioRows = filtered;
    }
    self.audioRows = audioRows;
    NSMutableArray<YMFormat *> *kept = [NSMutableArray array];
    for (YMFormat *current in self.selectedAudios) {
        for (YMFormat *f in self.audioRows) {
            if ([f.audioTrackID isEqualToString:current.audioTrackID]) {
                [kept addObject:f];
                break;
            }
        }
    }
    self.selectedAudios = kept;
    if (self.selectedAudios.count == 0 && self.audioRows.count > 0) {
        YMFormat *original = nil;
        for (YMFormat *audio in self.audioRows) {
            if (audio.isOriginal) {
                original = audio;
                break;
            }
        }
        [self.selectedAudios addObject:original ?: self.audioRows.firstObject];
    }
    if (self.isAudioOnly) {
        self.videoRows = @[];
        self.selectedVideo = nil;
    } else {
        self.videoRows = YMVideoFormatsForCodec(self.allFormats, self.selectedTab);
        if (![self.videoRows containsObject:self.selectedVideo]) {
            self.selectedVideo = self.videoRows.firstObject;
        }
    }
    NSMutableArray<NSNumber *> *sections = [NSMutableArray array];
    if (self.tabs.count > 1) [sections addObject:@(YMDownloadSheetSectionVideoCodec)];
    if (!self.isAudioOnly) [sections addObject:@(YMDownloadSheetSectionVideo)];
    if (self.audioCodecs.count > 1) [sections addObject:@(YMDownloadSheetSectionAudioCodec)];
    if (self.audioRows.count > 0) [sections addObject:@(YMDownloadSheetSectionAudio)];
    if (!self.isAudioOnly && self.captions.count > 0) [sections addObject:@(YMDownloadSheetSectionCaptions)];
    self.sections = sections;
}

- (unsigned long long)totalBytes {
    unsigned long long total = 0;
    total += self.selectedVideo.contentLength;
    for (YMFormat *audio in self.selectedAudios) total += audio.contentLength;
    return total;
}

static NSString *YMByteCountString(unsigned long long bytes) {
    if (bytes < 1) return nil;
    NSByteCountFormatter *fmt = [NSByteCountFormatter new];
    fmt.countStyle = NSByteCountFormatterCountStyleFile;
    return [fmt stringFromByteCount:(long long)bytes];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self buildModel];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.view.tintColor = UIColor.systemPurpleColor; // why he ourple

    UILabel *titleLabel = [UILabel new];
    if (self.channelTitle.length > 0) {
        titleLabel.text = [NSString stringWithFormat:@"%@ — %@", self.channelTitle, self.videoTitle];
    } else {
        titleLabel.text = self.videoTitle;
    }
    titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    titleLabel.textColor = UIColor.secondaryLabelColor;
    titleLabel.numberOfLines = 2;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *hint = [UILabel new];
    self.codecHint = hint;
    hint.font = [UIFont systemFontOfSize:12];
    hint.textColor = UIColor.tertiaryLabelColor;
    hint.numberOfLines = 0;
    hint.translatesAutoresizingMaskIntoConstraints = NO;

    UITableView *table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView = table;
    table.dataSource = self;
    table.delegate = self;
    table.rowHeight = 48;
    table.backgroundColor = UIColor.clearColor;
    table.translatesAutoresizingMaskIntoConstraints = NO;

    UIButton *download = [UIButton buttonWithType:UIButtonTypeSystem];
    self.downloadButton = download;
    download.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    download.backgroundColor = UIColor.secondarySystemBackgroundColor;
    download.layer.cornerRadius = 12;
    download.translatesAutoresizingMaskIntoConstraints = NO;
    [download addTarget:self action:@selector(startDownload) forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:titleLabel];
    [self.view addSubview:hint];
    [self.view addSubview:table];
    [self.view addSubview:download];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:safe.topAnchor constant:18],
        [titleLabel.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20],
        [titleLabel.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20],
        [hint.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:14],
        [hint.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20],
        [hint.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20],
        [table.topAnchor constraintEqualToAnchor:hint.bottomAnchor constant:4],
        [table.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [table.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [table.bottomAnchor constraintEqualToAnchor:download.topAnchor constant:-8],
        [download.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20],
        [download.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20],
        [download.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-12],
        [download.heightAnchor constraintEqualToConstant:50],
    ]];
    [self refreshChrome];
}

- (NSArray<NSString *> *)tabTitles {
    NSMutableArray<NSString *> *out = [NSMutableArray array];
    for (NSString *tab in self.tabs) {
        if ([tab isEqualToString:YMAudioOnlyTab]) {
            [out addObject:LOC(@"AUDIO_ONLY")];
        } else {
            [out addObject:YMCodecDisplayName(tab)];
        }
    }
    return out;
}

- (void)videoCodecChanged {
    NSInteger index = self.videoCodecControl.selectedSegmentIndex;
    if (index >= 0 && index < (NSInteger)self.tabs.count) {
        self.selectedTab = self.tabs[index];
        [self rebuildRows];
        [self.tableView reloadData];
        [self refreshChrome];
    }
}

- (void)audioCodecChanged {
        NSInteger index = self.audioCodecControl.selectedSegmentIndex;
        if (index >= 0 && index < (NSInteger)self.audioCodecs.count) {
            self.selectedAudioCodec = self.audioCodecs[index];
            [self rebuildRows];
            [self.tableView reloadData];
            [self refreshChrome];
        }
}

- (UISegmentedControl *)segmentedControlWithItems:(NSArray<NSString *> *)items action:(SEL)action {
    UISegmentedControl *control = [[UISegmentedControl alloc] initWithItems:items];
    control.translatesAutoresizingMaskIntoConstraints = NO;
    [control addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    return control;
}

- (NSString *)filesHint {
    NSString *tab = self.isAudioOnly ? nil : self.selectedTab;
    NSString *audioCodec = self.selectedAudioCodec;
    BOOL videoOK = YMCodecIsApplePlayable(tab, YES);
    if (tab.length == 0) {
        if (audioCodec.length > 0 && !YMCodecIsApplePlayable(audioCodec, NO)) {
            return [NSString stringWithFormat:LOC(@"FILES_HINT_AUDIO"), YMCodecDisplayName(audioCodec)];
        }
        return LOC(@"FILES_HINT_COMPATIBLE");
    }
    if (audioCodec.length == 0) {
        if (!videoOK) {
            return [NSString stringWithFormat:LOC(@"FILES_HINT_VIDEO"), YMCodecDisplayName(tab)];
        }
        return LOC(@"FILES_HINT_COMPATIBLE");
    }
    BOOL audioOK = YMCodecIsApplePlayable(audioCodec, NO);
    if (!videoOK && !audioOK) {
        return [NSString stringWithFormat:LOC(@"FILES_HINT_BOTH"),
                YMCodecDisplayName(tab), YMCodecDisplayName(audioCodec)];
    }
    if (videoOK && audioOK) return LOC(@"FILES_HINT_COMPATIBLE");
    if (videoOK) {
        return [NSString stringWithFormat:LOC(@"FILES_HINT_AUDIO"), YMCodecDisplayName(audioCodec)];
    }
    return [NSString stringWithFormat:LOC(@"FILES_HINT_VIDEO"), YMCodecDisplayName(tab)];
}

- (void)refreshChrome {
    if (self.destination == YMDownloadDestinationFiles) {
        self.codecHint.text = self.filesHint;
    } else {
        self.codecHint.text = LOC(@"PHOTOS_CODEC_NOTE");
    }
    NSString *bytes = YMByteCountString(self.totalBytes);
    if (bytes.length > 0) {
        [self.downloadButton setTitle:[NSString stringWithFormat:@"%@   ·   %@",
                                       LOC(@"DOWNLOAD_BUTTON"), bytes] forState:UIControlStateNormal];
    } else {
        [self.downloadButton setTitle:LOC(@"DOWNLOAD_BUTTON") forState:UIControlStateNormal];
    }
}

- (NSInteger)kindForSection:(NSInteger)section {
    return [self.sections[section] integerValue];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch ([self kindForSection:section]) {
        case YMDownloadSheetSectionVideoCodec:
        case YMDownloadSheetSectionAudioCodec:
            return 0;
        case YMDownloadSheetSectionVideo: return self.videoRows.count;
        case YMDownloadSheetSectionAudio: return self.audioRows.count;
        case YMDownloadSheetSectionCaptions: return self.captions.count;
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    static NSString *keys[] = {@"VIDEO_CODEC", @"AUDIO_CODEC", @"QUALITY", @"SOUNDTRACK", @"SUBTITLES"};
    NSInteger kind = [self kindForSection:section];
    if (kind < 0 || kind > 3) return nil;
    return LOC(keys[kind]);
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSInteger kind = [self kindForSection:section];
    NSString *title = nil;
    if (kind == YMDownloadSheetSectionVideoCodec) title = LOC(@"VIDEO_CODEC");
    else if (kind == YMDownloadSheetSectionAudioCodec) title = LOC(@"AUDIO_CODEC");
    if (!title) return nil;

    UIView *header = [[UIView alloc] initWithFrame:CGRectZero];
    header.backgroundColor = UIColor.clearColor;
    UILabel *label = [UILabel new];
    label.text = title.uppercaseString;
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    label.textColor = UIColor.secondaryLabelColor;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    NSArray<NSString *> *items = self.tabTitles;
    if (kind == YMDownloadSheetSectionAudioCodec) {
        NSMutableArray<NSString *> *titles = [NSMutableArray array];
        for (NSString *codec in self.audioCodecs) [titles addObject:YMCodecFriendlyName(codec)];
        items = titles;
    }
    UISegmentedControl *control = [self segmentedControlWithItems:items
                                                             action:kind == YMDownloadSheetSectionVideoCodec
                                                                    ? @selector(videoCodecChanged)
                                                                    : @selector(audioCodecChanged)];
    control.selectedSegmentIndex = kind == YMDownloadSheetSectionVideoCodec
        ? [self.tabs indexOfObject:self.selectedTab]
        : [self.audioCodecs indexOfObject:self.selectedAudioCodec];
    if (kind == YMDownloadSheetSectionVideoCodec) self.videoCodecControl = control;
    else self.audioCodecControl = control;
    [header addSubview:label];
    [header addSubview:control];
    [NSLayoutConstraint activateConstraints:@[
        [label.topAnchor constraintEqualToAnchor:header.topAnchor constant:8],
        [label.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20],
        [label.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],
        [control.topAnchor constraintEqualToAnchor:label.bottomAnchor constant:6],
        [control.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20],
        [control.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],
        [control.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-8],
        [control.heightAnchor constraintEqualToConstant:32],
    ]];
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    NSInteger kind = [self kindForSection:section];
    return (kind == YMDownloadSheetSectionVideoCodec || kind == YMDownloadSheetSectionAudioCodec) ? 78.0 : 28.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ym"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"ym"];
    }
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.detailTextLabel.text = nil;
    UITableViewCellAccessoryType accessory = UITableViewCellAccessoryNone;
    switch ([self kindForSection:indexPath.section]) {
        case YMDownloadSheetSectionVideo: {
            YMFormat *f = self.videoRows[indexPath.row];
            cell.textLabel.text = f.displayLabel;
            cell.detailTextLabel.text = YMByteCountString(f.contentLength);
            if (f == self.selectedVideo) accessory = UITableViewCellAccessoryCheckmark;
            break;
        }
        case YMDownloadSheetSectionAudio: {
            YMFormat *f = self.audioRows[indexPath.row];
            cell.textLabel.text = f.displayLabel;
            cell.detailTextLabel.text = YMByteCountString(f.contentLength);
            if ([self.selectedAudios containsObject:f]) accessory = UITableViewCellAccessoryCheckmark;
            break;
        }
        case YMDownloadSheetSectionCaptions: {
            YMCaptionTrack *t = self.captions[indexPath.row];
            cell.textLabel.text = t.name;
            cell.detailTextLabel.text = t.languageCode;
            if ([self.selectedCaptions containsObject:t]) accessory = UITableViewCellAccessoryCheckmark;
            break;
        }
        default:
            break;
    }
    cell.accessoryType = accessory;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    switch ([self kindForSection:indexPath.section]) {
        case YMDownloadSheetSectionVideo:
            self.selectedVideo = self.videoRows[indexPath.row];
            break;
        case YMDownloadSheetSectionAudio:
            if (self.destination == YMDownloadDestinationFiles) {
                YMFormat *audio = self.audioRows[indexPath.row];
                if ([self.selectedAudios containsObject:audio]) {
                    if (self.selectedAudios.count > 1) [self.selectedAudios removeObject:audio];
                } else {
                    [self.selectedAudios addObject:audio];
                }
            } else {
                [self.selectedAudios removeAllObjects];
                [self.selectedAudios addObject:self.audioRows[indexPath.row]];
            }
            break;
        case YMDownloadSheetSectionCaptions: {
            YMCaptionTrack *t = self.captions[indexPath.row];
            if ([self.selectedCaptions containsObject:t]) {
                [self.selectedCaptions removeObject:t];
            } else {
                [self.selectedCaptions addObject:t];
            }
            break;
        }
        default:
            break;
    }
    [tableView reloadData];
    [self refreshChrome];
}

- (void)startDownload {
    YMFormat *video = self.selectedVideo;
    NSArray<YMFormat *> *audioTracks = [self.selectedAudios copy];
    NSArray<YMCaptionTrack *> *captions = [self.selectedCaptions copy];
    NSString *title = self.videoTitle;
    if (self.videoID.length > 0) title = [NSString stringWithFormat:@"%@ [%@]", title, self.videoID];
    UIViewController *presenter = self.presentingViewController;
    if (self.destination != YMDownloadDestinationFiles && !video) {
        YouModSendError(LOC(@"NO_VID_AUDIO_STREAM_FOUND"));
        return;
    }
    [self dismissViewControllerAnimated:YES completion:^{
        YMDownloadStart(video, audioTracks, captions, title, self.destination, self.thumbnailURL, presenter);
    }];
}

@end

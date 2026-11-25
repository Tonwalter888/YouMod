// Download queue: runs saved downloads one after another. Each job resolves its
// own player response (PlayerResolver.x), so videos don't have to be playing.

#import "Headers.h"

static NSString *YMQLoc(NSString *key, NSString *fallback) {
    NSString *s = LOC(key);
    return (s.length == 0 || [s isEqualToString:key]) ? fallback : s;
}

static NSString * const kYMQueueChanged = @"YMDownloadQueueChanged";
static NSString * const kYMQueuePrefKey = @"YMDownloadQueueLastPreference";
// A failed download is restarted from the beginning this many times before the row shows the error.
static const int kYMQueueAutoRetries = 2;

typedef NS_ENUM(NSInteger, YMQueueState) { YMQueueStateQueued, YMQueueStateRunning, YMQueueStateDone, YMQueueStateFailed };

@interface YMQueueJob : NSObject
@property (nonatomic, copy) NSString *videoID, *title, *channel, *error;
@property (nonatomic, strong) NSURL *thumbnailURL;
@property (nonatomic, assign) YMDownloadDestination destination;
@property (nonatomic, assign) BOOL isShorts;
@property (nonatomic, copy) NSDictionary *preference;   // height, vcodec, acodec, audioOnly
@property (nonatomic, copy) NSArray<NSString *> *audioKeys;          // "itag|xtags" of the chosen soundtracks (empty = pick by preference)
@property (nonatomic, copy) NSDictionary *capture;                     // the playing video's SABR request when queued (body, headers)
@property (nonatomic, copy) NSArray<YMCaptionTrack *> *captions;      // chosen subtitle tracks, muxed in after the download
@property (nonatomic, assign) YMQueueState state;
@property (nonatomic, assign) float progress;
@property (nonatomic, assign) int autoRetries;          // automatic restarts used after a failed download
@property (nonatomic, copy) NSString *stage;            // "Preparing…" / "Downloading"
@end
@implementation YMQueueJob @end

#pragma mark - Preference

NSDictionary *YMDownloadQueuePreference(YMFormat *video, YMFormat *audio, BOOL audioOnly) {
    NSDictionary *pref = @{@"height": @(video.height), @"vcodec": video.codec ?: @"", @"acodec": audio.codec ?: @"", @"audioOnly": @(audioOnly)};
    [[NSUserDefaults standardUserDefaults] setObject:pref forKey:kYMQueuePrefKey];
    return pref;
}

static NSDictionary *YMDefaultPreference(void) {
    NSDictionary *saved = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kYMQueuePrefKey];
    return saved ?: @{@"height": @1080, @"vcodec": @"avc1", @"acodec": @"mp4a", @"audioOnly": @NO};
}

// Best video for the preference: same codec (else any), tallest not above the
// wanted height (else the smallest above it).
static YMFormat *YMPickVideo(NSArray<YMFormat *> *formats, NSDictionary *pref) {
    NSString *codec = pref[@"vcodec"];
    int want = [(NSNumber *)pref[@"height"] intValue] ?: 1080;
    NSArray<YMFormat *> *rows = codec.length ? YMVideoFormatsForCodec(formats, codec) : @[];
    if (rows.count == 0) {
        NSString *any = YMVideoCodecsInFormats(formats).firstObject;
        rows = any ? YMVideoFormatsForCodec(formats, any) : @[];
    }
    YMFormat *best = nil;   // rows are sorted tallest first
    for (YMFormat *f in rows) if (f.height <= want) { best = f; break; }
    return best ?: rows.lastObject;
}

static NSString *YMAudioKey(YMFormat *f) { return [NSString stringWithFormat:@"%d|%@", f.itag, f.xtags ?: @""]; }

static YMFormat *YMPickAudio(NSArray<YMFormat *> *formats, NSDictionary *pref) {
    NSString *codec = pref[@"acodec"];
    NSArray<YMFormat *> *tracks = codec.length ? YMAudioTracksForCodec(formats, codec) : @[];
    if (tracks.count == 0) tracks = YMAudioTracksInFormats(formats);
    return tracks.firstObject;   // original soundtrack sorts first
}

static NSURL *YMBestThumbnail(id playerData) {
    id details = nil; @try { details = [playerData valueForKey:@"videoDetails"]; } @catch (id ex) {}
    NSArray *thumbs = nil; @try { thumbs = [[details valueForKey:@"thumbnail"] valueForKey:@"thumbnailsArray"]; } @catch (id ex) {}
    NSString *best = nil; NSUInteger maxPx = 0;
    for (id t in thumbs) {
        NSUInteger px = 0; NSString *u = nil;
        @try { px = (NSUInteger)[[t valueForKey:@"width"] unsignedIntegerValue] * (NSUInteger)[[t valueForKey:@"height"] unsignedIntegerValue]; u = [t valueForKey:@"URL"]; } @catch (id ex) {}
        if (u && px >= maxPx) { maxPx = px; best = u; }
    }
    return best ? [NSURL URLWithString:best] : nil;
}

#pragma mark - Manager

@interface YMDownloadQueueManager : NSObject
@property (nonatomic, strong, readonly) NSMutableArray<YMQueueJob *> *jobs;
@property (nonatomic, assign) BOOL paused;
@property (nonatomic, strong) YMQueueJob *running;
+ (instancetype)shared;
- (void)addJob:(YMQueueJob *)job;
- (void)removeJob:(YMQueueJob *)job;
- (void)retryJob:(YMQueueJob *)job;
- (void)clearFinished;
- (void)setPaused:(BOOL)paused;
@end

@implementation YMDownloadQueueManager

+ (instancetype)shared {
    static YMDownloadQueueManager *m; static dispatch_once_t once;
    dispatch_once(&once, ^{ m = [YMDownloadQueueManager new]; m->_jobs = [NSMutableArray array]; });
    return m;
}

- (void)changed { [[NSNotificationCenter defaultCenter] postNotificationName:kYMQueueChanged object:nil]; }

- (void)addJob:(YMQueueJob *)job {
    for (YMQueueJob *j in self.jobs)
        if ([j.videoID isEqualToString:job.videoID] && (j.state == YMQueueStateQueued || j.state == YMQueueStateRunning)) { return; } // already waiting
    [self.jobs addObject:job];
    [self changed];
    [self pump];
}

- (void)removeJob:(YMQueueJob *)job {
    if (job == self.running) [YMSABR cancelCurrent];   // finish handler clears `running`
    [self.jobs removeObject:job];
    [self changed];
}

- (void)retryJob:(YMQueueJob *)job {
    if (job.state != YMQueueStateFailed) return;
    job.state = YMQueueStateQueued; job.error = nil; job.progress = 0; job.autoRetries = 0;
    [self changed]; [self pump];
}

- (void)clearFinished {
    NSIndexSet *idx = [self.jobs indexesOfObjectsPassingTest:^BOOL(YMQueueJob *j, NSUInteger i, BOOL *stop) { return j.state == YMQueueStateDone; }];
    [self.jobs removeObjectsAtIndexes:idx];
    [self changed];
}

- (void)setPaused:(BOOL)paused {
    _paused = paused;
    [self changed];
    if (!paused) [self pump];
}

- (void)finishJob:(YMQueueJob *)job success:(BOOL)ok error:(NSString *)err {
    [YMSABR useResolvedResponse:nil capture:nil];
    if (self.running == job) self.running = nil;
    job.state = ok ? YMQueueStateDone : YMQueueStateFailed;
    job.error = ok ? nil : err; job.progress = ok ? 1 : job.progress;
    [self changed];
    [self pump];
}

- (void)pump {
    if (self.paused || self.running) return;
    YMQueueJob *job = nil;
    for (YMQueueJob *j in self.jobs) if (j.state == YMQueueStateQueued) { job = j; break; }
    if (!job) {
        if (!self.running) [YMDownloadProgressView setUserHidden:NO];   // queue finished: show progress again next time
        return;
    }
    if (YMDownloadIsBusy()) {   // a manual download is running; try again shortly
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ [self pump]; });
        return;
    }
    self.running = job; job.state = YMQueueStateRunning; job.progress = 0;
    job.stage = YMQLoc(@"QUEUE_PREPARING", @"Preparing…");
    [self changed];

    if (![YMPlayerResolver templateReady]) {
        [self finishJob:job success:NO error:YMQLoc(@"QUEUE_NEED_PLAYBACK", @"Play any video once, then retry")];
        return;
    }
    [YMPlayerResolver resolveVideoID:job.videoID completion:^(id response, NSError *error) {
        if (self.running != job) return;   // removed while resolving
        if (!response) { [self finishJob:job success:NO error:error.localizedDescription ?: @"Could not load video"]; return; }
        [self startJob:job response:response];
    }];
}

- (void)startJob:(YMQueueJob *)job response:(id)response {
    id playerData = [response respondsToSelector:@selector(playerData)] ? [response playerData] : response;
    @try {
        id details = [playerData valueForKey:@"videoDetails"];
        NSString *t = [details valueForKey:@"title"], *a = [details valueForKey:@"author"];
        if ([t isKindOfClass:NSString.class] && t.length) job.title = t;
        if ([a isKindOfClass:NSString.class] && a.length) job.channel = a;
        id live = [details valueForKey:@"isLive"];
        if ([live respondsToSelector:@selector(boolValue)] && [live boolValue]) { [self finishJob:job success:NO error:YMQLoc(@"QUEUE_LIVE", @"Live streams can't be downloaded")]; return; }
    } @catch (id ex) {}
    if (!job.thumbnailURL) job.thumbnailURL = YMBestThumbnail(playerData);

    NSArray<YMFormat *> *formats = YMFormatsFromResponse(response);
    if (job.destination == YMDownloadDestinationPhotos) formats = YMPhotosCompatibleFormats(formats);
    BOOL audioOnly = [(NSNumber *)job.preference[@"audioOnly"] boolValue];
    YMFormat *video = audioOnly ? nil : YMPickVideo(formats, job.preference);
    YMFormat *audio = YMPickAudio(formats, job.preference);
    // The soundtracks picked in the sheet, matched against this response's formats.
    NSMutableArray<YMFormat *> *audios = [NSMutableArray array];
    for (NSString *key in job.audioKeys) {
        for (YMFormat *f in formats) {
            if (f.isAudio && [YMAudioKey(f) isEqualToString:key] && ![audios containsObject:f]) { [audios addObject:f]; break; }
        }
    }
    if (audios.count == 0 && audio) [audios addObject:audio];
    if (!audio || (!audioOnly && !video && job.destination != YMDownloadDestinationFiles)) {
        [self finishJob:job success:NO error:YMQLoc(@"QUEUE_NO_FORMATS", @"No downloadable formats")];
        return;
    }
    NSString *fileName = job.title.length ? [NSString stringWithFormat:@"%@ [%@]", job.title, job.videoID] : job.videoID;
    job.stage = YMQLoc(@"QUEUE_DOWNLOADING", @"Downloading");
    [self changed];

    [YMSABR useResolvedResponse:response capture:job.capture];
    __weak YMQueueJob *weakJob = job;
    YMDownloadSetHandlers(^(float f) {
        YMQueueJob *j = weakJob; if (!j) return;
        j.progress = f; [self changed];
    }, ^(BOOL ok, NSString *err) {
        YMQueueJob *j = weakJob; if (!j) return;
        BOOL cancelled = [err isEqualToString:LOC(@"DOWNLOAD_CANCELLED")] || [err isEqualToString:@"cancelled"];
        if (!ok && !cancelled && j.autoRetries < kYMQueueAutoRetries && [self.jobs containsObject:j]) {
            // Same as tapping retry: resolve again and start over.
            j.autoRetries++;
            [YMPlayerResolver appendLog:[NSString stringWithFormat:@"queue: %@ failed (%@), automatic retry %d/%d", j.videoID, err, j.autoRetries, kYMQueueAutoRetries]];
            YouModSendError([NSString stringWithFormat:@"Retrying %d/%d: %@", j.autoRetries, kYMQueueAutoRetries, err]);   // debug
            [YMSABR useResolvedResponse:nil capture:nil];
            if (self.running == j) self.running = nil;
            j.state = YMQueueStateQueued; j.progress = 0;
            [self changed];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{ [self pump]; });
            return;
        }
        YMDownloadSetQuietFailure(NO);
        [self finishJob:j success:ok error:err];
    });
    YMDownloadSetQuietFailure(job.autoRetries < kYMQueueAutoRetries);
    UIViewController *presenter = [YMHelpers topViewController:nil];
    YMDownloadStart(video, audios, job.captions ?: @[], fileName, job.destination, job.thumbnailURL, job.isShorts, presenter);
}

@end

void YMDownloadQueueAdd(NSString *videoID, NSString *title, NSString *channel, NSURL *thumbnailURL,
                        YMDownloadDestination destination, BOOL isShorts, NSDictionary *preference,
                        NSArray<YMFormat *> *audios, NSArray<YMCaptionTrack *> *captions, BOOL fromPlayer) {
    if (videoID.length == 0) return;
    YMQueueJob *job = [YMQueueJob new];
    job.videoID = videoID; job.title = title.length ? title : videoID; job.channel = channel;
    job.thumbnailURL = thumbnailURL; job.destination = destination; job.isShorts = isShorts;
    job.preference = preference ?: YMDefaultPreference();
    NSMutableArray<NSString *> *keys = [NSMutableArray array];
    for (YMFormat *a in audios) [keys addObject:YMAudioKey(a)];
    job.audioKeys = keys; job.captions = captions;
    void (^add)(void) = ^{
        // Only say "added" when the job has to wait; one that starts now shows its progress pill.
        YMDownloadQueueManager *m = [YMDownloadQueueManager shared];
        BOOL waits = m.paused || m.running || YMDownloadIsBusy();
        for (YMQueueJob *j in m.jobs) if (j.state == YMQueueStateQueued) waits = YES;
        [m addJob:job];
        if (waits) YouModSendSuccess(YMQLoc(@"QUEUE_ADDED", @"Added to download queue"));
    };
    if (!fromPlayer) { add(); return; }
    [YMSABR currentCapture:^(NSDictionary *capture) { job.capture = capture; add(); }];
}

NSUInteger YMDownloadQueueCount(void) {
    NSUInteger n = 0;
    for (YMQueueJob *j in [YMDownloadQueueManager shared].jobs) if (j.state == YMQueueStateQueued || j.state == YMQueueStateRunning) n++;
    return n;
}

#pragma mark - Video ID parsing

static NSString *YMVideoIDFromText(NSString *text) {
    text = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSRegularExpression *url = [NSRegularExpression regularExpressionWithPattern:@"(?:[?&]v=|youtu\\.be/|/shorts/|/embed/|/live/)([A-Za-z0-9_-]{11})" options:0 error:nil];
    NSTextCheckingResult *m = [url firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    if (m) return [text substringWithRange:[m rangeAtIndex:1]];
    NSRegularExpression *bare = [NSRegularExpression regularExpressionWithPattern:@"^[A-Za-z0-9_-]{11}$" options:0 error:nil];
    return [bare firstMatchInString:text options:0 range:NSMakeRange(0, text.length)] ? text : nil;
}

#pragma mark - UI

static UIImage *YMQSymbol(NSString *name, UIColor *color) {
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular];
    return [[UIImage systemImageNamed:name withConfiguration:cfg] imageWithTintColor:color renderingMode:UIImageRenderingModeAlwaysOriginal];
}

// Small thumbnails, cached for the life of the app.
static void YMQLoadThumbnail(NSString *videoID, void (^completion)(UIImage *image)) {
    static NSCache<NSString *, UIImage *> *cache; static dispatch_once_t once;
    dispatch_once(&once, ^{ cache = [NSCache new]; });
    UIImage *hit = [cache objectForKey:videoID];
    if (hit) { completion(hit); return; }
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://i.ytimg.com/vi/%@/mqdefault.jpg", videoID]];
    [[NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *r, NSError *e) {
        UIImage *img = data ? [UIImage imageWithData:data] : nil;
        if (img) [cache setObject:img forKey:videoID];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(img); });
    }] resume];
}

@interface YMQueueCell : UITableViewCell
@property (nonatomic, strong) UIImageView *thumb, *stateIcon;
@property (nonatomic, strong) UILabel *titleLabel, *statusLabel;
@property (nonatomic, strong) UIProgressView *bar;
@property (nonatomic, copy) NSString *videoID;
@end

@implementation YMQueueCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    if (!(self = [super initWithStyle:style reuseIdentifier:rid])) return nil;
    _thumb = [UIImageView new];
    _thumb.contentMode = UIViewContentModeScaleAspectFill;
    _thumb.clipsToBounds = YES;
    _thumb.layer.cornerRadius = 6;
    _thumb.backgroundColor = UIColor.tertiarySystemFillColor;
    _titleLabel = [UILabel new];
    _titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    _titleLabel.numberOfLines = 2;
    _statusLabel = [UILabel new];
    _statusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    _statusLabel.numberOfLines = 2;
    _bar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    _stateIcon = [UIImageView new];
    _stateIcon.contentMode = UIViewContentModeCenter;
    [_stateIcon setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[_titleLabel, _statusLabel, _bar]];
    text.axis = UILayoutConstraintAxisVertical;
    text.spacing = 4;
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[_thumb, text, _stateIcon]];
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 12;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:row];
    UILayoutGuide *m = self.contentView.layoutMarginsGuide;
    [NSLayoutConstraint activateConstraints:@[
        [row.leadingAnchor constraintEqualToAnchor:m.leadingAnchor],
        [row.trailingAnchor constraintEqualToAnchor:m.trailingAnchor],
        [row.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
        [row.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10],
        [_thumb.widthAnchor constraintEqualToConstant:96],
        [_thumb.heightAnchor constraintEqualToConstant:54],
        [_stateIcon.widthAnchor constraintEqualToConstant:24],
    ]];
    return self;
}

- (void)configureWithJob:(YMQueueJob *)j paused:(BOOL)paused {
    if (![self.videoID isEqualToString:j.videoID]) {
        self.videoID = j.videoID;
        self.thumb.image = nil;
        NSString *vid = j.videoID;
        YMQLoadThumbnail(vid, ^(UIImage *img) { if ([self.videoID isEqualToString:vid]) self.thumb.image = img; });
    }
    self.titleLabel.text = j.title.length ? j.title : j.videoID;
    NSString *status, *icon = nil; UIColor *color = UIColor.secondaryLabelColor, *iconColor = UIColor.secondaryLabelColor;
    switch (j.state) {
        case YMQueueStateQueued:
            status = paused ? YMQLoc(@"QUEUE_PAUSED", @"Paused") : YMQLoc(@"QUEUE_WAITING", @"Waiting");
            icon = paused ? @"pause.circle" : @"clock";
            break;
        case YMQueueStateRunning:
            status = j.progress > 0 ? [NSString stringWithFormat:@"%@ (%.0f%%)", j.stage, j.progress * 100] : j.stage;
            if (j.progress > 0 && YMDownloadRemainingString()) status = [NSString stringWithFormat:@"%@ · %@", status, YMDownloadRemainingString()];
            break;
        case YMQueueStateDone:
            status = YMQLoc(@"QUEUE_DONE", @"Done");
            icon = @"checkmark.circle.fill"; iconColor = UIColor.systemGreenColor;
            break;
        default:
            status = [NSString stringWithFormat:@"%@: %@", YMQLoc(@"QUEUE_FAILED", @"Failed"), j.error ?: @""];
            color = UIColor.systemRedColor;
            icon = @"arrow.clockwise.circle"; iconColor = UIColor.systemRedColor;
            break;
    }
    self.statusLabel.text = status;
    self.statusLabel.textColor = color;
    self.stateIcon.image = icon ? YMQSymbol(icon, iconColor) : nil;
    self.stateIcon.hidden = icon == nil;   // collapses in the stack view
    self.bar.hidden = j.state != YMQueueStateRunning;
    self.bar.progress = j.progress;
}
@end

@interface YMDownloadQueueViewController : UITableViewController
@end

@implementation YMDownloadQueueViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = YMQLoc(@"DOWNLOAD_QUEUE", @"Download queue");
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 76;
    [self.tableView registerClass:YMQueueCell.class forCellReuseIdentifier:@"job"];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(close)];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refresh) name:kYMQueueChanged object:nil];
    [self refresh];
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)refresh {
    YMDownloadQueueManager *m = [YMDownloadQueueManager shared];
    BOOL anyDone = NO;
    for (YMQueueJob *j in m.jobs) if (j.state == YMQueueStateDone) { anyDone = YES; break; }
    __weak typeof(self) weakSelf = self;
    UIAction *pause = [UIAction actionWithTitle:m.paused ? YMQLoc(@"QUEUE_RESUME", @"Resume") : YMQLoc(@"QUEUE_PAUSE", @"Pause")
                                          image:[UIImage systemImageNamed:m.paused ? @"play" : @"pause"] identifier:nil
                                        handler:^(UIAction *a) { [weakSelf togglePause]; }];
    UIAction *clear = [UIAction actionWithTitle:YMQLoc(@"QUEUE_CLEAR_DONE", @"Clear done")
                                          image:[UIImage systemImageNamed:@"checkmark.circle"] identifier:nil
                                        handler:^(UIAction *a) { [[YMDownloadQueueManager shared] clearFinished]; }];
    if (!anyDone) clear.attributes = UIMenuElementAttributesDisabled;
    UIBarButtonItem *more = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis.circle"] menu:[UIMenu menuWithChildren:@[pause, clear]]];
    UIBarButtonItem *add = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addTapped)];
    self.navigationItem.rightBarButtonItems = @[more, add];
    [self.tableView reloadData];
}

- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)togglePause { YMDownloadQueueManager *m = [YMDownloadQueueManager shared]; [m setPaused:!m.paused]; }

- (void)addTapped {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:YMQLoc(@"QUEUE_ADD_URL", @"Add video")
                                                              message:YMQLoc(@"QUEUE_ADD_URL_PROMPT", @"Paste a YouTube link or video ID")
                                                       preferredStyle:UIAlertControllerStyleAlert];
    [a addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        NSString *clip = UIPasteboard.generalPasteboard.string;
        if (clip.length && YMVideoIDFromText(clip)) tf.text = clip;
        tf.placeholder = @"https://youtu.be/…";
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
        tf.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }];
    [a addAction:[UIAlertAction actionWithTitle:YMQLoc(@"CANCEL", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [a addAction:[UIAlertAction actionWithTitle:YMQLoc(@"QUEUE_ADD", @"Add") style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
        NSString *vid = YMVideoIDFromText(a.textFields.firstObject.text ?: @"");
        if (!vid) { YouModSendError(YMQLoc(@"QUEUE_INVALID_URL", @"Not a YouTube link or video ID")); return; }
        NSString *text = a.textFields.firstObject.text ?: @"";
        YMDownloadQueueAdd(vid, nil, nil, nil, YMDownloadDestinationFiles, [text containsString:@"/shorts/"], nil, nil, nil, NO);
    }]];
    [self presentViewController:a animated:YES completion:nil];
}

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    NSInteger n = [YMDownloadQueueManager shared].jobs.count;
    if (n == 0) {
        UIListContentConfiguration *c = [UIListContentConfiguration cellConfiguration];
        UILabel *l = [UILabel new];
        l.text = YMQLoc(@"QUEUE_EMPTY", @"The queue is empty");
        l.textColor = UIColor.secondaryLabelColor;
        l.textAlignment = NSTextAlignmentCenter;
        l.font = c.textProperties.font;
        tv.backgroundView = l;
    } else tv.backgroundView = nil;
    return n;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    YMQueueCell *cell = [tv dequeueReusableCellWithIdentifier:@"job" forIndexPath:ip];
    YMDownloadQueueManager *m = [YMDownloadQueueManager shared];
    [cell configureWithJob:m.jobs[ip.row] paused:m.paused];
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    YMQueueJob *job = [YMDownloadQueueManager shared].jobs[ip.row];
    if (job.state != YMQueueStateFailed) return;
    if (job.error.length) UIPasteboard.generalPasteboard.string = [NSString stringWithFormat:@"%@\n\n%@", job.error, [YMPlayerResolver recentLog]];   // full text, the row truncates it
    [[YMDownloadQueueManager shared] retryJob:job];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tv trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)ip {
    YMQueueJob *job = [YMDownloadQueueManager shared].jobs[ip.row];
    UIContextualAction *remove = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:nil
                                                                      handler:^(UIContextualAction *a, UIView *v, void (^done)(BOOL)) {
        [[YMDownloadQueueManager shared] removeJob:job]; done(YES);
    }];
    remove.image = [UIImage systemImageNamed:@"trash"];
    return [UISwipeActionsConfiguration configurationWithActions:@[remove]];
}

@end

void YMDownloadQueuePresent(UIViewController *presenter) {
    YMDownloadQueueViewController *vc = [[YMDownloadQueueViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    [presenter presentViewController:nav animated:YES completion:nil];
}

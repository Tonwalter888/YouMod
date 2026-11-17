// DownloadComments.x — watch page for downloaded videos with YouTube-style comments.
//
// Comments come from YouTube's InnerTube `next` endpoint (WEB client, signed out,
// read-only): the watch response carries the comment-section continuation token,
// each continuation page lists commentThreadRenderer / commentViewModel items whose
// `commentKey` points at a commentEntityPayload in frameworkUpdates.
//
// Online: first page on open, "Top"/"Newest" sorting, infinite scroll, inline
// replies. Offline: a snapshot of the first ~100 top comments is stored next to
// each download (.meta/<file>.comments.json) and shown when the network fails.

#import "Headers.h"
#import <AVKit/AVKit.h>

static NSString *YMC(NSString *de, NSString *en) {
    NSString *lang = NSLocale.preferredLanguages.firstObject ?: @"en";
    return [lang hasPrefix:@"de"] ? de : en;
}

#pragma mark - InnerTube

static NSDictionary *YMCContext(void) {
    NSString *lang = [[NSLocale.preferredLanguages.firstObject ?: @"en" componentsSeparatedByString:@"-"].firstObject lowercaseString];
    NSString *region = [NSLocale.currentLocale objectForKey:NSLocaleCountryCode] ?: @"US";
    return @{@"client": @{@"clientName": @"WEB", @"clientVersion": @"2.20261101.00.00", @"hl": lang, @"gl": region}};
}

static NSURLSession *YMCSession(void) {
    static NSURLSession *s; static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        cfg.timeoutIntervalForRequest = 20;
        s = [NSURLSession sessionWithConfiguration:cfg];
    });
    return s;
}

static void YMCPost(NSDictionary *body, void (^completion)(NSDictionary *json, NSError *err)) {
    NSMutableDictionary *payload = [body mutableCopy];
    payload[@"context"] = YMCContext();
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://www.youtube.com/youtubei/v1/next?prettyPrint=false"]];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1" forHTTPHeaderField:@"User-Agent"];
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    [[YMCSession() dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        NSDictionary *json = nil;
        if (data.length) {
            id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([obj isKindOfClass:NSDictionary.class]) json = obj;
        }
        NSInteger status = [resp isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)resp).statusCode : 0;
        if (!err && (!json || status != 200))
            err = [NSError errorWithDomain:@"YouModComments" code:status userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP %ld", (long)status]}];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(err ? nil : json, err); });
    }] resume];
}

// Safe nested lookup: YMCGet(obj, @[@"a", @"b"]).
static id YMCGet(id obj, NSArray *path) {
    for (id key in path) {
        if ([key isKindOfClass:NSString.class]) obj = [obj isKindOfClass:NSDictionary.class] ? obj[key] : nil;
        else if ([key isKindOfClass:NSNumber.class]) obj = ([obj isKindOfClass:NSArray.class] && [key unsignedIntegerValue] < [obj count]) ? obj[[key unsignedIntegerValue]] : nil;
        if (!obj) return nil;
    }
    return obj;
}

static NSString *YMCRunsText(id textObj) {
    if ([textObj isKindOfClass:NSString.class]) return textObj;
    NSString *simple = YMCGet(textObj, @[@"simpleText"]);
    if (simple) return simple;
    NSMutableString *s = [NSMutableString string];
    for (NSDictionary *run in YMCGet(textObj, @[@"runs"])) if ([run[@"text"] isKindOfClass:NSString.class]) [s appendString:run[@"text"]];
    return s.length ? s : nil;
}

static NSString *YMCContinuationToken(NSDictionary *continuationItemRenderer) {
    return YMCGet(continuationItemRenderer, @[@"continuationEndpoint", @"continuationCommand", @"token"])
        ?: YMCGet(continuationItemRenderer, @[@"button", @"buttonRenderer", @"command", @"continuationCommand", @"token"]);
}

#pragma mark - Model

@interface YMComment : NSObject
@property (nonatomic, copy) NSString *author, *avatarURL, *text, *published, *likes, *pinnedText, *creatorAvatarURL;
@property (nonatomic, assign) NSInteger replyCount;
@property (nonatomic, assign) BOOL isCreator, isVerified, hearted, isReply, expandedText;
@property (nonatomic, copy) NSString *repliesToken;      // first replies page (threads only)
// thread state
@property (nonatomic, strong) NSMutableArray<YMComment *> *replies;
@property (nonatomic, copy) NSString *moreRepliesToken;
@property (nonatomic, assign) BOOL repliesExpanded, loadingReplies;
@end
@implementation YMComment
- (NSDictionary *)dictionary {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    if (self.author) d[@"author"] = self.author;
    if (self.avatarURL) d[@"avatar"] = self.avatarURL;
    if (self.text) d[@"text"] = self.text;
    if (self.published) d[@"published"] = self.published;
    if (self.likes) d[@"likes"] = self.likes;
    if (self.pinnedText) d[@"pinned"] = self.pinnedText;
    d[@"replyCount"] = @(self.replyCount);
    d[@"creator"] = @(self.isCreator);
    d[@"verified"] = @(self.isVerified);
    d[@"hearted"] = @(self.hearted);
    return d;
}
+ (instancetype)commentWithDictionary:(NSDictionary *)d {
    YMComment *c = [YMComment new];
    c.author = d[@"author"]; c.avatarURL = d[@"avatar"]; c.text = d[@"text"]; c.published = d[@"published"];
    c.likes = d[@"likes"]; c.pinnedText = d[@"pinned"]; c.replyCount = [d[@"replyCount"] integerValue];
    c.isCreator = [d[@"creator"] boolValue]; c.isVerified = [d[@"verified"] boolValue]; c.hearted = [d[@"hearted"] boolValue];
    return c;
}
@end

@interface YMCommentPage : NSObject
@property (nonatomic, strong) NSArray<YMComment *> *comments;
@property (nonatomic, copy) NSString *nextToken;
@property (nonatomic, copy) NSString *countText;
@property (nonatomic, strong) NSArray<NSDictionary *> *sortOptions; // [{title, token}]
@end
@implementation YMCommentPage @end

static YMCommentPage *YMCParsePage(NSDictionary *json) {
    NSMutableDictionary *entities = [NSMutableDictionary dictionary];
    NSMutableDictionary *hearts = [NSMutableDictionary dictionary];
    for (NSDictionary *m in YMCGet(json, @[@"frameworkUpdates", @"entityBatchUpdate", @"mutations"])) {
        NSDictionary *payload = m[@"payload"];
        if (![m[@"entityKey"] isKindOfClass:NSString.class] || ![payload isKindOfClass:NSDictionary.class]) continue;
        if (payload[@"commentEntityPayload"]) entities[m[@"entityKey"]] = payload[@"commentEntityPayload"];
        NSString *heart = YMCGet(payload, @[@"engagementToolbarStateEntityPayload", @"heartState"]);
        if (heart) hearts[m[@"entityKey"]] = heart;
    }

    YMComment *(^makeComment)(NSDictionary *, BOOL) = ^YMComment *(NSDictionary *vm, BOOL isReply) {
        NSDictionary *e = entities[vm[@"commentKey"] ?: @""];
        if (!e) return nil;
        YMComment *c = [YMComment new];
        c.isReply = isReply;
        c.author = YMCGet(e, @[@"author", @"displayName"]);
        c.avatarURL = YMCGet(e, @[@"author", @"avatarThumbnailUrl"]);
        c.isCreator = [YMCGet(e, @[@"author", @"isCreator"]) boolValue];
        c.isVerified = [YMCGet(e, @[@"author", @"isVerified"]) boolValue];
        c.text = YMCGet(e, @[@"properties", @"content", @"content"]);
        c.published = YMCGet(e, @[@"properties", @"publishedTime"]);
        c.likes = YMCGet(e, @[@"toolbar", @"likeCountNotliked"]);
        c.replyCount = [YMCGet(e, @[@"toolbar", @"replyCount"]) integerValue];
        c.creatorAvatarURL = YMCGet(e, @[@"toolbar", @"creatorThumbnailUrl"]);
        c.pinnedText = vm[@"pinnedText"];
        NSString *heart = hearts[vm[@"toolbarStateKey"] ?: @""];
        c.hearted = [heart isKindOfClass:NSString.class] && [heart hasSuffix:@"_HEARTED"];
        return c;
    };

    YMCommentPage *page = [YMCommentPage new];
    NSMutableArray *comments = [NSMutableArray array];
    for (NSDictionary *endpoint in YMCGet(json, @[@"onResponseReceivedEndpoints"])) {
        if (![endpoint isKindOfClass:NSDictionary.class]) continue;
        for (NSString *key in endpoint) {
            NSArray *items = YMCGet(endpoint, @[key, @"continuationItems"]);
            if (![items isKindOfClass:NSArray.class]) continue;
            for (NSDictionary *item in items) {
                if (item[@"commentsHeaderRenderer"]) {
                    NSDictionary *h = item[@"commentsHeaderRenderer"];
                    page.countText = [YMCRunsText(h[@"countText"]) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
                    NSMutableArray *sorts = [NSMutableArray array];
                    for (NSDictionary *sub in YMCGet(h, @[@"sortMenu", @"sortFilterSubMenuRenderer", @"subMenuItems"])) {
                        NSString *tok = YMCGet(sub, @[@"serviceEndpoint", @"continuationCommand", @"token"]);
                        if (tok && sub[@"title"]) [sorts addObject:@{@"title": sub[@"title"], @"token": tok}];
                    }
                    page.sortOptions = sorts;
                } else if (item[@"commentThreadRenderer"]) {
                    NSDictionary *t = item[@"commentThreadRenderer"];
                    YMComment *c = makeComment(YMCGet(t, @[@"commentViewModel", @"commentViewModel"]), NO);
                    if (!c) continue;
                    for (NSDictionary *r in YMCGet(t, @[@"replies", @"commentRepliesRenderer", @"contents"])) {
                        NSString *tok = YMCContinuationToken(r[@"continuationItemRenderer"]);
                        if (tok) { c.repliesToken = tok; break; }
                    }
                    [comments addObject:c];
                } else if (item[@"commentViewModel"]) {
                    YMComment *c = makeComment(item[@"commentViewModel"], YES);
                    if (c) [comments addObject:c];
                } else if (item[@"continuationItemRenderer"]) {
                    page.nextToken = YMCContinuationToken(item[@"continuationItemRenderer"]);
                }
            }
        }
    }
    page.comments = comments;
    return page;
}

// Watch response -> continuation token of the comment section (nil if comments are off).
static NSString *YMCCommentSectionToken(NSDictionary *watch) {
    for (NSDictionary *c in YMCGet(watch, @[@"contents", @"twoColumnWatchNextResults", @"results", @"results", @"contents"])) {
        NSDictionary *section = c[@"itemSectionRenderer"];
        if (!section) continue;
        for (NSDictionary *inner in section[@"contents"]) {
            NSString *tok = YMCContinuationToken(inner[@"continuationItemRenderer"]);
            if (tok) return tok;
        }
    }
    return nil;
}

static void YMCFetchFirstPage(NSString *videoId, void (^completion)(YMCommentPage *page, NSError *err)) {
    YMCPost(@{@"videoId": videoId}, ^(NSDictionary *watch, NSError *err) {
        if (err) { completion(nil, err); return; }
        NSString *tok = YMCCommentSectionToken(watch);
        if (!tok) { completion([YMCommentPage new], nil); return; } // comments disabled
        YMCPost(@{@"continuation": tok}, ^(NSDictionary *json, NSError *err2) {
            completion(err2 ? nil : YMCParsePage(json), err2);
        });
    });
}

static void YMCFetchPage(NSString *token, void (^completion)(YMCommentPage *page, NSError *err)) {
    YMCPost(@{@"continuation": token}, ^(NSDictionary *json, NSError *err) {
        completion(err ? nil : YMCParsePage(json), err);
    });
}

#pragma mark - Offline snapshot

void YMCommentsSaveSnapshot(NSString *videoId, NSURL *snapshotURL) {
    if (!videoId.length || !snapshotURL) return;
    NSMutableArray *all = [NSMutableArray array];
    __block NSString *count = nil;
    __block void (^next)(NSString *, int);
    void (^finish)(void) = ^{
        if (!all.count && !count) return;
        NSMutableDictionary *snap = [NSMutableDictionary dictionary];
        snap[@"fetchedAt"] = @([NSDate date].timeIntervalSince1970);
        if (count) snap[@"count"] = count;
        snap[@"comments"] = all;
        [[NSJSONSerialization dataWithJSONObject:snap options:0 error:nil] writeToURL:snapshotURL atomically:YES];
    };
    void (^handle)(YMCommentPage *, NSError *, int) = ^(YMCommentPage *page, NSError *err, int pageNo) {
        if (err || !page) { finish(); next = nil; return; }
        if (page.countText) count = page.countText;
        for (YMComment *c in page.comments) [all addObject:[c dictionary]];
        if (page.nextToken && all.count < 100 && pageNo < 6) next(page.nextToken, pageNo + 1);
        else { finish(); next = nil; }
    };
    next = ^(NSString *token, int pageNo) {
        YMCFetchPage(token, ^(YMCommentPage *p, NSError *e) { handle(p, e, pageNo); });
    };
    YMCFetchFirstPage(videoId, ^(YMCommentPage *p, NSError *e) { handle(p, e, 1); });
}

static NSDictionary *YMCLoadSnapshot(NSURL *snapshotURL) {
    NSData *data = snapshotURL ? [NSData dataWithContentsOfURL:snapshotURL] : nil;
    id obj = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    return [obj isKindOfClass:NSDictionary.class] ? obj : nil;
}

#pragma mark - Avatars

static UIImage *YMCInitialAvatar(NSString *name, CGFloat side) {
    NSString *letter = [[name stringByReplacingOccurrencesOfString:@"@" withString:@""] substringToIndex:MIN((NSUInteger)1, [name stringByReplacingOccurrencesOfString:@"@" withString:@""].length)].uppercaseString ?: @"?";
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(side, side)];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        NSUInteger hash = name.hash;
        [[UIColor colorWithHue:(hash % 360) / 360.0 saturation:0.45 brightness:0.75 alpha:1] setFill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, side, side)] fill];
        NSDictionary *attrs = @{NSFontAttributeName: [UIFont systemFontOfSize:side * 0.45 weight:UIFontWeightSemibold], NSForegroundColorAttributeName: UIColor.whiteColor};
        CGSize sz = [letter sizeWithAttributes:attrs];
        [letter drawAtPoint:CGPointMake((side - sz.width) / 2, (side - sz.height) / 2) withAttributes:attrs];
    }];
}

static NSCache *YMCAvatarCache(void) {
    static NSCache *c; static dispatch_once_t once;
    dispatch_once(&once, ^{ c = [NSCache new]; });
    return c;
}

static void YMCLoadAvatar(NSString *urlString, void (^completion)(UIImage *img)) {
    if (!urlString.length) return;
    UIImage *cached = [YMCAvatarCache() objectForKey:urlString];
    if (cached) { completion(cached); return; }
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) return;
    [[YMCSession() dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        UIImage *img = data.length ? [UIImage imageWithData:data] : nil;
        if (!img) return;
        [YMCAvatarCache() setObject:img forKey:urlString];
        dispatch_async(dispatch_get_main_queue(), ^{ completion(img); });
    }] resume];
}

#pragma mark - Comment cell

@interface YMCommentCell : UITableViewCell
@property (nonatomic, strong) UIImageView *avatar;
@property (nonatomic, strong) UILabel *pinnedLabel, *headerLabel, *bodyLabel, *footerLabel;
@property (nonatomic, strong) UIButton *repliesButton;
@property (nonatomic, strong) NSLayoutConstraint *leadingConstraint, *avatarSize;
@property (nonatomic, copy) NSString *avatarURL;
@property (nonatomic, copy) void (^onReplies)(void);
@end

@implementation YMCommentCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    self = [super initWithStyle:style reuseIdentifier:rid];
    if (!self) return nil;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    _avatar = [UIImageView new];
    _avatar.contentMode = UIViewContentModeScaleAspectFill;
    _avatar.clipsToBounds = YES;
    _avatar.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *(^label)(UIFontTextStyle, UIColor *) = ^UILabel *(UIFontTextStyle st, UIColor *color) {
        UILabel *l = [UILabel new];
        l.font = [UIFont preferredFontForTextStyle:st];
        l.textColor = color;
        l.numberOfLines = 0;
        l.translatesAutoresizingMaskIntoConstraints = NO;
        return l;
    };
    _pinnedLabel = label(UIFontTextStyleCaption2, UIColor.secondaryLabelColor);
    _headerLabel = label(UIFontTextStyleCaption1, UIColor.secondaryLabelColor);
    _bodyLabel = label(UIFontTextStyleSubheadline, UIColor.labelColor);
    _footerLabel = label(UIFontTextStyleCaption1, UIColor.secondaryLabelColor);

    _repliesButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _repliesButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    _repliesButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    _repliesButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_repliesButton addTarget:self action:@selector(ym_repliesTapped) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[_pinnedLabel, _headerLabel, _bodyLabel, _footerLabel, _repliesButton]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 3;
    stack.alignment = UIStackViewAlignmentLeading;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentView addSubview:_avatar];
    [self.contentView addSubview:stack];

    _leadingConstraint = [_avatar.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16];
    _avatarSize = [_avatar.widthAnchor constraintEqualToConstant:36];
    [NSLayoutConstraint activateConstraints:@[
        _leadingConstraint, _avatarSize,
        [_avatar.heightAnchor constraintEqualToAnchor:_avatar.widthAnchor],
        [_avatar.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:12],
        [stack.leadingAnchor constraintEqualToAnchor:_avatar.trailingAnchor constant:12],
        [stack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [stack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:10],
        [stack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-10],
        [self.contentView.bottomAnchor constraintGreaterThanOrEqualToAnchor:_avatar.bottomAnchor constant:10],
    ]];
    return self;
}
- (void)ym_repliesTapped { if (self.onReplies) self.onReplies(); }

- (void)configureWithComment:(YMComment *)c repliesTitle:(NSString *)repliesTitle {
    BOOL reply = c.isReply;
    self.leadingConstraint.constant = reply ? 64 : 16;
    self.avatarSize.constant = reply ? 26 : 36;
    self.avatar.layer.cornerRadius = (reply ? 26 : 36) / 2.0;
    self.avatar.image = YMCInitialAvatar(c.author ?: @"?", reply ? 26 : 36);
    self.avatarURL = c.avatarURL;
    __weak typeof(self) weakSelf = self;
    NSString *url = c.avatarURL;
    YMCLoadAvatar(url, ^(UIImage *img) { if ([weakSelf.avatarURL isEqualToString:url]) weakSelf.avatar.image = img; });

    self.pinnedLabel.text = c.pinnedText.length ? [@"📌 " stringByAppendingString:c.pinnedText] : nil;
    self.pinnedLabel.hidden = !c.pinnedText.length;

    NSMutableAttributedString *header = [NSMutableAttributedString new];
    NSString *name = c.author ?: @"";
    UIFont *hf = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    if (c.isCreator) {
        [header appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" %@ ", name] attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:hf.pointSize weight:UIFontWeightSemibold], NSForegroundColorAttributeName: UIColor.systemBackgroundColor, NSBackgroundColorAttributeName: UIColor.secondaryLabelColor}]];
    } else {
        [header appendAttributedString:[[NSAttributedString alloc] initWithString:name attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:hf.pointSize weight:UIFontWeightSemibold], NSForegroundColorAttributeName: UIColor.labelColor}]];
    }
    if (c.isVerified) [header appendAttributedString:[[NSAttributedString alloc] initWithString:@" ✓" attributes:@{NSFontAttributeName: hf, NSForegroundColorAttributeName: UIColor.secondaryLabelColor}]];
    if (c.published.length) [header appendAttributedString:[[NSAttributedString alloc] initWithString:[@" · " stringByAppendingString:c.published] attributes:@{NSFontAttributeName: hf, NSForegroundColorAttributeName: UIColor.secondaryLabelColor}]];
    self.headerLabel.attributedText = header;

    self.bodyLabel.text = c.text;
    self.bodyLabel.numberOfLines = c.expandedText ? 0 : 6;

    NSMutableArray *foot = [NSMutableArray array];
    [foot addObject:[NSString stringWithFormat:@"👍 %@", c.likes.length ? c.likes : @"0"]];
    if (c.hearted) [foot addObject:YMC(@"❤️ vom Kanal", @"❤️ by creator")];
    self.footerLabel.text = [foot componentsJoinedByString:@"   "];

    [self.repliesButton setTitle:repliesTitle forState:UIControlStateNormal];
    self.repliesButton.hidden = repliesTitle.length == 0;
}
@end

#pragma mark - Comments sheet

typedef NS_ENUM(NSInteger, YMCRowKind) { YMCRowComment, YMCRowMoreReplies, YMCRowLoading, YMCRowMessage };

@interface YMCRow : NSObject
@property (nonatomic, assign) YMCRowKind kind;
@property (nonatomic, strong) YMComment *comment;
@property (nonatomic, strong) YMComment *thread; // owner thread for reply rows / "more replies"
@property (nonatomic, copy) NSString *message;
@end
@implementation YMCRow @end

@interface YMCommentsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, copy) NSString *videoId;
@property (nonatomic, strong) NSURL *snapshotURL;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISegmentedControl *sortControl;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) NSMutableArray<YMComment *> *threads;
@property (nonatomic, strong) NSArray<YMCRow *> *rows;
@property (nonatomic, strong) NSArray<NSDictionary *> *sortOptions;
@property (nonatomic, copy) NSString *nextToken;
@property (nonatomic, assign) BOOL loading, offline;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, assign) NSUInteger generation;
@property (nonatomic, copy) void (^onCount)(NSString *count, YMComment *first);
@end

@implementation YMCommentsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.title = YMC(@"Kommentare", @"Comments");
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(ym_close)];

    self.sortControl = [[UISegmentedControl alloc] initWithItems:@[YMC(@"Beliebteste", @"Top"), YMC(@"Neueste", @"Newest")]];
    self.sortControl.selectedSegmentIndex = 0;
    self.sortControl.enabled = NO;
    [self.sortControl addTarget:self action:@selector(ym_sortChanged) forControlEvents:UIControlEventValueChanged];
    self.sortControl.translatesAutoresizingMaskIntoConstraints = NO;

    self.statusLabel = [UILabel new];
    self.statusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    self.statusLabel.textColor = UIColor.secondaryLabelColor;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 90;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 64, 0, 0);
    [self.tableView registerClass:YMCommentCell.class forCellReuseIdentifier:@"c"];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;

    [self.view addSubview:self.sortControl];
    [self.view addSubview:self.statusLabel];
    [self.view addSubview:self.tableView];
    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.sortControl.topAnchor constraintEqualToAnchor:g.topAnchor constant:8],
        [self.sortControl.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:16],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.sortControl.bottomAnchor constant:6],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:16],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-16],
        [self.tableView.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:6],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
    self.threads = [NSMutableArray array];
    [self ym_loadFirst];
}

- (void)ym_close { [self dismissViewControllerAnimated:YES completion:nil]; }

- (void)ym_setStatus:(NSString *)status {
    self.statusLabel.text = status;
}

- (void)ym_loadFirst {
    if (!self.videoId.length) { [self ym_showSnapshotWithReason:YMC(@"Zu diesem Download ist keine Video-ID gespeichert (älterer Download).", @"No video ID stored for this download (older download).")]; return; }
    self.loading = YES;
    self.message = nil;
    [self ym_rebuild];
    NSUInteger gen = ++self.generation;
    __weak typeof(self) weakSelf = self;
    YMCFetchFirstPage(self.videoId, ^(YMCommentPage *page, NSError *err) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || gen != self.generation) return;
        self.loading = NO;
        if (err || !page) { [self ym_showSnapshotWithReason:YMC(@"Offline – gespeicherte Kommentare.", @"Offline – saved comments.")]; return; }
        self.offline = NO;
        self.sortOptions = page.sortOptions;
        self.sortControl.enabled = page.sortOptions.count >= 2;
        [self ym_applyPage:page replace:YES];
        if (!page.comments.count) self.message = YMC(@"Keine Kommentare (oder Kommentare sind deaktiviert).", @"No comments (or comments are turned off).");
        [self ym_setStatus:page.countText.length ? page.countText : nil];
        if (self.onCount) self.onCount(page.countText, self.threads.firstObject);
        [self ym_rebuild];
        // Downloads made before this feature: store a snapshot for offline use now.
        if (self.snapshotURL && ![NSFileManager.defaultManager fileExistsAtPath:self.snapshotURL.path])
            YMCommentsSaveSnapshot(self.videoId, self.snapshotURL);
    });
}

- (void)ym_showSnapshotWithReason:(NSString *)reason {
    self.offline = YES;
    self.loading = NO;
    self.sortControl.enabled = NO;
    NSDictionary *snap = YMCLoadSnapshot(self.snapshotURL);
    [self.threads removeAllObjects];
    for (NSDictionary *d in snap[@"comments"]) if ([d isKindOfClass:NSDictionary.class]) [self.threads addObject:[YMComment commentWithDictionary:d]];
    self.nextToken = nil;
    if (snap) {
        NSString *date = [NSDateFormatter localizedStringFromDate:[NSDate dateWithTimeIntervalSince1970:[snap[@"fetchedAt"] doubleValue]] dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterShortStyle];
        [self ym_setStatus:[NSString stringWithFormat:@"%@%@%@ %@ %@", snap[@"count"] ?: @"", [snap[@"count"] length] ? @"\n" : @"", reason, YMC(@"Stand:", @"As of"), date]];
        self.message = self.threads.count ? nil : YMC(@"Keine gespeicherten Kommentare.", @"No saved comments.");
    } else {
        [self ym_setStatus:reason];
        self.message = YMC(@"Für diesen Download sind keine Kommentare gespeichert. Mit Internetverbindung werden sie geladen und für später gesichert.", @"No comments saved for this download. With a connection they are loaded and saved for later.");
    }
    if (self.onCount) self.onCount(snap[@"count"], self.threads.firstObject);
    [self ym_rebuild];
}

- (void)ym_applyPage:(YMCommentPage *)page replace:(BOOL)replace {
    if (replace) [self.threads removeAllObjects];
    [self.threads addObjectsFromArray:page.comments];
    self.nextToken = page.nextToken;
}

- (void)ym_sortChanged {
    NSInteger idx = self.sortControl.selectedSegmentIndex;
    if (idx < 0 || (NSUInteger)idx >= self.sortOptions.count) return;
    NSString *token = self.sortOptions[idx][@"token"];
    [self.threads removeAllObjects];
    self.nextToken = nil;
    self.loading = YES;
    [self ym_rebuild];
    NSUInteger gen = ++self.generation;
    __weak typeof(self) weakSelf = self;
    YMCFetchPage(token, ^(YMCommentPage *page, NSError *err) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || gen != self.generation) return;
        self.loading = NO;
        if (err || !page) { self.message = YMC(@"Laden fehlgeschlagen.", @"Loading failed."); [self ym_rebuild]; return; }
        [self ym_applyPage:page replace:YES];
        [self ym_rebuild];
        [self.tableView setContentOffset:CGPointZero animated:NO];
    });
}

- (void)ym_loadMore {
    if (self.loading || !self.nextToken || self.offline) return;
    self.loading = YES;
    [self ym_rebuild];
    NSUInteger gen = self.generation;
    __weak typeof(self) weakSelf = self;
    YMCFetchPage(self.nextToken, ^(YMCommentPage *page, NSError *err) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self || gen != self.generation) return;
        self.loading = NO;
        if (err || !page) { [self ym_rebuild]; return; } // keep token; scrolling retries
        [self ym_applyPage:page replace:NO];
        [self ym_rebuild];
    });
}

- (void)ym_toggleReplies:(YMComment *)thread {
    if (thread.repliesExpanded) { thread.repliesExpanded = NO; [self ym_rebuild]; return; }
    thread.repliesExpanded = YES;
    if (thread.replies) { [self ym_rebuild]; return; }
    [self ym_loadReplies:thread token:thread.repliesToken];
}

- (void)ym_loadReplies:(YMComment *)thread token:(NSString *)token {
    if (!token || thread.loadingReplies) return;
    thread.loadingReplies = YES;
    [self ym_rebuild];
    __weak typeof(self) weakSelf = self;
    YMCFetchPage(token, ^(YMCommentPage *page, NSError *err) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        thread.loadingReplies = NO;
        if (!err && page) {
            if (!thread.replies) thread.replies = [NSMutableArray array];
            for (YMComment *r in page.comments) r.isReply = YES;
            [thread.replies addObjectsFromArray:page.comments];
            thread.moreRepliesToken = page.nextToken;
        }
        [self ym_rebuild];
    });
}

- (void)ym_rebuild {
    NSMutableArray *rows = [NSMutableArray array];
    for (YMComment *t in self.threads) {
        YMCRow *r = [YMCRow new]; r.kind = YMCRowComment; r.comment = t; r.thread = t;
        [rows addObject:r];
        if (t.repliesExpanded) {
            for (YMComment *reply in t.replies) {
                YMCRow *rr = [YMCRow new]; rr.kind = YMCRowComment; rr.comment = reply; rr.thread = t;
                [rows addObject:rr];
            }
            if (t.loadingReplies) { YMCRow *l = [YMCRow new]; l.kind = YMCRowLoading; l.thread = t; [rows addObject:l]; }
            else if (t.moreRepliesToken) { YMCRow *m = [YMCRow new]; m.kind = YMCRowMoreReplies; m.thread = t; [rows addObject:m]; }
        }
    }
    if (self.loading) { YMCRow *l = [YMCRow new]; l.kind = YMCRowLoading; [rows addObject:l]; }
    if (self.message.length) { YMCRow *m = [YMCRow new]; m.kind = YMCRowMessage; m.message = self.message; [rows addObject:m]; }
    self.rows = rows;
    [self.tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.rows.count; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    YMCRow *row = self.rows[indexPath.row];
    if (row.kind == YMCRowComment) {
        YMCommentCell *cell = [tableView dequeueReusableCellWithIdentifier:@"c" forIndexPath:indexPath];
        YMComment *c = row.comment;
        NSString *repliesTitle = nil;
        if (!c.isReply && c.replyCount > 0 && !self.offline && c.repliesToken) {
            repliesTitle = c.repliesExpanded ? YMC(@"▲ Antworten ausblenden", @"▲ Hide replies")
                                             : [NSString stringWithFormat:@"▼ %ld %@", (long)c.replyCount, c.replyCount == 1 ? YMC(@"Antwort", @"reply") : YMC(@"Antworten", @"replies")];
        } else if (!c.isReply && c.replyCount > 0) {
            repliesTitle = nil;
        }
        [cell configureWithComment:c repliesTitle:repliesTitle];
        __weak typeof(self) weakSelf = self;
        cell.onReplies = ^{ [weakSelf ym_toggleReplies:c]; };
        return cell;
    }
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"misc"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"misc"];
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    cell.accessoryView = nil;
    cell.indentationLevel = row.thread ? 6 : 0;
    cell.indentationWidth = 10;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (row.kind == YMCRowLoading) {
        cell.textLabel.text = YMC(@"Wird geladen …", @"Loading …");
        cell.textLabel.textColor = UIColor.secondaryLabelColor;
        UIActivityIndicatorView *sp = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        [sp startAnimating];
        cell.accessoryView = sp;
    } else if (row.kind == YMCRowMoreReplies) {
        cell.textLabel.text = YMC(@"↳ Mehr Antworten ansehen", @"↳ Show more replies");
        cell.textLabel.textColor = UIColor.systemBlueColor;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    } else {
        cell.textLabel.text = row.message;
        cell.textLabel.textColor = UIColor.secondaryLabelColor;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    YMCRow *row = self.rows[indexPath.row];
    if (row.kind == YMCRowMoreReplies) {
        [self ym_loadReplies:row.thread token:row.thread.moreRepliesToken];
    } else if (row.kind == YMCRowComment) {
        row.comment.expandedText = !row.comment.expandedText;
        [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= (NSInteger)self.rows.count - 4) [self ym_loadMore];
}

@end

#pragma mark - Watch page

@interface YMWatchViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, copy) NSDictionary *info;
@property (nonatomic, strong) AVPlayerViewController *playerVC;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSString *commentCount;
@property (nonatomic, strong) YMComment *firstComment;
@property (nonatomic, assign) BOOL commentsLoaded, started;
@end

@implementation YMWatchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

    NSURL *fileURL = self.info[@"fileURL"];
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback mode:AVAudioSessionModeMoviePlayback options:0 error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:fileURL];
    AVMutableMetadataItem *titleMeta = [AVMutableMetadataItem metadataItem];
    titleMeta.identifier = AVMetadataCommonIdentifierTitle;
    titleMeta.value = self.info[@"title"] ?: @"";
    titleMeta.extendedLanguageTag = @"und";
    item.externalMetadata = @[titleMeta];
    self.playerVC = [AVPlayerViewController new];
    self.playerVC.player = [AVPlayer playerWithPlayerItem:item];
    self.playerVC.allowsPictureInPicturePlayback = YES;
    if (@available(iOS 14.2, *)) self.playerVC.canStartPictureInPictureAutomaticallyFromInline = YES;
    if ([self.info[@"isAudio"] boolValue]) {
        UIImageView *art = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:self.info[@"thumbPath"] ?: @""]];
        art.contentMode = UIViewContentModeScaleAspectFit;
        art.frame = self.playerVC.contentOverlayView.bounds;
        art.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.playerVC.contentOverlayView addSubview:art];
    }
    [self addChildViewController:self.playerVC];
    self.playerVC.view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.playerVC.view];
    [self.playerVC didMoveToParentViewController:self];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];

    UILayoutGuide *g = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.playerVC.view.topAnchor constraintEqualToAnchor:g.topAnchor],
        [self.playerVC.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.playerVC.view.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.playerVC.view.heightAnchor constraintEqualToAnchor:self.playerVC.view.widthAnchor multiplier:9.0 / 16.0],
        [self.tableView.topAnchor constraintEqualToAnchor:self.playerVC.view.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    // Comment teaser: offline snapshot first, then the live count/first comment.
    NSDictionary *snap = YMCLoadSnapshot(self.info[@"commentsURL"]);
    self.commentCount = snap[@"count"];
    NSDictionary *firstDict = [snap[@"comments"] firstObject];
    if ([firstDict isKindOfClass:NSDictionary.class]) self.firstComment = [YMComment commentWithDictionary:firstDict];
    NSString *vid = self.info[@"videoId"];
    if (vid.length) {
        __weak typeof(self) weakSelf = self;
        YMCFetchFirstPage(vid, ^(YMCommentPage *page, NSError *err) {
            if (err || !page) return;
            weakSelf.commentCount = page.countText ?: weakSelf.commentCount;
            weakSelf.firstComment = page.comments.firstObject ?: weakSelf.firstComment;
            [weakSelf.tableView reloadData];
        });
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.started) {
        self.started = YES;
        [self.playerVC.player play];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.isMovingFromParentViewController || self.isBeingDismissed) [self.playerVC.player pause];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return section == 2 ? 2 : 1; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    if (indexPath.section == 0) {
        cell.textLabel.text = self.info[@"title"];
        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        cell.detailTextLabel.text = self.info[@"detail"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if (indexPath.section == 1) {
        NSString *count = self.commentCount.length ? self.commentCount : YMC(@"Kommentare", @"Comments");
        NSMutableAttributedString *t = [[NSMutableAttributedString alloc] initWithString:YMC(@"Kommentare", @"Comments") attributes:@{NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]}];
        if (self.commentCount.length && ![count isEqualToString:YMC(@"Kommentare", @"Comments")])
            [t appendAttributedString:[[NSAttributedString alloc] initWithString:[@"  " stringByAppendingString:[[count stringByReplacingOccurrencesOfString:YMC(@"Kommentare", @"Comments") withString:@""] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]] attributes:@{NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline], NSForegroundColorAttributeName: UIColor.secondaryLabelColor}]];
        cell.textLabel.attributedText = t;
        if (self.firstComment) {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@: %@", self.firstComment.author ?: @"", self.firstComment.text ?: @""];
            cell.detailTextLabel.numberOfLines = 2;
            cell.imageView.image = YMCInitialAvatar(self.firstComment.author ?: @"?", 28);
            NSString *url = self.firstComment.avatarURL;
            __weak UITableViewCell *weakCell = cell;
            YMCLoadAvatar(url, ^(UIImage *img) {
                UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(28, 28)];
                weakCell.imageView.image = [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
                    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, 28, 28)] addClip];
                    [img drawInRect:CGRectMake(0, 0, 28, 28)];
                }];
                [weakCell setNeedsLayout];
            });
        } else {
            cell.detailTextLabel.text = [self.info[@"videoId"] length] ? YMC(@"Antippen, um Kommentare zu laden", @"Tap to load comments") : YMC(@"Für ältere Downloads nicht verfügbar", @"Not available for older downloads");
        }
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        if (indexPath.row == 0) {
            cell.textLabel.text = YMC(@"In YouTube öffnen", @"Open in YouTube");
            cell.imageView.image = [UIImage systemImageNamed:@"play.rectangle"];
            cell.textLabel.textColor = [self.info[@"videoId"] length] ? UIColor.labelColor : UIColor.tertiaryLabelColor;
        } else {
            cell.textLabel.text = YMC(@"Teilen", @"Share");
            cell.imageView.image = [UIImage systemImageNamed:@"square.and.arrow.up"];
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1) {
        YMCommentsViewController *c = [YMCommentsViewController new];
        c.videoId = self.info[@"videoId"];
        c.snapshotURL = self.info[@"commentsURL"];
        __weak typeof(self) weakSelf = self;
        c.onCount = ^(NSString *count, YMComment *first) {
            if (count.length) weakSelf.commentCount = count;
            if (first) weakSelf.firstComment = first;
            [weakSelf.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
        };
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:c];
        if (@available(iOS 15.0, *)) {
            UISheetPresentationController *sheet = nav.sheetPresentationController;
            sheet.detents = @[UISheetPresentationControllerDetent.mediumDetent, UISheetPresentationControllerDetent.largeDetent];
            sheet.prefersGrabberVisible = YES;
            sheet.largestUndimmedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium; // video stays usable
        }
        [self presentViewController:nav animated:YES completion:nil];
    } else if (indexPath.section == 2 && indexPath.row == 0) {
        NSString *vid = self.info[@"videoId"];
        if (!vid.length) return;
        [self.playerVC.player pause];
        NSURL *url = [NSURL URLWithString:[@"youtube://watch?v=" stringByAppendingString:vid]];
        UIApplication *app = UIApplication.sharedApplication;
        [self.navigationController dismissViewControllerAnimated:YES completion:^{
            id<UIApplicationDelegate> delegate = app.delegate;
            BOOL handled = NO;
            if ([delegate respondsToSelector:@selector(application:openURL:options:)]) handled = [delegate application:app openURL:url options:@{}];
            if (!handled) [app openURL:[NSURL URLWithString:[@"https://www.youtube.com/watch?v=" stringByAppendingString:vid]] options:@{} completionHandler:nil];
        }];
    } else if (indexPath.section == 2 && indexPath.row == 1) {
        UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:@[self.info[@"fileURL"]] applicationActivities:nil];
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        avc.popoverPresentationController.sourceView = cell ?: self.view;
        avc.popoverPresentationController.sourceRect = cell ? cell.bounds : CGRectZero;
        [self presentViewController:avc animated:YES completion:nil];
    }
}

@end

UIViewController *YMCreateWatchViewController(NSDictionary *info) {
    YMWatchViewController *vc = [YMWatchViewController new];
    vc.info = info;
    vc.title = nil;
    return vc;
}

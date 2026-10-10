#import "Headers.h"
#import <CommonCrypto/CommonDigest.h>

// SponsorBlock menu: the player-overlay shield button opens a YouTube-style
// bottom sheet (enable/disable, segment voting, channel whitelist), while
// voting / whitelist / user-ID editing use our own form-sheet card dialog
// (YMSBCardViewController) built on a UINavigationController + inset-grouped
// UITableView, so sub-screens push and swipe-left delete comes for free.

#pragma mark - Small helpers

void sbShowSBPill(NSString *message, BOOL success) {
    UIView *parent = sbGetNotificationParent();
    if (success) {
        [SBSkipNotificationView showSuccessInView:parent message:message duration:3.0];
    } else {
        [SBSkipNotificationView showErrorInView:parent message:message duration:4.0];
    }
}

static NSString *sbFormatTime(float t) {
    NSInteger total = (NSInteger)lroundf(t);
    if (total < 0) total = 0;
    NSInteger h = total / 3600;
    NSInteger m = (total % 3600) / 60;
    NSInteger s = total % 60;
    if (h > 0) return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)h, (long)m, (long)s];
    return [NSString stringWithFormat:@"%ld:%02ld", (long)m, (long)s];
}

// Like sbFormatTime but with tenths, for marking segment boundaries.
static NSString *sbFormatPreciseTime(float t) {
    if (t < 0) t = 0;
    NSInteger tenths = (NSInteger)lroundf(t * 10.0f);
    NSInteger total = tenths / 10;
    NSInteger h = total / 3600;
    NSInteger m = (total % 3600) / 60;
    NSInteger sec = total % 60;
    if (h > 0) return [NSString stringWithFormat:@"%ld:%02ld:%02ld.%ld", (long)h, (long)m, (long)sec, (long)(tenths % 10)];
    return [NSString stringWithFormat:@"%ld:%02ld.%ld", (long)m, (long)sec, (long)(tenths % 10)];
}

static NSString *sbLocalizedCategoryName(NSString *category) {
    return [YouModBundle() localizedStringForKey:[NSString stringWithFormat:@"SB_CAT_%@", category ?: @""]
                                            value:category
                                            table:nil];
}

static UIImage *sbSymbolImage(NSString *symbolName) {
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
    return [[UIImage systemImageNamed:symbolName withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

static UIImage *sbDotImage(UIColor *color) {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(18, 18)];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(2, 2, 14, 14)];
        [color setFill];
        [path fill];
    }];
}

// Uniform icon size for the YouTube action sheet: each SF Symbol is rendered
// into an exact 24x24 canvas (aspect-fit, centered), so every row's icon box
// is identical regardless of the symbol's natural proportions.
static UIImage *sbSheetIcon(NSString *symbolName) {
    return YouModSymbolImageInCanvas(symbolName, 24, 22, UIImageSymbolWeightMedium);
}

#pragma mark - User ID

NSString *sbLocalUserID(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *userID = [defaults stringForKey:SBPrivateUserIDKey];
    if (userID.length >= 30) return userID;
    // A UUID without hyphens is exactly 32 hex characters, matching the
    // SponsorBlock requirement for a local userID.
    userID = [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
    [defaults setObject:userID forKey:SBPrivateUserIDKey];
    return userID;
}

// The public userID is the private one hashed with SHA-256 5000 times
// (SponsorBlock spec). Cached as a dict so a private-ID change is detected
// and a manual public-ID override survives.
static NSString *sbHashPublicFromPrivate(NSString *privateID) {
    NSData *data = [privateID dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    for (NSInteger i = 1; i < 5000; i++) {
        CC_SHA256(digest, CC_SHA256_DIGEST_LENGTH, digest);
    }
    NSMutableString *hex = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSInteger i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return hex;
}

NSString *sbPublicUserID(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *cache = [defaults dictionaryForKey:SBPublicUserIDKey];
    if ([cache[@"manual"] boolValue]) {
        NSString *value = cache[@"value"];
        if (value.length > 0) return value;
    }
    NSString *privateID = sbLocalUserID();
    NSString *value = cache[@"value"];
    if (value.length > 0 && [cache[@"private"] isEqualToString:privateID]) return value;
    value = sbHashPublicFromPrivate(privateID);
    [defaults setObject:@{@"manual": @NO, @"private": privateID, @"value": value} forKey:SBPublicUserIDKey];
    return value;
}

void sbSetPrivateUserID(NSString *userID) {
    if (userID.length < 30) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:userID forKey:SBPrivateUserIDKey];
    // Drop the derived public-ID cache unless the user set a manual override.
    NSDictionary *cache = [defaults dictionaryForKey:SBPublicUserIDKey];
    if (![cache[@"manual"] boolValue]) {
        [defaults removeObjectForKey:SBPublicUserIDKey];
    }
}

void sbSetPublicUserIDManual(NSString *userID) {
    if (userID.length < 30) return;
    [[NSUserDefaults standardUserDefaults] setObject:@{@"manual": @YES, @"value": userID} forKey:SBPublicUserIDKey];
}

#pragma mark - Whitelist + channel info

// Same pattern as Download.x's YouModPlayerDataForPlayer: contentPlayerResponse
// when the player responds to it, playerResponse otherwise.
static YTIPlayerResponse *sbPlayerDataForPlayer(YTPlayerViewController *player) {
    YTPlayerResponse *response;
    if ([player respondsToSelector:@selector(contentPlayerResponse)]) {
        response = player.contentPlayerResponse;
    } else {
        response = player.playerResponse;
    }
    return response.playerData;
}

static NSString *sbCurrentChannelID(YTPlayerViewController *player) {
    return sbPlayerDataForPlayer(player).videoDetails.channelId;
}

static NSString *sbCurrentChannelName(YTPlayerViewController *player) {
    return sbPlayerDataForPlayer(player).videoDetails.author;
}

static NSDictionary *sbWhitelistDictionary(void) {
    NSDictionary *dict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:SBWhitelistKey];
    return dict ?: @{};
}

static void sbSaveWhitelistDictionary(NSDictionary *dict) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (dict.count == 0) {
        [defaults removeObjectForKey:SBWhitelistKey];
    } else {
        [defaults setObject:dict forKey:SBWhitelistKey];
    }
    [defaults synchronize];
}

static BOOL sbIsChannelWhitelisted(NSString *channelID) {
    if (channelID.length == 0) return NO;
    return sbWhitelistDictionary()[channelID] != nil;
}

static void sbSetChannelWhitelisted(NSString *channelID, NSString *channelName, BOOL whitelisted) {
    if (channelID.length == 0) return;
    NSMutableDictionary *dict = [sbWhitelistDictionary() mutableCopy];
    if (whitelisted) {
        dict[channelID] = channelName.length > 0 ? channelName : channelID;
    } else {
        [dict removeObjectForKey:channelID];
    }
    sbSaveWhitelistDictionary(dict);
}

BOOL sbActiveForVideo(YTPlayerViewController *player) {
    if (!IS_ENABLED(SBEnabled) || !IS_ENABLED(SBButtonKey)) return NO;
    NSString *channelID = sbCurrentChannelID(player);
    if (channelID && sbIsChannelWhitelisted(channelID)) return NO;
    return YES;
}

// Pushes a fresh segments notification for the player: fetches and activates
// segments when SB is (back) on, clears markers when it is off/whitelisted.
static void sbPostSegmentsForPlayer(YTPlayerViewController *player, BOOL enabled) {
    if (!player) return;
    NSString *videoID = [player currentVideoID];
    sbInvalidateSegmentCache(videoID);
    player.sbSegments = nil;
    if (!enabled || !sbActiveForVideo(player)) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SBSegmentsDidLoad"
                                                            object:player
                                                          userInfo:@{@"segments": @[]}];
        return;
    }
    [SBRequest fetchSegmentsForVideoID:videoID completion:^(NSArray<SBSegment *> *segments) {
        player.sbSegments = segments;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SBSegmentsDidLoad"
                                                            object:player
                                                          userInfo:@{@"segments": segments ?: @[]}];
    }];
}

// Re-syncs the currently playing video after the whitelist changed, so
// removing a channel brings skipping/markers back immediately instead of
// waiting for the next video.
static void sbRefreshPlayerAfterWhitelistChange(void) {
    YTPlayerViewController *player = YouModCurrentPlayerViewController;
    if (!player) return;
    NSString *channelID = sbCurrentChannelID(player);
    BOOL listed = channelID.length > 0 && sbIsChannelWhitelisted(channelID);
    sbPostSegmentsForPlayer(player, !listed);
}

#pragma mark - SBRequest (Write)

static NSString *sbQueryValue(NSString *value) {
    static NSCharacterSet *allowed;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableCharacterSet *set = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
        [set removeCharactersInString:@"&=+?"];
        allowed = set;
    });
    return [value ?: @"" stringByAddingPercentEncodingWithAllowedCharacters:allowed];
}

// All parameters go in the URL query string per the SponsorBlock API.
// Failed requests carry a plain-text reason in the body (400/403).
static void sbPostQuery(NSString *path, NSDictionary<NSString *, NSString *> *params, void (^completion)(BOOL success, NSInteger status, NSString *errorMessage)) {
    NSMutableArray *pairs = [NSMutableArray array];
    [params enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, __unused BOOL *stop) {
        [pairs addObject:[NSString stringWithFormat:@"%@=%@", key, sbQueryValue(value)]];
    }];
    NSString *urlString = [NSString stringWithFormat:@"https://sponsor.ajay.app%@?%@", path, [pairs componentsJoinedByString:@"&"]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 15.0;

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger status = [(NSHTTPURLResponse *)response statusCode];
        BOOL ok = (error == nil) && status == 200;
        NSString *message = nil;
        if (!ok) {
            if (error) message = error.localizedDescription;
            if (message.length == 0 && data.length > 0) {
                message = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            }
            if (message.length > 120) message = [message substringToIndex:120];
            if (message.length == 0) message = [NSString stringWithFormat:@"HTTP %ld", (long)status];
        }
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(ok, status, message); });
    }] resume];
}

@implementation SBRequest (Write)

+ (void)voteOnSegment:(SBSegment *)segment videoID:(NSString *)videoID type:(NSInteger)voteType completion:(void (^)(BOOL success, NSString *errorMessage))completion {
    if (!segment.UUID.length || !videoID.length) {
        if (completion) completion(NO, nil);
        return;
    }
    sbPostQuery(@"/api/voteOnSponsorTime",
                @{@"UUID": segment.UUID, @"videoID": videoID, @"userID": sbLocalUserID(), @"type": [@(voteType) stringValue]},
                ^(BOOL ok, __unused NSInteger status, NSString *message) { if (completion) completion(ok, message); });
}

+ (void)voteCategoryOnSegment:(SBSegment *)segment videoID:(NSString *)videoID category:(NSString *)category completion:(void (^)(BOOL success, NSString *errorMessage))completion {
    if (!segment.UUID.length || !videoID.length || category.length == 0) {
        if (completion) completion(NO, nil);
        return;
    }
    sbPostQuery(@"/api/voteOnSponsorTime",
                @{@"UUID": segment.UUID, @"videoID": videoID, @"userID": sbLocalUserID(), @"category": category},
                ^(BOOL ok, __unused NSInteger status, NSString *message) { if (completion) completion(ok, message); });
}

+ (void)submitSegmentForVideoID:(NSString *)videoID category:(NSString *)category start:(float)start end:(float)end duration:(float)duration completion:(void (^)(BOOL success, NSString *errorMessage))completion {
    NSString *actionType = @"skip";
    if ([category isEqualToString:@"poi_highlight"]) actionType = @"poi";
    else if ([category isEqualToString:@"exclusive_access"]) actionType = @"full";

    NSMutableDictionary *params = [@{
        @"videoID": videoID ?: @"",
        @"userID": sbLocalUserID(),
        @"category": category ?: @"",
        @"startTime": [NSString stringWithFormat:@"%.3f", start],
        @"endTime": [NSString stringWithFormat:@"%.3f", end],
        @"actionType": actionType,
        @"userAgent": [@"YouMod/" stringByAppendingString:YouModVersion],
    } mutableCopy];
    if (duration > 0) params[@"videoDuration"] = [NSString stringWithFormat:@"%.3f", duration];

    sbPostQuery(@"/api/skipSegments", params, ^(BOOL ok, NSInteger status, NSString *message) {
        if (status == 409) message = LOC(@"SB_SUBMIT_DUPLICATE");
        else if (status == 429) message = LOC(@"SB_SUBMIT_RATE_LIMIT");
        if (completion) completion(ok, message);
    });
}

@end

@implementation YMSBCardItem

+ (instancetype)itemWithImage:(UIImage *)image title:(NSString *)title subtitle:(NSString *)subtitle tintColor:(UIColor *)tint handler:(void (^)(YMSBCardViewController *card))handler {
    YMSBCardItem *item = [[YMSBCardItem alloc] init];
    item.image = image;
    item.title = title;
    item.subtitle = subtitle;
    item.tintColor = tint;
    item.handler = handler;
    return item;
}

@end

#pragma mark - Engagement panel

static NSString * const SBEngagementPanelID = @"youmod-sponsorblock";
static UINavigationController *sbEngagementPanelNav = nil;

static YTICommand *sbEngagementPanelShowCommand(NSString *title) {
    YTIEngagementPanelTitleHeaderRenderer *titleHeader = [[%c(YTIEngagementPanelTitleHeaderRenderer) alloc] init];
    titleHeader.title = [%c(YTIFormattedString) formattedStringWithString:title];
    YTIEngagementPanelSectionListHeaderSupportedRenderers *header = [[%c(YTIEngagementPanelSectionListHeaderSupportedRenderers) alloc] init];
    header.engagementPanelTitleHeaderRenderer = titleHeader;

    YTIEngagementPanelSectionListRenderer *sectionList = [[%c(YTIEngagementPanelSectionListRenderer) alloc] init];
    sectionList.panelIdentifier = SBEngagementPanelID;
    sectionList.header = header;
    sectionList.supportedOrientations = 1; // portrait and landscape (3 = landscape only)
    sectionList.allowReplace = YES;        // rebuild on every open instead of reusing a cached panel
    YTIEngagementPanelSupportedRenderers *panel = [[%c(YTIEngagementPanelSupportedRenderers) alloc] init];
    panel.engagementPanelSectionListRenderer = sectionList;

    YTIShowEngagementPanelEndpoint *endpoint = [[%c(YTIShowEngagementPanelEndpoint) alloc] init];
    endpoint.panelIdentifier = SBEngagementPanelID;
    endpoint.engagementPanel = panel;

    // The endpoint is a YTICommand extension whose descriptor YouTube keeps in a
    // C static (no ObjC accessor), so encode it as that extension field on the
    // wire and let YouTube's parser, which carries the app's extension registry,
    // attach it. Proto field numbers are fixed for wire compatibility.
    static const uint64_t SBShowEngagementPanelEndpointField = 138681778;
    NSData *payload = [endpoint data];
    NSMutableData *wire = [NSMutableData data];
    uint64_t varints[] = {(SBShowEngagementPanelEndpointField << 3) | 2, payload.length}; // tag, length
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
    return [%c(YTICommand) goog_parseFromData:wire error:nil];
}

@interface YMSBCardNavigationController : UINavigationController
@end
@implementation YMSBCardNavigationController
- (void)loadWithModel:(id)model {}
@end

static Class sbEngagementPanelClass(void) {
    return %c(YTEngagementPanelViewControllerImpl) ?: %c(YTMainAppEngagementPanelViewController);
}

static UIViewController *sbEngagementPanelFor(UIViewController *card) {
    UIViewController *panel = card.navigationController.parentViewController;
    return [panel isKindOfClass:sbEngagementPanelClass()] ? panel : nil;
}

static BOOL sbIsOurPanelModel(id model) {
    // The view model's panelIdentifier is a YTEngagementPanelIdentifier, not the
    // endpoint's NSString of the same name the compiler would pick for `id`.
    YTEngagementPanelIdentifier *panelID = ((id (*)(id, SEL))objc_msgSend)(model, @selector(panelIdentifier));
    return sbEngagementPanelNav && [panelID.identifierString isEqualToString:SBEngagementPanelID];
}

%hook YTEngagementPanelViewControllerImpl
- (void)prepareContentViewControllerForModel:(id)model {
    if (!sbIsOurPanelModel(model)) {
        %orig;
        return;
    }
    [self setContentViewController:sbEngagementPanelNav];
}
%end

%hook YTMainAppEngagementPanelViewController
- (void)prepareContentViewControllerForModel:(id)model {
    if (!sbIsOurPanelModel(model)) {
        %orig;
        return;
    }
    UIViewController *old = [self valueForKey:@"_contentViewController"];
    [old willMoveToParentViewController:nil];
    [old.view removeFromSuperview];
    [old removeFromParentViewController];

    [self setValue:sbEngagementPanelNav forKey:@"_contentViewController"];
    [self addChildViewController:sbEngagementPanelNav];
    [self.view performSelector:@selector(setContentView:) withObject:sbEngagementPanelNav.view];
    [sbEngagementPanelNav didMoveToParentViewController:self];
}
%end

#pragma mark - YMSBCardViewController (form sheet)

@interface YMSBCardViewController () <UISearchBarDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) NSArray<YMSBCardItem *> *allItems;
@property (nonatomic, copy) NSString *searchText;
@end

@implementation YMSBCardViewController {
    NSArray<YMSBCardItem *> *_visibleItems;
}

// items is the filtered view of allItems; setting items re-applies the
// current search query so deletions rebuild the list correctly.
- (void)setItems:(NSArray<YMSBCardItem *> *)items {
    self.allItems = items ?: @[];
    [self refilterItems];
}

- (NSArray<YMSBCardItem *> *)items {
    return _visibleItems;
}

- (void)refilterItems {
    [self refilterItemsWithReload:YES];
}

// Recomputes the visible list from allItems + the search query. Pass NO for
// reload when the caller animates row changes itself (e.g. deletion).
- (void)refilterItemsWithReload:(BOOL)reload {
    NSString *query = [self.searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray *source = self.allItems;
    if (query.length > 0) {
        source = [source filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"title CONTAINS[cd] %@ OR subtitle CONTAINS[cd] %@", query, query]];
    }
    _visibleItems = source;
    if (reload) [self.tableView reloadData];
    [self sbUpdateEmptyState];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.cardTitle;

    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithImage:YouModSymbolImageInCanvas(@"xmark", 24, 16, UIImageSymbolWeightMedium)
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(dismissCard)];
    // White in dark mode, black in light mode — re-resolved on appearance
    // changes in sbUpdateCloseButtonColor with a cross-dissolve.
    closeButton.tintColor = [UIColor labelColor];
    self.navigationItem.rightBarButtonItem = closeButton;

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 54;
    _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_tableView];
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];

    if (self.searchBar) {
        self.searchBar.delegate = self;
        // Clear the bar's own background so only the rounded inner field
        // shows — no outer white frame.
        self.searchBar.backgroundImage = [[UIImage alloc] init];
        self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;

        // Wrap the bar in a fixed-height, full-width header view: a bare
        // search bar as tableHeaderView gets mis-sized on inset-grouped
        // tables and rows slide underneath it.
        UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 56)];
        header.backgroundColor = [UIColor clearColor];
        [header addSubview:self.searchBar];
        [NSLayoutConstraint activateConstraints:@[
            [self.searchBar.topAnchor constraintEqualToAnchor:header.topAnchor constant:4],
            [self.searchBar.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-4],
            [self.searchBar.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:8],
            [self.searchBar.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-8],
        ]];
        _tableView.tableHeaderView = header;
    }

    [self sbStyleFieldBorders];

    if (self.swipeToDelete) {
        // Editing mode puts a red minus on the leading edge of every row;
        // tapping it reveals the red Delete button, identical to the
        // swipe-left interaction.
        _tableView.editing = YES;
        _tableView.allowsSelectionDuringEditing = NO;
    }

    // Centered empty-state text (e.g. "no whitelisted channels"), shown only
    // while there are no items.
    _emptyLabel = [[UILabel alloc] init];
    _emptyLabel.text = self.emptyText;
    _emptyLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    _emptyLabel.textColor = [UIColor secondaryLabelColor];
    _emptyLabel.textAlignment = NSTextAlignmentCenter;
    _emptyLabel.numberOfLines = 0;
    _emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_emptyLabel];
    [NSLayoutConstraint activateConstraints:@[
        [_emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [_emptyLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:24],
        [_emptyLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.view.trailingAnchor constant:-24],
    ]];

    [self refilterItems];
}

- (void)setEmptyText:(NSString *)emptyText {
    _emptyText = [emptyText copy];
    _emptyLabel.text = _emptyText;
    [self sbUpdateEmptyState];
}

- (void)sbUpdateEmptyState {
    _emptyLabel.hidden = !(self.items.count == 0 && _emptyText.length > 0);
}

// Re-applies trait-dependent field styling: no border, and a slightly grayer
// fill in light mode (default depth in dark mode). Called on theme changes
// inside a cross-dissolve so the flip is animated.
- (void)sbStyleFieldBorders {
    UIColor *fieldFill = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
        return (trait.userInterfaceStyle == UIUserInterfaceStyleDark) ? [UIColor secondarySystemBackgroundColor] : [UIColor systemGray5Color];
    }];
    if (self.searchBar) {
        UITextField *searchField = self.searchBar.searchTextField;
        searchField.layer.cornerRadius = 10.0;
        searchField.layer.masksToBounds = YES;
        searchField.layer.borderWidth = 0.0;
        searchField.layer.borderColor = nil;
        searchField.backgroundColor = fieldFill;
    }
    if (self.textField) {
        self.textField.layer.cornerRadius = 10.0;
        self.textField.layer.masksToBounds = YES;
        self.textField.layer.borderWidth = 0.0;
        self.textField.layer.borderColor = nil;
        self.textField.backgroundColor = fieldFill;
    }
}

// The close button flips white (dark mode) / black (light mode) with a short
// cross-dissolve instead of snapping.
- (void)sbUpdateCloseButtonColor {
    UIBarButtonItem *closeButton = self.navigationItem.rightBarButtonItem;
    if (!closeButton) return;
    BOOL dark = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark);
    [UIView transitionWithView:self.navigationController ? self.navigationController.view : self.view
                      duration:0.25
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
        closeButton.tintColor = dark ? [UIColor whiteColor] : [UIColor blackColor];
    }
                    completion:nil];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle) {
        [self sbUpdateCloseButtonColor];
        [UIView transitionWithView:self.view
                          duration:0.25
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            [self sbStyleFieldBorders];
            [self.tableView reloadData];
        }
                        completion:nil];
    }
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.searchText = searchText;
    [self refilterItems];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (sbEngagementPanelFor(self)) {
        self.navigationItem.rightBarButtonItem = nil;
        BOOL isRoot = self.navigationController.viewControllers.firstObject == self;
        [self.navigationController setNavigationBarHidden:isRoot animated:animated];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // Autofocus the field on the Edit-ID card's first appearance.
    if (self.textField && self.isBeingPresented) [self.textField becomeFirstResponder];
}

#pragma mark Row mapping: [message?][textField?][items...]

- (YMSBCardItem *)itemForRow:(NSInteger)row {
    NSInteger offset = 0;
    if (self.message.length > 0) {
        if (row == 0) return nil;
        offset = 1;
    }
    if (self.textField) {
        if (row == offset) return nil;
        offset += 1;
    }
    NSInteger idx = row - offset;
    return (idx >= 0 && idx < (NSInteger)self.items.count) ? self.items[idx] : nil;
}

#pragma mark UITableViewDataSource / Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count + (self.message.length > 0 ? 1 : 0) + (self.textField ? 1 : 0);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Message row
    if (self.message.length > 0 && indexPath.row == 0) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        UILabel *label = [[UILabel alloc] init];
        label.text = self.message;
        label.font = [UIFont systemFontOfSize:13];
        label.textColor = [UIColor secondaryLabelColor];
        label.numberOfLines = 0;
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:label];
        [NSLayoutConstraint activateConstraints:@[
            [label.leadingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.leadingAnchor],
            [label.trailingAnchor constraintLessThanOrEqualToAnchor:cell.contentView.layoutMarginsGuide.trailingAnchor],
            [label.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:8],
            [label.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-8],
        ]];
        return cell;
    }

    // Text field row
    if (self.textField && indexPath.row == (self.message.length > 0 ? 1 : 0)) {
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        UITextField *field = self.textField;
        field.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:field];
        [NSLayoutConstraint activateConstraints:@[
            [field.leadingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.leadingAnchor],
            [field.trailingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.trailingAnchor],
            [field.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:8],
            [field.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-8],
            [field.heightAnchor constraintEqualToConstant:40],
        ]];
        return cell;
    }

    YMSBCardItem *item = [self itemForRow:indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"sbCardItem"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"sbCardItem"];
    }
    // Re-applied on every pass so reused cells always carry the current
    // dynamic text colors (white in dark mode, black in light mode).
    cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    cell.textLabel.textColor = [UIColor labelColor];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.imageView.image = item.image;
    cell.imageView.tintColor = item.tintColor;
    cell.textLabel.text = item.title;
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.text = item.subtitle.length > 0 ? item.subtitle : nil;
    // Assigned on every pass so a reused cell never keeps another row's controls.
    cell.accessoryView = item.accessoryView;
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self itemForRow:indexPath.row] != nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    YMSBCardItem *item = [self itemForRow:indexPath.row];
    if (item && item.handler) item.handler(self);
}

// Editing mode: every whitelist row gets a red minus on its leading edge;
// tapping it bounces out the same red Delete button the swipe-left
// interaction used to reveal.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.swipeToDelete && [self itemForRow:indexPath.row] != nil;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return (self.swipeToDelete && [self itemForRow:indexPath.row] != nil) ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return LOC(@"SB_WHITELIST_DELETE");
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    YMSBCardItem *item = [self itemForRow:indexPath.row];
    if (!item) return;
    // Model change first (onDeleteItem no longer touches the UI), then drop
    // the item from the backing list and animate the row sliding out — a full
    // reloadData here would cut the animation off.
    if (self.onDeleteItem) self.onDeleteItem(self, item);
    NSMutableArray<YMSBCardItem *> *remaining = [self.allItems mutableCopy];
    [remaining removeObject:item];
    self.allItems = remaining;
    [self refilterItemsWithReload:NO];
    [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationLeft];
    [self sbUpdateEmptyState];
}

- (void)reloadItems {
    [self.tableView reloadData];
}

- (void)dismissCard {
    UIViewController *panel = sbEngagementPanelFor(self);
    if (panel) {
        [(YTEngagementPanelViewControllerImpl *)panel didTapCloseButton];
        return;
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

static UINavigationController *sbCardNavigationController(YMSBCardViewController *card) {
    UINavigationController *nav = [[YMSBCardNavigationController alloc] initWithRootViewController:card];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;

    // YouTube restyles navigation bars app-wide (appearance proxies), which
    // can leave a sheet's title invisible. Give our bar an explicit dynamic
    // title color and a background matching the grouped table so the header
    // blends seamlessly into the dialog.
    UIColor *headerBackground = [UIColor systemGroupedBackgroundColor];
    NSMutableDictionary *titleAttributes = [[NSMutableDictionary alloc] init];
    titleAttributes[NSForegroundColorAttributeName] = [UIColor labelColor];
    // Same size as the × close button (16pt), but bold so the title reads
    // heavier than the icon.
    titleAttributes[NSFontAttributeName] = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    UINavigationBarAppearance *barAppearance = [[UINavigationBarAppearance alloc] init];
    [barAppearance configureWithOpaqueBackground];
    barAppearance.backgroundColor = headerBackground;
    barAppearance.shadowColor = [UIColor clearColor];
    barAppearance.titleTextAttributes = titleAttributes;
    nav.navigationBar.standardAppearance = barAppearance;
    nav.navigationBar.scrollEdgeAppearance = barAppearance;
    nav.navigationBar.titleTextAttributes = titleAttributes;
    nav.navigationBar.prefersLargeTitles = NO;
    return nav;
}

+ (UINavigationController *)presentCard:(YMSBCardViewController *)card {
    UINavigationController *nav = sbCardNavigationController(card);
    UIViewController *presenter = YouModTopViewController(nil);
    while (presenter.presentedViewController) {
        presenter = presenter.presentedViewController;
    }
    [presenter presentViewController:nav animated:YES completion:nil];
    return nav;
}

+ (void)presentCardInEngagementPanel:(YMSBCardViewController *)card fromResponder:(id)responder {
    if (!sbEngagementPanelClass()) {
        [self presentCard:card];
        return;
    }
    sbEngagementPanelNav = sbCardNavigationController(card);
    [[%c(YTCommandResponderEvent) eventWithCommand:sbEngagementPanelShowCommand(card.cardTitle) fromView:nil entry:nil sendClick:NO firstResponder:responder] send];
}

@end

#pragma mark - YTPlayerViewController menu hooks

%hook YTPlayerViewController

// The YouTube-style bottom sheet opened from the overlay shield button.
%new
- (void)sbShowMainMenuFromView:(UIView *)sourceView {
    if (self.isPlayingAd) return;

    BOOL active = sbActiveForVideo(self);
    UIViewController *presenter = (UIViewController *)[self activeVideoPlayerOverlay];
    YTDefaultSheetController *sheet = [%c(YTDefaultSheetController) sheetControllerWithParentResponder:presenter];

    __weak typeof(self) weakSelf = self;

    // Whitelisted channel: SponsorBlock is fully overridden, so the enable/
    // disable toggle is meaningless — only whitelist management is offered.
    NSString *menuChannelID = sbCurrentChannelID(self);
    BOOL channelListed = menuChannelID.length > 0 && sbIsChannelWhitelisted(menuChannelID);

    if (!channelListed) {
        YTActionSheetAction *toggleAction = [%c(YTActionSheetAction) actionWithTitle:LOC(active ? @"SB_MENU_DISABLE" : @"SB_MENU_ENABLE")
                                                                            iconImage:sbSheetIcon(active ? @"shield" : @"shield.slash")
                                                                                 style:0
                                                                              handler:^(__unused YTActionSheetAction *action) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            BOOL newState = !active;
            [[NSUserDefaults standardUserDefaults] setBool:newState forKey:SBButtonKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            if (newState && strongSelf.sbSegments.count == 0) {
                [SBRequest fetchSegmentsForVideoID:[strongSelf currentVideoID] completion:^(NSArray<SBSegment *> *segments) {
                    __strong typeof(weakSelf) ss = weakSelf;
                    if (!ss) return;
                    ss.sbSegments = segments;
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"SBSegmentsDidLoad"
                                                                        object:ss
                                                                      userInfo:@{@"segments": segments ?: @[]}];
                }];
            } else {
                if (!newState) strongSelf.sbSegments = nil;
                NSArray *segments = newState ? (strongSelf.sbSegments ?: @[]) : @[];
                [[NSNotificationCenter defaultCenter] postNotificationName:@"SBSegmentsDidLoad"
                                                                    object:strongSelf
                                                                  userInfo:@{@"segments": segments}];
            }
            [[NSNotificationCenter defaultCenter] postNotificationName:@"YouModUpdateTimeLabel" object:nil];
        }];
        [sheet addAction:toggleAction];
    }

    if (active && self.sbSegments.count > 0) {
        YTActionSheetAction *voteAction = [%c(YTActionSheetAction) actionWithTitle:LOC(@"SB_MENU_VOTE")
                                                                          iconImage:sbSheetIcon(@"hand.thumbsup")
                                                                               style:0
                                                                            handler:^(__unused YTActionSheetAction *action) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) [strongSelf sbShowVoteCard];
        }];
        [sheet addAction:voteAction];
    }

    if (active) {
        YTActionSheetAction *submitAction = [%c(YTActionSheetAction) actionWithTitle:LOC(@"SB_MENU_SUBMIT")
                                                                            iconImage:sbSheetIcon(@"plus.circle")
                                                                                 style:0
                                                                              handler:^(__unused YTActionSheetAction *action) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) [strongSelf sbShowSubmitCard];
        }];
        [sheet addAction:submitAction];
    }

    YTActionSheetAction *whitelistAction = [%c(YTActionSheetAction) actionWithTitle:LOC(channelListed ? @"SB_WHITELIST_REMOVE" : @"SB_WHITELIST_ADD")
                                                                            iconImage:sbSheetIcon(channelListed ? @"checkmark.seal.fill" : @"checkmark.seal")
                                                                                 style:0
                                                                              handler:^(__unused YTActionSheetAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) [strongSelf sbToggleWhitelistFromMenu];
    }];
    [sheet addAction:whitelistAction];

    [sheet presentFromView:sourceView animated:YES completion:nil];
}

// выборы, выборы, кандидаты пидоры
static void sbHandleVoteResult(YTPlayerViewController *player, SBSegment *droppedSegment, NSString *videoID, BOOL success, NSString *errorMessage) {
    if (!success) {
        NSString *reason = errorMessage.length > 0 ? [NSString stringWithFormat:@"%@ — %@", LOC(@"SB_VOTE_FAILED"), errorMessage] : LOC(@"SB_VOTE_FAILED");
        sbShowSBPill(reason, NO);
        return;
    }
    sbInvalidateSegmentCache(videoID);
    sbShowSBPill(LOC(@"SB_VOTE_SUCCESS"), YES);
    if (!player || !droppedSegment || ![[player currentVideoID] isEqualToString:videoID]) return;
    NSMutableArray *remaining = [player.sbSegments mutableCopy];
    [remaining removeObject:droppedSegment];
    player.sbSegments = remaining;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SBSegmentsDidLoad"
                                                        object:player
                                                      userInfo:@{@"segments": remaining ?: @[]}];
}

// Form-sheet card listing every loaded segment (categories the user enabled);
// tapping one pushes the vote options screen.
%new
- (void)sbShowVoteCard {
    NSArray<SBSegment *> *segments = [self.sbSegments sortedArrayUsingComparator:^NSComparisonResult(SBSegment *a, SBSegment *b) {
        if (a.startTime == b.startTime) return NSOrderedSame;
        return a.startTime < b.startTime ? NSOrderedAscending : NSOrderedDescending;
    }];
    if (segments.count == 0) {
        sbShowSBPill(LOC(@"SB_VOTE_NO_SEGMENTS"), NO);
        return;
    }

    __weak typeof(self) weakSelf = self;
    YMSBCardViewController *card = [[YMSBCardViewController alloc] init];
    card.cardTitle = LOC(@"SB_VOTE_TITLE");
    UISearchBar *searchBar = [[UISearchBar alloc] init];
    searchBar.placeholder = LOC(@"SEARCH");
    card.searchBar = searchBar;
    NSMutableArray<YMSBCardItem *> *items = [NSMutableArray array];
    for (SBSegment *segment in segments) {
        NSString *catName = sbLocalizedCategoryName(segment.category);
        NSString *subtitle = [NSString stringWithFormat:@"%@ – %@  ·  %@",
                              sbFormatTime(segment.startTime),
                              sbFormatTime(segment.endTime),
                              [NSString stringWithFormat:LOC(@"SB_VOTES_COUNT"), (long)segment.votes]];
        [items addObject:[YMSBCardItem itemWithImage:sbDotImage(segment.segmentColor)
                                                title:catName
                                             subtitle:subtitle
                                            tintColor:[UIColor labelColor]
                                               handler:^(YMSBCardViewController *c) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) [strongSelf sbPushVoteOptionsForSegment:segment fromCard:c];
        }]];
    }
    card.items = items;
    [YMSBCardViewController presentCard:card];
}

// Vote options for one segment, pushed onto the card's navigation stack.
%new
- (void)sbPushVoteOptionsForSegment:(SBSegment *)segment fromCard:(YMSBCardViewController *)card {
    __weak typeof(self) weakSelf = self;
    NSString *segmentInfo = [NSString stringWithFormat:@"%@ – %@",
                             sbFormatTime(segment.startTime),
                             sbFormatTime(segment.endTime)];

    void (^voteHandler)(NSInteger) = ^(NSInteger type) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [card dismissCard];
        if (!strongSelf) return;
        NSString *videoID = [strongSelf currentVideoID];
        [SBRequest voteOnSegment:segment videoID:videoID type:type completion:^(BOOL success, NSString *errorMessage) {
            sbHandleVoteResult(weakSelf, type == 0 ? segment : nil, videoID, success, errorMessage);
        }];
    };

    BOOL canChangeCategory = ![segment.actionType isEqualToString:@"poi"] && ![segment.actionType isEqualToString:@"full"];

    YMSBCardViewController *options = [[YMSBCardViewController alloc] init];
    options.cardTitle = sbLocalizedCategoryName(segment.category);
    NSMutableArray<YMSBCardItem *> *optionItems = [@[
        [YMSBCardItem itemWithImage:sbSymbolImage(@"hand.thumbsup.fill")
                               title:LOC(@"SB_VOTE_UPVOTE")
                            subtitle:segmentInfo
                           tintColor:[UIColor systemGreenColor]
                              handler:^(__unused YMSBCardViewController *c) { voteHandler(1); }],
        [YMSBCardItem itemWithImage:sbSymbolImage(@"hand.thumbsdown.fill")
                               title:LOC(@"SB_VOTE_DOWNVOTE")
                            subtitle:segmentInfo
                           tintColor:[UIColor systemRedColor]
                              handler:^(__unused YMSBCardViewController *c) { voteHandler(0); }],
        [YMSBCardItem itemWithImage:sbSymbolImage(@"arrow.uturn.backward")
                               title:LOC(@"SB_VOTE_UNDO")
                            subtitle:segmentInfo
                           tintColor:[UIColor labelColor]
                              handler:^(__unused YMSBCardViewController *c) { voteHandler(20); }],
        [YMSBCardItem itemWithImage:sbSymbolImage(@"backward.end.fill")
                               title:LOC(@"SB_VOTE_JUMP_START")
                            subtitle:segmentInfo
                           tintColor:[UIColor labelColor]
                              handler:^(__unused YMSBCardViewController *c) {
            // Jumping keeps the card open so the user can keep browsing or
            // vote right after scrubbing around.
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) [strongSelf seekToTime:(CGFloat)segment.startTime];
        }],
        [YMSBCardItem itemWithImage:sbSymbolImage(@"forward.end.fill")
                               title:LOC(@"SB_VOTE_JUMP_END")
                            subtitle:segmentInfo
                           tintColor:[UIColor labelColor]
                              handler:^(__unused YMSBCardViewController *c) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) [strongSelf seekToTime:(CGFloat)segment.endTime];
        }],
    ] mutableCopy];
    if (canChangeCategory) {
        [optionItems insertObject:[YMSBCardItem itemWithImage:sbSymbolImage(@"tag")
                                                        title:LOC(@"SB_VOTE_CHANGE_CATEGORY")
                                                     subtitle:segmentInfo
                                                    tintColor:[UIColor labelColor]
                                                      handler:^(YMSBCardViewController *c) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) [strongSelf sbPushCategoryPickerForSegment:segment fromCard:c];
        }] atIndex:3];
    }
    options.items = optionItems;
    [card.navigationController pushViewController:options animated:YES];
}

// Category picker for a category vote, pushed onto the card's navigation stack.
%new
- (void)sbPushCategoryPickerForSegment:(SBSegment *)segment fromCard:(YMSBCardViewController *)card {
    __weak typeof(self) weakSelf = self;

    NSMutableArray<YMSBCardItem *> *items = [NSMutableArray array];
    for (NSString *category in sbAllCategories()) {
        if ([category isEqualToString:segment.category] || [category isEqualToString:@"poi_highlight"] || [category isEqualToString:@"exclusive_access"]) continue;
        NSString *hex = [[NSUserDefaults standardUserDefaults] stringForKey:SB_COLOR_KEY(category)];
        UIColor *color = hex ? SBColorFromHex(hex) : [UIColor whiteColor];
        [items addObject:[YMSBCardItem itemWithImage:sbDotImage(color)
                                               title:sbLocalizedCategoryName(category)
                                            subtitle:nil
                                           tintColor:[UIColor labelColor]
                                              handler:^(__unused YMSBCardViewController *c) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [card dismissCard];
            if (!strongSelf) return;
            NSString *videoID = [strongSelf currentVideoID];
            [SBRequest voteCategoryOnSegment:segment videoID:videoID category:category completion:^(BOOL success, NSString *errorMessage) {
                sbHandleVoteResult(weakSelf, nil, videoID, success, errorMessage);
            }];
        }]];
    }

    YMSBCardViewController *picker = [[YMSBCardViewController alloc] init];
    picker.cardTitle = LOC(@"SB_VOTE_CHANGE_CATEGORY");
    picker.items = items;
    [card.navigationController pushViewController:picker animated:YES];
}

// −1 / −0.1 / +0.1 / +1 second buttons for fine-tuning a marked time.
static UIView *sbNudgeControls(void (^nudge)(float delta)) {
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 4;
    for (NSNumber *delta in @[@(-1.0f), @(-0.1f), @(0.1f), @(1.0f)]) {
        float d = delta.floatValue;
        NSString *title = [NSString stringWithFormat:@"%@%@", d < 0 ? @"\u2212" : @"+", fabsf(d) < 1 ? @".1" : @"1"];
        UIButton *button = [UIButton systemButtonWithPrimaryAction:[UIAction actionWithTitle:title image:nil identifier:nil handler:^(__unused UIAction *action) {
            nudge(d);
        }]];
        button.titleLabel.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightSemibold];
        button.tintColor = [UIColor systemPurpleColor];
        button.backgroundColor = [UIColor tertiarySystemFillColor];
        button.layer.cornerRadius = 8;
        [button.widthAnchor constraintEqualToConstant:36].active = YES;
        [button.heightAnchor constraintEqualToConstant:32].active = YES;
        [stack addArrangedSubview:button];
    }
    stack.frame = CGRectMake(0, 0, 4 * 36 + 3 * 4, 32);
    return stack;
}

// New-segment draft for the current video (-1 means not set yet)
%property (nonatomic, strong) NSMutableDictionary *sbDraft;

%new
- (void)sbShowSubmitCard {
    NSString *videoID = [self currentVideoID];
    if (videoID.length == 0) return;
    if (![self.sbDraft[@"videoID"] isEqualToString:videoID]) {
        self.sbDraft = [@{@"videoID": videoID, @"category": @"sponsor", @"start": @(-1), @"end": @(-1)} mutableCopy];
    }
    YMSBCardViewController *card = [[YMSBCardViewController alloc] init];
    card.cardTitle = LOC(@"SB_SUBMIT_TITLE");
    card.message = LOC(@"SB_SUBMIT_MESSAGE");
    card.items = [self sbSubmitItemsForCard:card];
    [YMSBCardViewController presentCardInEngagementPanel:card fromResponder:self];
}

%new
- (NSArray<YMSBCardItem *> *)sbSubmitItemsForCard:(YMSBCardViewController *)card {
    __weak typeof(self) weakSelf = self;
    NSMutableDictionary *draft = self.sbDraft;
    NSString *category = draft[@"category"];
    float start = [draft[@"start"] floatValue];
    float end = [draft[@"end"] floatValue];
    BOOL isPoi = [category isEqualToString:@"poi_highlight"];
    BOOL isFull = [category isEqualToString:@"exclusive_access"];
    NSString *unset = LOC(@"SB_SUBMIT_NOT_SET");

    // Weak card: the items built here hold this block, and the card holds them.
    __weak YMSBCardViewController *weakCard = card;
    void (^refresh)(void) = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        YMSBCardViewController *strongCard = weakCard;
        if (strongSelf && strongCard) strongCard.items = [strongSelf sbSubmitItemsForCard:strongCard];
    };

    // Shifts a marked time and seeks there, so the exact frame is visible.
    void (^nudge)(NSString *, float) = ^(NSString *key, float delta) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        float duration = (float)[strongSelf currentVideoTotalMediaTime];
        float value = MAX(0.0f, [draft[key] floatValue] + delta);
        if (duration > 0) value = MIN(value, duration);
        draft[key] = @(value);
        [strongSelf seekToTime:(CGFloat)value];
        refresh();
    };

    NSString *hex = [[NSUserDefaults standardUserDefaults] stringForKey:SB_COLOR_KEY(category)];
    NSMutableArray<YMSBCardItem *> *items = [NSMutableArray array];
    [items addObject:[YMSBCardItem itemWithImage:sbDotImage(hex ? SBColorFromHex(hex) : [UIColor whiteColor])
                                           title:sbLocalizedCategoryName(category)
                                        subtitle:LOC(@"SB_SUBMIT_CATEGORY")
                                       tintColor:[UIColor labelColor]
                                         handler:^(YMSBCardViewController *c) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSMutableArray<YMSBCardItem *> *pickerItems = [NSMutableArray array];
        for (NSString *cat in sbAllCategories()) {
            NSString *catHex = [[NSUserDefaults standardUserDefaults] stringForKey:SB_COLOR_KEY(cat)];
            [pickerItems addObject:[YMSBCardItem itemWithImage:sbDotImage(catHex ? SBColorFromHex(catHex) : [UIColor whiteColor])
                                                         title:sbLocalizedCategoryName(cat)
                                                      subtitle:nil
                                                     tintColor:[UIColor labelColor]
                                                       handler:^(YMSBCardViewController *picker) {
                draft[@"category"] = cat;
                refresh();
                [picker.navigationController popViewControllerAnimated:YES];
            }]];
        }
        YMSBCardViewController *picker = [[YMSBCardViewController alloc] init];
        picker.cardTitle = LOC(@"SB_SUBMIT_CATEGORY");
        picker.items = pickerItems;
        [c.navigationController pushViewController:picker animated:YES];
    }]];

    if (!isFull) {
        [items addObject:[YMSBCardItem itemWithImage:sbSymbolImage(@"arrow.right.to.line")
                                               title:LOC(isPoi ? @"SB_SUBMIT_SET_HIGHLIGHT" : @"SB_SUBMIT_SET_START")
                                            subtitle:start >= 0 ? sbFormatPreciseTime(start) : unset
                                           tintColor:[UIColor labelColor]
                                             handler:^(__unused YMSBCardViewController *c) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            draft[@"start"] = @([strongSelf currentVideoMediaTime]);
            refresh();
        }]];
        if (start >= 0) items.lastObject.accessoryView = sbNudgeControls(^(float delta) { nudge(@"start", delta); });
    }
    if (!isFull && !isPoi) {
        [items addObject:[YMSBCardItem itemWithImage:sbSymbolImage(@"arrow.left.to.line")
                                               title:LOC(@"SB_SUBMIT_SET_END")
                                            subtitle:end >= 0 ? sbFormatPreciseTime(end) : unset
                                           tintColor:[UIColor labelColor]
                                             handler:^(__unused YMSBCardViewController *c) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            draft[@"end"] = @([strongSelf currentVideoMediaTime]);
            refresh();
        }]];
        if (end >= 0) items.lastObject.accessoryView = sbNudgeControls(^(float delta) { nudge(@"end", delta); });
    }
    if (!isFull && start >= 0) {
        [items addObject:[YMSBCardItem itemWithImage:sbSymbolImage(@"play.circle")
                                               title:LOC(@"SB_SUBMIT_PREVIEW")
                                            subtitle:nil
                                           tintColor:[UIColor labelColor]
                                             handler:^(__unused YMSBCardViewController *c) {
            // Plays from just before the start so the transition can be
            // checked; the half sheet stays open over the visible player.
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf seekToTime:(CGFloat)MAX(0.0f, start - 2.0f)];
        }]];
    }

    [items addObject:[YMSBCardItem itemWithImage:sbSymbolImage(@"paperplane.fill")
                                           title:LOC(@"SB_SUBMIT_SEND")
                                        subtitle:nil
                                       tintColor:[UIColor systemPurpleColor]
                                         handler:^(YMSBCardViewController *c) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        float submitStart = isFull ? 0 : start;
        float submitEnd = isFull ? 0 : (isPoi ? start : end);
        BOOL valid = isFull || (isPoi ? submitStart >= 0 : (submitStart >= 0 && submitEnd > submitStart));
        if (!valid) {
            sbShowSBPill(LOC(@"SB_SUBMIT_INVALID"), NO);
            return;
        }
        NSString *videoID = draft[@"videoID"];
        [c dismissCard];
        [SBRequest submitSegmentForVideoID:videoID
                                  category:category
                                     start:submitStart
                                       end:submitEnd
                                  duration:(float)[strongSelf currentVideoTotalMediaTime]
                                completion:^(BOOL success, NSString *errorMessage) {
            __strong typeof(weakSelf) ss = weakSelf;
            if (!success) {
                NSString *reason = errorMessage.length > 0 ? [NSString stringWithFormat:@"%@ — %@", LOC(@"SB_SUBMIT_FAILED"), errorMessage] : LOC(@"SB_SUBMIT_FAILED");
                sbShowSBPill(reason, NO);
                return;
            }
            sbShowSBPill(LOC(@"SB_SUBMIT_SUCCESS"), YES);
            if (!ss) return;
            ss.sbDraft = nil;
            if ([[ss currentVideoID] isEqualToString:videoID]) sbPostSegmentsForPlayer(ss, YES);
        }];
    }]];
    return items;
}

// Adds/removes the current channel to/from the whitelist directly from the
// video menu, with a success pill as feedback (no confirmation card).
%new
- (void)sbToggleWhitelistFromMenu {
    NSString *channelID = sbCurrentChannelID(self);
    if (channelID.length == 0) {
        sbShowSBPill(LOC(@"SB_VOTE_FAILED"), NO);
        return;
    }
    NSString *channelName = sbCurrentChannelName(self) ?: channelID;
    BOOL wasListed = sbIsChannelWhitelisted(channelID);
    sbSetChannelWhitelisted(channelID, channelName, !wasListed);

    // Removing the whitelist brings skipping/markers back for the video
    // being watched right now; adding it clears them.
    sbPostSegmentsForPlayer(self, wasListed);

    sbShowSBPill(LOC(wasListed ? @"SB_WHITELIST_REMOVE" : @"SB_WHITELIST_ADD"), YES);
}

%end

#pragma mark - Whitelist manager (tab bar entry)

static NSArray<YMSBCardItem *> *sbWhitelistManagerItems(void) {
    NSDictionary *whitelist = sbWhitelistDictionary();
    NSArray *channelIDs = [whitelist.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    NSMutableArray<YMSBCardItem *> *items = [NSMutableArray array];
    for (NSString *channelID in channelIDs) {
        // No icon on whitelist rows — just the channel name and its ID.
        [items addObject:[YMSBCardItem itemWithImage:nil
                                                title:whitelist[channelID]
                                             subtitle:channelID
                                            tintColor:nil
                                               handler:nil]];
        items.lastObject.identifier = channelID;
    }
    return items;
}

void YMSBPresentWhitelistManager(void) {
    YMSBCardViewController *card = [[YMSBCardViewController alloc] init];
    card.cardTitle = LOC(@"SB_WHITELIST_MANAGE");
    card.swipeToDelete = YES;

    UISearchBar *searchBar = [[UISearchBar alloc] init];
    searchBar.placeholder = LOC(@"SEARCH");
    card.searchBar = searchBar;
    card.emptyText = LOC(@"SB_WHITELIST_EMPTY");
    card.items = sbWhitelistManagerItems();

    card.onDeleteItem = ^(YMSBCardViewController *c, YMSBCardItem *item) {
        // Model only — the card animates the row out itself.
        if (item.identifier.length > 0) {
            sbSetChannelWhitelisted(item.identifier, item.title, NO);
        }
        sbRefreshPlayerAfterWhitelistChange();
    };

    [YMSBCardViewController presentCard:card];
}

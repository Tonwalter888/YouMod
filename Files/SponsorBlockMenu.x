#import "Headers.h"
#import <CommonCrypto/CommonDigest.h>

// SponsorBlock menu: the shield button opens a YouTube-style bottom sheet (toggle, voting, whitelist);
// sub-screens push onto our form-sheet card dialog (YMSBCardViewController), a nav stack with a table.

// Our engagement panel's ID and the nav controller currently shown in it (see the hooks below).
static NSString * const SBEngagementPanelID = @"youmod-sponsorblock";
static UINavigationController *sbEngagementPanelNav = nil;

// Menu helpers (see YMSBMenuHelpers.h).
@implementation YMSBMenuHelpers

#pragma mark - Small helpers

+ (NSString *)formatTime:(float)t {
    NSInteger total = (NSInteger)lroundf(t);
    if (total < 0) total = 0;
    NSInteger h = total / 3600;
    NSInteger m = (total % 3600) / 60;
    NSInteger s = total % 60;
    if (h > 0) return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)h, (long)m, (long)s];
    return [NSString stringWithFormat:@"%ld:%02ld", (long)m, (long)s];
}

// Like formatTime but with tenths, for marking segment boundaries.
+ (NSString *)formatPreciseTime:(float)t {
    if (t < 0) t = 0;
    NSInteger tenths = (NSInteger)lroundf(t * 10.0f);
    NSInteger total = tenths / 10;
    NSInteger h = total / 3600;
    NSInteger m = (total % 3600) / 60;
    NSInteger sec = total % 60;
    if (h > 0) return [NSString stringWithFormat:@"%ld:%02ld:%02ld.%ld", (long)h, (long)m, (long)sec, (long)(tenths % 10)];
    return [NSString stringWithFormat:@"%ld:%02ld.%ld", (long)m, (long)sec, (long)(tenths % 10)];
}

+ (NSString *)localizedCategoryName:(NSString *)category {
    return [[YMHelpers bundle] localizedStringForKey:[NSString stringWithFormat:@"SB_CAT_%@", category ?: @""]
                                            value:category
                                            table:nil];
}

+ (UIImage *)symbolImage:(NSString *)symbolName {
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
    return [[UIImage systemImageNamed:symbolName withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

+ (UIImage *)dotImage:(UIColor *)color {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(18, 18)];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(2, 2, 14, 14)];
        [color setFill];
        [path fill];
    }];
}

// Uniform icon size for the YouTube action sheet: each SF Symbol rendered into an exact 24x24 canvas.
+ (UIImage *)sheetIcon:(NSString *)symbolName {
    return [YMHelpers symbolImageInCanvas:symbolName canvasSize:24 pointSize:22 weight:UIImageSymbolWeightMedium];
}

#pragma mark - User ID hashing

// SHA-256 5000 times (SponsorBlock spec) — the public userID derived from the private one.
+ (NSString *)hashPublicFromPrivate:(NSString *)privateID {
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

#pragma mark - Whitelist + channel info

// Same as Download.x's YouModPlayerDataForPlayer: contentPlayerResponse when available, playerResponse otherwise.
+ (YTIPlayerResponse *)playerDataForPlayer:(YTPlayerViewController *)player {
    YTPlayerResponse *response;
    if ([player respondsToSelector:@selector(contentPlayerResponse)]) {
        response = player.contentPlayerResponse;
    } else {
        response = player.playerResponse;
    }
    return response.playerData;
}

+ (NSString *)currentChannelID:(YTPlayerViewController *)player {
    return [YMSBMenuHelpers playerDataForPlayer:player].videoDetails.channelId;
}

+ (NSString *)currentChannelName:(YTPlayerViewController *)player {
    return [YMSBMenuHelpers playerDataForPlayer:player].videoDetails.author;
}

+ (NSDictionary *)whitelistDictionary {
    NSDictionary *dict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:SBWhitelistKey];
    return dict ?: @{};
}

+ (void)saveWhitelistDictionary:(NSDictionary *)dict {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (dict.count == 0) {
        [defaults removeObjectForKey:SBWhitelistKey];
    } else {
        [defaults setObject:dict forKey:SBWhitelistKey];
    }
    [defaults synchronize];
}

+ (BOOL)isChannelWhitelisted:(NSString *)channelID {
    if (channelID.length == 0) return NO;
    return [YMSBMenuHelpers whitelistDictionary][channelID] != nil;
}

+ (void)setChannelWhitelisted:(NSString *)channelID channelName:(NSString *)channelName whitelisted:(BOOL)whitelisted {
    if (channelID.length == 0) return;
    NSMutableDictionary *dict = [[YMSBMenuHelpers whitelistDictionary] mutableCopy];
    if (whitelisted) {
        dict[channelID] = channelName.length > 0 ? channelName : channelID;
    } else {
        [dict removeObjectForKey:channelID];
    }
    [YMSBMenuHelpers saveWhitelistDictionary:dict];
}

// Posts a fresh segments notification: fetches segments when SB is (back) on, clears markers when off/whitelisted.
+ (void)postSegmentsForPlayer:(YTPlayerViewController *)player enabled:(BOOL)enabled {
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

// Re-syncs the current video after a whitelist change so skipping/markers update immediately.
+ (void)refreshPlayerAfterWhitelistChange {
    YTPlayerViewController *player = YouModCurrentPlayerViewController;
    if (!player) return;
    NSString *channelID = [YMSBMenuHelpers currentChannelID:player];
    BOOL listed = channelID.length > 0 && [YMSBMenuHelpers isChannelWhitelisted:channelID];
    [YMSBMenuHelpers postSegmentsForPlayer:player enabled:!listed];
}

#pragma mark - SBRequest (Write) plumbing

+ (NSString *)queryValue:(NSString *)value {
    static NSCharacterSet *allowed;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableCharacterSet *set = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
        [set removeCharactersInString:@"&=+?"];
        allowed = set;
    });
    return [value ?: @"" stringByAddingPercentEncodingWithAllowedCharacters:allowed];
}

// All parameters go in the URL query string per the SponsorBlock API; failed requests carry a plain-text reason in the body (400/403).
+ (void)postQuery:(NSString *)path params:(NSDictionary<NSString *, NSString *> *)params completion:(void (^)(BOOL success, NSInteger status, NSString *errorMessage))completion {
    NSMutableArray *pairs = [NSMutableArray array];
    [params enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, __unused BOOL *stop) {
        [pairs addObject:[NSString stringWithFormat:@"%@=%@", key, [YMSBMenuHelpers queryValue:value]]];
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

#pragma mark - Engagement panel

+ (YTICommand *)engagementPanelShowCommand:(NSString *)title {
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

    // The endpoint is a YTICommand extension whose descriptor YouTube keeps in a C static (no ObjC accessor) — encode it as that extension field on the wire and let YouTube's parser attach it.
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

+ (Class)engagementPanelClass {
    return %c(YTEngagementPanelViewControllerImpl) ?: %c(YTMainAppEngagementPanelViewController);
}

+ (UIViewController *)engagementPanelFor:(UIViewController *)card {
    UIViewController *panel = card.navigationController.parentViewController;
    return [panel isKindOfClass:[YMSBMenuHelpers engagementPanelClass]] ? panel : nil;
}

+ (BOOL)isOurPanelModel:(id)model {
    // panelIdentifier is a YTEngagementPanelIdentifier here, not the endpoint's NSString of the same name.
    YTEngagementPanelIdentifier *panelID = ((id (*)(id, SEL))objc_msgSend)(model, @selector(panelIdentifier));
    return sbEngagementPanelNav && [panelID.identifierString isEqualToString:SBEngagementPanelID];
}

#pragma mark - Card + voting

// YouTube restyles navigation bars app-wide and can leave a sheet's title invisible; give our bar explicit dynamic colors and a grouped-table background.
+ (UINavigationController *)cardNavigationController:(YMSBCardViewController *)card {
    UINavigationController *nav = [[YMSBCardNavigationController alloc] initWithRootViewController:card];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;

    UIColor *headerBackground = card.sbUsesSubmitColors
        ? [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
            return trait.userInterfaceStyle == UIUserInterfaceStyleDark ? [%c(YTColor) black3] : [UIColor whiteColor];
        }]
        : [UIColor systemGroupedBackgroundColor];
    NSMutableDictionary *titleAttributes = [[NSMutableDictionary alloc] init];
    titleAttributes[NSForegroundColorAttributeName] = [UIColor labelColor];
    // Same size as the × close button (16pt), but bold so the title reads heavier than the icon.
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

// выборы, выборы, кандидаты пидоры
+ (void)handleVoteResult:(YTPlayerViewController *)player droppedSegment:(SBSegment *)droppedSegment videoID:(NSString *)videoID success:(BOOL)success errorMessage:(NSString *)errorMessage {
    if (!success) {
        NSString *reason = errorMessage.length > 0 ? [NSString stringWithFormat:@"%@ — %@", LOC(@"SB_VOTE_FAILED"), errorMessage] : LOC(@"SB_VOTE_FAILED");
        YouModShowPill(reason, NO);
        return;
    }
    sbInvalidateSegmentCache(videoID);
    YouModShowPill(LOC(@"SB_VOTE_SUCCESS"), YES);
    if (!player || !droppedSegment || ![[player currentVideoID] isEqualToString:videoID]) return;
    NSMutableArray *remaining = [player.sbSegments mutableCopy];
    [remaining removeObject:droppedSegment];
    player.sbSegments = remaining;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"SBSegmentsDidLoad"
                                                        object:player
                                                      userInfo:@{@"segments": remaining ?: @[]}];
}

// −1 / −0.1 / +0.1 / +1 second buttons for fine-tuning a marked time.
+ (UIView *)nudgeControls:(void (^)(float delta))nudge {
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
        button.tintColor = [YMHelpers accentColor];
        button.backgroundColor = [UIColor tertiarySystemFillColor];
        button.layer.cornerRadius = 8;
        [button.widthAnchor constraintEqualToConstant:36].active = YES;
        [button.heightAnchor constraintEqualToConstant:32].active = YES;
        [stack addArrangedSubview:button];
    }
    stack.frame = CGRectMake(0, 0, 4 * 36 + 3 * 4, 32);
    return stack;
}

#pragma mark - Whitelist manager

+ (NSArray<YMSBCardItem *> *)whitelistManagerItems {
    NSDictionary *whitelist = [YMSBMenuHelpers whitelistDictionary];
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

@end

#pragma mark - User ID

NSString *sbLocalUserID(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *userID = [defaults stringForKey:SBPrivateUserIDKey];
    if (userID.length >= 30) return userID;
    // A hyphen-less UUID is 32 hex chars, matching SponsorBlock's local userID requirement.
    userID = [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
    [defaults setObject:userID forKey:SBPrivateUserIDKey];
    return userID;
}

// Caches the derived public ID so a private-ID change is detected and a manual override survives.
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
    value = [YMSBMenuHelpers hashPublicFromPrivate:privateID];
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

BOOL sbActiveForVideo(YTPlayerViewController *player) {
    if (!IS_ENABLED(SBEnabled) || !IS_ENABLED(SBButtonKey)) return NO;
    NSString *channelID = [YMSBMenuHelpers currentChannelID:player];
    if (channelID && [YMSBMenuHelpers isChannelWhitelisted:channelID]) return NO;
    return YES;
}

#pragma mark - SBRequest (Write)

@implementation SBRequest (Write)

+ (void)voteOnSegment:(SBSegment *)segment videoID:(NSString *)videoID type:(NSInteger)voteType completion:(void (^)(BOOL success, NSString *errorMessage))completion {
    if (!segment.UUID.length || !videoID.length) {
        if (completion) completion(NO, nil);
        return;
    }
    [YMSBMenuHelpers postQuery:@"/api/voteOnSponsorTime"
                       params:@{@"UUID": segment.UUID, @"videoID": videoID, @"userID": sbLocalUserID(), @"type": [@(voteType) stringValue]}
                   completion:^(BOOL ok, __unused NSInteger status, NSString *message) { if (completion) completion(ok, message); }];
}

+ (void)voteCategoryOnSegment:(SBSegment *)segment videoID:(NSString *)videoID category:(NSString *)category completion:(void (^)(BOOL success, NSString *errorMessage))completion {
    if (!segment.UUID.length || !videoID.length || category.length == 0) {
        if (completion) completion(NO, nil);
        return;
    }
    [YMSBMenuHelpers postQuery:@"/api/voteOnSponsorTime"
                       params:@{@"UUID": segment.UUID, @"videoID": videoID, @"userID": sbLocalUserID(), @"category": category}
                   completion:^(BOOL ok, __unused NSInteger status, NSString *message) { if (completion) completion(ok, message); }];
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

    [YMSBMenuHelpers postQuery:@"/api/skipSegments" params:params completion:^(BOOL ok, NSInteger status, NSString *message) {
        if (status == 409) message = LOC(@"SB_SUBMIT_DUPLICATE");
        else if (status == 429) message = LOC(@"SB_SUBMIT_RATE_LIMIT");
        if (completion) completion(ok, message);
    }];
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

@implementation YMSBCardNavigationController
- (void)loadWithModel:(id)model {}
@end

%hook YTEngagementPanelViewControllerImpl
- (void)prepareContentViewControllerForModel:(id)model {
    if (![YMSBMenuHelpers isOurPanelModel:model]) {
        %orig;
        return;
    }
    [self setContentViewController:sbEngagementPanelNav];
}
%end

%hook YTMainAppEngagementPanelViewController
- (void)prepareContentViewControllerForModel:(id)model {
    if (![YMSBMenuHelpers isOurPanelModel:model]) {
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

@implementation YMSBCardViewController {
    NSArray<YMSBCardItem *> *_visibleItems;
}

// items is the filtered view of allItems; setting it re-applies the search query so deletions rebuild correctly.
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

// Recomputes the visible list from allItems + the search query; pass NO when the caller animates row changes itself.
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
    if (self.sbUsesSubmitColors) {
        self.view.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
            return trait.userInterfaceStyle == UIUserInterfaceStyleDark ? [%c(YTColor) black3] : [UIColor whiteColor];
        }];
    }

    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithImage:[YMHelpers symbolImageInCanvas:@"xmark" canvasSize:24 pointSize:16 weight:UIImageSymbolWeightMedium]
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(dismissCard)];
    // White in dark mode, black in light mode; re-resolved on appearance changes in sbUpdateCloseButtonColor.
    closeButton.tintColor = [UIColor labelColor];
    self.navigationItem.rightBarButtonItem = closeButton;

    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.rowHeight = UITableViewAutomaticDimension;
    _tableView.estimatedRowHeight = 54;
    _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    _tableView.translatesAutoresizingMaskIntoConstraints = NO;
    if (self.sbUsesSubmitColors) _tableView.backgroundColor = self.view.backgroundColor;
    [self.view addSubview:_tableView];
    [NSLayoutConstraint activateConstraints:@[
        [_tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [_tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    ]];

    // Hold a row ~0.4s to run its longPressHandler (e.g. snap a segment time to 0:00 / video end).
    UILongPressGestureRecognizer *rowHold = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(sbHandleRowHold:)];
    rowHold.minimumPressDuration = 0.4;
    rowHold.delegate = self;
    [_tableView addGestureRecognizer:rowHold];

    if (self.searchBar) {
        self.searchBar.delegate = self;
        // Clear the bar's own background so only the rounded inner field shows.
        self.searchBar.backgroundImage = [[UIImage alloc] init];
        self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;

        // Wrap the bar in a fixed-height header view: a bare search bar as tableHeaderView gets mis-sized on inset-grouped tables.
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
        // Editing mode: a red minus on each row reveals the red Delete button, same as swipe-left.
        _tableView.editing = YES;
        _tableView.allowsSelectionDuringEditing = NO;
    }

    // Centered empty-state text (e.g. "no whitelisted channels"), shown only while empty.
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

// Re-applies trait-dependent field styling (no border, grayer fill in light mode) on theme changes inside a cross-dissolve.
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

// The close button flips white (dark mode) / black (light mode) with a short cross-dissolve.
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
    if ([YMSBMenuHelpers engagementPanelFor:self]) {
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
        if (self.sbUsesSubmitColors) {
            cell.backgroundColor = [UIColor systemGray6Color];
            // Clear fill so the pressed-state selectedBackgroundView shows across the whole cell.
            cell.contentView.backgroundColor = [UIColor clearColor];
            UIView *pressedFill = [[UIView alloc] init];
            pressedFill.backgroundColor = [UIColor systemGray5Color];
            cell.selectedBackgroundView = pressedFill;
        }
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
        if (self.sbUsesSubmitColors) {
            cell.backgroundColor = [UIColor systemGray6Color];
            // Clear fill so the pressed-state selectedBackgroundView shows across the whole cell.
            cell.contentView.backgroundColor = [UIColor clearColor];
            UIView *pressedFill = [[UIView alloc] init];
            pressedFill.backgroundColor = [UIColor systemGray5Color];
            cell.selectedBackgroundView = pressedFill;
        }
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
    if (self.sbUsesSubmitColors) {
        cell.backgroundColor = [UIColor systemGray6Color];
        // Clear fill so the pressed-state selectedBackgroundView shows across the whole cell.
        cell.contentView.backgroundColor = [UIColor clearColor];
        UIView *pressedFill = [[UIView alloc] init];
        pressedFill.backgroundColor = [UIColor systemGray5Color];
        cell.selectedBackgroundView = pressedFill;
    }
    // Re-applied on every pass so reused cells always carry the current dynamic text colors.
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

// Only rows with a longPressHandler take the hold; controls (nudge buttons, fields) keep their own taps.
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view isKindOfClass:[UIControl class]]) return NO;
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:[touch locationInView:self.tableView]];
    return indexPath && [self itemForRow:indexPath.row].longPressHandler != nil;
}

- (void)sbHandleRowHold:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:[gesture locationInView:self.tableView]];
    YMSBCardItem *item = indexPath ? [self itemForRow:indexPath.row] : nil;
    if (!item.longPressHandler) return;
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
    item.longPressHandler(self);
}

// Editing mode: every whitelist row gets a red minus revealing the red Delete button, as in swipe-left.
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
    // Model change first, then drop the item from the backing list and animate the row out; a full reloadData here would cut the animation off.
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
    UIViewController *panel = [YMSBMenuHelpers engagementPanelFor:self];
    if (panel) {
        [(YTEngagementPanelViewControllerImpl *)panel didTapCloseButton];
        return;
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

+ (UINavigationController *)presentCard:(YMSBCardViewController *)card {
    UINavigationController *nav = [YMSBMenuHelpers cardNavigationController:card];
    UIViewController *presenter = [YMHelpers topViewController:nil];
    while (presenter.presentedViewController) {
        presenter = presenter.presentedViewController;
    }
    [presenter presentViewController:nav animated:YES completion:nil];
    return nav;
}

+ (void)presentCardInEngagementPanel:(YMSBCardViewController *)card fromResponder:(id)responder {
    if (![YMSBMenuHelpers engagementPanelClass]) {
        [self presentCard:card];
        return;
    }
    sbEngagementPanelNav = [YMSBMenuHelpers cardNavigationController:card];
    [[%c(YTCommandResponderEvent) eventWithCommand:[YMSBMenuHelpers engagementPanelShowCommand:card.cardTitle] fromView:nil entry:nil sendClick:NO firstResponder:responder] send];
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

    // Whitelisted channel: SponsorBlock is fully overridden, so only whitelist management is offered.
    NSString *menuChannelID = [YMSBMenuHelpers currentChannelID:self];
    BOOL channelListed = menuChannelID.length > 0 && [YMSBMenuHelpers isChannelWhitelisted:menuChannelID];

    if (!channelListed) {
        YTActionSheetAction *toggleAction = [%c(YTActionSheetAction) actionWithTitle:LOC(active ? @"SB_MENU_DISABLE" : @"SB_MENU_ENABLE")
                                                                            iconImage:[YMSBMenuHelpers sheetIcon:(active ? @"shield" : @"shield.slash")]
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
                                                                          iconImage:[YMSBMenuHelpers sheetIcon:@"hand.thumbsup"]
                                                                               style:0
                                                                            handler:^(__unused YTActionSheetAction *action) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) [strongSelf sbShowVoteCard];
        }];
        [sheet addAction:voteAction];
    }

    if (active) {
        YTActionSheetAction *submitAction = [%c(YTActionSheetAction) actionWithTitle:LOC(@"SB_MENU_SUBMIT")
                                                                            iconImage:[YMSBMenuHelpers sheetIcon:@"plus.circle"]
                                                                                 style:0
                                                                              handler:^(__unused YTActionSheetAction *action) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) [strongSelf sbShowSubmitCard];
        }];
        [sheet addAction:submitAction];
    }

    YTActionSheetAction *whitelistAction = [%c(YTActionSheetAction) actionWithTitle:LOC(channelListed ? @"SB_WHITELIST_REMOVE" : @"SB_WHITELIST_ADD")
                                                                            iconImage:[YMSBMenuHelpers sheetIcon:(channelListed ? @"checkmark.seal.fill" : @"checkmark.seal")]
                                                                                 style:0
                                                                              handler:^(__unused YTActionSheetAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) [strongSelf sbToggleWhitelistFromMenu];
    }];
    [sheet addAction:whitelistAction];

    [sheet presentFromView:sourceView animated:YES completion:nil];
}

// Card listing every loaded segment (enabled categories); tapping one pushes the vote options screen.
%new
- (void)sbShowVoteCard {
    NSArray<SBSegment *> *segments = [self.sbSegments sortedArrayUsingComparator:^NSComparisonResult(SBSegment *a, SBSegment *b) {
        if (a.startTime == b.startTime) return NSOrderedSame;
        return a.startTime < b.startTime ? NSOrderedAscending : NSOrderedDescending;
    }];
    if (segments.count == 0) {
        YouModShowPill(LOC(@"SB_VOTE_NO_SEGMENTS"), NO);
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
        NSString *catName = [YMSBMenuHelpers localizedCategoryName:segment.category];
        NSString *subtitle = [NSString stringWithFormat:@"%@ – %@  ·  %@",
                              [YMSBMenuHelpers formatTime:segment.startTime],
                              [YMSBMenuHelpers formatTime:segment.endTime],
                              [NSString stringWithFormat:LOC(@"SB_VOTES_COUNT"), (long)segment.votes]];
        [items addObject:[YMSBCardItem itemWithImage:[YMSBMenuHelpers dotImage:segment.segmentColor]
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
                             [YMSBMenuHelpers formatTime:segment.startTime],
                             [YMSBMenuHelpers formatTime:segment.endTime]];

    void (^voteHandler)(NSInteger) = ^(NSInteger type) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [card dismissCard];
        if (!strongSelf) return;
        NSString *videoID = [strongSelf currentVideoID];
        [SBRequest voteOnSegment:segment videoID:videoID type:type completion:^(BOOL success, NSString *errorMessage) {
            [YMSBMenuHelpers handleVoteResult:weakSelf droppedSegment:(type == 0 ? segment : nil) videoID:videoID success:success errorMessage:errorMessage];
        }];
    };

    BOOL canChangeCategory = ![segment.actionType isEqualToString:@"poi"] && ![segment.actionType isEqualToString:@"full"];

    YMSBCardViewController *options = [[YMSBCardViewController alloc] init];
    options.cardTitle = [YMSBMenuHelpers localizedCategoryName:segment.category];
    NSMutableArray<YMSBCardItem *> *optionItems = [@[
        [YMSBCardItem itemWithImage:[YMSBMenuHelpers symbolImage:@"hand.thumbsup.fill"]
                               title:LOC(@"SB_VOTE_UPVOTE")
                            subtitle:segmentInfo
                           tintColor:[UIColor systemGreenColor]
                              handler:^(__unused YMSBCardViewController *c) { voteHandler(1); }],
        [YMSBCardItem itemWithImage:[YMSBMenuHelpers symbolImage:@"hand.thumbsdown.fill"]
                               title:LOC(@"SB_VOTE_DOWNVOTE")
                            subtitle:segmentInfo
                           tintColor:[UIColor systemRedColor]
                              handler:^(__unused YMSBCardViewController *c) { voteHandler(0); }],
        [YMSBCardItem itemWithImage:[YMSBMenuHelpers symbolImage:@"arrow.uturn.backward"]
                               title:LOC(@"SB_VOTE_UNDO")
                            subtitle:segmentInfo
                           tintColor:[UIColor labelColor]
                              handler:^(__unused YMSBCardViewController *c) { voteHandler(20); }],
        [YMSBCardItem itemWithImage:[YMSBMenuHelpers symbolImage:@"backward.end.fill"]
                               title:LOC(@"SB_VOTE_JUMP_START")
                            subtitle:segmentInfo
                           tintColor:[UIColor labelColor]
                              handler:^(__unused YMSBCardViewController *c) {
            // Jumping keeps the card open so the user can vote right after scrubbing around.
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) [strongSelf seekToTime:(CGFloat)segment.startTime];
        }],
        [YMSBCardItem itemWithImage:[YMSBMenuHelpers symbolImage:@"forward.end.fill"]
                               title:LOC(@"SB_VOTE_JUMP_END")
                            subtitle:segmentInfo
                           tintColor:[UIColor labelColor]
                              handler:^(__unused YMSBCardViewController *c) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) [strongSelf seekToTime:(CGFloat)segment.endTime];
        }],
    ] mutableCopy];
    if (canChangeCategory) {
        [optionItems insertObject:[YMSBCardItem itemWithImage:[YMSBMenuHelpers symbolImage:@"tag"]
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
        [items addObject:[YMSBCardItem itemWithImage:[YMSBMenuHelpers dotImage:color]
                                               title:[YMSBMenuHelpers localizedCategoryName:category]
                                            subtitle:nil
                                           tintColor:[UIColor labelColor]
                                              handler:^(__unused YMSBCardViewController *c) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [card dismissCard];
            if (!strongSelf) return;
            NSString *videoID = [strongSelf currentVideoID];
            [SBRequest voteCategoryOnSegment:segment videoID:videoID category:category completion:^(BOOL success, NSString *errorMessage) {
                [YMSBMenuHelpers handleVoteResult:weakSelf droppedSegment:nil videoID:videoID success:success errorMessage:errorMessage];
            }];
        }]];
    }

    YMSBCardViewController *picker = [[YMSBCardViewController alloc] init];
    picker.cardTitle = LOC(@"SB_VOTE_CHANGE_CATEGORY");
    picker.items = items;
    [card.navigationController pushViewController:picker animated:YES];
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
    card.sbUsesSubmitColors = YES;
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
    [items addObject:[YMSBCardItem itemWithImage:[YMSBMenuHelpers dotImage:(hex ? SBColorFromHex(hex) : [UIColor whiteColor])]
                                           title:[YMSBMenuHelpers localizedCategoryName:category]
                                        subtitle:LOC(@"SB_SUBMIT_CATEGORY")
                                       tintColor:[UIColor labelColor]
                                         handler:^(YMSBCardViewController *c) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        NSMutableArray<YMSBCardItem *> *pickerItems = [NSMutableArray array];
        for (NSString *cat in sbAllCategories()) {
            NSString *catHex = [[NSUserDefaults standardUserDefaults] stringForKey:SB_COLOR_KEY(cat)];
            [pickerItems addObject:[YMSBCardItem itemWithImage:[YMSBMenuHelpers dotImage:(catHex ? SBColorFromHex(catHex) : [UIColor whiteColor])]
                                                         title:[YMSBMenuHelpers localizedCategoryName:cat]
                                                      subtitle:nil
                                                     tintColor:[UIColor labelColor]
                                                       handler:^(YMSBCardViewController *picker) {
                draft[@"category"] = cat;
                refresh();
                [picker.navigationController popViewControllerAnimated:YES];
            }]];
        }
        YMSBCardViewController *picker = [[YMSBCardViewController alloc] init];
        picker.sbUsesSubmitColors = YES;
        picker.cardTitle = LOC(@"SB_SUBMIT_CATEGORY");
        picker.items = pickerItems;
        [c.navigationController pushViewController:picker animated:YES];
    }]];

    if (!isFull) {
        [items addObject:[YMSBCardItem itemWithImage:[YMSBMenuHelpers symbolImage:@"arrow.right.to.line"]
                                               title:LOC(isPoi ? @"SB_SUBMIT_SET_HIGHLIGHT" : @"SB_SUBMIT_SET_START")
                                            subtitle:start >= 0 ? [YMSBMenuHelpers formatPreciseTime:start] : unset
                                           tintColor:[UIColor labelColor]
                                             handler:^(__unused YMSBCardViewController *c) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            draft[@"start"] = @([strongSelf currentVideoMediaTime]);
            refresh();
        }]];
        // Hold: snap the start to 0:00 without touching playback.
        items.lastObject.longPressHandler = ^(__unused YMSBCardViewController *c) {
            draft[@"start"] = @(0);
            refresh();
        };
        if (start >= 0) items.lastObject.accessoryView = [YMSBMenuHelpers nudgeControls:^(float delta) { nudge(@"start", delta); }];
    }
    if (!isFull && !isPoi) {
        [items addObject:[YMSBCardItem itemWithImage:[YMSBMenuHelpers symbolImage:@"arrow.left.to.line"]
                                               title:LOC(@"SB_SUBMIT_SET_END")
                                            subtitle:end >= 0 ? [YMSBMenuHelpers formatPreciseTime:end] : unset
                                           tintColor:[UIColor labelColor]
                                             handler:^(__unused YMSBCardViewController *c) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            draft[@"end"] = @([strongSelf currentVideoMediaTime]);
            refresh();
        }]];
        // Hold: snap the end to the video's last frame without touching playback.
        items.lastObject.longPressHandler = ^(__unused YMSBCardViewController *c) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            float duration = (float)[strongSelf currentVideoTotalMediaTime];
            if (duration <= 0) return;
            draft[@"end"] = @(duration);
            refresh();
        };
        if (end >= 0) items.lastObject.accessoryView = [YMSBMenuHelpers nudgeControls:^(float delta) { nudge(@"end", delta); }];
    }
    if (!isFull && start >= 0) {
        [items addObject:[YMSBCardItem itemWithImage:[YMSBMenuHelpers symbolImage:@"play.circle"]
                                               title:LOC(@"SB_SUBMIT_PREVIEW")
                                            subtitle:nil
                                           tintColor:[UIColor labelColor]
                                             handler:^(__unused YMSBCardViewController *c) {
            // Plays from just before the start so the transition can be checked; the sheet stays open.
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            [strongSelf seekToTime:(CGFloat)MAX(0.0f, start - 2.0f)];
        }]];
    }

    [items addObject:[YMSBCardItem itemWithImage:[YMSBMenuHelpers symbolImage:@"paperplane.fill"]
                                           title:LOC(@"SB_SUBMIT_SEND")
                                        subtitle:nil
                                       tintColor:[YMHelpers accentColor]
                                         handler:^(YMSBCardViewController *c) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        float submitStart = isFull ? 0 : start;
        float submitEnd = isFull ? 0 : (isPoi ? start : end);
        BOOL valid = isFull || (isPoi ? submitStart >= 0 : (submitStart >= 0 && submitEnd > submitStart));
        if (!valid) {
            YouModShowPill(LOC(@"SB_SUBMIT_INVALID"), NO);
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
                YouModShowPill(reason, NO);
                return;
            }
            YouModShowPill(LOC(@"SB_SUBMIT_SUCCESS"), YES);
            if (!ss) return;
            ss.sbDraft = nil;
            if ([[ss currentVideoID] isEqualToString:videoID]) [YMSBMenuHelpers postSegmentsForPlayer:ss enabled:YES];
        }];
    }]];
    return items;
}

// Toggles the current channel on/off the whitelist from the video menu, with a success pill (no confirmation card).
%new
- (void)sbToggleWhitelistFromMenu {
    NSString *channelID = [YMSBMenuHelpers currentChannelID:self];
    if (channelID.length == 0) {
        YouModShowPill(LOC(@"SB_VOTE_FAILED"), NO);
        return;
    }
    NSString *channelName = [YMSBMenuHelpers currentChannelName:self] ?: channelID;
    BOOL wasListed = [YMSBMenuHelpers isChannelWhitelisted:channelID];
    [YMSBMenuHelpers setChannelWhitelisted:channelID channelName:channelName whitelisted:!wasListed];

    // Removing the whitelist brings skipping/markers back for the current video; adding it clears them.
    [YMSBMenuHelpers postSegmentsForPlayer:self enabled:wasListed];

    YouModShowPill(LOC(wasListed ? @"SB_WHITELIST_REMOVE" : @"SB_WHITELIST_ADD"), YES);
}

%end

#pragma mark - Whitelist manager (tab bar entry)

void YMSBPresentWhitelistManager(void) {
    YMSBCardViewController *card = [[YMSBCardViewController alloc] init];
    card.cardTitle = LOC(@"SB_WHITELIST_MANAGE");
    card.swipeToDelete = YES;

    UISearchBar *searchBar = [[UISearchBar alloc] init];
    searchBar.placeholder = LOC(@"SEARCH");
    card.searchBar = searchBar;
    card.emptyText = LOC(@"SB_WHITELIST_EMPTY");
    card.items = [YMSBMenuHelpers whitelistManagerItems];

    card.onDeleteItem = ^(YMSBCardViewController *c, YMSBCardItem *item) {
        // Model only — the card animates the row out itself.
        if (item.identifier.length > 0) {
            [YMSBMenuHelpers setChannelWhitelisted:item.identifier channelName:item.title whitelisted:NO];
        }
        [YMSBMenuHelpers refreshPlayerAfterWhitelistChange];
    };

    [YMSBCardViewController presentCard:card];
}

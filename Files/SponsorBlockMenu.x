#import "Headers.h"
#import <CommonCrypto/CommonDigest.h>

// SponsorBlock menu: the player-overlay shield button opens a YouTube-style
// bottom sheet (enable/disable, segment voting, channel whitelist), while
// voting / whitelist / user-ID editing use our own centered card dialog
// (YMSBCardView) presented over the app's key window.

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

static NSString *sbLocalizedCategoryName(NSString *category) {
    return [YouModBundle() localizedStringForKey:[NSString stringWithFormat:@"SB_CAT_%@", category ?: @""]
                                            value:category
                                            table:nil];
}

static UIImage *sbSymbolImage(NSString *symbolName, UIColor *tint) {
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
    UIImage *image = [[UIImage systemImageNamed:symbolName withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    return image;
}

static UIImage *sbDotImage(UIColor *color) {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(18, 18)];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(2, 2, 14, 14)];
        [color setFill];
        [path fill];
    }];
    return image;
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

#pragma mark - SBRequest (Vote)

// All parameters go in the URL query string per the SponsorBlock API; the
// response body is empty on 200 and carries a plain-text reason on 400/403.
static void sbPostVoteQuery(NSString *query, void (^completion)(BOOL success, NSString *errorMessage)) {
    NSString *urlString = [@"https://sponsor.ajay.app/api/voteOnSponsorTime?" stringByAppendingString:query];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 15.0;

    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        BOOL ok = (error == nil) && [httpResponse statusCode] == 200;
        NSString *message = nil;
        if (!ok) {
            if (error) message = error.localizedDescription;
            if (message.length == 0 && data.length > 0) {
                message = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            }
            if (message.length > 120) message = [message substringToIndex:120];
            if (message.length == 0) message = [NSString stringWithFormat:@"HTTP %ld", (long)[httpResponse statusCode]];
        }
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(ok, message); });
    }] resume];
}

@implementation SBRequest (Vote)

+ (void)voteOnSegment:(SBSegment *)segment videoID:(NSString *)videoID type:(NSInteger)voteType completion:(void (^)(BOOL success, NSString *errorMessage))completion {
    if (!segment.UUID.length || !videoID.length) {
        if (completion) completion(NO, nil);
        return;
    }
    NSString *query = [NSString stringWithFormat:@"UUID=%@&videoID=%@&userID=%@&type=%ld",
                       segment.UUID, videoID, sbLocalUserID(), (long)voteType];
    sbPostVoteQuery(query, completion);
}

+ (void)voteCategoryOnSegment:(SBSegment *)segment videoID:(NSString *)videoID category:(NSString *)category completion:(void (^)(BOOL success, NSString *errorMessage))completion {
    if (!segment.UUID.length || !videoID.length || category.length == 0) {
        if (completion) completion(NO, nil);
        return;
    }
    NSString *query = [NSString stringWithFormat:@"UUID=%@&videoID=%@&userID=%@&category=%@",
                       segment.UUID, videoID, sbLocalUserID(), category];
    sbPostVoteQuery(query, completion);
}

@end

#pragma mark - Card option row

@interface YMSBCardOptionRow : UIControl
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, copy) void (^handler)(void);
@end

@implementation YMSBCardOptionRow

- (instancetype)initWithImage:(UIImage *)image title:(NSString *)title subtitle:(NSString *)subtitle tintColor:(UIColor *)tint handler:(void (^)(void))handler {
    self = [super init];
    if (self) {
        _handler = handler;
        self.translatesAutoresizingMaskIntoConstraints = NO;

        _iconView = [[UIImageView alloc] init];
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        _iconView.image = image;
        _iconView.tintColor = tint;
        _iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_iconView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.text = title;
        _titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        _titleLabel.textColor = [UIColor labelColor];
        _titleLabel.numberOfLines = 1;
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_titleLabel];

        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.text = subtitle;
        _subtitleLabel.font = [UIFont systemFontOfSize:12];
        _subtitleLabel.textColor = [UIColor secondaryLabelColor];
        _subtitleLabel.numberOfLines = 1;
        _subtitleLabel.hidden = subtitle.length == 0;
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_subtitleLabel];

        [NSLayoutConstraint activateConstraints:@[
            [_iconView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:4],
            [_iconView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_iconView.widthAnchor constraintEqualToConstant:26],
            [_iconView.heightAnchor constraintEqualToConstant:26],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:12],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-4],
        ]];
        if (subtitle.length > 0) {
            [NSLayoutConstraint activateConstraints:@[
                [_titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:9],
                [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:1],
                [_subtitleLabel.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
                [_subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-4],
                [_subtitleLabel.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-9],
            ]];
        } else {
            [NSLayoutConstraint activateConstraints:@[
                [_titleLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
                [self.heightAnchor constraintEqualToConstant:44],
            ]];
        }

        [self addTarget:self action:@selector(ymTapped) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)ymTapped {
    if (self.handler) self.handler();
}

@end

#pragma mark - Whitelist swipe-to-delete row

// A row whose content slides right to reveal a red delete button on its left.
@interface YMSBSwipeRow : UIView <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIButton *deleteButton;
@property (nonatomic, strong) UIView *rowContentView;
@property (nonatomic, strong) NSLayoutConstraint *contentLeadingConstraint;
@property (nonatomic, copy) void (^onDelete)(void);
@end

static const CGFloat kYMSwipeRevealWidth = 72.0;

@implementation YMSBSwipeRow

- (instancetype)initWithChannelName:(NSString *)name onDelete:(void (^)(void))onDelete {
    self = [super init];
    if (self) {
        _onDelete = onDelete;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.clipsToBounds = YES;
        self.layer.cornerRadius = 10;

        _deleteButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _deleteButton.backgroundColor = [UIColor systemRedColor];
        _deleteButton.translatesAutoresizingMaskIntoConstraints = NO;
        [_deleteButton setImage:[UIImage systemImageNamed:@"trash.fill"] forState:UIControlStateNormal];
        [_deleteButton addTarget:self action:@selector(ymDeleteTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_deleteButton];

        _rowContentView = [[UIView alloc] init];
        _rowContentView.backgroundColor = [UIColor secondarySystemBackgroundColor];
        _rowContentView.layer.cornerRadius = 10;
        _rowContentView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_rowContentView];

        UILabel *label = [[UILabel alloc] init];
        label.text = name;
        label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        label.textColor = [UIColor labelColor];
        label.translatesAutoresizingMaskIntoConstraints = NO;
        [_rowContentView addSubview:label];

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(ymPan:)];
        pan.delegate = self;
        [_rowContentView addGestureRecognizer:pan];

        _contentLeadingConstraint = [_rowContentView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor];
        [NSLayoutConstraint activateConstraints:@[
            [_deleteButton.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_deleteButton.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_deleteButton.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [_deleteButton.widthAnchor constraintEqualToConstant:kYMSwipeRevealWidth],

            _contentLeadingConstraint,
            [_rowContentView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_rowContentView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_rowContentView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

            [label.leadingAnchor constraintEqualToAnchor:_rowContentView.leadingAnchor constant:12],
            [label.trailingAnchor constraintLessThanOrEqualToAnchor:_rowContentView.trailingAnchor constant:-12],
            [label.centerYAnchor constraintEqualToAnchor:_rowContentView.centerYAnchor],

            [self.heightAnchor constraintEqualToConstant:48],
        ]];
    }
    return self;
}

- (void)ymPan:(UIPanGestureRecognizer *)gesture {
    CGFloat x = [gesture translationInView:self].x;
    // Only swipe-to-right within [0, reveal width].
    CGFloat target = MIN(MAX(0.0, self.contentLeadingConstraint.constant + x), kYMSwipeRevealWidth);
    if (gesture.state == UIGestureRecognizerStateChanged) {
        self.contentLeadingConstraint.constant = target;
        [gesture setTranslation:CGPointZero inView:self];
    } else if (gesture.state == UIGestureRecognizerStateEnded) {
        CGFloat open = target > kYMSwipeRevealWidth / 2.0 ? kYMSwipeRevealWidth : 0.0;
        [UIView animateWithDuration:0.2 animations:^{
            self.contentLeadingConstraint.constant = open;
            [self layoutIfNeeded];
        }];
    }
}

- (void)ymDeleteTapped {
    if (self.onDelete) self.onDelete();
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return NO;
}

@end

#pragma mark - YMSBCardView

@interface YMSBCardView ()
@property (nonatomic, strong) UIControl *backdropControl;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *closeButton;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIStackView *contentStack;
@end

@implementation YMSBCardView

- (void)setCardTitle:(NSString *)cardTitle {
    _cardTitle = [cardTitle copy];
    self.titleLabel.text = cardTitle;
}

+ (instancetype)presentWithTitle:(NSString *)title {
    UIWindow *window = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *w in scene.windows) {
            if (w.isKeyWindow) {
                window = w;
                break;
            }
        }
        if (!window && scene.windows.count > 0) window = scene.windows.firstObject;
        if (window) break;
    }
    if (!window) return nil;

    YMSBCardView *card = [[self alloc] initWithFrame:window.bounds];
    card.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    card.cardTitle = title;
    [window addSubview:card];

    card.backdropControl.alpha = 0.0;
    card.cardView.alpha = 0.0;
    card.cardView.transform = CGAffineTransformMakeScale(0.92, 0.92);
    [UIView animateWithDuration:0.22 animations:^{
        card.backdropControl.alpha = 0.5;
        card.cardView.alpha = 1.0;
        card.cardView.transform = CGAffineTransformIdentity;
    }];
    return card;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];

        _backdropControl = [[UIControl alloc] init];
        _backdropControl.backgroundColor = [UIColor blackColor];
        _backdropControl.translatesAutoresizingMaskIntoConstraints = NO;
        [_backdropControl addTarget:self action:@selector(dismissAnimated) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_backdropControl];

        _cardView = [[UIView alloc] init];
        _cardView.backgroundColor = isDarkMode(self) ? [%c(YTColor) black3] : [UIColor systemBackgroundColor];
        _cardView.layer.cornerRadius = 16;
        _cardView.layer.masksToBounds = NO;
        _cardView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:_cardView];

        _titleLabel = [[UILabel alloc] init];
        _titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
        _titleLabel.textColor = [UIColor labelColor];
        _titleLabel.numberOfLines = 2;
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_cardView addSubview:_titleLabel];

        _closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightSemibold];
        [_closeButton setImage:[[UIImage systemImageNamed:@"xmark" withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
        _closeButton.tintColor = [UIColor secondaryLabelColor];
        _closeButton.backgroundColor = [UIColor secondarySystemBackgroundColor];
        _closeButton.layer.cornerRadius = 13;
        _closeButton.translatesAutoresizingMaskIntoConstraints = NO;
        [_closeButton addTarget:self action:@selector(dismissAnimated) forControlEvents:UIControlEventTouchUpInside];
        [_cardView addSubview:_closeButton];

        _scrollView = [[UIScrollView alloc] init];
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
        [_cardView addSubview:_scrollView];

        _contentStack = [[UIStackView alloc] init];
        _contentStack.axis = UILayoutConstraintAxisVertical;
        _contentStack.spacing = 2;
        _contentStack.translatesAutoresizingMaskIntoConstraints = NO;
        [_scrollView addSubview:_contentStack];

        [NSLayoutConstraint activateConstraints:@[
            [_backdropControl.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_backdropControl.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [_backdropControl.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_backdropControl.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],

            [_cardView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_cardView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_cardView.widthAnchor constraintEqualToConstant:300],
            [_cardView.widthAnchor constraintLessThanOrEqualToAnchor:self.widthAnchor constant:-32],
            [_cardView.topAnchor constraintGreaterThanOrEqualToAnchor:self.safeAreaLayoutGuide.topAnchor constant:32],
            [_cardView.bottomAnchor constraintLessThanOrEqualToAnchor:self.safeAreaLayoutGuide.bottomAnchor constant:-32],

            [_titleLabel.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:16],
            [_titleLabel.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:16],
            [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_closeButton.leadingAnchor constant:-8],

            [_closeButton.topAnchor constraintEqualToAnchor:_cardView.topAnchor constant:14],
            [_closeButton.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-14],
            [_closeButton.widthAnchor constraintEqualToConstant:26],
            [_closeButton.heightAnchor constraintEqualToConstant:26],

            [_scrollView.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:12],
            [_scrollView.leadingAnchor constraintEqualToAnchor:_cardView.leadingAnchor constant:12],
            [_scrollView.trailingAnchor constraintEqualToAnchor:_cardView.trailingAnchor constant:-12],
            [_scrollView.bottomAnchor constraintEqualToAnchor:_cardView.bottomAnchor constant:-16],

            [_contentStack.topAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.topAnchor],
            [_contentStack.bottomAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.bottomAnchor],
            [_contentStack.leadingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.leadingAnchor],
            [_contentStack.trailingAnchor constraintEqualToAnchor:_scrollView.contentLayoutGuide.trailingAnchor],
            [_contentStack.widthAnchor constraintEqualToAnchor:_scrollView.frameLayoutGuide],
        ]];
    }
    return self;
}

- (void)clearContent {
    for (UIView *sub in [_contentStack.arrangedSubviews copy]) {
        [_contentStack removeArrangedSubview:sub];
        [sub removeFromSuperview];
    }
    self.scrollView.contentOffset = CGPointZero;
}

- (void)addOptionRowWithImage:(UIImage *)image title:(NSString *)title subtitle:(NSString *)subtitle tintColor:(UIColor *)tint handler:(void (^)(void))handler {
    YMSBCardOptionRow *row = [[YMSBCardOptionRow alloc] initWithImage:image title:title subtitle:subtitle tintColor:tint handler:handler];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentStack addArrangedSubview:row];
}

- (void)addOptionRowWithSymbol:(NSString *)symbolName title:(NSString *)title subtitle:(NSString *)subtitle tintColor:(UIColor *)tint handler:(void (^)(void))handler {
    [self addOptionRowWithImage:sbSymbolImage(symbolName, tint) title:title subtitle:subtitle tintColor:tint handler:handler];
}

- (void)addCustomView:(UIView *)view {
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentStack addArrangedSubview:view];
    [NSLayoutConstraint activateConstraints:@[
        [view.widthAnchor constraintEqualToAnchor:self.contentStack.widthAnchor],
    ]];
}

- (void)dismissAnimated {
    [UIView animateWithDuration:0.18 animations:^{
        self.backdropControl.alpha = 0.0;
        self.cardView.alpha = 0.0;
        self.cardView.transform = CGAffineTransformMakeScale(0.94, 0.94);
    } completion:^(__unused BOOL finished) {
        [self removeFromSuperview];
    }];
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
    [sheet addHeaderWithTitle:LOC(@"SB_MENU_TITLE") subtitle:sbCurrentChannelName(self) ?: @""];

    __weak typeof(self) weakSelf = self;

    YTActionSheetAction *toggleAction = [%c(YTActionSheetAction) actionWithTitle:LOC(active ? @"SB_MENU_DISABLE" : @"SB_MENU_ENABLE")
                                                                        iconImage:[UIImage systemImageNamed:active ? @"shield" : @"shield.slash"]
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
    }];
    [sheet addAction:toggleAction];

    if (active && self.sbSegments.count > 0) {
        YTActionSheetAction *voteAction = [%c(YTActionSheetAction) actionWithTitle:LOC(@"SB_MENU_VOTE")
                                                                          iconImage:[UIImage systemImageNamed:@"hand.thumbsup"]
                                                                               style:0
                                                                            handler:^(__unused YTActionSheetAction *action) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) [strongSelf sbShowVoteCard];
        }];
        [sheet addAction:voteAction];
    }

    YTActionSheetAction *whitelistAction = [%c(YTActionSheetAction) actionWithTitle:LOC(@"SB_MENU_WHITELIST")
                                                                            iconImage:[UIImage systemImageNamed:@"checkmark.seal"]
                                                                                 style:0
                                                                              handler:^(__unused YTActionSheetAction *action) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) [strongSelf sbShowWhitelistCard];
    }];
    [sheet addAction:whitelistAction];

    [sheet presentFromView:sourceView animated:YES completion:nil];
}

// Centered card listing every loaded segment (categories the user enabled),
// then vote options for the tapped one.
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

    YMSBCardView *card = [YMSBCardView presentWithTitle:LOC(@"SB_VOTE_TITLE")];
    if (!card) return;
    __weak typeof(self) weakSelf = self;
    __weak YMSBCardView *weakCard = card;

    for (SBSegment *segment in segments) {
        NSString *catName = sbLocalizedCategoryName(segment.category);
        NSString *subtitle = [NSString stringWithFormat:@"%@ – %@  ·  %@",
                              sbFormatTime(segment.startTime),
                              sbFormatTime(segment.endTime),
                              [NSString stringWithFormat:LOC(@"SB_VOTES_COUNT"), (long)segment.votes]];
        [card addOptionRowWithImage:sbDotImage(segment.segmentColor)
                              title:catName
                           subtitle:subtitle
                          tintColor:[UIColor labelColor]
                             handler:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            YMSBCardView *strongCard = weakCard;
            if (!strongCard || !strongSelf) return;
            [strongCard clearContent];
            strongCard.cardTitle = catName;
            [strongSelf sbPopulateVoteOptions:strongCard segment:segment];
        }];
    }
}

%new
- (void)sbPopulateVoteOptions:(YMSBCardView *)card segment:(SBSegment *)segment {
    __weak typeof(self) weakSelf = self;
    __weak YMSBCardView *weakCard = card;

    NSString *segmentInfo = [NSString stringWithFormat:@"%@ – %@",
                             sbFormatTime(segment.startTime),
                             sbFormatTime(segment.endTime)];

    void (^voteHandler)(NSInteger) = ^(NSInteger type) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [weakCard dismissAnimated];
        if (!strongSelf) return;
        NSString *videoID = [strongSelf currentVideoID];
        [SBRequest voteOnSegment:segment videoID:videoID type:type completion:^(BOOL success, NSString *errorMessage) {
            if (success) {
                sbInvalidateSegmentCache(videoID);
                sbShowSBPill(LOC(@"SB_VOTE_SUCCESS"), YES);
            } else {
                NSString *reason = errorMessage.length > 0 ? [NSString stringWithFormat:@"%@ — %@", LOC(@"SB_VOTE_FAILED"), errorMessage] : LOC(@"SB_VOTE_FAILED");
                sbShowSBPill(reason, NO);
            }
        }];
    };

    [card addOptionRowWithSymbol:@"hand.thumbsup.fill" title:LOC(@"SB_VOTE_UPVOTE") subtitle:segmentInfo tintColor:[UIColor systemGreenColor] handler:^{
        voteHandler(1);
    }];
    [card addOptionRowWithSymbol:@"hand.thumbsdown.fill" title:LOC(@"SB_VOTE_DOWNVOTE") subtitle:segmentInfo tintColor:[UIColor systemRedColor] handler:^{
        voteHandler(0);
    }];
    [card addOptionRowWithSymbol:@"arrow.uturn.backward" title:LOC(@"SB_VOTE_UNDO") subtitle:segmentInfo tintColor:[UIColor labelColor] handler:^{
        voteHandler(20);
    }];
    [card addOptionRowWithSymbol:@"tag" title:LOC(@"SB_VOTE_CHANGE_CATEGORY") subtitle:segmentInfo tintColor:[UIColor labelColor] handler:^{
        YMSBCardView *categoryCard = weakCard;
        [categoryCard clearContent];
        categoryCard.cardTitle = LOC(@"SB_VOTE_CHANGE_CATEGORY");
        for (NSString *category in sbAllCategories()) {
            NSString *hex = [[NSUserDefaults standardUserDefaults] stringForKey:SB_COLOR_KEY(category)];
            UIColor *color = hex ? SBColorFromHex(hex) : [UIColor whiteColor];
            [categoryCard addOptionRowWithImage:sbDotImage(color)
                                          title:sbLocalizedCategoryName(category)
                                       subtitle:nil
                                      tintColor:[UIColor labelColor]
                                         handler:^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                [categoryCard dismissAnimated];
                if (!strongSelf) return;
                NSString *videoID = [strongSelf currentVideoID];
                [SBRequest voteCategoryOnSegment:segment videoID:videoID category:category completion:^(BOOL success, NSString *errorMessage) {
                    if (success) {
                        sbInvalidateSegmentCache(videoID);
                        sbShowSBPill(LOC(@"SB_VOTE_SUCCESS"), YES);
                    } else {
                        NSString *reason = errorMessage.length > 0 ? [NSString stringWithFormat:@"%@ — %@", LOC(@"SB_VOTE_FAILED"), errorMessage] : LOC(@"SB_VOTE_FAILED");
                        sbShowSBPill(reason, NO);
                    }
                }];
            }];
        }
    }];
    [card addOptionRowWithSymbol:@"backward.end.fill" title:LOC(@"SB_VOTE_JUMP_START") subtitle:segmentInfo tintColor:[UIColor labelColor] handler:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [weakCard dismissAnimated];
        if (strongSelf) [strongSelf seekToTime:(CGFloat)segment.startTime];
    }];
    [card addOptionRowWithSymbol:@"forward.end.fill" title:LOC(@"SB_VOTE_JUMP_END") subtitle:segmentInfo tintColor:[UIColor labelColor] handler:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [weakCard dismissAnimated];
        if (strongSelf) [strongSelf seekToTime:(CGFloat)segment.endTime];
    }];
}

// Centered card to add/remove the current channel to/from the whitelist.
%new
- (void)sbShowWhitelistCard {
    NSString *channelID = sbCurrentChannelID(self);
    if (channelID.length == 0) {
        sbShowSBPill(LOC(@"SB_VOTE_FAILED"), NO);
        return;
    }
    NSString *channelName = sbCurrentChannelName(self) ?: channelID;
    BOOL listed = sbIsChannelWhitelisted(channelID);

    YMSBCardView *card = [YMSBCardView presentWithTitle:channelName];
    if (!card) return;
    __weak typeof(self) weakSelf = self;
    __weak YMSBCardView *weakCard = card;

    UILabel *desc = [[UILabel alloc] init];
    desc.text = LOC(@"SB_WHITELIST_DESC");
    desc.font = [UIFont systemFontOfSize:13];
    desc.textColor = [UIColor secondaryLabelColor];
    desc.numberOfLines = 0;
    [card addCustomView:desc];

    if (listed) {
        [card addOptionRowWithSymbol:@"checkmark.seal.fill" title:LOC(@"SB_WHITELIST_REMOVE") subtitle:nil tintColor:[UIColor systemRedColor] handler:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            sbSetChannelWhitelisted(channelID, channelName, NO);
            [weakCard dismissAnimated];
            sbShowSBPill(LOC(@"SB_WHITELIST_REMOVE"), YES);
            if (strongSelf) {
                sbInvalidateSegmentCache([strongSelf currentVideoID]);
                strongSelf.sbSegments = nil;
                [[NSNotificationCenter defaultCenter] postNotificationName:@"SBSegmentsDidLoad"
                                                                    object:strongSelf
                                                                  userInfo:@{@"segments": @[]}];
            }
        }];
    } else {
        [card addOptionRowWithSymbol:@"checkmark.seal" title:LOC(@"SB_WHITELIST_ADD") subtitle:nil tintColor:[UIColor systemGreenColor] handler:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            sbSetChannelWhitelisted(channelID, channelName, YES);
            [weakCard dismissAnimated];
            sbShowSBPill(LOC(@"SB_WHITELIST_ADD"), YES);
            if (strongSelf) {
                sbInvalidateSegmentCache([strongSelf currentVideoID]);
                strongSelf.sbSegments = nil;
                [[NSNotificationCenter defaultCenter] postNotificationName:@"SBSegmentsDidLoad"
                                                                    object:strongSelf
                                                                  userInfo:@{@"segments": @[]}];
            }
        }];
    }
}

%end

#pragma mark - Whitelist manager (tab bar entry)

static void sbRebuildWhitelistCardContent(YMSBCardView *card);

void YMSBPresentWhitelistManager(void) {
    YMSBCardView *card = [YMSBCardView presentWithTitle:LOC(@"SB_WHITELIST_MANAGE")];
    if (!card) return;
    sbRebuildWhitelistCardContent(card);
}

static void sbRebuildWhitelistCardContent(YMSBCardView *card) {
    [card clearContent];
    NSDictionary *whitelist = sbWhitelistDictionary();
    NSArray *channelIDs = [whitelist.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    if (channelIDs.count == 0) {
        UILabel *empty = [[UILabel alloc] init];
        empty.text = LOC(@"SB_WHITELIST_EMPTY");
        empty.font = [UIFont systemFontOfSize:14];
        empty.textColor = [UIColor secondaryLabelColor];
        empty.numberOfLines = 0;
        [card addCustomView:empty];
        return;
    }
    for (NSString *channelID in channelIDs) {
        NSString *name = whitelist[channelID];
        __weak YMSBCardView *weakCard = card;
        YMSBSwipeRow *row = [[YMSBSwipeRow alloc] initWithChannelName:name onDelete:^{
            sbSetChannelWhitelisted(channelID, name, NO);
            YMSBCardView *strongCard = weakCard;
            if (strongCard) sbRebuildWhitelistCardContent(strongCard);
        }];
        [card addCustomView:row];
    }
}

%ctor {
    %init;
}

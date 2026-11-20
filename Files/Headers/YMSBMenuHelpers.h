// YMSBMenuHelpers — file-local helpers for SponsorBlockMenu.x: time/name
// formatting, icons, user-ID hashing, whitelist, SponsorBlock API calls,
// engagement-panel plumbing and card glue.

@class YTPlayerViewController, YTIPlayerResponse, YTICommand, SBSegment, YMSBCardItem, YMSBCardViewController;

@interface YMSBMenuHelpers : NSObject
// "m:ss" or "h:mm:ss" for a segment timestamp (clamped at 0).
+ (NSString *)formatTime:(float)t;
// Like formatTime but with tenths, for marking segment boundaries.
+ (NSString *)formatPreciseTime:(float)t;
// Localized display name for a segment category.
+ (NSString *)localizedCategoryName:(NSString *)category;
// 18pt template-rendered SF Symbol.
+ (UIImage *)symbolImage:(NSString *)symbolName;
// 18x18 dot image filled with the given color.
+ (UIImage *)dotImage:(UIColor *)color;
// SF Symbol rendered into an exact 24x24 canvas so every action-sheet icon box is identical.
+ (UIImage *)sheetIcon:(NSString *)symbolName;
// SHA-256 x 5000 of the private ID — the SponsorBlock public userID.
+ (NSString *)hashPublicFromPrivate:(NSString *)privateID;
// contentPlayerResponse when available, playerResponse otherwise (like Download.x's YouModPlayerDataForPlayer:).
+ (YTIPlayerResponse *)playerDataForPlayer:(YTPlayerViewController *)player;
+ (NSString *)currentChannelID:(YTPlayerViewController *)player;
+ (NSString *)currentChannelName:(YTPlayerViewController *)player;
// Whitelist dictionary from defaults; empty when unset.
+ (NSDictionary *)whitelistDictionary;
// Persists the whitelist (removes the key when empty).
+ (void)saveWhitelistDictionary:(NSDictionary *)dict;
+ (BOOL)isChannelWhitelisted:(NSString *)channelID;
+ (void)setChannelWhitelisted:(NSString *)channelID channelName:(NSString *)channelName whitelisted:(BOOL)whitelisted;
// Posts a fresh segments notification: fetches segments when on, clears markers when off/whitelisted.
+ (void)postSegmentsForPlayer:(YTPlayerViewController *)player enabled:(BOOL)enabled;
// Re-syncs the current video after a whitelist change so skipping/markers update immediately.
+ (void)refreshPlayerAfterWhitelistChange;
// Percent-encodes a query-string value (&=+? never literal).
+ (NSString *)queryValue:(NSString *)value;
// POST to the SponsorBlock API with all parameters in the URL query string; failures carry a plain-text reason (400/403).
+ (void)postQuery:(NSString *)path params:(NSDictionary<NSString *, NSString *> *)params completion:(void (^)(BOOL success, NSInteger status, NSString *errorMessage))completion;
// YTICommand that shows our engagement panel with the given title.
+ (YTICommand *)engagementPanelShowCommand:(NSString *)title;
// Engagement panel VC class used by this YouTube version.
+ (Class)engagementPanelClass;
// Our engagement panel when card is inside one, otherwise nil.
+ (UIViewController *)engagementPanelFor:(UIViewController *)card;
// YES when the panel model is ours (its panelIdentifier is a YTEngagementPanelIdentifier here).
+ (BOOL)isOurPanelModel:(id)model;
// Form-sheet nav stack for a card with explicit bar colors (YouTube restyles bars app-wide).
+ (UINavigationController *)cardNavigationController:(YMSBCardViewController *)card;
// Pill for a vote result; on success drops the voted segment from the player.
+ (void)handleVoteResult:(YTPlayerViewController *)player droppedSegment:(SBSegment *)droppedSegment videoID:(NSString *)videoID success:(BOOL)success errorMessage:(NSString *)errorMessage;
// -1 / -0.1 / +0.1 / +1 second buttons for fine-tuning a marked time.
+ (UIView *)nudgeControls:(void (^)(float delta))nudge;
// Whitelist-manager rows: every whitelisted channel (name + ID).
+ (NSArray<YMSBCardItem *> *)whitelistManagerItems;
@end

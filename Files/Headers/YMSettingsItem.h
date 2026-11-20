#import "YMVisibilityCondition.h"
#import "YTIIcon.h"

#pragma mark - YouMod Settings Framework (YouModSettings.x)

typedef NS_ENUM(NSInteger, YMRowType) {
    YMRowTypeToggle = 0,
    YMRowTypePicker,
    YMRowTypeAction,
    YMRowTypeHeader,
    YMRowTypeSegment,
    YMRowTypeTextSegment,
    YMRowTypeImageSegment,
    YMRowTypeSlider,
    YMRowTypeDeveloper
};

// Page implementation for nav rows carrying a submenu (YMSettingsItem.submenuKind).
typedef NS_ENUM(NSInteger, YMSubmenuKind) {
    YMSubmenuKindSettings = 0,    // regular settings page (submenuItems)
    YMSubmenuKindSponsorBlock = 1 // SponsorBlock settings page (submenuItems nil)
};

@interface YMSettingsItem : NSObject
@property (nonatomic, assign) YMRowType type;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *subtitle;
@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) NSArray<NSString *> *pickerOptions;
@property (nonatomic, assign) NSInteger pickerDefault;
@property (nonatomic, copy) void (^action)(UIViewController *vc);
@property (nonatomic, assign) BOOL opensPage; // YES -> row pushes another page, gets a disclosure chevron
@property (nonatomic, assign) NSInteger iconType; // YT icon (YTIIcon type) shown leading; 0 = no icon
@property (nonatomic, strong) NSString *bundleIcon; // YouMod bundle icon name (icons/old|new/<name>); takes precedence over iconType
@property (nonatomic, strong) NSArray<NSNumber *> *segmentIcons;
@property (nonatomic, strong) NSArray<NSString *> *segmentLabels;
@property (nonatomic, strong) NSArray<UIImage *> *segmentImages;
@property (nonatomic, assign) float sliderMin;
@property (nonatomic, assign) float sliderMax;
@property (nonatomic, assign) float sliderStep;
@property (nonatomic, assign) float sliderDefault;
// Developer row: circular GitHub avatar + name + role; tap opens profileURL,
// avatarURL (github.com/<user>.png) is fetched async and cached.
@property (nonatomic, strong) NSString *profileURL;
@property (nonatomic, strong) NSString *avatarURL;

// Nav rows: the page this row opens (pushed on iPhone, shown in the detail pane
// on iPad). submenuKind selects the page implementation; SponsorBlock rows leave
// submenuItems nil. Carrying the page data here keeps row taps independent of any
// view controller captured when the rows were built.
@property (nonatomic, strong) NSArray<YMSettingsItem *> *submenuItems;
@property (nonatomic, assign) NSInteger submenuKind;

// Visibility predicates: all must match (AND), or any when matchAnyCondition is YES (OR).
@property (nonatomic, strong) NSMutableArray<YMVisibilityCondition *> *visibilityConditions;
@property (nonatomic, assign) BOOL matchAnyCondition;

+ (instancetype)toggleWithTitle:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key;
+ (instancetype)sliderWithTitle:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key min:(float)min max:(float)max step:(float)step defaultValue:(float)defaultValue;
+ (instancetype)pickerWithTitle:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key options:(NSArray<NSString *> *)options defaultValue:(NSInteger)defaultValue;
+ (instancetype)actionWithTitle:(NSString *)title subtitle:(NSString *)subtitle action:(void (^)(UIViewController *vc))action;
+ (instancetype)navActionWithTitle:(NSString *)title subtitle:(NSString *)subtitle action:(void (^)(UIViewController *vc))action;
+ (instancetype)headerWithTitle:(NSString *)title;
+ (instancetype)segmentWithTitle:(NSString *)title key:(NSString *)key icons:(NSArray<NSNumber *> *)icons defaultValue:(NSInteger)defaultValue;
+ (instancetype)textSegmentWithTitle:(NSString *)title key:(NSString *)key labels:(NSArray<NSString *> *)labels defaultValue:(NSInteger)defaultValue;
+ (instancetype)imageSegmentWithTitle:(NSString *)title key:(NSString *)key images:(NSArray<UIImage *> *)images defaultValue:(NSInteger)defaultValue;
+ (instancetype)developerWithName:(NSString *)name role:(NSString *)role profileURL:(NSString *)profileURL avatarURL:(NSString *)avatarURL;

// Chainable row styling
- (instancetype)withIconType:(NSInteger)iconType;
- (instancetype)withBundleIcon:(NSString *)name;
- (instancetype)withSubmenuItems:(NSArray<YMSettingsItem *> *)items kind:(NSInteger)kind;

// Evaluation
- (BOOL)isVisible;
- (BOOL)isVisibleWithDefaults:(NSUserDefaults *)defaults;

// Integer conditions (chainable)
- (instancetype)visibleWhenKey:(NSString *)key equals:(NSInteger)value;
- (instancetype)visibleWhenKey:(NSString *)key isNotEqualTo:(NSInteger)value;
- (instancetype)visibleWhenKey:(NSString *)key isGreaterThan:(NSInteger)value;
- (instancetype)visibleWhenKey:(NSString *)key isGreaterThanOrEqualTo:(NSInteger)value;
- (instancetype)visibleWhenKey:(NSString *)key isLessThan:(NSInteger)value;
- (instancetype)visibleWhenKey:(NSString *)key isLessThanOrEqualTo:(NSInteger)value;
- (instancetype)visibleWhenKey:(NSString *)key inValues:(NSArray<NSNumber *> *)values;
- (instancetype)visibleWhenKey:(NSString *)key notInValues:(NSArray<NSNumber *> *)values;
- (instancetype)visibleWhenKeyDictionary:(NSDictionary<NSString *, NSNumber *> *)keyValues;

// Boolean conditions (chainable)
- (instancetype)visibleWhenBoolKey:(NSString *)key equals:(BOOL)value;
- (instancetype)visibleWhenBoolKey:(NSString *)key;
- (instancetype)visibleWhenBoolKeys:(NSArray<NSString *> *)keys;
- (instancetype)visibleWhenBoolKeys:(NSArray<NSString *> *)keys allEqualTo:(BOOL)value;
- (instancetype)visibleWhenAnyBoolKey:(NSArray<NSString *> *)keys;
- (instancetype)visibleWhenBoolDictionary:(NSDictionary<NSString *, NSNumber *> *)keyValues;

// Block / Custom conditions & modifier
- (instancetype)visibleWhen:(BOOL (^)(NSUserDefaults *defaults))block;
- (instancetype)requireAnyCondition;
@end

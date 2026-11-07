// YouModSettings.x — Reusable UIKit-based sub-page for YouMod settings sections
#import "Headers.h"

#import <objc/runtime.h>
#import <objc/message.h>

// YouTube's version utility; the footer reads [%c(YTVersionUtils) appVersion].
@interface YTVersionUtils : NSObject
+ (NSString *)appVersion;
@end

#pragma mark - Data Model

@implementation YMVisibilityCondition

+ (instancetype)conditionWithBoolKey:(NSString *)key equals:(BOOL)value {
    YMVisibilityCondition *cond = [[YMVisibilityCondition alloc] init];
    cond.key = key;
    cond.op = YMVisibilityOperatorBoolEquals;
    cond.boolValue = value;
    return cond;
}

+ (instancetype)conditionWithKey:(NSString *)key intOperator:(YMVisibilityOperator)op value:(NSInteger)value {
    YMVisibilityCondition *cond = [[YMVisibilityCondition alloc] init];
    cond.key = key;
    cond.op = op;
    cond.intValue = value;
    return cond;
}

+ (instancetype)conditionWithKey:(NSString *)key inValues:(NSArray<NSNumber *> *)values {
    YMVisibilityCondition *cond = [[YMVisibilityCondition alloc] init];
    cond.key = key;
    cond.op = YMVisibilityOperatorIntInValues;
    cond.intValues = values;
    return cond;
}

+ (instancetype)conditionWithKey:(NSString *)key notInValues:(NSArray<NSNumber *> *)values {
    YMVisibilityCondition *cond = [[YMVisibilityCondition alloc] init];
    cond.key = key;
    cond.op = YMVisibilityOperatorIntNotInValues;
    cond.intValues = values;
    return cond;
}

+ (instancetype)conditionWithBlock:(BOOL (^)(NSUserDefaults *defaults))block {
    YMVisibilityCondition *cond = [[YMVisibilityCondition alloc] init];
    cond.op = YMVisibilityOperatorCustomBlock;
    cond.customBlock = block;
    return cond;
}

- (BOOL)evaluateWithDefaults:(NSUserDefaults *)defaults {
    if (!defaults) defaults = [NSUserDefaults standardUserDefaults];
    switch (self.op) {
        case YMVisibilityOperatorBoolEquals:
            return [defaults boolForKey:self.key] == self.boolValue;
        case YMVisibilityOperatorIntEquals:
            return [defaults integerForKey:self.key] == self.intValue;
        case YMVisibilityOperatorIntNotEquals:
            return [defaults integerForKey:self.key] != self.intValue;
        case YMVisibilityOperatorIntGreaterThan:
            return [defaults integerForKey:self.key] > self.intValue;
        case YMVisibilityOperatorIntGreaterThanOrEqual:
            return [defaults integerForKey:self.key] >= self.intValue;
        case YMVisibilityOperatorIntLessThan:
            return [defaults integerForKey:self.key] < self.intValue;
        case YMVisibilityOperatorIntLessThanOrEqual:
            return [defaults integerForKey:self.key] <= self.intValue;
        case YMVisibilityOperatorIntInValues: {
            NSInteger current = [defaults integerForKey:self.key];
            for (NSNumber *v in self.intValues) {
                if ([v integerValue] == current) return YES;
            }
            return NO;
        }
        case YMVisibilityOperatorIntNotInValues: {
            NSInteger current = [defaults integerForKey:self.key];
            for (NSNumber *v in self.intValues) {
                if ([v integerValue] == current) return NO;
            }
            return YES;
        }
        case YMVisibilityOperatorCustomBlock:
            return self.customBlock ? self.customBlock(defaults) : YES;
        default:
            return YES;
    }
}

@end

@implementation YMSettingsItem

- (instancetype)init {
    self = [super init];
    if (self) {
        _visibilityConditions = [NSMutableArray array];
    }
    return self;
}

+ (instancetype)toggleWithTitle:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key {
    YMSettingsItem *item = [[YMSettingsItem alloc] init];
    item.type = YMRowTypeToggle;
    item.title = title;
    item.subtitle = subtitle;
    item.key = key;
    return item;
}

+ (instancetype)sliderWithTitle:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key min:(float)min max:(float)max step:(float)step defaultValue:(float)defaultValue {
    YMSettingsItem *item = [[YMSettingsItem alloc] init];
    item.type = YMRowTypeSlider;
    item.title = title;
    item.subtitle = subtitle;
    item.key = key;
    item.sliderMin = min;
    item.sliderMax = max;
    item.sliderStep = step;
    item.sliderDefault = defaultValue;
    return item;
}

+ (instancetype)pickerWithTitle:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key options:(NSArray<NSString *> *)options defaultValue:(NSInteger)defaultValue {
    YMSettingsItem *item = [[YMSettingsItem alloc] init];
    item.type = YMRowTypePicker;
    item.title = title;
    item.subtitle = subtitle;
    item.key = key;
    item.pickerOptions = options;
    item.pickerDefault = defaultValue;
    return item;
}

+ (instancetype)actionWithTitle:(NSString *)title subtitle:(NSString *)subtitle action:(void (^)(UIViewController *vc))action {
    YMSettingsItem *item = [[YMSettingsItem alloc] init];
    item.type = YMRowTypeAction;
    item.title = title;
    item.subtitle = subtitle;
    item.action = action;
    return item;
}

+ (instancetype)navActionWithTitle:(NSString *)title subtitle:(NSString *)subtitle action:(void (^)(UIViewController *vc))action {
    YMSettingsItem *item = [self actionWithTitle:title subtitle:subtitle action:action];
    item.opensPage = YES;
    return item;
}

+ (instancetype)headerWithTitle:(NSString *)title {
    YMSettingsItem *item = [[YMSettingsItem alloc] init];
    item.type = YMRowTypeHeader;
    item.title = title;
    return item;
}

+ (instancetype)segmentWithTitle:(NSString *)title key:(NSString *)key icons:(NSArray<NSNumber *> *)icons defaultValue:(NSInteger)defaultValue {
    YMSettingsItem *item = [[YMSettingsItem alloc] init];
    item.type = YMRowTypeSegment;
    item.title = title;
    item.key = key;
    item.segmentIcons = icons;
    item.pickerDefault = defaultValue;
    return item;
}

+ (instancetype)textSegmentWithTitle:(NSString *)title key:(NSString *)key labels:(NSArray<NSString *> *)labels defaultValue:(NSInteger)defaultValue {
    YMSettingsItem *item = [[YMSettingsItem alloc] init];
    item.type = YMRowTypeTextSegment;
    item.title = title;
    item.key = key;
    item.segmentLabels = labels;
    item.pickerDefault = defaultValue;
    return item;
}

+ (instancetype)imageSegmentWithTitle:(NSString *)title key:(NSString *)key images:(NSArray<UIImage *> *)images defaultValue:(NSInteger)defaultValue {
    YMSettingsItem *item = [[YMSettingsItem alloc] init];
    item.type = YMRowTypeImageSegment;
    item.title = title;
    item.key = key;
    item.segmentImages = images;
    item.pickerDefault = defaultValue;
    return item;
}

+ (instancetype)developerWithName:(NSString *)name role:(NSString *)role profileURL:(NSString *)profileURL avatarURL:(NSString *)avatarURL {
    YMSettingsItem *item = [[YMSettingsItem alloc] init];
    item.type = YMRowTypeDeveloper;
    item.title = name;
    item.subtitle = role;
    item.profileURL = profileURL;
    item.avatarURL = avatarURL;
    return item;
}

- (instancetype)withIconType:(NSInteger)iconType {
    self.iconType = iconType;
    return self;
}

- (BOOL)isVisible {
    return [self isVisibleWithDefaults:[NSUserDefaults standardUserDefaults]];
}

- (BOOL)isVisibleWithDefaults:(NSUserDefaults *)defaults {
    if (!self.visibilityConditions || self.visibilityConditions.count == 0) return YES;
    if (!defaults) defaults = [NSUserDefaults standardUserDefaults];
    if (self.matchAnyCondition) {
        for (YMVisibilityCondition *cond in self.visibilityConditions) {
            if ([cond evaluateWithDefaults:defaults]) return YES;
        }
        return NO;
    } else {
        for (YMVisibilityCondition *cond in self.visibilityConditions) {
            if (![cond evaluateWithDefaults:defaults]) return NO;
        }
        return YES;
    }
}

- (instancetype)visibleWhenKey:(NSString *)key equals:(NSInteger)value {
    if (key) {
        [self.visibilityConditions addObject:[YMVisibilityCondition conditionWithKey:key intOperator:YMVisibilityOperatorIntEquals value:value]];
    }
    return self;
}

- (instancetype)visibleWhenKey:(NSString *)key isNotEqualTo:(NSInteger)value {
    if (key) {
        [self.visibilityConditions addObject:[YMVisibilityCondition conditionWithKey:key intOperator:YMVisibilityOperatorIntNotEquals value:value]];
    }
    return self;
}

- (instancetype)visibleWhenKey:(NSString *)key isGreaterThan:(NSInteger)value {
    if (key) {
        [self.visibilityConditions addObject:[YMVisibilityCondition conditionWithKey:key intOperator:YMVisibilityOperatorIntGreaterThan value:value]];
    }
    return self;
}

- (instancetype)visibleWhenKey:(NSString *)key isGreaterThanOrEqualTo:(NSInteger)value {
    if (key) {
        [self.visibilityConditions addObject:[YMVisibilityCondition conditionWithKey:key intOperator:YMVisibilityOperatorIntGreaterThanOrEqual value:value]];
    }
    return self;
}

- (instancetype)visibleWhenKey:(NSString *)key isLessThan:(NSInteger)value {
    if (key) {
        [self.visibilityConditions addObject:[YMVisibilityCondition conditionWithKey:key intOperator:YMVisibilityOperatorIntLessThan value:value]];
    }
    return self;
}

- (instancetype)visibleWhenKey:(NSString *)key isLessThanOrEqualTo:(NSInteger)value {
    if (key) {
        [self.visibilityConditions addObject:[YMVisibilityCondition conditionWithKey:key intOperator:YMVisibilityOperatorIntLessThanOrEqual value:value]];
    }
    return self;
}

- (instancetype)visibleWhenKey:(NSString *)key inValues:(NSArray<NSNumber *> *)values {
    if (key && values) {
        [self.visibilityConditions addObject:[YMVisibilityCondition conditionWithKey:key inValues:values]];
    }
    return self;
}

- (instancetype)visibleWhenKey:(NSString *)key notInValues:(NSArray<NSNumber *> *)values {
    if (key && values) {
        [self.visibilityConditions addObject:[YMVisibilityCondition conditionWithKey:key notInValues:values]];
    }
    return self;
}

- (instancetype)visibleWhenKeyDictionary:(NSDictionary<NSString *, NSNumber *> *)keyValues {
    [keyValues enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSNumber *val, BOOL *stop) {
        [self visibleWhenKey:k equals:[val integerValue]];
    }];
    return self;
}

- (instancetype)visibleWhenBoolKey:(NSString *)key equals:(BOOL)value {
    if (key) {
        [self.visibilityConditions addObject:[YMVisibilityCondition conditionWithBoolKey:key equals:value]];
    }
    return self;
}

- (instancetype)visibleWhenBoolKey:(NSString *)key {
    return [self visibleWhenBoolKey:key equals:YES];
}

- (instancetype)visibleWhenBoolKeys:(NSArray<NSString *> *)keys {
    return [self visibleWhenBoolKeys:keys allEqualTo:YES];
}

- (instancetype)visibleWhenBoolKeys:(NSArray<NSString *> *)keys allEqualTo:(BOOL)value {
    for (NSString *k in keys) {
        [self visibleWhenBoolKey:k equals:value];
    }
    return self;
}

- (instancetype)visibleWhenAnyBoolKey:(NSArray<NSString *> *)keys {
    if (keys.count == 0) return self;
    return [self visibleWhen:^BOOL(NSUserDefaults *defaults) {
        for (NSString *k in keys) {
            if ([defaults boolForKey:k]) return YES;
        }
        return NO;
    }];
}

- (instancetype)visibleWhenBoolDictionary:(NSDictionary<NSString *, NSNumber *> *)keyValues {
    [keyValues enumerateKeysAndObjectsUsingBlock:^(NSString *k, NSNumber *val, BOOL *stop) {
        [self visibleWhenBoolKey:k equals:[val boolValue]];
    }];
    return self;
}

- (instancetype)visibleWhen:(BOOL (^)(NSUserDefaults *defaults))block {
    if (block) {
        [self.visibilityConditions addObject:[YMVisibilityCondition conditionWithBlock:block]];
    }
    return self;
}

- (instancetype)requireAnyCondition {
    self.matchAnyCondition = YES;
    return self;
}

@end

#pragma mark - Settings Search Registry

// A registered settings group (name + items) feeding the home page search index.
@interface YMSettingsGroup : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSArray<YMSettingsItem *> *items;
@end
@implementation YMSettingsGroup
@end

@implementation YMSearchRow
@end

// Registered groups; SponsorBlock adds its own rows via sbSearchRows.
// Registration dedupes by title so screen rebuilds don't duplicate rows.
static NSMutableArray<YMSettingsGroup *> *gYMSearchGroups = nil;

void YMRegisterSettingsGroup(NSString *title, NSArray<YMSettingsItem *> *items) {
    if (!gYMSearchGroups) gYMSearchGroups = [NSMutableArray array];
    for (YMSettingsGroup *existing in [gYMSearchGroups copy]) {
        if ([existing.title isEqualToString:title]) [gYMSearchGroups removeObject:existing];
    }
    YMSettingsGroup *group = [YMSettingsGroup new];
    group.title = title;
    group.items = items;
    [gYMSearchGroups addObject:group];
}

#pragma mark - YMSubSettingsViewController

@interface YMSubSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>
- (UITableView *)tableView;
- (void)setTableView:(UITableView *)tv;
- (UISearchBar *)searchBar;
- (void)setSearchBar:(UISearchBar *)sb;
- (NSString *)navTitle;
- (void)setNavTitle:(NSString *)t;
- (NSArray<YMSettingsItem *> *)items;
- (void)setItems:(NSArray<YMSettingsItem *> *)items;
- (UIColor *)ymTextColor;
- (UIColor *)ymSecondaryColor;
- (UITableViewCell *)cellForItem:(YMSettingsItem *)item tableView:(UITableView *)tableView;
- (UITableViewCell *)navCellForItem:(YMSettingsItem *)item tableView:(UITableView *)tableView;
- (void)updateSearchBarTheme;

// Global search (home page): the search bar covers every registered settings group
// instead of just this page's own rows.
- (BOOL)globalSearch;
- (void)setGlobalSearch:(BOOL)global;
- (NSArray<YMSearchRow *> *)globalSearchIndex;
- (NSArray<YMSearchRow *> *)filteredSearchRows;
- (void)setFilteredSearchRows:(NSArray<YMSearchRow *> *)rows;
// YES = per-page search bar filtering this page's own rows. Subclasses can override.
- (BOOL)usesPageSearch;
// YES = thin version footer below the rows (set before pushing; home page only).
- (BOOL)showsVersionFooter;
- (void)setShowsVersionFooter:(BOOL)shows;
- (UIView *)ymVersionFooterView;
@end

static const void *kYMTableViewKey = &kYMTableViewKey;
static const void *kYMSearchBarKey = &kYMSearchBarKey;
static const void *kYMNavTitleKey = &kYMNavTitleKey;
static const void *kYMItemsKey = &kYMItemsKey;
static const void *kYMSwitchKeyAssoc = &kYMSwitchKeyAssoc;
static const void *kYMSliderKeyAssoc = &kYMSliderKeyAssoc;
static const void *kYMSliderStepAssoc = &kYMSliderStepAssoc;
static const void *kYMSliderLabelAssoc = &kYMSliderLabelAssoc;
static const void *kYMPageFilterKey = &kYMPageFilterKey;
static const void *kYMShowsVersionFooterKey = &kYMShowsVersionFooterKey;
static const void *kYMGlobalSearchKey = &kYMGlobalSearchKey;
static const void *kYMGlobalSearchIndexKey = &kYMGlobalSearchIndexKey;
static const void *kYMFilteredSearchRowsKey = &kYMFilteredSearchRowsKey;

static NSString *YMFormattedSliderValue(NSString *key, float value) {
    if ([key isEqualToString:HoldToSpeedRate]) {
        NSString *number = [NSString stringWithFormat:@"%.2f", value];
        while ([number hasSuffix:@"0"]) number = [number substringToIndex:number.length - 1];
        if ([number hasSuffix:@"."]) number = [number substringToIndex:number.length - 1];
        return [number stringByAppendingString:@"x"];
    }
    NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
    formatter.allowedUnits = NSCalendarUnitSecond;
    formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleAbbreviated;
    return [formatter stringFromTimeInterval:value] ?: @"";
}

@implementation YMSubSettingsViewController

- (UITableView *)tableView { return objc_getAssociatedObject(self, kYMTableViewKey); }
- (void)setTableView:(UITableView *)tv { objc_setAssociatedObject(self, kYMTableViewKey, tv, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (UISearchBar *)searchBar { return objc_getAssociatedObject(self, kYMSearchBarKey); }
- (void)setSearchBar:(UISearchBar *)sb { objc_setAssociatedObject(self, kYMSearchBarKey, sb, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSString *)navTitle { return objc_getAssociatedObject(self, kYMNavTitleKey); }
- (void)setNavTitle:(NSString *)t { objc_setAssociatedObject(self, kYMNavTitleKey, t, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSArray<YMSettingsItem *> *)items { return objc_getAssociatedObject(self, kYMItemsKey); }
- (void)setItems:(NSArray<YMSettingsItem *> *)items { objc_setAssociatedObject(self, kYMItemsKey, items, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

- (BOOL)usesPageSearch { return YES; }

#pragma mark - Version footer

- (BOOL)showsVersionFooter { return [objc_getAssociatedObject(self, kYMShowsVersionFooterKey) boolValue]; }
- (void)setShowsVersionFooter:(BOOL)shows { objc_setAssociatedObject(self, kYMShowsVersionFooterKey, @(shows), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

// Thin unselectable footer "YouTube <ver> • YouMod <ver>" (leading/trailing +
// natural alignment = RTL-safe).
- (UIView *)ymVersionFooterView {
    // tableFooterView is frame-sized (no constraints), so give it a real height.
    UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 60)];
    footer.userInteractionEnabled = NO;

    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;

    // YouTube version via [%c(YTVersionUtils) appVersion].
    NSString *ytVersion = @"";
    @try {
        ytVersion = [%c(YTVersionUtils) appVersion] ?: @"";
    } @catch (...) {}
    label.text = [NSString stringWithFormat:@"YouTube %@ • YouMod %@", ytVersion, YouModVersion];
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightLight];
    label.textColor = [self ymSecondaryColor];
    label.textAlignment = NSTextAlignmentNatural; // follows RTL/LTR
    label.userInteractionEnabled = NO; // unselectable
    [footer addSubview:label];

    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:footer.leadingAnchor constant:16],  // gap from screen (flips in RTL)
        [label.trailingAnchor constraintEqualToAnchor:footer.trailingAnchor constant:-16],
        [label.topAnchor constraintEqualToAnchor:footer.topAnchor constant:12],
        [label.bottomAnchor constraintEqualToAnchor:footer.bottomAnchor constant:-24],
    ]];

    return footer;
}

// The active per-page filter text (nil/empty = not filtering).
- (NSString *)pageFilter { return objc_getAssociatedObject(self, kYMPageFilterKey); }
- (void)setPageFilter:(NSString *)f { objc_setAssociatedObject(self, kYMPageFilterKey, f, OBJC_ASSOCIATION_COPY_NONATOMIC); }

static const void *kYMCachedDisplayedItemsKey = &kYMCachedDisplayedItemsKey;

- (NSArray<YMSettingsItem *> *)cachedDisplayedItems {
    return objc_getAssociatedObject(self, kYMCachedDisplayedItemsKey);
}

- (void)setCachedDisplayedItems:(NSArray<YMSettingsItem *> *)items {
    objc_setAssociatedObject(self, kYMCachedDisplayedItemsKey, items, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// Rows to show: visible items, or title/subtitle matches while a page search is
// active (headers dropped — a filtered list has no sections).
- (BOOL)isItemVisible:(YMSettingsItem *)item {
    return [item isVisible];
}

- (NSArray<YMSettingsItem *> *)computeDisplayedItems {
    NSString *q = self.pageFilter;
    if (q.length == 0) {
        NSMutableArray<YMSettingsItem *> *visible = [NSMutableArray array];
        for (YMSettingsItem *item in self.items)
            if ([self isItemVisible:item]) [visible addObject:item];
        return visible;
    }
    NSMutableArray<YMSettingsItem *> *matches = [NSMutableArray array];
    NSStringCompareOptions opts = NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch;
    for (YMSettingsItem *item in self.items) {
        if (item.type == YMRowTypeHeader || ![self isItemVisible:item]) continue;
        NSString *hay = [NSString stringWithFormat:@"%@ %@", item.title ?: @"", item.subtitle ?: @""];
        if ([hay rangeOfString:q options:opts].location != NSNotFound) [matches addObject:item];
    }
    return matches;
}

- (NSArray<YMSettingsItem *> *)displayedItems {
    NSArray<YMSettingsItem *> *cached = [self cachedDisplayedItems];
    if (!cached) {
        cached = [self computeDisplayedItems];
        [self setCachedDisplayedItems:cached];
    }
    return cached;
}

- (void)updateDisplayedItemsAnimated:(BOOL)animated {
    NSArray<YMSettingsItem *> *oldItems = [self displayedItems];
    NSArray<YMSettingsItem *> *newItems = [self computeDisplayedItems];

    if (!animated || self.pageFilter.length > 0 || !self.tableView.window) {
        [self setCachedDisplayedItems:newItems];
        [self.tableView reloadData];
        return;
    }

    NSMutableArray<NSIndexPath *> *deletions = [NSMutableArray array];
    for (NSUInteger i = 0; i < oldItems.count; i++) {
        if (![newItems containsObject:oldItems[i]]) {
            [deletions addObject:[NSIndexPath indexPathForRow:i inSection:0]];
        }
    }

    NSMutableArray<NSIndexPath *> *insertions = [NSMutableArray array];
    for (NSUInteger i = 0; i < newItems.count; i++) {
        if (![oldItems containsObject:newItems[i]]) {
            [insertions addObject:[NSIndexPath indexPathForRow:i inSection:0]];
        }
    }

    if (deletions.count > 0 || insertions.count > 0) {
        [self setCachedDisplayedItems:newItems];
        [self.tableView performBatchUpdates:^{
            if (deletions.count > 0) {
                [self.tableView deleteRowsAtIndexPaths:deletions withRowAnimation:UITableViewRowAnimationFade];
            }
            if (insertions.count > 0) {
                [self.tableView insertRowsAtIndexPaths:insertions withRowAnimation:UITableViewRowAnimationFade];
            }
        } completion:nil];
    } else {
        [self setCachedDisplayedItems:newItems];
    }
}

- (void)updateSearchBarTheme {
    UISearchBar *sb = self.searchBar;
    if (!sb) return;
    sb.backgroundColor = UIColor.clearColor;
    sb.barTintColor = UIColor.clearColor;
    if ([sb respondsToSelector:@selector(searchTextField)]) {
        UITextField *tf = sb.searchTextField;
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            tf.textColor = [UIColor whiteColor];
        } else {
            tf.textColor = [UIColor labelColor];
        }
        tf.backgroundColor = UIColor.clearColor;
        tf.tintColor = sb.tintColor;
        tf.attributedPlaceholder = [[NSAttributedString alloc] initWithString:sb.placeholder ?: @"" attributes:@{NSForegroundColorAttributeName: [UIColor secondaryLabelColor]}];
        YouModApplyLiquidGlassToView(tf, NO);
    }
}

- (void)viewDidLoad {
    Class ytStyled = objc_getClass("YTStyledViewController");
    struct objc_super superStruct = { self, ytStyled ?: [UIViewController class] };
    ((void (*)(struct objc_super *, SEL))objc_msgSendSuper)(&superStruct, @selector(viewDidLoad));

    self.title = self.navTitle;

    UIColor *bgColor = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark)
        ? [%c(YTColor) black3]
        : [UIColor systemBackgroundColor];

    self.view.backgroundColor = bgColor;

    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];
    appearance.backgroundColor = bgColor;
    self.navigationController.navigationBar.standardAppearance = appearance;
    self.navigationController.navigationBar.scrollEdgeAppearance = appearance;

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.estimatedRowHeight = 60;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.backgroundColor = bgColor;

    [self.view addSubview:self.tableView];

    if (self.usesPageSearch) {
        UISearchBar *sb = [[UISearchBar alloc] initWithFrame:CGRectZero];
        sb.translatesAutoresizingMaskIntoConstraints = NO;
        sb.placeholder = LOC(@"SEARCH");
        sb.searchBarStyle = UISearchBarStyleMinimal;
        sb.tintColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.9 alpha:1.0];
        sb.delegate = self;
        sb.backgroundImage = [[UIImage alloc] init];
        [self.view addSubview:sb];
        self.searchBar = sb;
        [self updateSearchBarTheme];

        [NSLayoutConstraint activateConstraints:@[
            [sb.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
            [sb.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [sb.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

            [self.tableView.topAnchor constraintEqualToAnchor:sb.bottomAnchor],
            [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
            [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
            [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
        ]];
    }

    // Thin version footer below the rows (custom YouMod home page only).
    if (self.showsVersionFooter) {
        self.tableView.tableFooterView = [self ymVersionFooterView];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle) {
        UIColor *bgColor = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark)
            ? [%c(YTColor) black3]
            : [UIColor systemBackgroundColor];
        self.view.backgroundColor = bgColor;
        self.tableView.backgroundColor = bgColor;
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithDefaultBackground];
        appearance.backgroundColor = bgColor;
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
        [self updateSearchBarTheme];
        [self updateDisplayedItemsAnimated:NO];
    }
}

#pragma mark - Global Search

- (BOOL)globalSearch { return [objc_getAssociatedObject(self, kYMGlobalSearchKey) boolValue]; }
- (void)setGlobalSearch:(BOOL)global { objc_setAssociatedObject(self, kYMGlobalSearchKey, @(global), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSArray<YMSearchRow *> *)filteredSearchRows { return objc_getAssociatedObject(self, kYMFilteredSearchRowsKey) ?: @[]; }
- (void)setFilteredSearchRows:(NSArray<YMSearchRow *> *)rows { objc_setAssociatedObject(self, kYMFilteredSearchRowsKey, rows, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

// One settings item as a search row rendered through this page's cell builders.
- (YMSearchRow *)searchRowForItem:(YMSettingsItem *)item groupTitle:(NSString *)groupTitle {
    __weak typeof(self) weakSelf = self;
    YMSearchRow *row = [YMSearchRow new];
    NSString *sub = item.subtitle.length ? item.subtitle : @"";
    row.searchText = [NSString stringWithFormat:@"%@ %@ %@", item.title ?: @"", sub, groupTitle ?: @""];
    row.makeCell = ^UITableViewCell *(UITableView *tv) { return [weakSelf cellForItem:item tableView:tv]; };
    return row;
}

// Index of every real setting (toggle/picker/segment/slider) from the registered
// groups plus SponsorBlock rows. Menu rows and headers are entries, not settings.
- (NSArray<YMSearchRow *> *)globalSearchIndex {
    NSArray<YMSearchRow *> *cached = objc_getAssociatedObject(self, kYMGlobalSearchIndexKey);
    if (cached) return cached;
    NSMutableArray<YMSearchRow *> *rows = [NSMutableArray array];
    for (YMSettingsGroup *group in gYMSearchGroups) {
        for (YMSettingsItem *item in group.items) {
            BOOL searchable = item.type == YMRowTypeToggle || item.type == YMRowTypePicker
                || item.type == YMRowTypeSegment || item.type == YMRowTypeTextSegment
                || item.type == YMRowTypeImageSegment || item.type == YMRowTypeSlider;
            if (!searchable || item.title.length == 0 || ![item isVisible]) continue;
            [rows addObject:[self searchRowForItem:item groupTitle:group.title]];
        }
    }
    [rows addObjectsFromArray:sbSearchRows(self)];
    objc_setAssociatedObject(self, kYMGlobalSearchIndexKey, rows, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return rows;
}

// Refilter the global index for the current pageFilter text.
- (void)updateGlobalSearchResults {
    NSString *q = self.pageFilter;
    if (q.length == 0) {
        self.filteredSearchRows = @[];
        return;
    }
    NSMutableArray<YMSearchRow *> *matches = [NSMutableArray array];
    NSStringCompareOptions opts = NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch;
    for (YMSearchRow *row in [self globalSearchIndex]) {
        if ([row.searchText rangeOfString:q options:opts].location != NSNotFound) [matches addObject:row];
    }
    self.filteredSearchRows = matches;
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.pageFilter = [searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (self.globalSearch) {
        [self updateGlobalSearchResults];
        [self.tableView reloadData];
    } else {
        [self updateDisplayedItemsAnimated:NO];
    }
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:NO animated:YES];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = @"";
    self.pageFilter = @"";
    [searchBar resignFirstResponder];
    if (self.globalSearch) {
        [self updateGlobalSearchResults];
        [self.tableView reloadData];
    } else {
        [self updateDisplayedItemsAnimated:NO];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    Class ytStyled = objc_getClass("YTStyledViewController");
    struct objc_super superStruct = { self, ytStyled ?: [UIViewController class] };
    ((void (*)(struct objc_super *, SEL, BOOL))objc_msgSendSuper)(&superStruct, @selector(viewWillAppear:), animated);
}

- (void)viewDidLayoutSubviews {
    Class ytStyled = objc_getClass("YTStyledViewController");
    struct objc_super superStruct = { self, ytStyled ?: [UIViewController class] };
    ((void (*)(struct objc_super *, SEL))objc_msgSendSuper)(&superStruct, @selector(viewDidLayoutSubviews));
    YTQTMButton *backButton = [self valueForKey:@"_backButton"];

    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        backButton.tintColor = [UIColor whiteColor];
    } else {
        backButton.tintColor = [UIColor blackColor];
    }

    // Keep the footer width in sync with the table (created before layout).
    UIView *footer = self.tableView.tableFooterView;
    if (footer) {
        CGRect f = footer.frame;
        if (f.size.width != self.tableView.bounds.size.width) {
            f.size.width = self.tableView.bounds.size.width;
            footer.frame = f;
        }
    }
}

- (UIColor *)navBarForegroundColor {
    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        return [UIColor whiteColor];
    }
    // Concrete colour in light mode; nil would let YouTube tint the nav-bar
    // foreground system blue. labelColor = black in light / white in dark.
    return [UIColor labelColor];
}

- (UIColor *)ymTextColor {
    return (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark)
        ? [UIColor whiteColor] : [UIColor labelColor];
}

- (UIColor *)ymSecondaryColor {
    return [UIColor colorWithWhite:0.55 alpha:1.0];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.globalSearch && self.pageFilter.length > 0) return self.filteredSearchRows.count;
    return self.displayedItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.globalSearch && self.pageFilter.length > 0) {
        return self.filteredSearchRows[indexPath.row].makeCell(tableView);
    }
    return [self cellForItem:self.displayedItems[indexPath.row] tableView:tableView];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.globalSearch && self.pageFilter.length > 0) {
        CGFloat h = self.filteredSearchRows[indexPath.row].cellHeight;
        return h > 0 ? h : UITableViewAutomaticDimension;
    }
    YMSettingsItem *item = self.displayedItems[indexPath.row];
    // Nav rows without a subtitle (home page section rows) get a taller, icon-ready row.
    if (item.type == YMRowTypeAction && item.opensPage && item.subtitle.length == 0) return 66;
    return UITableViewAutomaticDimension;
}

// Builds a cell for one item by row type (shared by the data source and search).
- (UITableViewCell *)cellForItem:(YMSettingsItem *)item tableView:(UITableView *)tableView {
    if (item.type == YMRowTypeToggle) {
        return [self toggleCellForItem:item tableView:tableView];
    } else if (item.type == YMRowTypeAction) {
        return item.opensPage ? [self navCellForItem:item tableView:tableView] : [self actionCellForItem:item tableView:tableView];
    } else if (item.type == YMRowTypeHeader) {
        return [self headerCellForItem:item tableView:tableView];
    } else if (item.type == YMRowTypeSegment) {
        return [self segmentCellForItem:item tableView:tableView];
    } else if (item.type == YMRowTypeTextSegment) {
        return [self textSegmentCellForItem:item tableView:tableView];
    } else if (item.type == YMRowTypeImageSegment) {
        return [self imageSegmentCellForItem:item tableView:tableView];
    } else if (item.type == YMRowTypeSlider) {
        return [self sliderCellForItem:item tableView:tableView];
    } else if (item.type == YMRowTypeDeveloper) {
        return [self developerCellForItem:item tableView:tableView];
    }
    return [self pickerCellForItem:item tableView:tableView];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.globalSearch && self.pageFilter.length > 0) {
        YMSearchRow *row = self.filteredSearchRows[indexPath.row];
        if (!row.onSelect) return;
        __weak typeof(self) weakSelf = self;
        row.onSelect(self, ^{ [weakSelf.tableView reloadData]; });
        return;
    }
    YMSettingsItem *item = self.displayedItems[indexPath.row];
    if (item.type == YMRowTypeAction && item.action) {
        item.action(self);
    } else if (item.type == YMRowTypeDeveloper && item.profileURL.length > 0) {
        NSURL *url = [NSURL URLWithString:item.profileURL];
        if (url) [%c(YTUIUtils) openURL:url];
    }
}

#pragma mark - Toggle Cell

- (UITableViewCell *)toggleCellForItem:(YMSettingsItem *)item tableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = item.title;
    cell.textLabel.textColor = [self ymTextColor];
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];

    if (item.subtitle.length > 0) {
        cell.detailTextLabel.text = item.subtitle;
        cell.detailTextLabel.textColor = [self ymSecondaryColor];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
        cell.detailTextLabel.numberOfLines = 0;
    }

    UISwitch *sw = [[UISwitch alloc] init];
    sw.on = IS_ENABLED(item.key);
    sw.onTintColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.9 alpha:1.0];
    objc_setAssociatedObject(sw, kYMSwitchKeyAssoc, item.key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [sw addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = sw;

    return cell;
}

- (void)toggleChanged:(UISwitch *)sender {
    NSString *key = objc_getAssociatedObject(sender, kYMSwitchKeyAssoc);
    if (key) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setBool:sender.on forKey:key];
        if ([key isEqualToString:HoldToSpeedEnabled] && !sender.on) {
            [defaults setBool:NO forKey:GlobalSpeedLocked];
        }
        [self updateDisplayedItemsAnimated:YES];
        if ([key isEqualToString:SkipBackwardEnabled] || [key isEqualToString:SkipForwardEnabled]) {
            YouModConfigureRemoteSkipCommands();
        }
    }
}

- (UITableViewCell *)sliderCellForItem:(YMSettingsItem *)item tableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    // Stored 0 = "no value yet" → show the default. Slider ranges must be positive.
    float stored = [[NSUserDefaults standardUserDefaults] floatForKey:item.key];
    if (stored <= 0) stored = item.sliderDefault;
    stored = fmaxf(item.sliderMin, fminf(stored, item.sliderMax));
    if (item.sliderStep > 0) {
        stored = item.sliderMin + roundf((stored - item.sliderMin) / item.sliderStep) * item.sliderStep;
    }

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = item.title;
    titleLabel.textColor = [self ymTextColor];
    titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    [cell.contentView addSubview:titleLabel];

    UILabel *valueLabel = [[UILabel alloc] init];
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.textColor = [self ymSecondaryColor];
    valueLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    valueLabel.textAlignment = NSTextAlignmentRight;
    valueLabel.text = YMFormattedSliderValue(item.key, stored);
    [cell.contentView addSubview:valueLabel];

    UISlider *slider = [[UISlider alloc] init];
    slider.translatesAutoresizingMaskIntoConstraints = NO;
    slider.minimumValue = item.sliderMin;
    slider.maximumValue = item.sliderMax;
    [slider setValue:stored animated:NO];
    slider.minimumTrackTintColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.9 alpha:1.0];
    slider.maximumTrackTintColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    objc_setAssociatedObject(slider, kYMSliderKeyAssoc, item.key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(slider, kYMSliderStepAssoc, @(item.sliderStep), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(slider, kYMSliderLabelAssoc, valueLabel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [cell.contentView addSubview:slider];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [titleLabel.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:12],
        [valueLabel.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
        [valueLabel.centerYAnchor constraintEqualToAnchor:titleLabel.centerYAnchor],
        [valueLabel.widthAnchor constraintGreaterThanOrEqualToConstant:60],
        [slider.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [slider.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
        [slider.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
        [slider.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-12],
    ]];

    return cell;
}

- (void)sliderChanged:(UISlider *)sender {
    NSString *key = objc_getAssociatedObject(sender, kYMSliderKeyAssoc);
    if (!key) return;
    float step = [objc_getAssociatedObject(sender, kYMSliderStepAssoc) floatValue];
    if (step <= 0) step = 1;
    float snapped = sender.minimumValue + roundf((sender.value - sender.minimumValue) / step) * step;
    snapped = fmaxf(sender.minimumValue, fminf(snapped, sender.maximumValue));
    [sender setValue:snapped animated:YES];
    [[NSUserDefaults standardUserDefaults] setFloat:snapped forKey:key];
    UILabel *valueLabel = objc_getAssociatedObject(sender, kYMSliderLabelAssoc);
    NSString *formattedValue = YMFormattedSliderValue(key, snapped);
    if (valueLabel && ![valueLabel.text isEqualToString:formattedValue]) {
        [UIView transitionWithView:valueLabel
                          duration:0.12
                           options:UIViewAnimationOptionTransitionCrossDissolve | UIViewAnimationOptionBeginFromCurrentState
                        animations:^{ valueLabel.text = formattedValue; }
                        completion:nil];
    }
    if ([key isEqualToString:RewindSeconds] || [key isEqualToString:ForwardSeconds]) {
        YouModConfigureRemoteSkipCommands();
    }
}

#pragma mark - Developer Cell

// In-memory avatar cache keyed by avatar URL, shared across all settings pages.
static NSCache<NSString *, UIImage *> *YMAvatarCache(void) {
    static NSCache<NSString *, UIImage *> *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [[NSCache alloc] init];
        cache.countLimit = 32;
    });
    return cache;
}

// Round an image to a circle of the given diameter (points).
static UIImage *YMCircularImage(UIImage *image, CGFloat diameter) {
    if (!image) return nil;
    CGSize size = CGSizeMake(diameter, diameter);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGRect rect = CGRectMake(0, 0, size.width, size.height);
    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:rect];
    [path addClip];
    [image drawInRect:rect];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result ?: image;
}

// Gray circle shown while a GitHub avatar is still downloading.
static UIImage *YMGrayCircle(CGFloat diameter) {
    CGSize size = CGSizeMake(diameter, diameter);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    [[UIColor colorWithWhite:0.3 alpha:1.0] setFill];
    UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, size.width, size.height)];
    [path fill];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

- (UITableViewCell *)developerCellForItem:(YMSettingsItem *)item tableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator; // the trailing ">"

    cell.textLabel.text = item.title;
    cell.textLabel.textColor = [self ymTextColor];
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];

    if (item.subtitle.length > 0) {
        cell.detailTextLabel.text = item.subtitle;
        cell.detailTextLabel.textColor = [self ymSecondaryColor];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
        cell.detailTextLabel.numberOfLines = 0;
    }

    // Avatar in cell.imageView so UIKit lays the name/role text beside it.
    const CGFloat avatarDiameter = 36.0;
    cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
    cell.imageView.clipsToBounds = YES;

    NSString *urlString = item.avatarURL;
    if (urlString.length > 0) {
        UIImage *cached = [YMAvatarCache() objectForKey:urlString];
        if (cached) {
            cell.imageView.image = cached;
        } else {
            cell.imageView.image = YMGrayCircle(avatarDiameter); // placeholder, no text jump
            NSURL *url = [NSURL URLWithString:urlString];
            if (url) {
                __weak UITableViewCell *weakCell = cell;
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                    NSData *data = [NSData dataWithContentsOfURL:url];
                    UIImage *img = data ? [UIImage imageWithData:data] : nil;
                    UIImage *rounded = img ? YMCircularImage(img, avatarDiameter) : nil;
                    if (rounded) [YMAvatarCache() setObject:rounded forKey:urlString];
                    if (rounded) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            __strong UITableViewCell *strongCell = weakCell;
                            if (!strongCell) return;
                            strongCell.imageView.image = rounded;
                            [strongCell setNeedsLayout];
                        });
                    }
                });
            }
        }
    }

    return cell;
}

#pragma mark - Nav Cell

// Menu row that pushes a page: leading YT icon (RTL-mirrored), title, chevron.
- (UITableViewCell *)navCellForItem:(YMSettingsItem *)item tableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = item.title;
    titleLabel.textColor = [self ymTextColor];
    titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    [cell.contentView addSubview:titleLabel];

    NSLayoutXAxisAnchor *textLeading = cell.contentView.leadingAnchor;
    CGFloat textInset = 16;

    if (item.iconType > 0) {
        UIImageView *iconView = [[UIImageView alloc] init];
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        UIImage *icon = YouModYTIconImage(item.iconType, NO, nil);
        iconView.image = [icon imageFlippedForRightToLeftLayoutDirection];
        [cell.contentView addSubview:iconView];
        [NSLayoutConstraint activateConstraints:@[
            [iconView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
            [iconView.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
            [iconView.widthAnchor constraintEqualToConstant:28],
            [iconView.heightAnchor constraintEqualToConstant:28],
        ]];
        textLeading = iconView.trailingAnchor;
        textInset = 12;
    }

    if (item.subtitle.length > 0) {
        UILabel *subtitleLabel = [[UILabel alloc] init];
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        subtitleLabel.text = item.subtitle;
        subtitleLabel.textColor = [self ymSecondaryColor];
        subtitleLabel.font = [UIFont systemFontOfSize:13];
        subtitleLabel.numberOfLines = 0;
        [cell.contentView addSubview:subtitleLabel];
        [NSLayoutConstraint activateConstraints:@[
            [titleLabel.leadingAnchor constraintEqualToAnchor:textLeading constant:textInset],
            [titleLabel.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:12],
            [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
            [subtitleLabel.leadingAnchor constraintEqualToAnchor:textLeading constant:textInset],
            [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:3],
            [subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
            [subtitleLabel.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-12],
        ]];
    } else {
        [NSLayoutConstraint activateConstraints:@[
            [titleLabel.leadingAnchor constraintEqualToAnchor:textLeading constant:textInset],
            [titleLabel.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
            [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
        ]];
    }

    return cell;
}

#pragma mark - Action Cell

- (UITableViewCell *)actionCellForItem:(YMSettingsItem *)item tableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.textLabel.text = item.title;
    cell.textLabel.textColor = [self ymTextColor];
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];

    if (item.opensPage) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    if (item.subtitle.length > 0) {
        cell.detailTextLabel.text = item.subtitle;
        cell.detailTextLabel.textColor = [self ymSecondaryColor];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
        cell.detailTextLabel.numberOfLines = 0;
    }

    return cell;
}

#pragma mark - Header Cell

- (UITableViewCell *)headerCellForItem:(YMSettingsItem *)item tableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = item.title;
    cell.textLabel.textColor = [self ymSecondaryColor];
    cell.textLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    return cell;
}

#pragma mark - Segment Cell

- (UITableViewCell *)segmentCellForItem:(YMSettingsItem *)item tableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = item.title;
    titleLabel.textColor = [self ymTextColor];
    titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:titleLabel];

    NSMutableArray *items = [NSMutableArray array];
    for (NSUInteger i = 0; i < item.segmentIcons.count; i++) {
        [items addObject:@""];
    }
    UISegmentedControl *segment = [[UISegmentedControl alloc] initWithItems:items];

    for (NSInteger i = 0; i < (NSInteger)item.segmentIcons.count; i++) {
        YTIIcon *ytIcon = [%c(YTIIcon) new];
        if (ytIcon) {
            ((void (*)(id, SEL, int))objc_msgSend)(ytIcon, @selector(setIconType:), [item.segmentIcons[i] intValue]);
            UIImage *iconImage = nil;
            if ([ytIcon respondsToSelector:@selector(iconImageWithColor:)]) {
                iconImage = [ytIcon iconImageWithColor:[UIColor whiteColor]];
            } else if ([ytIcon respondsToSelector:@selector(iconImageWithSelected:)]) {
                iconImage = [ytIcon iconImageWithSelected:NO];
            }
            if (iconImage) {
                [segment setImage:iconImage forSegmentAtIndex:i];
            }
        }
    }

    id storedSegVal = [[NSUserDefaults standardUserDefaults] objectForKey:item.key];
    NSInteger segIdx = storedSegVal ? [storedSegVal integerValue] : item.pickerDefault;
    segment.selectedSegmentIndex = MAX(0, MIN(segIdx, segment.numberOfSegments - 1));
    segment.backgroundColor = [UIColor colorWithRed:0.13 green:0.13 blue:0.13 alpha:1.0];
    segment.selectedSegmentTintColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:1.0];
    segment.layer.cornerRadius = 8.0;
    segment.clipsToBounds = YES;

    objc_setAssociatedObject(segment, kYMSwitchKeyAssoc, item.key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [segment addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];

    segment.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:segment];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [titleLabel.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:12],

        [segment.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [segment.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
        [segment.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10],
        [segment.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-12],
        [segment.heightAnchor constraintEqualToConstant:36]
    ]];

    return cell;
}

- (void)segmentChanged:(UISegmentedControl *)sender {
    NSString *key = objc_getAssociatedObject(sender, kYMSwitchKeyAssoc);
    if (key) {
        [[NSUserDefaults standardUserDefaults] setInteger:sender.selectedSegmentIndex forKey:key];
        [self updateDisplayedItemsAnimated:YES];
    }
}

#pragma mark - Text Segment Cell

- (UITableViewCell *)textSegmentCellForItem:(YMSettingsItem *)item tableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = item.title;
    titleLabel.textColor = [self ymTextColor];
    titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:titleLabel];

    UISegmentedControl *segment = [[UISegmentedControl alloc] initWithItems:item.segmentLabels];

    id storedVal = [[NSUserDefaults standardUserDefaults] objectForKey:item.key];
    NSInteger txtSegIdx = storedVal ? [storedVal integerValue] : item.pickerDefault;
    segment.selectedSegmentIndex = MAX(0, MIN(txtSegIdx, segment.numberOfSegments - 1));
    segment.backgroundColor = [UIColor colorWithRed:0.13 green:0.13 blue:0.13 alpha:1.0];
    segment.selectedSegmentTintColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:1.0];
    segment.layer.cornerRadius = 8.0;
    segment.clipsToBounds = YES;

    NSDictionary *textAttrs = @{NSForegroundColorAttributeName: [UIColor whiteColor], NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightMedium]};
    [segment setTitleTextAttributes:textAttrs forState:UIControlStateNormal];
    [segment setTitleTextAttributes:textAttrs forState:UIControlStateSelected];

    objc_setAssociatedObject(segment, kYMSwitchKeyAssoc, item.key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [segment addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];

    segment.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:segment];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [titleLabel.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:12],

        [segment.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [segment.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
        [segment.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10],
        [segment.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-12],
        [segment.heightAnchor constraintEqualToConstant:36]
    ]];

    return cell;
}

#pragma mark - Image Segment Cell

- (UITableViewCell *)imageSegmentCellForItem:(YMSettingsItem *)item tableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = item.title;
    titleLabel.textColor = [self ymTextColor];
    titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:titleLabel];

    NSMutableArray *segItems = [NSMutableArray array];
    for (NSUInteger i = 0; i < item.segmentImages.count; i++) {
        [segItems addObject:@""];
    }
    UISegmentedControl *segment = [[UISegmentedControl alloc] initWithItems:segItems];

    for (NSInteger i = 0; i < (NSInteger)item.segmentImages.count; i++) {
        UIImage *img = item.segmentImages[i];
        if (img) [segment setImage:img forSegmentAtIndex:i];
    }

    id storedVal = [[NSUserDefaults standardUserDefaults] objectForKey:item.key];
    NSInteger idx = storedVal ? [storedVal integerValue] : item.pickerDefault;
    segment.selectedSegmentIndex = MAX(0, MIN(idx, segment.numberOfSegments - 1));
    segment.backgroundColor = [UIColor colorWithRed:0.13 green:0.13 blue:0.13 alpha:1.0];
    segment.selectedSegmentTintColor = [UIColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:1.0];
    segment.layer.cornerRadius = 8.0;
    segment.clipsToBounds = YES;

    objc_setAssociatedObject(segment, kYMSwitchKeyAssoc, item.key, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [segment addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];

    segment.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:segment];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [titleLabel.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:12],

        [segment.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [segment.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
        [segment.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:10],
        [segment.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-12],
        [segment.heightAnchor constraintEqualToConstant:36]
    ]];

    return cell;
}

#pragma mark - Picker Cell

- (void)updatePickerButton:(UIButton *)menuButton item:(YMSettingsItem *)item {
    NSInteger safeDefault = (item.pickerDefault >= 0 && item.pickerDefault < (NSInteger)item.pickerOptions.count)
        ? item.pickerDefault : 0;
    id storedValue = [[NSUserDefaults standardUserDefaults] objectForKey:item.key];
    NSInteger currentValue = storedValue ? [storedValue integerValue] : safeDefault;
    NSString *currentTitle = (currentValue >= 0 && currentValue < (NSInteger)item.pickerOptions.count)
        ? item.pickerOptions[currentValue]
        : item.pickerOptions[safeDefault];

    if ([UIButtonConfiguration class] && [menuButton respondsToSelector:@selector(setConfiguration:)]) {
        UIButtonConfiguration *config = [UIButtonConfiguration plainButtonConfiguration];
        config.title = currentTitle;
        config.image = [UIImage systemImageNamed:@"chevron.up.chevron.down" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightMedium]];
        config.imagePlacement = NSDirectionalRectEdgeTrailing;
        config.imagePadding = 6.0;
        config.baseForegroundColor = [self ymSecondaryColor];
        config.contentInsets = NSDirectionalEdgeInsetsMake(6, 8, 6, 8);
        menuButton.configuration = config;
    } else {
        [menuButton setTitle:currentTitle forState:UIControlStateNormal];
        [menuButton setTitleColor:[self ymSecondaryColor] forState:UIControlStateNormal];
        menuButton.titleLabel.font = [UIFont systemFontOfSize:15];
        [menuButton setImage:[UIImage systemImageNamed:@"chevron.up.chevron.down"] forState:UIControlStateNormal];
        menuButton.tintColor = [self ymSecondaryColor];
        menuButton.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
        menuButton.imageEdgeInsets = UIEdgeInsetsMake(0, 6, 0, -6);
    }

    NSMutableArray<UIMenuElement *> *menuActions = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;
    __weak typeof(menuButton) weakButton = menuButton;
    for (NSInteger i = 0; i < (NSInteger)item.pickerOptions.count; i++) {
        NSString *optionTitle = item.pickerOptions[i];
        NSString *itemKey = item.key;
        UIAction *action = [UIAction actionWithTitle:optionTitle image:nil identifier:nil handler:^(__kindof UIAction *a) {
            [[NSUserDefaults standardUserDefaults] setInteger:i forKey:itemKey];
            if ([itemKey isEqualToString:SleepTimerEntry]) {
                // Update the locked sleep.timer entry only when a custom overlay
                // order exists (a one-entry order would default all others to on).
                NSArray *savedOrder = [[NSUserDefaults standardUserDefaults] arrayForKey:OverlayButtonOrder];
                if (savedOrder.count > 0) {
                    NSMutableArray *order = [NSMutableArray array];
                    for (NSDictionary *entry in savedOrder) {
                        if ([entry isKindOfClass:[NSDictionary class]]) [order addObject:[entry mutableCopy]];
                    }
                    NSMutableDictionary *sleepEntry = nil;
                    for (NSMutableDictionary *d in order) {
                        if ([d[@"id"] isEqualToString:@"sleep.timer"]) { sleepEntry = d; break; }
                    }
                    if (!sleepEntry) {
                        sleepEntry = [NSMutableDictionary dictionaryWithDictionary:@{@"id": @"sleep.timer", @"bottom": @(NO)}];
                        [order addObject:sleepEntry];
                    }
                    sleepEntry[@"enabled"] = @(i == 2 || i == 3);
                    [[NSUserDefaults standardUserDefaults] setObject:order forKey:OverlayButtonOrder];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:@"YouModUpdateOverlayButtons" object:nil];
            }
            if (weakButton) {
                [weakSelf updatePickerButton:weakButton item:item];
            }
            [weakSelf updateDisplayedItemsAnimated:YES];
        }];
        action.state = (i == currentValue) ? UIMenuElementStateOn : UIMenuElementStateOff;
        [menuActions addObject:action];
    }

    menuButton.menu = [UIMenu menuWithTitle:item.title ?: @"" children:menuActions];
}

- (UITableViewCell *)pickerCellForItem:(YMSettingsItem *)item tableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    UIStackView *labelStack = [[UIStackView alloc] init];
    labelStack.axis = UILayoutConstraintAxisVertical;
    labelStack.spacing = 2.0;
    labelStack.alignment = UIStackViewAlignmentLeading;
    labelStack.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = item.title;
    titleLabel.textColor = [self ymTextColor];
    titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    titleLabel.numberOfLines = 0;
    [labelStack addArrangedSubview:titleLabel];

    if (item.subtitle.length > 0) {
        UILabel *subLabel = [[UILabel alloc] init];
        subLabel.text = item.subtitle;
        subLabel.textColor = [self ymSecondaryColor];
        subLabel.font = [UIFont systemFontOfSize:13];
        subLabel.numberOfLines = 0;
        [labelStack addArrangedSubview:subLabel];
    }

    UIButton *menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
    menuButton.translatesAutoresizingMaskIntoConstraints = NO;
    menuButton.showsMenuAsPrimaryAction = YES;
    [menuButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [menuButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

    [self updatePickerButton:menuButton item:item];

    [cell.contentView addSubview:labelStack];
    [cell.contentView addSubview:menuButton];

    [NSLayoutConstraint activateConstraints:@[
        [labelStack.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [labelStack.topAnchor constraintGreaterThanOrEqualToAnchor:cell.contentView.topAnchor constant:12],
        [labelStack.bottomAnchor constraintLessThanOrEqualToAnchor:cell.contentView.bottomAnchor constant:-12],
        [labelStack.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],

        [menuButton.leadingAnchor constraintGreaterThanOrEqualToAnchor:labelStack.trailingAnchor constant:12],
        [menuButton.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
        [menuButton.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [menuButton.topAnchor constraintGreaterThanOrEqualToAnchor:cell.contentView.topAnchor constant:8],
        [menuButton.bottomAnchor constraintLessThanOrEqualToAnchor:cell.contentView.bottomAnchor constant:-8]
    ]];

    return cell;
}

#pragma mark - Table View Footer

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    return [[UIView alloc] init];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 16;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    return [[UIView alloc] init];
}

@end

#pragma mark - Convenience Factory Functions

YMSettingsItem *YMToggle(NSString *title, NSString *subtitle, NSString *key) {
    return [YMSettingsItem toggleWithTitle:title subtitle:subtitle key:key];
}

YMSettingsItem *YMSlider(NSString *title, NSString *subtitle, NSString *key, float min, float max, float step, float defaultValue) {
    return [YMSettingsItem sliderWithTitle:title subtitle:subtitle key:key min:min max:max step:step defaultValue:defaultValue];
}

YMSettingsItem *YMPicker(NSString *title, NSString *subtitle, NSString *key, NSArray<NSString *> *options, NSInteger defaultValue) {
    return [YMSettingsItem pickerWithTitle:title subtitle:subtitle key:key options:options defaultValue:defaultValue];
}

YMSettingsItem *YMAction(NSString *title, NSString *subtitle, void (^action)(UIViewController *vc)) {
    return [YMSettingsItem actionWithTitle:title subtitle:subtitle action:action];
}

YMSettingsItem *YMNavAction(NSString *title, NSString *subtitle, void (^action)(UIViewController *vc)) {
    return [YMSettingsItem navActionWithTitle:title subtitle:subtitle action:action];
}

YMSettingsItem *YMHeader(NSString *title) {
    return [YMSettingsItem headerWithTitle:title];
}

YMSettingsItem *YMSegment(NSString *title, NSString *key, NSArray<NSNumber *> *icons, NSInteger defaultValue) {
    return [YMSettingsItem segmentWithTitle:title key:key icons:icons defaultValue:defaultValue];
}

YMSettingsItem *YMTextSegment(NSString *title, NSString *key, NSArray<NSString *> *labels, NSInteger defaultValue) {
    return [YMSettingsItem textSegmentWithTitle:title key:key labels:labels defaultValue:defaultValue];
}

YMSettingsItem *YMImageSegment(NSString *title, NSString *key, NSArray<UIImage *> *images, NSInteger defaultValue) {
    return [YMSettingsItem imageSegmentWithTitle:title key:key images:images defaultValue:defaultValue];
}

// Developer row builder: GitHub serves avatars at github.com/<user>.png, so the
// handle both opens the profile and fetches the avatar.
YMSettingsItem *YMDeveloper(NSString *name, NSString *role, NSString *profileURL, NSString *avatarBaseURL) {
    NSString *avatarURL = [NSString stringWithFormat:@"%@.png", avatarBaseURL];
    return [YMSettingsItem developerWithName:name role:role profileURL:profileURL avatarURL:avatarURL];
}

#pragma mark - YMTabOrderViewController

static NSString * const kYMTabIDs[] = {
    @"home", @"shorts", @"create", @"subscriptions", @"library", @"history", @"gaming", @"sports", @"notifications", @"news", @"music", @"watchlater", @"playlist", @"like", @"live", @"post", @"video", @"movie", @"course", @"minigame", @"fashion", @"learning", @"download"
};
static const NSInteger kYMTabCount = 23;
static const NSInteger kYMTabMaxEnabled = 6;
static const NSInteger kYMTabMinEnabled = 1;

@interface YMTabOrderViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
- (UITableView *)tableView;
- (void)setTableView:(UITableView *)tv;
- (NSMutableArray<NSMutableDictionary *> *)tabData;
- (void)setTabData:(NSMutableArray<NSMutableDictionary *> *)data;
- (NSArray *)initialSnapshot;
- (void)setInitialSnapshot:(NSArray *)snap;
@end

static const void *kYMTabTableViewKey = &kYMTabTableViewKey;
static const void *kYMTabDataKey = &kYMTabDataKey;
static const void *kYMTabSnapshotKey = &kYMTabSnapshotKey;
// Saved nav-bar appearances, restored on dismissal. This screen installs its own
// opaque appearance; the shared bar would otherwise repaint the previous screen's
// back button with the appearance's default (blue) tint.
static const void *kYMTabSavedStdAppearanceKey = &kYMTabSavedStdAppearanceKey;
static const void *kYMTabSavedScrollEdgeAppearanceKey = &kYMTabSavedScrollEdgeAppearanceKey;

@implementation YMTabOrderViewController

- (UITableView *)tableView { return objc_getAssociatedObject(self, kYMTabTableViewKey); }
- (void)setTableView:(UITableView *)tv { objc_setAssociatedObject(self, kYMTabTableViewKey, tv, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSMutableArray<NSMutableDictionary *> *)tabData { return objc_getAssociatedObject(self, kYMTabDataKey); }
- (void)setTabData:(NSMutableArray<NSMutableDictionary *> *)data { objc_setAssociatedObject(self, kYMTabDataKey, data, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSArray *)initialSnapshot { return objc_getAssociatedObject(self, kYMTabSnapshotKey); }
- (void)setInitialSnapshot:(NSArray *)snap { objc_setAssociatedObject(self, kYMTabSnapshotKey, snap, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

- (NSString *)localizedNameForTabID:(NSString *)tabID {
    if ([tabID isEqualToString:@"home"]) return LOC(@"HOME_TAB");
    if ([tabID isEqualToString:@"shorts"]) return LOC(@"SHORTS_TAB");
    if ([tabID isEqualToString:@"create"]) return LOC(@"CREATE_TAB");
    if ([tabID isEqualToString:@"subscriptions"]) return LOC(@"SUBSCRIPTIONS_TAB");
    if ([tabID isEqualToString:@"library"]) return LOC(@"LIBRARY_TAB");
    if ([tabID isEqualToString:@"history"]) return LOC(@"HISTORY_TAB");
    if ([tabID isEqualToString:@"gaming"]) return LOC(@"GAMING_TAB");
    if ([tabID isEqualToString:@"sports"]) return LOC(@"SPORTS_TAB");
    if ([tabID isEqualToString:@"notifications"]) return LOC(@"NOTI_TAB");
    if ([tabID isEqualToString:@"news"]) return LOC(@"NEWS_TAB");
    if ([tabID isEqualToString:@"music"]) return LOC(@"MUSIC_TAB");
    if ([tabID isEqualToString:@"watchlater"]) return LOC(@"WATCH_LATER_TAB");
    if ([tabID isEqualToString:@"playlist"]) return LOC(@"PLAYLIST_TAB");
    if ([tabID isEqualToString:@"like"]) return LOC(@"LIKE_TAB");
    if ([tabID isEqualToString:@"live"]) return LOC(@"LIVE_TAB");
    if ([tabID isEqualToString:@"post"]) return LOC(@"POST_TAB");
    if ([tabID isEqualToString:@"video"]) return LOC(@"VIDEO_TAB");
    if ([tabID isEqualToString:@"movie"]) return LOC(@"MOVIE_TAB");
    if ([tabID isEqualToString:@"course"]) return LOC(@"COURSE_TAB");
    if ([tabID isEqualToString:@"minigame"]) return LOC(@"MINIGAME_TAB");
    if ([tabID isEqualToString:@"fashion"]) return LOC(@"FASHION_TAB");
    if ([tabID isEqualToString:@"learning"]) return LOC(@"LEARNING_TAB");
    if ([tabID isEqualToString:@"download"]) return LOC(@"DOWNLOAD_LIBRARY_TAB");
    return tabID;
}

- (UIImage *)iconForTabID:(NSString *)tabID {
    static YTAssetLoader *cachedLoader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cachedLoader = [[%c(YTAssetLoader) alloc] initWithBundle:YouModBundle()];
    });

    if ([tabID isEqualToString:@"create"]) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
        return [[UIImage systemImageNamed:@"plus" withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    NSDictionary *ytIconTypes = @{@"home": @(65), @"shorts": @(769), @"subscriptions": @(66), @"library": @(61)};
    NSDictionary *bundleIcons = @{@"history": @"icons/history", @"gaming": @"icons/gaming", @"sports": @"icons/sports", @"notifications": @"icons/noti", @"news": @"icons/news", @"music": @"icons/music", @"watchlater": @"icons/watchlater", @"playlist": @"icons/playlist", @"like": @"icons/like", @"live": @"icons/live", @"post": @"icons/post", @"video": @"icons/video", @"movie": @"icons/movie", @"course": @"icons/course", @"minigame": @"icons/minigame", @"fashion": @"icons/fashion", @"learning": @"icons/learning", @"download": @"icons/download"};

    NSNumber *iconType = ytIconTypes[tabID];
    if (iconType) {
        YTIIcon *icon = [%c(YTIIcon) new];
        if (icon) {
            ((void (*)(id, SEL, int))objc_msgSend)(icon, @selector(setIconType:), [iconType intValue]);
            if ([icon respondsToSelector:@selector(iconImageWithColor:)]) {
                return [[icon iconImageWithColor:[UIColor whiteColor]] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            }
        }
    }

    NSString *bundleName = bundleIcons[tabID];
    if (bundleName && cachedLoader) {
        UIImage *img = [cachedLoader imageNamed:bundleName];
        if (img) return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }

    return nil;
}

- (void)viewDidLoad {
    Class ytStyled = objc_getClass("YTStyledViewController");
    struct objc_super superStruct = { self, ytStyled ?: [UIViewController class] };
    ((void (*)(struct objc_super *, SEL))objc_msgSendSuper)(&superStruct, @selector(viewDidLoad));

    self.title = LOC(@"MANAGE_TABS");
    [self loadTabData];
    [self takeSnapshot];

    // Save the previous nav-bar appearance before installing ours; restore it on dismissal.
    UINavigationBar *sharedNavBar = self.navigationController.navigationBar;
    objc_setAssociatedObject(self, kYMTabSavedStdAppearanceKey, sharedNavBar.standardAppearance, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, kYMTabSavedScrollEdgeAppearanceKey, sharedNavBar.scrollEdgeAppearance, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Configure navigation bar appearance with solid color
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];
    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        appearance.backgroundColor = [%c(YTColor) black3];
    } else {
        appearance.backgroundColor = [UIColor systemBackgroundColor];
    }
    self.navigationController.navigationBar.standardAppearance = appearance;
    self.navigationController.navigationBar.scrollEdgeAppearance = appearance;

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.editing = YES;
    self.tableView.allowsSelectionDuringEditing = NO;
    self.tableView.estimatedRowHeight = 56;
    self.tableView.rowHeight = UITableViewAutomaticDimension;

    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        self.tableView.backgroundColor = [%c(YTColor) black3];
    } else {
        self.tableView.backgroundColor = [UIColor systemBackgroundColor];
    }

    [self.view addSubview:self.tableView];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle) {
        self.tableView.backgroundColor = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark)
            ? [%c(YTColor) black3]
            : [UIColor systemBackgroundColor];
        
        // Update navigation bar appearance for dark/light mode
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithDefaultBackground];
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            appearance.backgroundColor = [%c(YTColor) black3];
        } else {
            appearance.backgroundColor = [UIColor systemBackgroundColor];
        }
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;

        [self.tableView reloadData];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    Class ytStyled = objc_getClass("YTStyledViewController");
    struct objc_super superStruct = { self, ytStyled ?: [UIViewController class] };
    ((void (*)(struct objc_super *, SEL, BOOL))objc_msgSendSuper)(&superStruct, @selector(viewWillAppear:), animated);
}

- (void)viewWillDisappear:(BOOL)animated {
    Class ytStyled = objc_getClass("YTStyledViewController");
    struct objc_super superStruct = { self, ytStyled ?: [UIViewController class] };
    ((void (*)(struct objc_super *, SEL, BOOL))objc_msgSendSuper)(&superStruct, @selector(viewWillDisappear:), animated);

    // Restore the saved nav-bar appearance so the previous screen keeps its tint.
    UINavigationBar *navBar = self.navigationController.navigationBar;
    navBar.standardAppearance = objc_getAssociatedObject(self, kYMTabSavedStdAppearanceKey);
    navBar.scrollEdgeAppearance = objc_getAssociatedObject(self, kYMTabSavedScrollEdgeAppearanceKey);
}

- (void)viewDidLayoutSubviews {
    Class ytStyled = objc_getClass("YTStyledViewController");
    struct objc_super superStruct = { self, ytStyled ?: [UIViewController class] };
    ((void (*)(struct objc_super *, SEL))objc_msgSendSuper)(&superStruct, @selector(viewDidLayoutSubviews));
    YTQTMButton *backButton = [self valueForKey:@"_backButton"];

    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        backButton.tintColor = [UIColor whiteColor];
    } else {
        backButton.tintColor = [UIColor blackColor];
    }
}

- (void)loadTabData {
    NSArray *savedOrder = [[NSUserDefaults standardUserDefaults] arrayForKey:TabOrder];
    BOOL downloadTabEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:DownloadLibraryTab];
    NSMutableArray *data = [NSMutableArray array];

    if (savedOrder.count > 0) {
        for (NSDictionary *entry in savedOrder) {
            if (![entry isKindOfClass:[NSDictionary class]]) continue;
            NSString *tabID = entry[@"id"];
            BOOL enabled = [entry[@"enabled"] boolValue];
            if (tabID) {
                [data addObject:[@{@"id": tabID, @"enabled": @(enabled)} mutableCopy]];
            }
        }
        // Add any new tabs not in saved data
        for (NSInteger i = 0; i < kYMTabCount; i++) {
            NSString *tabID = kYMTabIDs[i];
            BOOL found = NO;
            for (NSDictionary *d in data) {
                if ([d[@"id"] isEqualToString:tabID]) { found = YES; break; }
            }
            if (!found) {
                BOOL defaultEnabled = [tabID isEqualToString:@"download"] ? downloadTabEnabled : NO;
                [data addObject:[@{@"id": tabID, @"enabled": @(defaultEnabled)} mutableCopy]];
            }
        }
    } else {
        // Default: Home, Shorts, Create, Subscriptions, Library enabled
        for (NSInteger i = 0; i < kYMTabCount; i++) {
            NSString *tabID = kYMTabIDs[i];
            BOOL defaultEnabled = i < 5;
            if ([tabID isEqualToString:@"download"]) defaultEnabled = downloadTabEnabled;
            [data addObject:[@{@"id": tabID, @"enabled": @(defaultEnabled)} mutableCopy]];
        }
    }

    self.tabData = data;
}

- (void)saveTabData {
    NSMutableArray *toSave = [NSMutableArray array];
    for (NSMutableDictionary *entry in self.tabData) {
        if ([entry[@"id"] isEqualToString:@"download"]) {
            // Download tab state lives in the Downloading settings
            // (DownloadLibraryTab); keep the saved entry in sync with it.
            [toSave addObject:@{@"id": entry[@"id"], @"enabled": @([[NSUserDefaults standardUserDefaults] boolForKey:DownloadLibraryTab])}];
        } else {
            [toSave addObject:@{@"id": entry[@"id"], @"enabled": entry[@"enabled"]}];
        }
    }
    [[NSUserDefaults standardUserDefaults] setObject:toSave forKey:TabOrder];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"YouModUpdateTabBar" object:nil];
}

- (void)takeSnapshot {
    NSMutableArray *snap = [NSMutableArray array];
    for (NSDictionary *entry in self.tabData) {
        [snap addObject:@{@"id": entry[@"id"], @"enabled": entry[@"enabled"]}];
    }
    self.initialSnapshot = [snap copy];
}

- (NSInteger)enabledCount {
    NSInteger count = 0;
    for (NSDictionary *entry in self.tabData) {
        // Download tab is governed by the Downloading settings, not the
        // per-tab limit here.
        if ([entry[@"id"] isEqualToString:@"download"]) continue;
        if ([entry[@"enabled"] boolValue]) count++;
    }
    return count;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.tabData.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"YMTabCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    UISwitch *sw;

    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
        cell.backgroundColor = [UIColor clearColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        sw = [[UISwitch alloc] init];
        sw.onTintColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.9 alpha:1.0];
        [sw addTarget:self action:@selector(tabToggleChanged:) forControlEvents:UIControlEventValueChanged];
        sw.translatesAutoresizingMaskIntoConstraints = NO;
        sw.tag = 999;
        [cell.contentView addSubview:sw];

        [NSLayoutConstraint activateConstraints:@[
            [sw.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
            [sw.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16]
        ]];
    } else {
        sw = [cell.contentView viewWithTag:999];
    }

    NSMutableDictionary *entry = self.tabData[indexPath.row];
    NSString *tabID = entry[@"id"];
    BOOL enabled = [entry[@"enabled"] boolValue];

    cell.textLabel.text = [self localizedNameForTabID:tabID];
    cell.textLabel.textColor = [UIColor labelColor];
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];

    UIImage *tabIcon = [self iconForTabID:tabID];
    cell.imageView.image = tabIcon;
    cell.imageView.tintColor = [UIColor labelColor];

    BOOL isDownloadTab = [tabID isEqualToString:@"download"];
    if (isDownloadTab) {
        // Download tab switch just mirrors the Downloading settings state.
        sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:DownloadLibraryTab];
        sw.enabled = NO;
    } else {
        sw.on = enabled;
        sw.enabled = YES;
    }
    objc_setAssociatedObject(sw, kYMSwitchKeyAssoc, tabID, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    return cell;
}

- (void)tabToggleChanged:(UISwitch *)sender {
    NSString *tabID = objc_getAssociatedObject(sender, kYMSwitchKeyAssoc);
    if (!tabID) return;
    if ([tabID isEqualToString:@"download"]) {
        sender.on = [[NSUserDefaults standardUserDefaults] boolForKey:DownloadLibraryTab];
        return;
    }

    NSMutableDictionary *entry = nil;
    for (NSMutableDictionary *d in self.tabData) {
        if ([d[@"id"] isEqualToString:tabID]) { entry = d; break; }
    }
    if (!entry) return;

    BOOL wantsEnabled = sender.on;

    if (wantsEnabled && [self enabledCount] >= kYMTabMaxEnabled) {
        sender.on = NO;
        YTAlertView *alert = [%c(YTAlertView) infoDialog];
        alert.title = LOC(@"TAB_LIMIT");
        alert.subtitle = LOC(@"TAB_LIMIT_DESC");
        [alert show];
        return;
    } else if (!wantsEnabled && [self enabledCount] <= kYMTabMinEnabled) {
        sender.on = YES;
        YTAlertView *alert = [%c(YTAlertView) infoDialog];
        alert.title = LOC(@"WARNING");
        alert.subtitle = LOC(@"ZERO_TAB_DESC");
        [alert show];
        return;
    }

    entry[@"enabled"] = @(wantsEnabled);
    [self saveTabData];
}

#pragma mark - Reordering

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath { return YES; }

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to {
    NSMutableDictionary *item = self.tabData[from.row];
    [self.tabData removeObjectAtIndex:from.row];
    [self.tabData insertObject:item atIndex:to.row];
    [self saveTabData];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

#pragma mark - Section Header/Footer

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return UITableViewAutomaticDimension;
}

- (UIColor *)ymSecondaryColor {
    return [UIColor colorWithWhite:0.55 alpha:1.0];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *headerView = [[UIView alloc] init];
    headerView.backgroundColor = [UIColor clearColor];
    
    UILabel *hintLabel = [[UILabel alloc] init];
    hintLabel.text = LOC(@"TAB_REORDER_HINT");
    hintLabel.textColor = [self ymSecondaryColor];
    hintLabel.font = [UIFont systemFontOfSize:13];
    hintLabel.numberOfLines = 0;
    hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [headerView addSubview:hintLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [hintLabel.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor constant:16],
        [hintLabel.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor constant:-16],
        [hintLabel.topAnchor constraintEqualToAnchor:headerView.topAnchor constant:12],
        [hintLabel.bottomAnchor constraintEqualToAnchor:headerView.bottomAnchor constant:-12]
    ]];
    
    return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section { return 0; }
- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section { return [[UIView alloc] init]; }

@end

void YMPushTabOrder(id settingsVC, id parentResponder) {
    Class styledClass = objc_getClass("YMTabOrderViewControllerStyled");
    if (!styledClass) styledClass = [YMTabOrderViewController class];

    YMTabOrderViewController *vc = (YMTabOrderViewController *)((id (*)(id, SEL, id))objc_msgSend)([styledClass alloc], @selector(initWithParentResponder:), parentResponder);
    if (!vc) vc = [[styledClass alloc] init];
    [settingsVC pushViewController:vc];
}

// Modal Manage Tabs entry (Home tab long-press) when no settings nav stack exists:
// wraps the tab-order VC in a UINavigationController with a Done button.
void YMPresentTabOrderModally(id parentResponder) {
    Class styledClass = objc_getClass("YMTabOrderViewControllerStyled");
    if (!styledClass) styledClass = [YMTabOrderViewController class];

    YMTabOrderViewController *vc = (YMTabOrderViewController *)((id (*)(id, SEL, id))objc_msgSend)([styledClass alloc], @selector(initWithParentResponder:), parentResponder);
    if (!vc) vc = [[styledClass alloc] init];

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;

    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];
    appearance.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
        if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [%c(YTColor) black3];
        } else {
            return [UIColor systemBackgroundColor];
        }
    }];
        
    nav.navigationBar.standardAppearance = appearance;
    nav.navigationBar.scrollEdgeAppearance = appearance;
    nav.navigationBar.compactAppearance = appearance;

    __weak UINavigationController *weakNav = nav;
    UIAction *doneAction = [UIAction actionWithTitle:@"" image:nil identifier:nil handler:^(__unused UIAction *action) {
        [weakNav dismissViewControllerAnimated:YES completion:nil];
    }];
    vc.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
        primaryAction:doneAction];

    UIViewController *presenter = YouModTopViewController(nil);
    if (!presenter) return;
    [presenter presentViewController:nav animated:YES completion:nil];
}

#pragma mark - YMOverlayButtonOrderViewController

// sleep.timer toggle is locked here; its state derives from the SleepTimerEntry
// picker (2 = overlay, 3 = both).
static BOOL YMSleepTimerOverlayEnabled(void) {
    NSInteger entry = INTFORVAL(SleepTimerEntry);
    return entry == 2 || entry == 3;
}

static NSString * const kYMOverlayButtonIDs[] = {
    @"sponsorblock.toggle",
    @"download.video",
    @"mute.video",
    @"speed.video",
    @"quality.video",
    @"share.video",
    @"loop.video",
    @"caption.video",
    @"sleep.timer"
};
static const NSInteger kYMOverlayButtonCount = 9;

@interface YMOverlayButtonOrderViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
- (UITableView *)tableView;
- (void)setTableView:(UITableView *)tv;
- (NSMutableArray<NSMutableDictionary *> *)buttonData;
- (void)setButtonData:(NSMutableArray<NSMutableDictionary *> *)data;
- (NSArray *)initialSnapshot;
- (void)setInitialSnapshot:(NSArray *)snap;
@end

static const void *kYMOverlayTableViewKey = &kYMOverlayTableViewKey;
static const void *kYMOverlayButtonDataKey = &kYMOverlayButtonDataKey;
static const void *kYMOverlayButtonSnapshotKey = &kYMOverlayButtonSnapshotKey;
static const void *kYMOverlaySavedStdAppearanceKey = &kYMOverlaySavedStdAppearanceKey;
static const void *kYMOverlaySavedScrollEdgeAppearanceKey = &kYMOverlaySavedScrollEdgeAppearanceKey;
static const void *kYMOverlayMoveInFlightKey = &kYMOverlayMoveInFlightKey;

@implementation YMOverlayButtonOrderViewController

- (UITableView *)tableView { return objc_getAssociatedObject(self, kYMOverlayTableViewKey); }
- (void)setTableView:(UITableView *)tv { objc_setAssociatedObject(self, kYMOverlayTableViewKey, tv, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSMutableArray<NSMutableDictionary *> *)buttonData { return objc_getAssociatedObject(self, kYMOverlayButtonDataKey); }
- (void)setButtonData:(NSMutableArray<NSMutableDictionary *> *)data { objc_setAssociatedObject(self, kYMOverlayButtonDataKey, data, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSArray *)initialSnapshot { return objc_getAssociatedObject(self, kYMOverlayButtonSnapshotKey); }
- (void)setInitialSnapshot:(NSArray *)snap { objc_setAssociatedObject(self, kYMOverlayButtonSnapshotKey, snap, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

- (NSString *)localizedNameForButtonID:(NSString *)buttonID {
    if ([buttonID isEqualToString:@"sponsorblock.toggle"]) return LOC(@"SPONSORBLOCK_BUTTON");
    if ([buttonID isEqualToString:@"download.video"]) return LOC(@"DOWNLOAD_BUTTON");
    if ([buttonID isEqualToString:@"mute.video"]) return LOC(@"MUTE_BUTTON");
    if ([buttonID isEqualToString:@"speed.video"]) return LOC(@"SPEED_BUTTON");
    if ([buttonID isEqualToString:@"quality.video"]) return LOC(@"QUALITY_BUTTON");
    if ([buttonID isEqualToString:@"share.video"]) return LOC(@"SHARE_BUTTON");
    if ([buttonID isEqualToString:@"loop.video"]) return LOC(@"LOOP_BUTTON");
    if ([buttonID isEqualToString:@"caption.video"]) return LOC(@"CAPTION_BUTTON");
    if ([buttonID isEqualToString:@"sleep.timer"]) return LOC(@"SLEEP_TIMER");
    return buttonID;
}

- (UIImage *)iconForButtonID:(NSString *)buttonID {
    if ([buttonID isEqualToString:@"quality.video"]) {
        NSDictionary *attrs = @{
            NSFontAttributeName: [UIFont systemFontOfSize:14 weight:UIFontWeightBold],
            NSForegroundColorAttributeName: [UIColor whiteColor]
        };
        CGSize size = [@"HD" sizeWithAttributes:attrs];
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(ceil(size.width), ceil(size.height))];
        UIImage *img = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
            [@"HD" drawAtPoint:CGPointZero withAttributes:attrs];
        }];
        return [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }

    NSString *symbol = @"circle";
    if ([buttonID isEqualToString:@"sponsorblock.toggle"]) symbol = @"shield.fill";
    else if ([buttonID isEqualToString:@"download.video"]) symbol = @"arrow.down.circle";
    else if ([buttonID isEqualToString:@"mute.video"]) symbol = @"speaker.wave.2";
    else if ([buttonID isEqualToString:@"speed.video"]) symbol = @"speedometer";
    else if ([buttonID isEqualToString:@"share.video"]) symbol = @"arrowshape.turn.up.right";
    else if ([buttonID isEqualToString:@"loop.video"]) symbol = @"repeat";
    else if ([buttonID isEqualToString:@"caption.video"]) symbol = @"captions.bubble";
    else if ([buttonID isEqualToString:@"sleep.timer"]) symbol = @"moon";

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
    return [[UIImage systemImageNamed:symbol withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

- (void)viewDidLoad {
    Class ytStyled = objc_getClass("YTStyledViewController");
    struct objc_super superStruct = { self, ytStyled ?: [UIViewController class] };
    ((void (*)(struct objc_super *, SEL))objc_msgSendSuper)(&superStruct, @selector(viewDidLoad));

    self.title = LOC(@"MANAGE_OVERLAY_BUTTONS");
    [self loadButtonData];
    [self takeSnapshot];

    UINavigationBar *sharedNavBar = self.navigationController.navigationBar;
    objc_setAssociatedObject(self, kYMOverlaySavedStdAppearanceKey, sharedNavBar.standardAppearance, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, kYMOverlaySavedScrollEdgeAppearanceKey, sharedNavBar.scrollEdgeAppearance, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithDefaultBackground];
    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        appearance.backgroundColor = [%c(YTColor) black3];
    } else {
        appearance.backgroundColor = [UIColor systemBackgroundColor];
    }
    self.navigationController.navigationBar.standardAppearance = appearance;
    self.navigationController.navigationBar.scrollEdgeAppearance = appearance;

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.editing = YES;
    self.tableView.allowsSelectionDuringEditing = NO;
    self.tableView.estimatedRowHeight = 56;
    self.tableView.rowHeight = UITableViewAutomaticDimension;

    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        self.tableView.backgroundColor = [%c(YTColor) black3];
    } else {
        self.tableView.backgroundColor = [UIColor systemBackgroundColor];
    }

    [self.view addSubview:self.tableView];

    // Hint lives above both sections so each section header can carry its title.
    UIView *hintHeader = [[UIView alloc] init];
    UILabel *hintLabel = [[UILabel alloc] init];
    hintLabel.text = LOC(@"OVERLAY_BUTTON_REORDER_HINT");
    hintLabel.textColor = [self ymSecondaryColor];
    hintLabel.font = [UIFont systemFontOfSize:13];
    hintLabel.numberOfLines = 0;
    hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [hintHeader addSubview:hintLabel];
    [NSLayoutConstraint activateConstraints:@[
        [hintLabel.leadingAnchor constraintEqualToAnchor:hintHeader.leadingAnchor constant:16],
        [hintLabel.trailingAnchor constraintEqualToAnchor:hintHeader.trailingAnchor constant:-16],
        [hintLabel.topAnchor constraintEqualToAnchor:hintHeader.topAnchor constant:8],
        [hintLabel.bottomAnchor constraintEqualToAnchor:hintHeader.bottomAnchor constant:-4]
    ]];
    CGFloat headerWidth = self.view.bounds.size.width > 0 ? self.view.bounds.size.width : 320;
    CGSize headerFit = [hintHeader systemLayoutSizeFittingSize:CGSizeMake(headerWidth, 0)
                                 withHorizontalFittingPriority:UILayoutPriorityRequired
                                   verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    hintHeader.frame = CGRectMake(0, 0, headerWidth, ceil(headerFit.height));
    self.tableView.tableHeaderView = hintHeader;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle) {
        self.tableView.backgroundColor = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark)
            ? [%c(YTColor) black3]
            : [UIColor systemBackgroundColor];
        
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithDefaultBackground];
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            appearance.backgroundColor = [%c(YTColor) black3];
        } else {
            appearance.backgroundColor = [UIColor systemBackgroundColor];
        }
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;

        [self.tableView reloadData];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    Class ytStyled = objc_getClass("YTStyledViewController");
    struct objc_super superStruct = { self, ytStyled ?: [UIViewController class] };
    ((void (*)(struct objc_super *, SEL, BOOL))objc_msgSendSuper)(&superStruct, @selector(viewWillAppear:), animated);
}

- (void)viewWillDisappear:(BOOL)animated {
    Class ytStyled = objc_getClass("YTStyledViewController");
    struct objc_super superStruct = { self, ytStyled ?: [UIViewController class] };
    ((void (*)(struct objc_super *, SEL, BOOL))objc_msgSendSuper)(&superStruct, @selector(viewWillDisappear:), animated);

    UINavigationBar *navBar = self.navigationController.navigationBar;
    navBar.standardAppearance = objc_getAssociatedObject(self, kYMOverlaySavedStdAppearanceKey);
    navBar.scrollEdgeAppearance = objc_getAssociatedObject(self, kYMOverlaySavedScrollEdgeAppearanceKey);
}

- (void)viewDidLayoutSubviews {
    Class ytStyled = objc_getClass("YTStyledViewController");
    struct objc_super superStruct = { self, ytStyled ?: [UIViewController class] };
    ((void (*)(struct objc_super *, SEL))objc_msgSendSuper)(&superStruct, @selector(viewDidLayoutSubviews));
    YTQTMButton *backButton = [self valueForKey:@"_backButton"];

    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        backButton.tintColor = [UIColor whiteColor];
    } else {
        backButton.tintColor = [UIColor blackColor];
    }
}

- (void)loadButtonData {
    NSArray *savedOrder = [[NSUserDefaults standardUserDefaults] arrayForKey:OverlayButtonOrder];
    NSMutableArray *data = [NSMutableArray array];

    if (savedOrder.count > 0) {
        for (NSDictionary *entry in savedOrder) {
            if (![entry isKindOfClass:[NSDictionary class]]) continue;
            NSString *buttonID = entry[@"id"];
            BOOL enabled = [entry[@"enabled"] boolValue];
            BOOL bottom = [entry[@"bottom"] boolValue];
            if ([buttonID isEqualToString:@"sponsorblock.toggle"]) {
                enabled = YMIsOverlayButtonEnabled(buttonID);
            }
            if (buttonID) {
                [data addObject:[@{@"id": buttonID, @"enabled": @(enabled), @"bottom": @(bottom)} mutableCopy]];
            }
        }
        for (NSInteger i = 0; i < kYMOverlayButtonCount; i++) {
            NSString *buttonID = kYMOverlayButtonIDs[i];
            BOOL found = NO;
            for (NSDictionary *d in data) {
                if ([d[@"id"] isEqualToString:buttonID]) { found = YES; break; }
            }
            if (!found) {
                [data addObject:[@{@"id": buttonID, @"enabled": @(YMIsOverlayButtonEnabled(buttonID)), @"bottom": @(NO)} mutableCopy]];
            }
        }
    } else {
        for (NSInteger i = 0; i < kYMOverlayButtonCount; i++) {
            NSString *buttonID = kYMOverlayButtonIDs[i];
            BOOL defaultEnabled = YMIsOverlayButtonEnabled(buttonID);
            [data addObject:[@{@"id": buttonID, @"enabled": @(defaultEnabled), @"bottom": @(NO)} mutableCopy]];
        }
    }

    // sleep.timer tracks the SleepTimerEntry picker, never the stored flag.
    for (NSMutableDictionary *d in data) {
        if ([d[@"id"] isEqualToString:@"sleep.timer"]) {
            d[@"enabled"] = @(YMSleepTimerOverlayEnabled());
        }
    }

    self.buttonData = data;
}

- (void)saveButtonData {
    NSMutableArray *toSave = [NSMutableArray array];
    for (NSMutableDictionary *entry in self.buttonData) {
        NSString *buttonID = entry[@"id"];
        BOOL enabled = [entry[@"enabled"] boolValue];
        if ([buttonID isEqualToString:@"sponsorblock.toggle"]) {
            enabled = YMIsOverlayButtonEnabled(buttonID);
        }
        if ([buttonID isEqualToString:@"sleep.timer"]) {
            enabled = YMSleepTimerOverlayEnabled();
        }
        [toSave addObject:@{@"id": buttonID, @"enabled": @(enabled), @"bottom": @([entry[@"bottom"] boolValue])}];
    }
    [[NSUserDefaults standardUserDefaults] setObject:toSave forKey:OverlayButtonOrder];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"YouModUpdateOverlayButtons" object:nil];
}

- (void)takeSnapshot {
    NSMutableArray *snap = [NSMutableArray array];
    for (NSDictionary *entry in self.buttonData) {
        [snap addObject:@{@"id": entry[@"id"], @"enabled": entry[@"enabled"], @"bottom": entry[@"bottom"]}];
    }
    self.initialSnapshot = [snap copy];
}

#pragma mark - UITableViewDataSource

// Section 0 = top overlay row, section 1 = bottom bar. Both come from buttonData
// via the "bottom" flag (saved format unchanged).
- (NSArray<NSNumber *> *)flatIndexesForSection:(NSInteger)section {
    BOOL wantBottom = (section == 1);
    NSMutableArray<NSNumber *> *indexes = [NSMutableArray array];
    [self.buttonData enumerateObjectsUsingBlock:^(NSMutableDictionary *entry, NSUInteger idx, BOOL *stop) {
        if ([entry[@"bottom"] boolValue] == wantBottom) [indexes addObject:@(idx)];
    }];
    return indexes;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger count = [self flatIndexesForSection:section].count;
    return count > 0 ? count : 1; // empty section keeps one "no buttons" row
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<NSNumber *> *flatIndexes = [self flatIndexesForSection:indexPath.section];

    if (flatIndexes.count == 0) {
        static NSString *emptyCellID = @"YMOverlayEmptyCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:emptyCellID];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:emptyCellID];
            cell.backgroundColor = [UIColor clearColor];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;

            UILabel *emptyLabel = [[UILabel alloc] init];
            emptyLabel.tag = 996;
            emptyLabel.text = LOC(@"OVERLAY_BUTTONS_EMPTY");
            emptyLabel.textColor = [self ymSecondaryColor];
            emptyLabel.font = [UIFont systemFontOfSize:14];
            emptyLabel.textAlignment = NSTextAlignmentCenter;
            emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
            [cell.contentView addSubview:emptyLabel];
            [NSLayoutConstraint activateConstraints:@[
                [emptyLabel.centerXAnchor constraintEqualToAnchor:cell.contentView.centerXAnchor],
                [emptyLabel.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor]
            ]];
        }
        return cell;
    }

    static NSString *cellID = @"YMOverlayButtonCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    UISwitch *sw;
    UIButton *moveButton;

    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
        cell.backgroundColor = [UIColor clearColor];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;

        sw = [[UISwitch alloc] init];
        sw.onTintColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.9 alpha:1.0];
        [sw addTarget:self action:@selector(buttonToggleChanged:) forControlEvents:UIControlEventValueChanged];
        sw.translatesAutoresizingMaskIntoConstraints = NO;
        sw.tag = 999;
        [cell.contentView addSubview:sw];

        // Arrow button moves the button to the other row
        // (replaces the old top/bottom segment).
        moveButton = [UIButton buttonWithType:UIButtonTypeSystem];
        moveButton.backgroundColor = [UIColor secondarySystemBackgroundColor];
        moveButton.tintColor = [UIColor labelColor];
        moveButton.layer.cornerRadius = 15;
        moveButton.layer.masksToBounds = YES;
        [moveButton addTarget:self action:@selector(moveButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        moveButton.translatesAutoresizingMaskIntoConstraints = NO;
        moveButton.tag = 998;
        [cell.contentView addSubview:moveButton];

        [NSLayoutConstraint activateConstraints:@[
            [sw.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
            [sw.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
            [moveButton.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
            [moveButton.trailingAnchor constraintEqualToAnchor:sw.leadingAnchor constant:-12],
            [moveButton.widthAnchor constraintEqualToConstant:30],
            [moveButton.heightAnchor constraintEqualToConstant:30]
        ]];
    } else {
        sw = [cell.contentView viewWithTag:999];
        moveButton = [cell.contentView viewWithTag:998];
    }

    NSMutableDictionary *entry = self.buttonData[flatIndexes[indexPath.row].integerValue];
    NSString *buttonID = entry[@"id"];
    BOOL enabled = [entry[@"enabled"] boolValue];

    cell.textLabel.text = [self localizedNameForButtonID:buttonID];
    cell.textLabel.textColor = [UIColor labelColor];
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];

    UIImage *btnIcon = [self iconForButtonID:buttonID];
    cell.imageView.image = btnIcon;
    cell.imageView.tintColor = [UIColor labelColor];

    // These buttons are controlled by their own settings, so their switches are
    // locked. Set enabled explicitly (cells are reused) or a locked switch would
    // leave a regular button's toggle disabled.
    BOOL isExternallyManaged = [buttonID isEqualToString:@"download.video"]
        || [buttonID isEqualToString:@"sponsorblock.toggle"]
        || [buttonID isEqualToString:@"sleep.timer"];
    sw.enabled = !isExternallyManaged;

    sw.on = enabled;
    objc_setAssociatedObject(sw, kYMSwitchKeyAssoc, buttonID, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIImageSymbolConfiguration *arrowConfig = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold];
    UIImage *arrow = [UIImage systemImageNamed:(indexPath.section == 0 ? @"arrow.down" : @"arrow.up") withConfiguration:arrowConfig];
    [moveButton setImage:arrow forState:UIControlStateNormal];
    objc_setAssociatedObject(moveButton, kYMSwitchKeyAssoc, buttonID, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    return cell;
}

- (void)buttonToggleChanged:(UISwitch *)sender {
    NSString *buttonID = objc_getAssociatedObject(sender, kYMSwitchKeyAssoc);
    if (!buttonID) return;

    NSMutableDictionary *entry = nil;
    for (NSMutableDictionary *d in self.buttonData) {
        if ([d[@"id"] isEqualToString:buttonID]) { entry = d; break; }
    }
    if (!entry) return;

    entry[@"enabled"] = @(sender.on);
    [self saveButtonData];
}

- (void)moveButtonTapped:(UIButton *)sender {
    NSString *buttonID = objc_getAssociatedObject(sender, kYMSwitchKeyAssoc);
    if (!buttonID) return;

    NSMutableDictionary *entry = nil;
    for (NSMutableDictionary *d in self.buttonData) {
        if ([d[@"id"] isEqualToString:buttonID]) { entry = d; break; }
    }
    if (!entry) return;

    NSInteger fromSection = [entry[@"bottom"] boolValue] ? 1 : 0;
    NSInteger toSection = 1 - fromSection;
    NSArray<NSNumber *> *fromFlat = [self flatIndexesForSection:fromSection];
    NSArray<NSNumber *> *toFlat = [self flatIndexesForSection:toSection];
    NSInteger fromRow = -1;
    for (NSInteger i = 0; i < (NSInteger)fromFlat.count; i++) {
        if (self.buttonData[fromFlat[i].integerValue] == entry) { fromRow = i; break; }
    }
    if (fromRow < 0) return;
    // The moved entry is appended to its new section, so its new row equals
    // that section's current count.
    NSInteger toRow = (NSInteger)toFlat.count;
    BOOL fromBecomesEmpty = (fromFlat.count == 1);
    BOOL toWasEmpty = (toFlat.count == 0);

    // Stacking a batch update on a still-running move leaves ghost rows (stale
    // buttonIDs on fading cells) — serialize: one move in flight at a time.
    if ([objc_getAssociatedObject(self, kYMOverlayMoveInFlightKey) boolValue]) return;
    objc_setAssociatedObject(self, kYMOverlayMoveInFlightKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [self.tableView performBatchUpdates:^{
        // Rebuild buttonData as top group + bottom group so the entry lands at
        // the end of its section (relative order preserved).
        entry[@"bottom"] = @(toSection == 1);
        NSMutableArray *top = [NSMutableArray array];
        NSMutableArray *bottom = [NSMutableArray array];
        for (NSMutableDictionary *d in self.buttonData) {
            [([d[@"bottom"] boolValue] ? bottom : top) addObject:d];
        }
        [self.buttonData removeAllObjects];
        [self.buttonData addObjectsFromArray:top];
        [self.buttonData addObjectsFromArray:bottom];

        // Slide in from the direction of the move; placeholders swap with a fade.
        UITableViewRowAnimation rowAnim = (toSection == 1) ? UITableViewRowAnimationBottom : UITableViewRowAnimationTop;
        [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:fromRow inSection:fromSection]] withRowAnimation:UITableViewRowAnimationFade];
        if (fromBecomesEmpty) {
            [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:fromSection]] withRowAnimation:UITableViewRowAnimationFade];
        }
        if (toWasEmpty) {
            [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:toSection]] withRowAnimation:UITableViewRowAnimationFade];
        }
        [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:toRow inSection:toSection]] withRowAnimation:rowAnim];

        [self saveButtonData];
    } completion:^(BOOL finished) {
        objc_setAssociatedObject(self, kYMOverlayMoveInFlightKey, @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        // Self-sizing + batch updates can leave stale cells; reload once settled.
        [self.tableView reloadData];
    }];
}

#pragma mark - Reordering

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // The lone row of an empty section is a placeholder, not draggable.
    return [self flatIndexesForSection:indexPath.section].count > 0;
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedIndexPath {
    // Drag reorders within a section only; cross-section drops are redirected
    // back (switching sides is the arrow button's job).
    if (proposedIndexPath.section == sourceIndexPath.section) return proposedIndexPath;
    NSInteger rows = [self tableView:tableView numberOfRowsInSection:sourceIndexPath.section];
    NSInteger row = MIN(proposedIndexPath.row, rows - 1);
    if (row < 0) row = 0;
    return [NSIndexPath indexPathForRow:row inSection:sourceIndexPath.section];
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to {
    if (from.section != to.section) return; // prevented by the clamp above
    NSArray<NSNumber *> *fromFlat = [self flatIndexesForSection:from.section];
    NSArray<NSNumber *> *toFlat = [self flatIndexesForSection:to.section];
    if (from.row >= (NSInteger)fromFlat.count || to.row >= (NSInteger)toFlat.count) return;
    NSInteger fromIndex = fromFlat[from.row].integerValue;
    NSInteger toIndex = toFlat[to.row].integerValue;
    if (fromIndex == toIndex) return;
    NSMutableDictionary *item = self.buttonData[fromIndex];
    [self.buttonData removeObjectAtIndex:fromIndex];
    [self.buttonData insertObject:item atIndex:toIndex];
    [self saveButtonData];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

#pragma mark - Row & Section Heights

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self flatIndexesForSection:indexPath.section].count == 0) return 44; // "no buttons" row
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return UITableViewAutomaticDimension;
}

- (UIColor *)ymSecondaryColor {
    return [UIColor colorWithWhite:0.55 alpha:1.0];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *headerView = [[UIView alloc] init];
    headerView.backgroundColor = [UIColor clearColor];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = LOC(section == 0 ? @"OVERLAY_BUTTONS_TOP" : @"OVERLAY_BUTTONS_BOTTOM");
    titleLabel.textColor = [self ymSecondaryColor];
    titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    titleLabel.numberOfLines = 0;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [headerView addSubview:titleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor constant:16],
        [titleLabel.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor constant:-16],
        [titleLabel.topAnchor constraintEqualToAnchor:headerView.topAnchor constant:12],
        [titleLabel.bottomAnchor constraintEqualToAnchor:headerView.bottomAnchor constant:-4]
    ]];

    return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section { return 0; }
- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section { return [[UIView alloc] init]; }

@end

void YMPushOverlayButtonOrder(id settingsVC, id parentResponder) {
    Class styledClass = objc_getClass("YMOverlayButtonOrderViewControllerStyled");
    if (!styledClass) styledClass = [YMOverlayButtonOrderViewController class];

    YMOverlayButtonOrderViewController *vc = (YMOverlayButtonOrderViewController *)((id (*)(id, SEL, id))objc_msgSend)([styledClass alloc], @selector(initWithParentResponder:), parentResponder);
    if (!vc) vc = [[styledClass alloc] init];
    [settingsVC pushViewController:vc];
}

#pragma mark - Entry Point

void YMPushSubSettings(NSString *title, NSArray<YMSettingsItem *> *items, id settingsVC, id parentResponder) {
    Class styledClass = objc_getClass("YMSubSettingsViewControllerStyled");
    if (!styledClass) styledClass = [YMSubSettingsViewController class];

    YMSubSettingsViewController *vc = (YMSubSettingsViewController *)((id (*)(id, SEL, id))objc_msgSend)([styledClass alloc], @selector(initWithParentResponder:), parentResponder);
    if (!vc) vc = [[styledClass alloc] init];
    vc.navTitle = title;
    vc.items = items;
    [settingsVC pushViewController:vc];
}

// Same as YMPushSubSettings, but for the home page: version footer on, and the
// search bar searches every registered settings group instead of just these rows.
void YMPushSubSettingsWithFooter(NSString *title, NSArray<YMSettingsItem *> *items, id settingsVC, id parentResponder) {
    Class styledClass = objc_getClass("YMSubSettingsViewControllerStyled");
    if (!styledClass) styledClass = [YMSubSettingsViewController class];

    YMSubSettingsViewController *vc = (YMSubSettingsViewController *)((id (*)(id, SEL, id))objc_msgSend)([styledClass alloc], @selector(initWithParentResponder:), parentResponder);
    if (!vc) vc = [[styledClass alloc] init];
    vc.navTitle = title;
    vc.items = items;
    vc.showsVersionFooter = YES;
    vc.globalSearch = YES;
    [settingsVC pushViewController:vc];
}

#pragma mark - Runtime Class Registration

static void ymRegisterStyledSubclass(Class sourceClass, const char *name) {
    Class ytStyled = %c(YTStyledViewController);
    Class newClass = objc_allocateClassPair(ytStyled, name, 0);
    if (!newClass) return;

    // Copy methods/properties from sourceClass up its class chain (stops before
    // UIViewController). Subclass levels copy first so overrides win.
    for (Class cls = sourceClass; cls && cls != [UIViewController class]; cls = class_getSuperclass(cls)) {
        unsigned int count = 0;
        Method *methods = class_copyMethodList(cls, &count);
        for (unsigned int i = 0; i < count; i++) {
            class_addMethod(newClass, method_getName(methods[i]), method_getImplementation(methods[i]), method_getTypeEncoding(methods[i]));
        }
        free(methods);

        unsigned int propCount = 0;
        objc_property_t *props = class_copyPropertyList(cls, &propCount);
        for (unsigned int i = 0; i < propCount; i++) {
            unsigned int attrCount = 0;
            objc_property_attribute_t *attrs = property_copyAttributeList(props[i], &attrCount);
            class_addProperty(newClass, property_getName(props[i]), attrs, attrCount);
            free(attrs);
        }
        free(props);
    }

    objc_registerClassPair(newClass);
}

%hook YTQTMButton
- (void)layoutSubviews {
    %orig;
    if ([self.accessibilityIdentifier isEqualToString:@"id.ui.title.tab.button"]) {
        UIColor *customTitle = [self valueForKey:@"_desiredCustomTitleColor"];

        if (isDarkMode(self)) {
            self.titleLabel.textColor = [UIColor whiteColor];
            if (customTitle) {
                [self setValue:[UIColor whiteColor] forKey:@"_desiredCustomTitleColor"];
            }
        } else {
            self.titleLabel.textColor = [UIColor blackColor];
            if (customTitle) {
                [self setValue:[UIColor blackColor] forKey:@"_desiredCustomTitleColor"];
            }
        }
    } else if ([self.accessibilityIdentifier isEqualToString:@"id.ui.browse.back.button"]) {
        if (isDarkMode(self)) {
            self.tintColor = [UIColor whiteColor];
        } else {
            self.tintColor = [UIColor blackColor];
        }
    }
}
%end

%hook YTPivotBarViewController
- (void)viewDidLoad {
    %orig;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(YouModReloadTabBar:) name:@"YouModUpdateTabBar" object:nil];
}
%new
- (void)YouModReloadTabBar:(id)arg {
    [self.parentViewController performSelector:@selector(refreshPivotBarWithTriggedByNotification:) withObject:@YES];
}
%end

%ctor {
    ymRegisterStyledSubclass([YMSubSettingsViewController class], "YMSubSettingsViewControllerStyled");
    ymRegisterStyledSubclass([YMTabOrderViewController class], "YMTabOrderViewControllerStyled");
    ymRegisterStyledSubclass([YMOverlayButtonOrderViewController class], "YMOverlayButtonOrderViewControllerStyled");
}

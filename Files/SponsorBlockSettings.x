// SponsorBlockSettings.x — Custom UITableViewController matching YTLite's SponsorBlock UI
#import "Headers.h"
#import <objc/runtime.h>
#import <objc/message.h>

extern UIColor *SBColorFromHex(NSString *hexString);

// Purple accent used to tint the toggle switches and duration sliders on this
// page. (Distinct from the player overlay button's accent in SponsorBlock.x.)
static UIColor *SBControlTintColor(void) {
    return [UIColor colorWithRed:0.6 green:0.2 blue:0.9 alpha:1.0];
}

// Tag base for a slider row's value label, offset by the row index so each
// slider can find its own label via viewWithTag:.
static const NSInteger SBSliderValueLabelTagBase = 100;

// The localization key for a segment action's display name. Shared by the
// selected-action label and the action picker menu so the two never disagree.
static NSString *SBActionLocKey(SBSegmentAction action) {
    switch (action) {
        case SBSegmentActionAutoSkip: return @"SB_ACTION_AUTO_SKIP";
        case SBSegmentActionAsk:      return @"SB_ACTION_ASK";
        case SBSegmentActionDisplay:  return @"SB_ACTION_DISPLAY";
        case SBSegmentActionSkipTo:   return @"SB_ACTION_SKIP_TO";
        default:                      return @"SB_ACTION_DISABLE";
    }
}

// One toggle row: the defaults key it controls and its localized title/description
// keys. This is the single source of truth for the toggle section — the row count,
// each cell's contents, and the value written on change all read from it, so a row
// can never display one setting while toggling another.
@interface SBToggleRow : NSObject
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *titleKey;
@property (nonatomic, copy) NSString *descKey;
@end
@implementation SBToggleRow
+ (instancetype)key:(NSString *)key title:(NSString *)titleKey desc:(NSString *)descKey {
    SBToggleRow *row = [SBToggleRow new];
    row.key = key; row.titleKey = titleKey; row.descKey = descKey;
    return row;
}
@end

static NSArray<SBToggleRow *> *sbToggleRows() {
    return @[
        [SBToggleRow key:SBEnabled title:@"SB_ENABLE" desc:@"SB_ENABLE_DESC"],
        [SBToggleRow key:SBShowButton title:@"SB_SHOW_BUTTON" desc:@"SB_SHOW_BUTTON_DESC"],
        [SBToggleRow key:SBShowNotifications title:@"SB_SHOW_NOTIFICATIONS" desc:@"SB_SHOW_NOTIFICATIONS_DESC"],
        [SBToggleRow key:SBSegmentsInPlayer title:@"SB_SEGMENTS_IN_PLAYER" desc:@"SB_SEGMENTS_IN_PLAYER_DESC"],
        [SBToggleRow key:SBSegmentsInFeed title:@"SB_SEGMENTS_IN_FEED" desc:@"SB_SEGMENTS_IN_FEED_DESC"],
        [SBToggleRow key:SBSegmentsInMiniPlayer title:@"SB_SEGMENTS_IN_MINIPLAYER" desc:@"SB_SEGMENTS_IN_MINIPLAYER_DESC"],
        [SBToggleRow key:SBAudioNotification title:@"SB_HAPTIC_FEEDBACK" desc:@"SB_HAPTIC_FEEDBACK_DESC"],
        [SBToggleRow key:SBShowDuration title:@"SB_SHOW_DURATION" desc:@"SB_SHOW_DURATION_DESC"],
    ];
}

static NSString *SBActionName(NSInteger action) {
    return LOC(SBActionLocKey((SBSegmentAction)action));
}

static NSString *SBHexFromColor(UIColor *color) {
    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    return [NSString stringWithFormat:@"#%02X%02X%02X", (int)(r * 255), (int)(g * 255), (int)(b * 255)];
}

#pragma mark - Color Circle View (filled center + rainbow ring)

@interface SBColorCircleView : UIView
@property (nonatomic, strong) UIColor *fillColor;
@end

@implementation SBColorCircleView

- (instancetype)initWithFrame:(CGRect)frame color:(UIColor *)color {
    self = [super initWithFrame:frame];
    if (self) {
        self.fillColor = color;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGFloat size = MIN(rect.size.width, rect.size.height);
    CGRect square = CGRectMake((rect.size.width - size) / 2, (rect.size.height - size) / 2, size, size);
    CGFloat cx = CGRectGetMidX(square), cy = CGRectGetMidY(square);
    CGFloat ringWidth = 3.0;
    CGFloat radius = (size - ringWidth) / 2.0;

    // Draw rainbow ring by stroking arc segments at varying hues
    NSInteger segments = 64;
    CGFloat anglePerSegment = (2.0 * M_PI) / segments;
    for (NSInteger i = 0; i < segments; i++) {
        CGFloat startAngle = i * anglePerSegment - M_PI_2;
        CGFloat endAngle = startAngle + anglePerSegment + 0.02; // slight overlap to avoid gaps
        CGFloat hue = (CGFloat)i / segments;
        UIColor *color = [UIColor colorWithHue:hue saturation:1.0 brightness:1.0 alpha:1.0];
        CGContextSetStrokeColorWithColor(ctx, color.CGColor);
        CGContextSetLineWidth(ctx, ringWidth);
        CGContextAddArc(ctx, cx, cy, radius, startAngle, endAngle, 0);
        CGContextStrokePath(ctx);
    }

    // Filled center circle
    CGRect innerRect = CGRectInset(square, ringWidth + 2, ringWidth + 2);
    UIBezierPath *innerPath = [UIBezierPath bezierPathWithOvalInRect:innerRect];
    [self.fillColor setFill];
    [innerPath fill];
}

- (void)setFillColor:(UIColor *)fillColor {
    _fillColor = fillColor;
    [self setNeedsDisplay];
}

@end

#pragma mark - SBSettingsViewController

@interface SBSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UIColorPickerViewControllerDelegate, UISearchResultsUpdating>
- (UITableView *)tableView;
- (void)setTableView:(UITableView *)tv;
- (NSString *)activeColorKey;
- (void)setActiveColorKey:(NSString *)key;
- (NSIndexPath *)activeColorIndexPath;
- (void)setActiveColorIndexPath:(NSIndexPath *)ip;
- (UIColor *)sbTextColor;
- (UIColor *)sbSecondaryTextColor;
// Cell builders, also reused by the global settings search (sbSearchRows).
- (UITableViewCell *)toggleCellForRow:(NSInteger)row tableView:(UITableView *)tableView;
- (UITableViewCell *)sliderCellForRow:(NSInteger)row tableView:(UITableView *)tableView;
- (UITableViewCell *)actionCellForCategory:(NSString *)category name:(NSString *)catName tableView:(UITableView *)tableView;
- (UITableViewCell *)colorCellForCategory:(NSString *)category name:(NSString *)catName tableView:(UITableView *)tableView;
@end

// Flat list of all SB settings as search rows (declared before use by the per-page
// filter below; defined in the Settings Search section).
extern NSArray<YMSearchRow *> *sbFlatRowsWithRenderer(SBSettingsViewController *renderer);

static const void *kSBTableViewKey = &kSBTableViewKey;
static const void *kSBColorKeyKey = &kSBColorKeyKey;
static const void *kSBColorIndexPathKey = &kSBColorIndexPathKey;
static const void *kSBPageFilterKey = &kSBPageFilterKey;
static const void *kSBAllFlatRowsKey = &kSBAllFlatRowsKey;

@implementation SBSettingsViewController

- (UITableView *)tableView { return objc_getAssociatedObject(self, kSBTableViewKey); }
- (void)setTableView:(UITableView *)tv { objc_setAssociatedObject(self, kSBTableViewKey, tv, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSString *)activeColorKey { return objc_getAssociatedObject(self, kSBColorKeyKey); }
- (void)setActiveColorKey:(NSString *)key { objc_setAssociatedObject(self, kSBColorKeyKey, key, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSIndexPath *)activeColorIndexPath { return objc_getAssociatedObject(self, kSBColorIndexPathKey); }
- (void)setActiveColorIndexPath:(NSIndexPath *)ip { objc_setAssociatedObject(self, kSBColorIndexPathKey, ip, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

// Per-page search state. pageFilter is the active query (nil/empty = not filtering);
// while filtering, the page collapses to one flat section of matching search rows.
- (NSString *)pageFilter { return objc_getAssociatedObject(self, kSBPageFilterKey); }
- (void)setPageFilter:(NSString *)f { objc_setAssociatedObject(self, kSBPageFilterKey, f, OBJC_ASSOCIATION_COPY_NONATOMIC); }
- (NSArray<YMSearchRow *> *)allFlatRows { return objc_getAssociatedObject(self, kSBAllFlatRowsKey); }
- (void)setAllFlatRows:(NSArray<YMSearchRow *> *)r { objc_setAssociatedObject(self, kSBAllFlatRowsKey, r, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

- (BOOL)isFiltering { return self.pageFilter.length > 0; }

- (NSArray<YMSearchRow *> *)filteredFlatRows {
    NSString *q = self.pageFilter;
    if (q.length == 0) return @[];
    NSMutableArray<YMSearchRow *> *matches = [NSMutableArray array];
    NSStringCompareOptions opts = NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch;
    for (YMSearchRow *row in self.allFlatRows) {
        if ([row.searchText rangeOfString:q options:opts].location != NSNotFound) [matches addObject:row];
    }
    return matches;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    self.pageFilter = [searchController.searchBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    [self.tableView reloadData];
}

- (void)viewDidLoad {
    Class ytStyled = objc_getClass("YTStyledViewController");
    struct objc_super superStruct = { self, ytStyled ?: [UIViewController class] };
    ((void (*)(struct objc_super *, SEL))objc_msgSendSuper)(&superStruct, @selector(viewDidLoad));

    self.title = @"SponsorBlock";

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.estimatedRowHeight = 60;
    self.tableView.rowHeight = UITableViewAutomaticDimension;

    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        self.tableView.backgroundColor = [%c(YTColor) black3];
    } else {
        self.tableView.backgroundColor = [UIColor systemBackgroundColor];
    }

    [self.view addSubview:self.tableView];

    // Pinned per-page search bar that filters this page's own rows. The flat row
    // list is built once with self as the renderer (its cells write straight to
    // NSUserDefaults, so reusing the live VC is safe).
    self.allFlatRows = sbFlatRowsWithRenderer(self);
    UISearchController *sc = [[UISearchController alloc] initWithSearchResultsController:nil];
    sc.searchResultsUpdater = self;
    sc.obscuresBackgroundDuringPresentation = NO;
    sc.searchBar.placeholder = LOC(@"SEARCH");
    sc.searchBar.tintColor = SBControlTintColor();
    self.navigationItem.searchController = sc;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle) {
        self.tableView.backgroundColor = (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark)
            ? [%c(YTColor) black3]
            : [UIColor systemBackgroundColor];
        [self.tableView reloadData];
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
}

- (UIColor *)navBarForegroundColor {
    if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
        return [UIColor whiteColor];
    }
    // Light mode: return a concrete colour rather than nil. nil lets YouTube tint the
    // nav-bar foreground (back chevron + title) with its default appearance, which is
    // system blue in light mode. labelColor keeps it black in light / white in dark.
    return [UIColor labelColor];
}

- (UIColor *)sbTextColor {
    return (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark)
        ? [UIColor whiteColor] : [UIColor labelColor];
}

- (UIColor *)sbSecondaryTextColor {
    return [UIColor colorWithWhite:0.55 alpha:1.0];
}

#pragma mark - Sections: 0=Main, 1=Sliders, 2=Segments

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.isFiltering ? 1 : 3;  // one flat section of matches while searching
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.isFiltering) return self.filteredFlatRows.count;
    if (section == 0) return sbToggleRows().count;  // toggles
    if (section == 1) return 3;  // sliders (skip alert, unskip alert, min duration)
    return sbAllCategories().count * 2;  // action + color per category
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (self.isFiltering) return nil;  // headers dropped in the flat filtered list
    NSString *title = nil;
    if (section == 0) title = LOC(@"SB_SECTION_MAIN");
    else if (section == 2) title = LOC(@"SB_CATEGORIES_HEADER");
    if (!title) return nil;

    UIView *header = [[UIView alloc] init];
    UILabel *label = [[UILabel alloc] init];
    label.text = title;
    // Match the main YouMod settings section headers (ymSecondaryColor / size 14).
    label.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
    label.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
        [label.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-6],
    ]];
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (self.isFiltering) return 0;
    if (section == 1) return 16;
    return 36;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isFiltering) {
        CGFloat h = self.filteredFlatRows[indexPath.row].cellHeight;
        return h > 0 ? h : UITableViewAutomaticDimension;
    }
    if (indexPath.section == 1) return 70;
    if (indexPath.section == 2) {
        BOOL isActionRow = (indexPath.row % 2 == 0);
        NSInteger catIndex = indexPath.row / 2;
        if (isActionRow && catIndex > 0) return 64; // extra top spacing between groups
        return 48;
    }
    return UITableViewAutomaticDimension;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isFiltering) return self.filteredFlatRows[indexPath.row].makeCell(tableView);
    if (indexPath.section == 0) return [self toggleCellForRow:indexPath.row tableView:tableView];
    if (indexPath.section == 1) return [self sliderCellForRow:indexPath.row tableView:tableView];
    return [self segmentCellForRow:indexPath.row tableView:tableView];
}

#pragma mark - Toggle Cells (Section 0)

- (UITableViewCell *)toggleCellForRow:(NSInteger)row tableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.textColor = [self sbTextColor];
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    cell.detailTextLabel.textColor = [self sbSecondaryTextColor];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
    cell.detailTextLabel.numberOfLines = 0;

    SBToggleRow *def = sbToggleRows()[row];

    cell.textLabel.text = LOC(def.titleKey);
    cell.detailTextLabel.text = LOC(def.descKey);

    UISwitch *sw = [[UISwitch alloc] init];
    sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:def.key];
    sw.onTintColor = SBControlTintColor();
    sw.tag = row;
    [sw addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = sw;

    return cell;
}

- (void)toggleChanged:(UISwitch *)sender {
    NSArray<SBToggleRow *> *rows = sbToggleRows();
    if (sender.tag < 0 || sender.tag >= (NSInteger)rows.count) return;
    NSString *key = rows[sender.tag].key;
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:key];
    [self.tableView reloadData];
}

#pragma mark - Slider Cells (Section 1)

- (UITableViewCell *)sliderCellForRow:(NSInteger)row tableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    NSString *title;
    NSString *key;
    float minVal = SBAlertDurationMin;
    float maxVal = SBAlertDurationMax;
    float currentVal = 0;

    if (row == 0) {
        title = LOC(@"SB_SKIP_ALERT_DURATION");
        key = SBSkipAlertDuration;
        currentVal = [[NSUserDefaults standardUserDefaults] floatForKey:key];
        if (currentVal <= 0) currentVal = SBAlertDurationDefault;
    } else if (row == 1) {
        title = LOC(@"SB_UNSKIP_ALERT_DURATION");
        key = SBUnskipAlertDuration;
        currentVal = [[NSUserDefaults standardUserDefaults] floatForKey:key];
        if (currentVal <= 0) currentVal = SBAlertDurationDefault;
    } else {
        title = LOC(@"SB_MIN_DURATION_SLIDER");
        key = SBMinDuration;
        minVal = 0.0;
        maxVal = 60.0;
        currentVal = [[NSUserDefaults standardUserDefaults] floatForKey:key];
    }

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.textColor = [self sbSecondaryTextColor];
    titleLabel.font = [UIFont systemFontOfSize:13];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    UISlider *slider = [[UISlider alloc] init];
    slider.minimumValue = minVal;
    slider.maximumValue = maxVal;
    slider.value = currentVal;
    slider.minimumTrackTintColor = SBControlTintColor();
    slider.maximumTrackTintColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    slider.translatesAutoresizingMaskIntoConstraints = NO;
    slider.tag = row;
    [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];

    UILabel *valueLabel = [[UILabel alloc] init];
    NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
    formatter.allowedUnits = NSCalendarUnitSecond;
    formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleAbbreviated;

    valueLabel.text = [formatter stringFromTimeInterval:currentVal];
    valueLabel.textColor = [self sbSecondaryTextColor];
    valueLabel.font = [UIFont systemFontOfSize:13];
    valueLabel.textAlignment = NSTextAlignmentRight;
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.tag = SBSliderValueLabelTagBase + row;

    [cell.contentView addSubview:titleLabel];
    [cell.contentView addSubview:slider];
    [cell.contentView addSubview:valueLabel];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:8],
        [titleLabel.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],

        [slider.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
        [slider.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [slider.trailingAnchor constraintEqualToAnchor:valueLabel.leadingAnchor constant:-8],
        [slider.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-8],

        [valueLabel.centerYAnchor constraintEqualToAnchor:slider.centerYAnchor],
        [valueLabel.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
        [valueLabel.widthAnchor constraintEqualToConstant:50],
    ]];

    return cell;
}

- (void)sliderChanged:(UISlider *)sender {
    NSString *key;
    if (sender.tag == 0) key = SBSkipAlertDuration;
    else if (sender.tag == 1) key = SBUnskipAlertDuration;
    else key = SBMinDuration;

    int rounded = (int)roundf(sender.value);
    sender.value = rounded;
    [[NSUserDefaults standardUserDefaults] setFloat:(float)rounded forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    UILabel *valueLabel = (UILabel *)[sender.superview viewWithTag:SBSliderValueLabelTagBase + sender.tag];
    NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
    formatter.allowedUnits = NSCalendarUnitSecond;
    formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleAbbreviated;
    
    valueLabel.text = [formatter stringFromTimeInterval:rounded];
}

#pragma mark - Segment Cells (Section 2)

- (UITableViewCell *)segmentCellForRow:(NSInteger)row tableView:(UITableView *)tableView {
    NSInteger catIndex = row / 2;
    BOOL isColorRow = (row % 2 == 1);
    NSString *category = sbAllCategories()[catIndex];
    NSBundle *bundle = YouModBundle();
    NSString *catLocKey = [NSString stringWithFormat:@"SB_CAT_%@", category];
    NSString *catName = [bundle localizedStringForKey:catLocKey value:category table:nil];

    if (isColorRow) {
        return [self colorCellForCategory:category name:catName tableView:tableView];
    } else {
        return [self actionCellForCategory:category name:catName tableView:tableView];
    }
}

- (UITableViewCell *)actionCellForCategory:(NSString *)category name:(NSString *)catName tableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = catName;
    cell.textLabel.textColor = [self sbTextColor];
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];

    BOOL isHighlight = [category isEqualToString:@"poi_highlight"];
    NSString *actionKey = SB_ACTION_KEY(category);

    UIButton *menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
    NSInteger currentAction = [[NSUserDefaults standardUserDefaults] integerForKey:actionKey];
    [menuButton setTitle:SBActionName(currentAction) forState:UIControlStateNormal];
    [menuButton setTitleColor:[self sbSecondaryTextColor] forState:UIControlStateNormal];
    menuButton.titleLabel.font = [UIFont systemFontOfSize:15];
    [menuButton setImage:[UIImage systemImageNamed:@"chevron.up.chevron.down"] forState:UIControlStateNormal];
    menuButton.tintColor = [self sbSecondaryTextColor];

    NSMutableArray *menuActions = [NSMutableArray array];
    // Which actions a category may take differs by kind: a highlight can only be
    // disabled, skipped-to, or displayed, while a regular segment offers
    // auto-skip / ask instead of skip-to. These are separate option sets, not
    // duplication — each action's label is resolved through SBActionLocKey.
    NSArray<NSNumber *> *actionOptions;
    if (isHighlight) {
        actionOptions = @[@(SBSegmentActionDisable), @(SBSegmentActionAutoSkip), @(SBSegmentActionAsk), @(SBSegmentActionDisplay)];
    } else {
        actionOptions = @[@(SBSegmentActionDisable), @(SBSegmentActionAutoSkip), @(SBSegmentActionAsk), @(SBSegmentActionDisplay)];
    }

    NSBundle *bundle = YouModBundle();
    for (NSNumber *option in actionOptions) {
        NSInteger actionVal = [option integerValue];
        NSString *actionTitle = [bundle localizedStringForKey:SBActionLocKey((SBSegmentAction)actionVal) value:nil table:nil];

        UIAction *action = [UIAction actionWithTitle:actionTitle image:nil identifier:nil handler:^(__kindof UIAction *a) {
            [[NSUserDefaults standardUserDefaults] setInteger:actionVal forKey:actionKey];
            [self.tableView reloadData];
        }];
        if (actionVal == currentAction) action.state = UIMenuElementStateOn;
        [menuActions addObject:action];
    }

    menuButton.menu = [UIMenu menuWithTitle:catName children:menuActions];
    menuButton.showsMenuAsPrimaryAction = YES;
    [menuButton sizeToFit];
    cell.accessoryView = menuButton;

    return cell;
}

- (UITableViewCell *)colorCellForCategory:(NSString *)category name:(NSString *)catName tableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", catName, LOC(@"SB_SEGMENT_COLOR_SUFFIX")];
    cell.textLabel.textColor = [self sbTextColor];
    cell.textLabel.font = [UIFont systemFontOfSize:15];

    NSString *colorKey = SB_COLOR_KEY(category);
    NSString *hex = [[NSUserDefaults standardUserDefaults] stringForKey:colorKey];
    UIColor *color = SBColorFromHex(hex);

    SBColorCircleView *circle = [[SBColorCircleView alloc] initWithFrame:CGRectMake(0, 0, 34, 34) color:color];
    cell.accessoryView = circle;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isFiltering) {
        // In the flat filtered list the row carries its own tap handler (colour rows
        // open the picker); route through it with a reload that refreshes results.
        YMSearchRow *row = self.filteredFlatRows[indexPath.row];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        __weak typeof(self) weakSelf = self;
        if (row.onSelect) row.onSelect(self, ^{ [weakSelf.tableView reloadData]; });
        return;
    }
    if (indexPath.section != 2) return;
    if (indexPath.row % 2 != 1) return; // only color rows are tappable

    NSInteger catIndex = indexPath.row / 2;
    NSString *category = sbAllCategories()[catIndex];
    NSString *colorKey = SB_COLOR_KEY(category);

    self.activeColorKey = colorKey;
    self.activeColorIndexPath = indexPath;

    UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
    NSString *catName = [YouModBundle() localizedStringForKey:[NSString stringWithFormat:@"SB_CAT_%@", category] value:category table:nil];
    picker.title = [NSString stringWithFormat:@"%@ %@", catName, LOC(@"SB_SEGMENT_COLOR_SUFFIX")];
    NSString *currentHex = [[NSUserDefaults standardUserDefaults] stringForKey:colorKey];
    if (currentHex) picker.selectedColor = SBColorFromHex(currentHex);
    picker.supportsAlpha = NO;
    picker.delegate = self;

    [self presentViewController:picker animated:YES completion:nil];
}

#pragma mark - UIColorPickerViewControllerDelegate

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController {
    UIColor *color = viewController.selectedColor;
    NSString *hex = SBHexFromColor(color);
    [[NSUserDefaults standardUserDefaults] setObject:hex forKey:self.activeColorKey];
    [self.tableView reloadRowsAtIndexPaths:@[self.activeColorIndexPath] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)colorPickerViewController:(UIColorPickerViewController *)viewController didSelectColor:(UIColor *)color continuously:(BOOL)continuously {
    if (!continuously) {
        NSString *hex = SBHexFromColor(color);
        [[NSUserDefaults standardUserDefaults] setObject:hex forKey:self.activeColorKey];
        [self.tableView reloadRowsAtIndexPaths:@[self.activeColorIndexPath] withRowAnimation:UITableViewRowAnimationNone];
    }
}

#pragma mark - Footer spacing between category groups

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return (section == 2) ? 0 : 16;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    return [[UIView alloc] init];
}

@end

#pragma mark - Settings Search integration

// Retained delegate for a colour picker opened from a search result. The stock
// SBSettingsViewController colour flow reloads a specific SB-table index path,
// which doesn't exist in the search results table; this dedicated delegate writes
// the chosen colour and calls the search table's own reload instead. It is
// associated with the presented picker so it lives exactly as long as the picker.
@interface SBSearchColorDelegate : NSObject <UIColorPickerViewControllerDelegate>
@property (nonatomic, copy) NSString *colorKey;
@property (nonatomic, copy) void (^reload)(void);
@end
@implementation SBSearchColorDelegate
- (void)applyColor:(UIColor *)color {
    [[NSUserDefaults standardUserDefaults] setObject:SBHexFromColor(color) forKey:self.colorKey];
    if (self.reload) self.reload();
}
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)vc { [self applyColor:vc.selectedColor]; }
- (void)colorPickerViewController:(UIColorPickerViewController *)vc didSelectColor:(UIColor *)color continuously:(BOOL)continuously {
    if (!continuously) [self applyColor:color];
}
@end

static const void *kSBSearchColorDelegateKey = &kSBSearchColorDelegateKey;

// Build the flat list of every SponsorBlock setting as YMSearchRows, each rendered
// by the given SBSettingsViewController's own cell builders. Shared by the global
// settings search (via sbSearchRows) and SponsorBlock's own per-page search filter.
NSArray<YMSearchRow *> *sbFlatRowsWithRenderer(SBSettingsViewController *renderer) {
    NSMutableArray<YMSearchRow *> *rows = [NSMutableArray array];
    // Weak so a row's makeCell block can't retain the renderer: on the SponsorBlock
    // page the renderer IS the presented VC, which also retains this row list, so a
    // strong capture would cycle and leak the VC on every visit. The renderer always
    // outlives cell rendering (it's the live VC or a retained child), so weak is safe.
    __weak SBSettingsViewController *renderer_w = renderer;

    // Section 0 — toggles.
    NSArray<SBToggleRow *> *toggles = sbToggleRows();
    for (NSInteger i = 0; i < (NSInteger)toggles.count; i++) {
        SBToggleRow *def = toggles[i];
        YMSearchRow *row = [YMSearchRow new];
        row.searchText = [NSString stringWithFormat:@"%@ %@", LOC(def.titleKey), LOC(def.descKey)];
        row.makeCell = ^UITableViewCell *(UITableView *tv) { return [renderer_w toggleCellForRow:i tableView:tv]; };
        [rows addObject:row];
    }

    // Section 1 — the alert-duration sliders & min duration slider.
    for (NSInteger i = 0; i < 3; i++) {
        YMSearchRow *row = [YMSearchRow new];
        if (i == 0) row.searchText = LOC(@"SB_SKIP_ALERT_DURATION");
        else if (i == 1) row.searchText = LOC(@"SB_UNSKIP_ALERT_DURATION");
        else row.searchText = LOC(@"SB_MIN_DURATION_SLIDER");
        row.cellHeight = 70;
        row.makeCell = ^UITableViewCell *(UITableView *tv) { return [renderer_w sliderCellForRow:i tableView:tv]; };
        [rows addObject:row];
    }

    // Section 2 — per category: an action picker and a colour circle.
    NSBundle *bundle = YouModBundle();
    for (NSString *category in sbAllCategories()) {
        NSString *catName = [bundle localizedStringForKey:[NSString stringWithFormat:@"SB_CAT_%@", category] value:category table:nil];

        YMSearchRow *actionRow = [YMSearchRow new];
        actionRow.searchText = catName;
        actionRow.cellHeight = 48;
        actionRow.makeCell = ^UITableViewCell *(UITableView *tv) { return [renderer_w actionCellForCategory:category name:catName tableView:tv]; };
        [rows addObject:actionRow];

        YMSearchRow *colorRow = [YMSearchRow new];
        colorRow.searchText = [NSString stringWithFormat:@"%@ %@", catName, LOC(@"SB_SEGMENT_COLOR_SUFFIX")];
        colorRow.cellHeight = 48;
        colorRow.makeCell = ^UITableViewCell *(UITableView *tv) { return [renderer_w colorCellForCategory:category name:catName tableView:tv]; };
        colorRow.onSelect = ^(UIViewController *presenter, void (^reload)(void)) {
            NSString *colorKey = SB_COLOR_KEY(category);
            UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
            picker.title = [NSString stringWithFormat:@"%@ %@", catName, LOC(@"SB_SEGMENT_COLOR_SUFFIX")];
            NSString *currentHex = [[NSUserDefaults standardUserDefaults] stringForKey:colorKey];
            if (currentHex) picker.selectedColor = SBColorFromHex(currentHex);
            picker.supportsAlpha = NO;

            SBSearchColorDelegate *delegate = [SBSearchColorDelegate new];
            delegate.colorKey = colorKey;
            delegate.reload = reload;
            picker.delegate = delegate;
            objc_setAssociatedObject(picker, kSBSearchColorDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

            [presenter presentViewController:picker animated:YES completion:nil];
        };
        [rows addObject:colorRow];
    }

    return rows;
}

NSArray<YMSearchRow *> *sbSearchRows(UIViewController *host) {
    // One renderer builds every SB result cell. It's added as a child VC so the
    // cells inherit the host's trait collection (light/dark), and its tableView is
    // pointed at the host's (search results) table so SB's own cell handlers —
    // e.g. the action picker's [self.tableView reloadData] — refresh the visible
    // results rather than a table the renderer never presents.
    SBSettingsViewController *renderer = [[SBSettingsViewController alloc] init];
    [host addChildViewController:renderer];
    [renderer didMoveToParentViewController:host];
    if ([host respondsToSelector:@selector(tableView)]) {
        renderer.tableView = ((UITableView *(*)(id, SEL))objc_msgSend)(host, @selector(tableView));
    }
    return sbFlatRowsWithRenderer(renderer);
}

#pragma mark - Hook entry point

@interface YTSettingsSectionItemManager (SponsorBlock)
- (void)updateSponsorBlockSectionWithEntry:(id)entry;
@end

%hook YTSettingsSectionItemManager

%new(v@:@)
- (void)updateSponsorBlockSectionWithEntry:(id)entry {
    YTSettingsViewController *settingsVC = [self valueForKey:@"_settingsViewControllerDelegate"];
    // Use runtime-registered subclass of YTStyledViewController for YouTube's nav styling
    Class sbClass = objc_getClass("SBSettingsViewControllerStyled");
    if (!sbClass) sbClass = [SBSettingsViewController class];
    // initWithParentResponder: sets up YouTube's DI container (gimme) for nav bar theming
    id allocated = [sbClass alloc];
    SBSettingsViewController *sbVC = (SBSettingsViewController *)((id (*)(id, SEL, id))objc_msgSend)(allocated, @selector(initWithParentResponder:), settingsVC);
    [settingsVC pushViewController:sbVC];
}

%end

%ctor {
    // Register SBSettingsViewControllerStyled as a runtime subclass of YTStyledViewController
    // with all methods from SBSettingsViewController — gives us YouTube's nav bar styling
    Class ytStyled = %c(YTStyledViewController);
    if (ytStyled) {
        Class sbStyled = objc_allocateClassPair(ytStyled, "SBSettingsViewControllerStyled", 0);
        if (sbStyled) {
            // Copy all instance methods from our compiled SBSettingsViewController
            unsigned int count = 0;
            Method *methods = class_copyMethodList([SBSettingsViewController class], &count);
            for (unsigned int i = 0; i < count; i++) {
                SEL sel = method_getName(methods[i]);
                IMP imp = method_getImplementation(methods[i]);
                const char *types = method_getTypeEncoding(methods[i]);
                class_addMethod(sbStyled, sel, imp, types);
            }
            free(methods);

            // Copy properties (for @synthesize ivars)
            unsigned int propCount = 0;
            objc_property_t *props = class_copyPropertyList([SBSettingsViewController class], &propCount);
            for (unsigned int i = 0; i < propCount; i++) {
                unsigned int attrCount = 0;
                objc_property_attribute_t *attrs = property_copyAttributeList(props[i], &attrCount);
                class_addProperty(sbStyled, property_getName(props[i]), attrs, attrCount);
                free(attrs);
            }
            free(props);

            // Copy ivars won't work after registration, but properties use associated objects
            objc_registerClassPair(sbStyled);
        }
    }

    // Per-category default action and seek-bar color. Sponsor is the only
    // category that auto-skips out of the box; the rest are disabled until the
    // user opts in. The action/color default entries are generated from
    // sbAllCategories() below so this table stays the sole per-category source.
    NSDictionary<NSString *, NSArray *> *categoryDefaults = @{
        @"sponsor":        @[@(SBSegmentActionAutoSkip), @"#00D400"],
        @"intro":          @[@(SBSegmentActionDisable),  @"#00FFFF"],
        @"outro":          @[@(SBSegmentActionDisable),  @"#0202ED"],
        @"interaction":    @[@(SBSegmentActionDisable),  @"#FF00F7"],
        @"selfpromo":      @[@(SBSegmentActionDisable),  @"#FFFF00"],
        @"music_offtopic": @[@(SBSegmentActionDisable),  @"#FF9900"],
        @"preview":        @[@(SBSegmentActionDisable),  @"#0084D6"],
        @"hook":           @[@(SBSegmentActionDisable),  @"#395699"],
        @"poi_highlight":  @[@(SBSegmentActionDisable),  @"#FF006A"],
        @"filler":         @[@(SBSegmentActionDisable),  @"#7300FF"],
    };

    NSMutableDictionary *defaults = [@{
        SBEnabled: @YES,
        SBShowButton: @YES,
        SBShowNotifications: @YES,
        SBSegmentsInPlayer: @YES,
        SBSegmentsInFeed: @YES,
        SBSegmentsInMiniPlayer: @YES,
        SBSkipAlertDuration: @(SBAlertDurationDefault),
        SBUnskipAlertDuration: @(SBAlertDurationDefault),
    } mutableCopy];

    for (NSString *category in sbAllCategories()) {
        NSArray *def = categoryDefaults[category];
        if (!def) continue;
        defaults[SB_ACTION_KEY(category)] = def[0];
        defaults[SB_COLOR_KEY(category)] = def[1];
    }

    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
    %init;
}

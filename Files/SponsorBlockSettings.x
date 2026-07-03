// SponsorBlockSettings.x — Custom UITableViewController matching YTLite's SponsorBlock UI
#import "Headers.h"
#import <objc/runtime.h>
#import <objc/message.h>

extern UIColor *SBColorFromHex(NSString *hexString);

static NSBundle *SBSettingsBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:@"YouMod" ofType:@"bundle"];
        if (tweakBundlePath)
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        else
            bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:PS_ROOT_PATH_NS(@"/Library/Application Support/%@.bundle"), @"YouMod"]];
    });
    return bundle;
}

#define SB_LOC(x) [SBSettingsBundle() localizedStringForKey:x value:nil table:nil]

static NSArray<NSString *> *sbSettingsCategories() {
    return @[@"sponsor", @"intro", @"outro", @"interaction", @"selfpromo",
             @"music_offtopic", @"preview", @"hook", @"poi_highlight", @"filler"];
}

static NSString *SBActionName(NSInteger action) {
    switch (action) {
        case SBSegmentActionAutoSkip: return SB_LOC(@"SB_ACTION_AUTO_SKIP");
        case SBSegmentActionAsk:      return SB_LOC(@"SB_ACTION_ASK");
        case SBSegmentActionDisplay:   return SB_LOC(@"SB_ACTION_DISPLAY");
        case SBSegmentActionSkipTo:    return SB_LOC(@"SB_ACTION_SKIP_TO");
        default:                       return SB_LOC(@"SB_ACTION_DISABLE");
    }
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

@interface SBSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UIColorPickerViewControllerDelegate>
- (UITableView *)tableView;
- (void)setTableView:(UITableView *)tv;
- (NSString *)activeColorKey;
- (void)setActiveColorKey:(NSString *)key;
- (NSIndexPath *)activeColorIndexPath;
- (void)setActiveColorIndexPath:(NSIndexPath *)ip;
- (UIColor *)sbTextColor;
- (UIColor *)sbSecondaryTextColor;
@end

static const void *kSBTableViewKey = &kSBTableViewKey;
static const void *kSBColorKeyKey = &kSBColorKeyKey;
static const void *kSBColorIndexPathKey = &kSBColorIndexPathKey;

@implementation SBSettingsViewController

- (UITableView *)tableView { return objc_getAssociatedObject(self, kSBTableViewKey); }
- (void)setTableView:(UITableView *)tv { objc_setAssociatedObject(self, kSBTableViewKey, tv, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSString *)activeColorKey { return objc_getAssociatedObject(self, kSBColorKeyKey); }
- (void)setActiveColorKey:(NSString *)key { objc_setAssociatedObject(self, kSBColorKeyKey, key, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSIndexPath *)activeColorIndexPath { return objc_getAssociatedObject(self, kSBColorIndexPathKey); }
- (void)setActiveColorIndexPath:(NSIndexPath *)ip { objc_setAssociatedObject(self, kSBColorIndexPathKey, ip, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

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
    return nil;
}

- (UIColor *)sbTextColor {
    return (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark)
        ? [UIColor whiteColor] : [UIColor labelColor];
}

- (UIColor *)sbSecondaryTextColor {
    return [UIColor colorWithWhite:0.55 alpha:1.0];
}

#pragma mark - Sections: 0=Main, 1=Sliders, 2=Segments

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 3; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 7;  // toggles
    if (section == 1) return 2;  // sliders
    return sbSettingsCategories().count * 2;  // action + color per category
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *title = nil;
    if (section == 0) title = SB_LOC(@"SB_SECTION_MAIN");
    else if (section == 2) title = SB_LOC(@"SB_CATEGORIES_HEADER");
    if (!title) return nil;

    UIView *header = [[UIView alloc] init];
    UILabel *label = [[UILabel alloc] init];
    label.text = title;
    label.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    label.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
        [label.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
        [label.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-6],
    ]];
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 1) return 16;
    return 36;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
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

    NSString *title, *desc, *key;
    switch (row) {
        case 0: title = SB_LOC(@"SB_ENABLE"); desc = SB_LOC(@"SB_ENABLE_DESC"); key = SBEnabled; break;
        case 1: title = SB_LOC(@"SB_SHOW_BUTTON"); desc = SB_LOC(@"SB_SHOW_BUTTON_DESC"); key = SBShowButton; break;
        case 2: title = SB_LOC(@"SB_SHOW_NOTIFICATIONS"); desc = SB_LOC(@"SB_SHOW_NOTIFICATIONS_DESC"); key = SBShowNotifications; break;
        case 3: title = SB_LOC(@"SB_SEGMENTS_IN_FEED"); desc = SB_LOC(@"SB_SEGMENTS_IN_FEED_DESC"); key = SBSegmentsInFeed; break;
        case 4: title = SB_LOC(@"SB_SEGMENTS_IN_MINIPLAYER"); desc = SB_LOC(@"SB_SEGMENTS_IN_MINIPLAYER_DESC"); key = SBSegmentsInMiniPlayer; break;
        case 5: title = SB_LOC(@"SB_HAPTIC_FEEDBACK"); desc = SB_LOC(@"SB_HAPTIC_FEEDBACK_DESC"); key = SBAudioNotification; break;
        default: title = SB_LOC(@"SB_SHOW_DURATION"); desc = SB_LOC(@"SB_SHOW_DURATION_DESC"); key = SBShowDuration; break;
    }

    cell.textLabel.text = title;
    cell.detailTextLabel.text = desc;

    UISwitch *sw = [[UISwitch alloc] init];
    sw.on = [[NSUserDefaults standardUserDefaults] boolForKey:key];
    sw.onTintColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.9 alpha:1.0];
    sw.tag = row;
    [sw addTarget:self action:@selector(toggleChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = sw;

    return cell;
}

- (void)toggleChanged:(UISwitch *)sender {
    NSString *key;
    switch (sender.tag) {
        case 0: key = SBEnabled; break;
        case 1: key = SBShowButton; break;
        case 2: key = SBShowNotifications; break;
        case 3: key = SBSegmentsInFeed; break;
        case 4: key = SBSegmentsInMiniPlayer; break;
        case 5: key = SBAudioNotification; break;
        default: key = SBShowDuration; break;
    }
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:key];
}

#pragma mark - Slider Cells (Section 1)

- (UITableViewCell *)sliderCellForRow:(NSInteger)row tableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    NSString *title = (row == 0) ? SB_LOC(@"SB_SKIP_ALERT_DURATION") : SB_LOC(@"SB_UNSKIP_ALERT_DURATION");
    NSString *key = (row == 0) ? SBSkipAlertDuration : SBUnskipAlertDuration;
    float currentVal = [[NSUserDefaults standardUserDefaults] floatForKey:key];
    if (currentVal <= 0) currentVal = 4.0;

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.textColor = [self sbSecondaryTextColor];
    titleLabel.font = [UIFont systemFontOfSize:13];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;

    UISlider *slider = [[UISlider alloc] init];
    slider.minimumValue = 2.0;
    slider.maximumValue = 20.0;
    slider.value = currentVal;
    slider.minimumTrackTintColor = [UIColor colorWithRed:0.6 green:0.2 blue:0.9 alpha:1.0];
    slider.maximumTrackTintColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    slider.translatesAutoresizingMaskIntoConstraints = NO;
    slider.tag = row;
    [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];

    UILabel *valueLabel = [[UILabel alloc] init];
    valueLabel.text = [NSString stringWithFormat:@"%d secs", (int)currentVal];
    valueLabel.textColor = [self sbSecondaryTextColor];
    valueLabel.font = [UIFont systemFontOfSize:13];
    valueLabel.textAlignment = NSTextAlignmentRight;
    valueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    valueLabel.tag = 100 + row;

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
    NSString *key = (sender.tag == 0) ? SBSkipAlertDuration : SBUnskipAlertDuration;
    int rounded = (int)roundf(sender.value);
    sender.value = rounded;
    [[NSUserDefaults standardUserDefaults] setFloat:(float)rounded forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    UILabel *valueLabel = (UILabel *)[sender.superview viewWithTag:100 + sender.tag];
    valueLabel.text = [NSString stringWithFormat:@"%d secs", rounded];
}

#pragma mark - Segment Cells (Section 2)

- (UITableViewCell *)segmentCellForRow:(NSInteger)row tableView:(UITableView *)tableView {
    NSInteger catIndex = row / 2;
    BOOL isColorRow = (row % 2 == 1);
    NSString *category = sbSettingsCategories()[catIndex];
    NSBundle *bundle = SBSettingsBundle();
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
    menuButton.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [menuButton setImage:[UIImage systemImageNamed:@"chevron.up.chevron.down"] forState:UIControlStateNormal];
    menuButton.tintColor = [self sbSecondaryTextColor];

    NSMutableArray *menuActions = [NSMutableArray array];
    NSArray *actionDefs;
    if (isHighlight) {
        actionDefs = @[@[@(SBSegmentActionDisable), @"SB_ACTION_DISABLE"],
                       @[@(SBSegmentActionSkipTo), @"SB_ACTION_SKIP_TO"],
                       @[@(SBSegmentActionDisplay), @"SB_ACTION_DISPLAY"]];
    } else {
        actionDefs = @[@[@(SBSegmentActionDisable), @"SB_ACTION_DISABLE"],
                       @[@(SBSegmentActionAutoSkip), @"SB_ACTION_AUTO_SKIP"],
                       @[@(SBSegmentActionAsk), @"SB_ACTION_ASK"],
                       @[@(SBSegmentActionDisplay), @"SB_ACTION_DISPLAY"]];
    }

    NSBundle *bundle = SBSettingsBundle();
    for (NSArray *def in actionDefs) {
        NSInteger actionVal = [def[0] integerValue];
        NSString *locKey = def[1];
        NSString *actionTitle = [bundle localizedStringForKey:locKey value:nil table:nil];
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14];
        UIImage *checkImage = (actionVal == currentAction) ? [UIImage systemImageNamed:@"checkmark" withConfiguration:config] : nil;

        UIAction *action = [UIAction actionWithTitle:actionTitle image:checkImage identifier:nil handler:^(__kindof UIAction *a) {
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
    cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", catName, SB_LOC(@"SB_SEGMENT_COLOR_SUFFIX")];
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
    if (indexPath.section != 2) return;
    if (indexPath.row % 2 != 1) return; // only color rows are tappable

    NSInteger catIndex = indexPath.row / 2;
    NSString *category = sbSettingsCategories()[catIndex];
    NSString *colorKey = SB_COLOR_KEY(category);

    self.activeColorKey = colorKey;
    self.activeColorIndexPath = indexPath;

    UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
    NSString *catName = [SBSettingsBundle() localizedStringForKey:[NSString stringWithFormat:@"SB_CAT_%@", category] value:category table:nil];
    picker.title = [NSString stringWithFormat:@"%@ %@", catName, SB_LOC(@"SB_SEGMENT_COLOR_SUFFIX")];
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

    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        SBEnabled: @YES,
        SBShowButton: @YES,
        SBShowNotifications: @YES,
        SBSegmentsInFeed: @YES,
        SBSegmentsInMiniPlayer: @YES,
        SBSkipAlertDuration: @4.0,
        SBUnskipAlertDuration: @4.0,
        SB_ACTION_KEY(@"sponsor"): @(SBSegmentActionAutoSkip),
        SB_ACTION_KEY(@"intro"): @(SBSegmentActionDisable),
        SB_ACTION_KEY(@"outro"): @(SBSegmentActionDisable),
        SB_ACTION_KEY(@"interaction"): @(SBSegmentActionDisable),
        SB_ACTION_KEY(@"selfpromo"): @(SBSegmentActionDisable),
        SB_ACTION_KEY(@"music_offtopic"): @(SBSegmentActionDisable),
        SB_ACTION_KEY(@"preview"): @(SBSegmentActionDisable),
        SB_ACTION_KEY(@"hook"): @(SBSegmentActionDisable),
        SB_ACTION_KEY(@"poi_highlight"): @(SBSegmentActionDisable),
        SB_ACTION_KEY(@"filler"): @(SBSegmentActionDisable),
        SB_COLOR_KEY(@"sponsor"): @"#00D400",
        SB_COLOR_KEY(@"intro"): @"#00FFFF",
        SB_COLOR_KEY(@"outro"): @"#0202ED",
        SB_COLOR_KEY(@"interaction"): @"#FF00F7",
        SB_COLOR_KEY(@"selfpromo"): @"#FFFF00",
        SB_COLOR_KEY(@"music_offtopic"): @"#FF9900",
        SB_COLOR_KEY(@"preview"): @"#0084D6",
        SB_COLOR_KEY(@"hook"): @"#395699",
        SB_COLOR_KEY(@"poi_highlight"): @"#FF006A",
        SB_COLOR_KEY(@"filler"): @"#7300FF",
    }];
    %init;
}

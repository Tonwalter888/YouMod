// YouModSettings.x — Reusable UIKit-based sub-page for YouMod settings sections
#import "Headers.h"
#import <objc/runtime.h>
#import <objc/message.h>

static NSBundle *YMSettingsBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *path = [[NSBundle mainBundle] pathForResource:@"YouMod" ofType:@"bundle"];
        if (path) bundle = [NSBundle bundleWithPath:path];
    });
    return bundle;
}
#define YMLOC(x) [YMSettingsBundle() localizedStringForKey:x value:nil table:nil]

#pragma mark - Data Model

typedef NS_ENUM(NSInteger, YMRowType) {
    YMRowTypeToggle = 0,
    YMRowTypePicker,
    YMRowTypeAction,
    YMRowTypeHeader,
    YMRowTypeSegment,
    YMRowTypeTextSegment,
    YMRowTypeImageSegment,
    YMRowTypeSlider
};

@interface YMSettingsItem : NSObject
@property (nonatomic, assign) YMRowType type;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *subtitle;
@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) NSArray<NSString *> *pickerOptions;
@property (nonatomic, assign) NSInteger pickerDefault;
@property (nonatomic, copy) void (^action)(UIViewController *vc);
@property (nonatomic, strong) NSArray<NSNumber *> *segmentIcons;
@property (nonatomic, strong) NSArray<NSString *> *segmentLabels;
@property (nonatomic, strong) NSArray<UIImage *> *segmentImages;
@property (nonatomic, assign) float sliderMin;
@property (nonatomic, assign) float sliderMax;
@property (nonatomic, assign) float sliderStep;
@property (nonatomic, assign) float sliderDefault;
+ (instancetype)toggleWithTitle:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key;
+ (instancetype)sliderWithTitle:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key min:(float)min max:(float)max step:(float)step defaultValue:(float)defaultValue;
+ (instancetype)pickerWithTitle:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key options:(NSArray<NSString *> *)options defaultValue:(NSInteger)defaultValue;
+ (instancetype)actionWithTitle:(NSString *)title subtitle:(NSString *)subtitle action:(void (^)(UIViewController *vc))action;
+ (instancetype)headerWithTitle:(NSString *)title;
+ (instancetype)segmentWithTitle:(NSString *)title key:(NSString *)key icons:(NSArray<NSNumber *> *)icons defaultValue:(NSInteger)defaultValue;
+ (instancetype)textSegmentWithTitle:(NSString *)title key:(NSString *)key labels:(NSArray<NSString *> *)labels defaultValue:(NSInteger)defaultValue;
+ (instancetype)imageSegmentWithTitle:(NSString *)title key:(NSString *)key images:(NSArray<UIImage *> *)images defaultValue:(NSInteger)defaultValue;
@end

@implementation YMSettingsItem

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

@end

#pragma mark - YMSubSettingsViewController

@interface YMSubSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
- (UITableView *)tableView;
- (void)setTableView:(UITableView *)tv;
- (NSString *)navTitle;
- (void)setNavTitle:(NSString *)t;
- (NSArray<YMSettingsItem *> *)items;
- (void)setItems:(NSArray<YMSettingsItem *> *)items;
- (UIColor *)ymTextColor;
- (UIColor *)ymSecondaryColor;
@end

static const void *kYMTableViewKey = &kYMTableViewKey;
static const void *kYMNavTitleKey = &kYMNavTitleKey;
static const void *kYMItemsKey = &kYMItemsKey;
static const void *kYMSwitchKeyAssoc = &kYMSwitchKeyAssoc;
static const void *kYMSliderKeyAssoc = &kYMSliderKeyAssoc;
static const void *kYMSliderStepAssoc = &kYMSliderStepAssoc;
static const void *kYMSliderLabelAssoc = &kYMSliderLabelAssoc;

@implementation YMSubSettingsViewController

- (UITableView *)tableView { return objc_getAssociatedObject(self, kYMTableViewKey); }
- (void)setTableView:(UITableView *)tv { objc_setAssociatedObject(self, kYMTableViewKey, tv, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSString *)navTitle { return objc_getAssociatedObject(self, kYMNavTitleKey); }
- (void)setNavTitle:(NSString *)t { objc_setAssociatedObject(self, kYMNavTitleKey, t, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (NSArray<YMSettingsItem *> *)items { return objc_getAssociatedObject(self, kYMItemsKey); }
- (void)setItems:(NSArray<YMSettingsItem *> *)items { objc_setAssociatedObject(self, kYMItemsKey, items, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

- (void)viewDidLoad {
    Class ytStyled = objc_getClass("YTStyledViewController");
    struct objc_super superStruct = { self, ytStyled ?: [UIViewController class] };
    ((void (*)(struct objc_super *, SEL))objc_msgSendSuper)(&superStruct, @selector(viewDidLoad));

    self.title = self.navTitle;

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
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    YMSettingsItem *item = self.items[indexPath.row];
    if (item.type == YMRowTypeToggle) {
        return [self toggleCellForItem:item tableView:tableView];
    } else if (item.type == YMRowTypeAction) {
        return [self actionCellForItem:item tableView:tableView];
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
    }
    return [self pickerCellForItem:item tableView:tableView];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    YMSettingsItem *item = self.items[indexPath.row];
    if (item.type == YMRowTypeAction && item.action) {
        item.action(self);
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
        [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:key];
    }
}

- (UITableViewCell *)sliderCellForItem:(YMSettingsItem *)item tableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    // A stored value of zero is treated as "no value yet" and shown as the
    // default. Slider ranges are therefore expected to be positive.
    float stored = [[NSUserDefaults standardUserDefaults] floatForKey:item.key];
    if (stored <= 0) stored = item.sliderDefault;

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
    valueLabel.text = [NSString stringWithFormat:@"%d secs", (int)stored];
    [cell.contentView addSubview:valueLabel];

    UISlider *slider = [[UISlider alloc] init];
    slider.translatesAutoresizingMaskIntoConstraints = NO;
    slider.minimumValue = item.sliderMin;
    slider.maximumValue = item.sliderMax;
    slider.value = stored;
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
    float snapped = roundf(sender.value / step) * step;
    sender.value = snapped;
    [[NSUserDefaults standardUserDefaults] setFloat:snapped forKey:key];
    UILabel *valueLabel = objc_getAssociatedObject(sender, kYMSliderLabelAssoc);
    valueLabel.text = [NSString stringWithFormat:@"%d secs", (int)snapped];
}

#pragma mark - Action Cell

- (UITableViewCell *)actionCellForItem:(YMSettingsItem *)item tableView:(UITableView *)tableView {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.textLabel.text = item.title;
    cell.textLabel.textColor = [self ymTextColor];
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];

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

- (UITableViewCell *)pickerCellForItem:(YMSettingsItem *)item tableView:(UITableView *)tableView {
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

    NSInteger safeDefault = (item.pickerDefault >= 0 && item.pickerDefault < (NSInteger)item.pickerOptions.count)
        ? item.pickerDefault : 0;
    id storedValue = [[NSUserDefaults standardUserDefaults] objectForKey:item.key];
    NSInteger currentValue = storedValue ? [storedValue integerValue] : safeDefault;
    NSString *currentTitle = (currentValue >= 0 && currentValue < (NSInteger)item.pickerOptions.count)
        ? item.pickerOptions[currentValue]
        : item.pickerOptions[safeDefault];

    UIButton *menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [menuButton setTitle:currentTitle forState:UIControlStateNormal];
    [menuButton setTitleColor:[self ymSecondaryColor] forState:UIControlStateNormal];
    menuButton.titleLabel.font = [UIFont systemFontOfSize:15];
    menuButton.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    [menuButton setImage:[UIImage systemImageNamed:@"chevron.up.chevron.down"] forState:UIControlStateNormal];
    menuButton.tintColor = [self ymSecondaryColor];

    NSMutableArray *menuActions = [NSMutableArray array];
    __weak typeof(self) weakSelf = self;
    for (NSInteger i = 0; i < (NSInteger)item.pickerOptions.count; i++) {
        NSString *optionTitle = item.pickerOptions[i];
        NSString *itemKey = item.key;
        UIAction *action = [UIAction actionWithTitle:optionTitle image:nil identifier:nil handler:^(__kindof UIAction *a) {
            [[NSUserDefaults standardUserDefaults] setInteger:i forKey:itemKey];
            [weakSelf.tableView reloadData];
        }];
        if (i == currentValue) {
            action.state = UIMenuElementStateOn;
        }
        [menuActions addObject:action];
    }

    menuButton.menu = [UIMenu menuWithTitle:item.title children:menuActions];
    menuButton.showsMenuAsPrimaryAction = YES;
    [menuButton sizeToFit];
    cell.accessoryView = menuButton;

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

#pragma mark - YMTabOrderViewController

static NSString * const kYMTabIDs[] = {
    @"home", @"shorts", @"create", @"subscriptions",  @"library", @"history", @"gaming", @"sports", @"notifications", @"news", @"music", @"watchlater", @"playlist", @"like", @"live", @"post", @"video", @"movie", @"course", @"minigame"
};
static const NSInteger kYMTabCount = 20;
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
// Saved copies of the shared navigation bar's appearance, restored when this
// screen is dismissed. This screen installs its own opaque navigation bar
// appearance; because that appearance is shared, leaving it in place would repaint
// the previous screen's back button with the appearance's default (blue) tint.
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
    if ([tabID isEqualToString:@"home"]) return YMLOC(@"HOME_TAB");
    if ([tabID isEqualToString:@"shorts"]) return YMLOC(@"SHORTS_TAB");
    if ([tabID isEqualToString:@"create"]) return YMLOC(@"CREATE_TAB");
    if ([tabID isEqualToString:@"subscriptions"]) return YMLOC(@"SUBSCRIPTIONS_TAB");
    if ([tabID isEqualToString:@"library"]) return YMLOC(@"LIBRARY_TAB");
    if ([tabID isEqualToString:@"history"]) return YMLOC(@"HISTORY_TAB");
    if ([tabID isEqualToString:@"gaming"]) return YMLOC(@"GAMING_TAB");
    if ([tabID isEqualToString:@"sports"]) return YMLOC(@"SPORTS_TAB");
    if ([tabID isEqualToString:@"notifications"]) return YMLOC(@"NOTI_TAB");
    if ([tabID isEqualToString:@"news"]) return YMLOC(@"NEWS_TAB");
    if ([tabID isEqualToString:@"music"]) return YMLOC(@"MUSIC_TAB");
    if ([tabID isEqualToString:@"watchlater"]) return YMLOC(@"WATCH_LATER_TAB");
    if ([tabID isEqualToString:@"playlist"]) return YMLOC(@"PLAYLIST_TAB");
    if ([tabID isEqualToString:@"like"]) return YMLOC(@"LIKE_TAB");
    if ([tabID isEqualToString:@"live"]) return YMLOC(@"LIVE_TAB");
    if ([tabID isEqualToString:@"post"]) return YMLOC(@"POST_TAB");
    if ([tabID isEqualToString:@"video"]) return YMLOC(@"VIDEO_TAB");
    if ([tabID isEqualToString:@"movie"]) return YMLOC(@"MOVIE_TAB");
    if ([tabID isEqualToString:@"course"]) return YMLOC(@"COURSE_TAB");
    if ([tabID isEqualToString:@"minigame"]) return YMLOC(@"MINIGAME_TAB");
    return tabID;
}

- (UIImage *)iconForTabID:(NSString *)tabID {
    static YTAssetLoader *cachedLoader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cachedLoader = [[%c(YTAssetLoader) alloc] initWithBundle:YMSettingsBundle()];
    });

    if ([tabID isEqualToString:@"create"]) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 weight:UIImageSymbolWeightMedium];
        return [[UIImage systemImageNamed:@"plus" withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    NSDictionary *ytIconTypes = @{@"home": @(65), @"shorts": @(769), @"subscriptions": @(66), @"library": @(61)};
    NSDictionary *bundleIcons = @{@"history": @"icons/history", @"gaming": @"icons/gaming", @"sports": @"icons/sports", @"notifications": @"icons/noti", @"news": @"icons/news", @"music": @"icons/music", @"watchlater": @"icons/watchlater", @"playlist": @"icons/playlist", @"like": @"icons/like", @"live": @"icons/live", @"post": @"icons/post", @"video": @"icons/video", @"movie": @"icons/movie", @"course": @"icons/course", @"minigame": @"icons/minigame"};

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

    self.title = YMLOC(@"MANAGE_TABS");
    [self loadTabData];
    [self takeSnapshot];

    // The previous screen's navigation bar appearance is saved before this screen
    // installs its own opaque appearance, and restored on dismissal so that screen
    // keeps its own back-button tint.
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

    // Restore the previous screen's saved navigation bar appearance so it keeps
    // its own back-button tint rather than this screen's opaque appearance.
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
    NSMutableArray *data = [NSMutableArray array];

    if (savedOrder.count > 0) {
        for (NSDictionary *entry in savedOrder) {
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
                [data addObject:[@{@"id": tabID, @"enabled": @NO} mutableCopy]];
            }
        }
    } else {
        // Default: Home, Shorts, Create, Subscriptions, Library enabled
        for (NSInteger i = 0; i < kYMTabCount; i++) {
            BOOL defaultEnabled = i < 5;
            [data addObject:[@{@"id": kYMTabIDs[i], @"enabled": @(defaultEnabled)} mutableCopy]];
        }
    }

    self.tabData = data;
}

- (void)saveTabData {
    NSMutableArray *toSave = [NSMutableArray array];
    for (NSMutableDictionary *entry in self.tabData) {
        [toSave addObject:@{@"id": entry[@"id"], @"enabled": entry[@"enabled"]}];
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

    sw.on = enabled;
    objc_setAssociatedObject(sw, kYMSwitchKeyAssoc, tabID, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    return cell;
}

- (void)tabToggleChanged:(UISwitch *)sender {
    NSString *tabID = objc_getAssociatedObject(sender, kYMSwitchKeyAssoc);
    if (!tabID) return;

    NSMutableDictionary *entry = nil;
    for (NSMutableDictionary *d in self.tabData) {
        if ([d[@"id"] isEqualToString:tabID]) { entry = d; break; }
    }
    if (!entry) return;

    BOOL wantsEnabled = sender.on;

    if (wantsEnabled && [self enabledCount] >= kYMTabMaxEnabled) {
        sender.on = NO;
        YTAlertView *alert = [%c(YTAlertView) infoDialog];
        alert.title = YMLOC(@"TAB_LIMIT");
        alert.subtitle = YMLOC(@"TAB_LIMIT_DESC");
        [alert show];
        return;
    } else if (!wantsEnabled && [self enabledCount] < kYMTabMinEnabled) {
        sender.on = YES;
        YTAlertView *alert = [%c(YTAlertView) infoDialog];
        alert.title = YMLOC(@"WARNING");
        alert.subtitle = YMLOC(@"ZERO_TAB_DESC");
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
    hintLabel.text = YMLOC(@"TAB_REORDER_HINT");
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

// Modal entry point for opening Manage Tabs without a YTSettingsViewController nav stack
// (used by the long-press gesture on the Home tab). Wraps the standard tab-order VC in
// a UINavigationController with a Done button and presents from the topmost VC.
void YMPresentTabOrderModally(id parentResponder) {
    Class styledClass = objc_getClass("YMTabOrderViewControllerStyled");
    if (!styledClass) styledClass = [YMTabOrderViewController class];

    YMTabOrderViewController *vc = (YMTabOrderViewController *)((id (*)(id, SEL, id))objc_msgSend)([styledClass alloc], @selector(initWithParentResponder:), parentResponder);
    if (!vc) vc = [[styledClass alloc] init];

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;

    __weak UINavigationController *weakNav = nav;
    UIAction *doneAction = [UIAction actionWithTitle:@"" image:nil identifier:nil handler:^(__unused UIAction *action) {
        [weakNav dismissViewControllerAnimated:YES completion:nil];
    }];
    vc.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemDone
        primaryAction:doneAction];

    UIViewController *presenter = [%c(YTUIUtils) topViewControllerForPresenting];
    if (!presenter) return;
    [presenter presentViewController:nav animated:YES completion:nil];
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

#pragma mark - Runtime Class Registration

static void ymRegisterStyledSubclass(Class sourceClass, const char *name) {
    Class ytStyled = %c(YTStyledViewController);
    Class newClass = objc_allocateClassPair(ytStyled, name, 0);
    if (!newClass) return;

    unsigned int count = 0;
    Method *methods = class_copyMethodList(sourceClass, &count);
    for (unsigned int i = 0; i < count; i++) {
        class_addMethod(newClass, method_getName(methods[i]), method_getImplementation(methods[i]), method_getTypeEncoding(methods[i]));
    }
    free(methods);

    unsigned int propCount = 0;
    objc_property_t *props = class_copyPropertyList(sourceClass, &propCount);
    for (unsigned int i = 0; i < propCount; i++) {
        unsigned int attrCount = 0;
        objc_property_attribute_t *attrs = property_copyAttributeList(props[i], &attrCount);
        class_addProperty(newClass, property_getName(props[i]), attrs, attrCount);
        free(attrs);
    }
    free(props);

    objc_registerClassPair(newClass);
}

%hook YTQTMButton
- (void)layoutSubviews {
    %orig;
    if ([self.accessibilityIdentifier isEqualToString:@"id.ui.title.tab.button"]) {
        UIColor *customTitle = [self valueForKey:@"_desiredCustomTitleColor"];

        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
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
        if (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
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
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"YouModUpdateTabBar" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(YouModReloadTabBar:)
                                                 name:@"YouModUpdateTabBar"
                                               object:nil];
}
%new
- (void)YouModReloadTabBar:(id)arg {
    if ([self.parentViewController isKindOfClass:%c(YTAppViewControllerImpl)]) {
        YTAppViewControllerImpl *appcon = (YTAppViewControllerImpl *)self.parentViewController;
        [appcon refreshPivotBarWithTriggedByNotification:YES];
    } else {
        YTAppViewController *appcon = (YTAppViewController *)self.parentViewController;
        [appcon refreshPivotBarWithTriggedByNotification:YES];
    }
}
%end

%ctor {
    ymRegisterStyledSubclass([YMSubSettingsViewController class], "YMSubSettingsViewControllerStyled");
    ymRegisterStyledSubclass([YMTabOrderViewController class], "YMTabOrderViewControllerStyled");
}

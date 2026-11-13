// YMSplitSettings.x — iPad two-pane YouMod settings page (sidebar + detail).
//
// Left pane: the home rows (section groups + developer rows) with a global
// search bar whose results are shown in the detail pane. Right pane: the
// selected group's settings page (or the global search results). Tapping a
// sidebar row swaps the detail pane instead of pushing a page.
//
// A plain UIViewController inside the modal settings navigation created by
// YMPresentSettingsPage.
#import "Headers.h"

#import <objc/runtime.h>
#import <objc/message.h>

@interface YMSplitSettingsViewController : UIViewController <UINavigationControllerDelegate>
- (NSArray<YMSettingsItem *> *)sidebarItems;
- (void)setSidebarItems:(NSArray<YMSettingsItem *> *)items;
- (YMSubSettingsViewController *)sidebarVC;
- (void)setSidebarVC:(YMSubSettingsViewController *)vc;
- (YMSubSettingsViewController *)resultsVC;
- (void)setResultsVC:(YMSubSettingsViewController *)vc;
- (UINavigationController *)detailNav;
- (void)setDetailNav:(UINavigationController *)nav;
- (UIViewController *)groupRootVC;
- (void)setGroupRootVC:(UIViewController *)vc;
- (UIView *)detailContainer;
- (void)setDetailContainer:(UIView *)view;
- (NSString *)currentTitle;
- (void)setCurrentTitle:(NSString *)title;
- (NSArray<YMSettingsItem *> *)currentItems;
- (void)setCurrentItems:(NSArray<YMSettingsItem *> *)items;
- (NSInteger)currentKind;
- (void)setCurrentKind:(NSInteger)kind;
- (NSString *)searchQuery;
- (void)setSearchQuery:(NSString *)query;
- (UIView *)sidebarPane;
- (void)setSidebarPane:(UIView *)view;
- (UIView *)detailPane;
- (void)setDetailPane:(UIView *)view;
- (UIView *)separatorView;
- (void)setSeparatorView:(UIView *)view;
@end

#pragma mark - Associated state

static const void *kYMSplitSidebarItemsKey = &kYMSplitSidebarItemsKey;
static const void *kYMSplitSidebarVCKey = &kYMSplitSidebarVCKey;
static const void *kYMSplitResultsVCKey = &kYMSplitResultsVCKey;
static const void *kYMSplitDetailNavKey = &kYMSplitDetailNavKey;
static const void *kYMSplitGroupRootKey = &kYMSplitGroupRootKey;
static const void *kYMSplitDetailContainerKey = &kYMSplitDetailContainerKey;
static const void *kYMSplitCurrentTitleKey = &kYMSplitCurrentTitleKey;
static const void *kYMSplitCurrentItemsKey = &kYMSplitCurrentItemsKey;
static const void *kYMSplitCurrentKindKey = &kYMSplitCurrentKindKey;
static const void *kYMSplitSearchQueryKey = &kYMSplitSearchQueryKey;
static const void *kYMSplitSidebarPaneKey = &kYMSplitSidebarPaneKey;
static const void *kYMSplitDetailPaneKey = &kYMSplitDetailPaneKey;
static const void *kYMSplitSeparatorKey = &kYMSplitSeparatorKey;

@implementation YMSplitSettingsViewController

#define YMSplitGetter(name, type, key) \
    - (type)name { return objc_getAssociatedObject(self, key); }
#define YMSplitSetter(name, type, key) \
    - (void)set##name:(type)value { objc_setAssociatedObject(self, key, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

YMSplitGetter(sidebarItems, NSArray<YMSettingsItem *> *, kYMSplitSidebarItemsKey)
YMSplitSetter(SidebarItems, NSArray<YMSettingsItem *> *, kYMSplitSidebarItemsKey)
YMSplitGetter(sidebarVC, YMSubSettingsViewController *, kYMSplitSidebarVCKey)
YMSplitSetter(SidebarVC, YMSubSettingsViewController *, kYMSplitSidebarVCKey)
YMSplitGetter(resultsVC, YMSubSettingsViewController *, kYMSplitResultsVCKey)
YMSplitSetter(ResultsVC, YMSubSettingsViewController *, kYMSplitResultsVCKey)
YMSplitGetter(detailNav, UINavigationController *, kYMSplitDetailNavKey)
YMSplitSetter(DetailNav, UINavigationController *, kYMSplitDetailNavKey)
YMSplitGetter(groupRootVC, UIViewController *, kYMSplitGroupRootKey)
YMSplitSetter(GroupRootVC, UIViewController *, kYMSplitGroupRootKey)
YMSplitGetter(detailContainer, UIView *, kYMSplitDetailContainerKey)
YMSplitSetter(DetailContainer, UIView *, kYMSplitDetailContainerKey)
YMSplitGetter(currentTitle, NSString *, kYMSplitCurrentTitleKey)
YMSplitSetter(CurrentTitle, NSString *, kYMSplitCurrentTitleKey)
YMSplitGetter(currentItems, NSArray<YMSettingsItem *> *, kYMSplitCurrentItemsKey)
YMSplitSetter(CurrentItems, NSArray<YMSettingsItem *> *, kYMSplitCurrentItemsKey)
YMSplitGetter(sidebarPane, UIView *, kYMSplitSidebarPaneKey)
YMSplitSetter(SidebarPane, UIView *, kYMSplitSidebarPaneKey)
YMSplitGetter(detailPane, UIView *, kYMSplitDetailPaneKey)
YMSplitSetter(DetailPane, UIView *, kYMSplitDetailPaneKey)
YMSplitGetter(separatorView, UIView *, kYMSplitSeparatorKey)
YMSplitSetter(SeparatorView, UIView *, kYMSplitSeparatorKey)

#undef YMSplitGetter
#undef YMSplitSetter

- (NSInteger)currentKind {
    NSNumber *kind = objc_getAssociatedObject(self, kYMSplitCurrentKindKey);
    return kind ? kind.integerValue : YMSubmenuKindSettings;
}
- (void)setCurrentKind:(NSInteger)kind {
    objc_setAssociatedObject(self, kYMSplitCurrentKindKey, @(kind), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSString *)searchQuery {
    return objc_getAssociatedObject(self, kYMSplitSearchQueryKey) ?: @"";
}
- (void)setSearchQuery:(NSString *)query {
    objc_setAssociatedObject(self, kYMSplitSearchQueryKey, query ?: @"", OBJC_ASSOCIATION_COPY_NONATOMIC);
}

#pragma mark - Colors

- (UIColor *)ymBackgroundColor {
    return (self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark)
        ? [%c(YTColor) black3]
        : [UIColor systemBackgroundColor];
}

#pragma mark - Layout

- (void)viewDidLoad {
    [super viewDidLoad];

    // Page title in the settings navigation bar (next to the close button).
    self.title = @"YouMod";

    UIColor *bg = [self ymBackgroundColor];
    self.view.backgroundColor = bg;

    // Left pane: fixed-width sidebar with the home rows.
    UIView *sidebarPane = [[UIView alloc] init];
    sidebarPane.translatesAutoresizingMaskIntoConstraints = NO;
    sidebarPane.backgroundColor = bg;
    [self.view addSubview:sidebarPane];
    self.sidebarPane = sidebarPane;

    // Hairline divider between the panes.
    UIView *separator = [[UIView alloc] init];
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    separator.backgroundColor = [UIColor separatorColor];
    [self.view addSubview:separator];
    self.separatorView = separator;

    // Right pane: the selected group's page (or the search results).
    UIView *detailPane = [[UIView alloc] init];
    detailPane.translatesAutoresizingMaskIntoConstraints = NO;
    detailPane.backgroundColor = bg;
    [self.view addSubview:detailPane];
    self.detailPane = detailPane;

    UIView *detailContainer = [[UIView alloc] init];
    detailContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [detailPane addSubview:detailContainer];
    self.detailContainer = detailContainer;
    [NSLayoutConstraint activateConstraints:@[
        [sidebarPane.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [sidebarPane.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [sidebarPane.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [sidebarPane.widthAnchor constraintEqualToConstant:380],

        [separator.leadingAnchor constraintEqualToAnchor:sidebarPane.trailingAnchor],
        [separator.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [separator.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [separator.widthAnchor constraintEqualToConstant:1.0 / UIScreen.mainScreen.scale],

        [detailPane.leadingAnchor constraintEqualToAnchor:separator.trailingAnchor],
        [detailPane.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [detailPane.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [detailPane.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [detailContainer.topAnchor constraintEqualToAnchor:detailPane.topAnchor],
        [detailContainer.leadingAnchor constraintEqualToAnchor:detailPane.leadingAnchor],
        [detailContainer.trailingAnchor constraintEqualToAnchor:detailPane.trailingAnchor],
        [detailContainer.bottomAnchor constraintEqualToAnchor:detailPane.bottomAnchor],
    ]];

    // The detail pane owns its navigation stack: pages opened from a group
    // (Manage tabs, Manage overlay buttons, …) push inside this pane — the
    // sidebar and split layout stay visible. The pane's bar (back button +
    // page title) appears only above pushed pages (see the delegate below).
    UINavigationController *detailNav = [[UINavigationController alloc] init];
    detailNav.delegate = self;
    BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    UINavigationBarAppearance *barAppearance = YMNavBarAppearance(bg, dark ? [UIColor whiteColor] : [UIColor labelColor]);
    detailNav.navigationBar.standardAppearance = barAppearance;
    detailNav.navigationBar.scrollEdgeAppearance = barAppearance;
    detailNav.navigationBar.compactAppearance = barAppearance;
    detailNav.navigationBar.tintColor = dark ? [UIColor whiteColor] : [UIColor labelColor];
    [self embedChild:detailNav in:detailContainer];
    self.detailNav = detailNav;

    // Sidebar content: the home rows as an embedded settings page whose group
    // taps and search text are routed here instead of pushed/filtered there.
    YMSubSettingsViewController *sidebar = (YMSubSettingsViewController *)YMNewSubSettings(nil, self.sidebarItems);
    sidebar.showsVersionFooter = YES;
    __weak typeof(self) weakSelf = self;
    sidebar.groupHandler = ^BOOL(NSString *title, NSArray<YMSettingsItem *> *items, NSInteger kind) {
        [weakSelf selectGroup:title items:items kind:kind];
        return YES;
    };
    sidebar.searchTextHandler = ^(NSString *text) {
        [weakSelf searchTextChanged:text];
    };
    [self embedChild:sidebar in:sidebarPane];
    self.sidebarVC = sidebar;

    // Open the first section by default.
    for (YMSettingsItem *item in self.sidebarItems) {
        if (item.submenuItems.count > 0 || item.submenuKind == YMSubmenuKindSponsorBlock) {
            [self selectGroup:item.title items:item.submenuItems kind:item.submenuKind];
            break;
        }
    }
}

// Adds a settings page as a child filling the given pane.
- (void)embedChild:(UIViewController *)child in:(UIView *)pane {
    [self addChildViewController:child];
    [pane addSubview:child.view];
    child.view.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [child.view.topAnchor constraintEqualToAnchor:pane.topAnchor],
        [child.view.leadingAnchor constraintEqualToAnchor:pane.leadingAnchor],
        [child.view.trailingAnchor constraintEqualToAnchor:pane.trailingAnchor],
        [child.view.bottomAnchor constraintEqualToAnchor:pane.bottomAnchor],
    ]];
    [child didMoveToParentViewController:self];
}

// Swaps the detail pane's page (resets the pane's stack: switching sections or
// search results starts fresh at the new page).
- (void)showDetailChild:(UIViewController *)child {
    UINavigationController *nav = self.detailNav;
    if (!nav) return;
    if (child && nav.viewControllers.count == 1 && nav.topViewController == child) return;
    [nav setViewControllers:child ? @[child] : @[] animated:NO];
}

// Pages opened from inside a group push into the detail pane's own stack; the
// pane's bar (‹ back + page title) shows only above those pushed pages — at the
// root (a group's page) the pane starts at the very top with its search bar.
// The back button is chevron-only so the group's name never shows in the pane.
- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    BOOL isRoot = navigationController.viewControllers.firstObject == viewController;
    [navigationController setNavigationBarHidden:isRoot animated:animated];
    if (!isRoot) {
        viewController.navigationItem.backButtonDisplayMode = UINavigationItemBackButtonDisplayModeMinimal;
    }
}

#pragma mark - Selection

// A sidebar row (or a global search result) picked a group: clear any search and
// show the group's page in the detail pane. Tapping the group you're already in
// animates back to its main page (pop to root) instead of resetting it.
- (void)selectGroup:(NSString *)title items:(NSArray<YMSettingsItem *> *)items kind:(NSInteger)kind {
    if (!title) return;
    UINavigationController *nav = self.detailNav;
    BOOL sameGroup = [title isEqualToString:self.currentTitle] && kind == self.currentKind;
    BOOL groupRootIsShowing = nav && nav.viewControllers.firstObject == self.groupRootVC;

    self.searchQuery = @"";
    YMSubSettingsViewController *sidebar = self.sidebarVC;
    sidebar.selectedGroupTitle = title;
    sidebar.pageFilter = @"";
    if (sidebar.searchBar.text.length > 0) sidebar.searchBar.text = @"";
    [sidebar.tableView reloadData];

    if (sameGroup && groupRootIsShowing) {
        // E.g. in "Manage overlay buttons" (pushed above the Player page) and the
        // Player row is tapped: slide back to the group's main settings page.
        if (nav.viewControllers.count > 1) [nav popToRootViewControllerAnimated:YES];
        return;
    }

    self.currentTitle = title;
    self.currentItems = items;
    self.currentKind = kind;
    [self showCurrentGroup];
}

- (void)showCurrentGroup {
    NSString *title = self.currentTitle;
    if (!title) return;
    UIViewController *child;
    if (self.currentKind == YMSubmenuKindSponsorBlock) {
        child = YMNewSponsorBlockSettings();
    } else {
        child = YMNewSubSettings(title, self.currentItems);
    }
    self.groupRootVC = child;
    [self showDetailChild:child];
}

// Sidebar search text changed: show global search results in the detail pane
// (every registered settings group), or the current group again when cleared.
- (void)searchTextChanged:(NSString *)text {
    self.searchQuery = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] ?: @"";
    if (self.searchQuery.length == 0) {
        [self showCurrentGroup];
        return;
    }
    [self showSearchResults];
}

- (void)showSearchResults {
    YMSubSettingsViewController *results = self.resultsVC;
    if (!results) {
        results = (YMSubSettingsViewController *)YMNewSubSettings(nil, @[]);
        results.globalSearch = YES;
        results.hideSearchBar = YES; // the query comes from the sidebar search bar
        __weak typeof(self) weakSelf = self;
        results.groupHandler = ^BOOL(NSString *title, NSArray<YMSettingsItem *> *items, NSInteger kind) {
            // Tapping a result enters its group (and clears the search).
            [weakSelf selectGroup:title items:items kind:kind];
            return YES;
        };
        self.resultsVC = results;
    }
    results.pageFilter = self.searchQuery;
    [results updateGlobalSearchResults];
    [self showDetailChild:results];
    [results.tableView reloadData];
}

#pragma mark - Theme

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle) {
        YMAnimateThemeChange(self.view, ^{
            UIColor *bg = [self ymBackgroundColor];
            BOOL dark = self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
            self.view.backgroundColor = bg;
            self.sidebarPane.backgroundColor = bg;
            self.detailPane.backgroundColor = bg;
            self.separatorView.backgroundColor = [UIColor separatorColor];

            UINavigationBar *bar = self.detailNav.navigationBar;
            UINavigationBarAppearance *appearance = YMNavBarAppearance(bg, dark ? [UIColor whiteColor] : [UIColor labelColor]);
            bar.standardAppearance = appearance;
            bar.scrollEdgeAppearance = appearance;
            bar.compactAppearance = appearance;
            bar.tintColor = dark ? [UIColor whiteColor] : [UIColor labelColor];
        });
    }
}

@end

#pragma mark - Entry Point

// Builds the iPad split settings page without presenting it (sidebarItems = the
// home rows). Presented by Settings.x on iPad hardware only.
UIViewController *YMNewSplitSettings(NSArray<YMSettingsItem *> *sidebarItems) {
    YMSplitSettingsViewController *vc = [[YMSplitSettingsViewController alloc] init];
    vc.sidebarItems = sidebarItems;
    return vc;
}

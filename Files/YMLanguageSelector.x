#import "Headers.h"

// Ordered preferred-language lists (audio/caption pickers) saved as codes.

@implementation YMLanguageStore

// Moves the old single-language picker index into the code list once.
+ (void)migrateLegacyKeys {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSArray<NSString *> *values = [YMHelpers allSystemLanguageValues];
        NSDictionary<NSString *, NSString *> *legacyKeys = @{
            AudioTrackLangs: @"YouModAudioTrackLangIndex",
            CaptionTrackLangs: @"YouModCaptionTrackLangIndex"
        };
        [legacyKeys enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *oldKey, BOOL *stop) {
            if ([defaults objectForKey:key] != nil || [defaults objectForKey:oldKey] == nil) return;
            NSInteger index = [defaults integerForKey:oldKey];
            if (index >= 0 && index < (NSInteger)values.count) [defaults setObject:@[values[index]] forKey:key];
        }];
    });
}

+ (NSArray<NSString *> *)codesForKey:(NSString *)key {
    [self migrateLegacyKeys];
    // Unset keys default to English; an explicitly emptied list stays empty.
    return [[NSUserDefaults standardUserDefaults] arrayForKey:key] ?: @[@"en"];
}

+ (void)saveCodes:(NSArray<NSString *> *)codes forKey:(NSString *)key {
    [[NSUserDefaults standardUserDefaults] setObject:codes forKey:key];
}

+ (NSArray<NSString *> *)namesForCodes:(NSArray<NSString *> *)codes {
    NSArray<NSString *> *titles = [YMHelpers allSystemLanguageTitles];
    NSArray<NSString *> *values = [YMHelpers allSystemLanguageValues];
    NSMutableArray<NSString *> *names = [NSMutableArray arrayWithCapacity:codes.count];
    for (NSString *code in codes) {
        NSUInteger index = [values indexOfObject:code];
        [names addObject:index == NSNotFound ? code : titles[index]];
    }
    return names;
}

+ (NSString *)summaryForKey:(NSString *)key {
    return [[self namesForCodes:[self codesForKey:key]] componentsJoinedByString:@", "];
}

@end

#pragma mark - Bottom card presentation

@implementation YMBottomCardPresentationController

// Anchors the card to the bottom edge of the screen.
- (CGRect)frameOfPresentedViewInContainerView {
    CGRect bounds = self.containerView.bounds;
    CGSize size = self.presentedViewController.preferredContentSize;
    // Full screen width on iPhone is intentional; iPad keeps side margins.
    CGFloat width = MIN(size.width, bounds.size.width);
    CGFloat height = MIN(size.height, bounds.size.height - 40);
    return CGRectMake((bounds.size.width - width) / 2, bounds.size.height - height, width, height);
}

- (void)containerViewWillLayoutSubviews {
    [super containerViewWillLayoutSubviews];
    self.dimmingView.frame = self.containerView.bounds;
    // Setting frame with a non-identity transform is undefined (causes flashes):
    // park the keyboard lift aside, size the card, then put it back.
    CGAffineTransform lift = self.presentedView.transform;
    self.presentedView.transform = CGAffineTransformIdentity;
    self.presentedView.frame = [self frameOfPresentedViewInContainerView];
    self.presentedView.transform = lift;
}

- (void)presentationTransitionWillBegin {
    UIView *container = self.containerView;
    self.dimmingView = [[UIView alloc] initWithFrame:container.bounds];
    self.dimmingView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
    self.dimmingView.alpha = 0;
    [self.dimmingView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissTapped)]];
    [container insertSubview:self.dimmingView atIndex:0];

    // Bottom sheet look: rounded top corners only.
    self.presentedView.layer.cornerRadius = 16;
    self.presentedView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    self.presentedView.clipsToBounds = YES;

    // Drag down from the card body to dismiss, like a sheet.
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDismissPan:)];
    pan.delegate = self;
    [self.presentedView addGestureRecognizer:pan];

    [self.presentedViewController.transitionCoordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        self.dimmingView.alpha = 1;
    } completion:nil];
}

- (void)dismissalTransitionWillBegin {
    [self.presentedViewController.transitionCoordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        self.dimmingView.alpha = 0;
    } completion:nil];
}

- (void)dismissTapped {
    // A sheet can consume the tap (search sheet hides its keyboard first).
    if ([self.presentedViewController conformsToProtocol:@protocol(YMBottomCardTapHandler)] &&
        [(id<YMBottomCardTapHandler>)self.presentedViewController bottomCardConsumeBackdropTap]) return;
    [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Drag to dismiss

- (void)handleDismissPan:(UIPanGestureRecognizer *)pan {
    UIView *card = self.presentedView;
    CGFloat translation = [pan translationInView:self.containerView].y;
    switch (pan.state) {
        case UIGestureRecognizerStateBegan:
            self.dragStartTransform = card.transform;
            break;
        case UIGestureRecognizerStateChanged: {
            CGFloat offset = MAX(0, translation); // down only
            card.transform = CGAffineTransformTranslate(self.dragStartTransform, 0, offset);
            break;
        }
        case UIGestureRecognizerStateEnded: {
            CGFloat velocity = [pan velocityInView:self.containerView].y;
            BOOL dismiss = translation > card.bounds.size.height / 4 || velocity > 800;
            if (dismiss) {
                [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
            } else {
                [UIView animateWithDuration:0.2 animations:^{
                    card.transform = self.dragStartTransform;
                }];
            }
            break;
        }
        default:
            [UIView animateWithDuration:0.2 animations:^{
                card.transform = self.dragStartTransform;
            }];
            break;
    }
}

// The pan must not fight the table's own gestures (scroll, swipe delete, drag reorder).
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gestureRecognizer;
    CGPoint velocity = [pan velocityInView:self.presentedView];
    // Horizontal drags stay with swipe-to-delete.
    if (fabs(velocity.y) <= fabs(velocity.x)) return NO;
    UIView *view = [self.presentedView hitTest:[pan locationInView:self.presentedView] withEvent:nil];
    while (view && view != self.presentedView) {
        if ([view isKindOfClass:UIScrollView.class]) {
            UIScrollView *scroll = (UIScrollView *)view;
            // A scrolling list keeps its gestures until it rests at the top.
            return velocity.y > 0 && scroll.contentOffset.y <= -scroll.adjustedContentInset.top + 0.5;
        }
        view = view.superview;
    }
    return YES;
}

// Scroll pans wait for the dismiss pan, so top-of-list drags move the card.
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return [otherGestureRecognizer isKindOfClass:UIPanGestureRecognizer.class]
        && [otherGestureRecognizer.view isKindOfClass:UIScrollView.class];
}

// The dismiss pan waits for the reorder long-press: holding still reorders rows,
// a quick swipe fails the long-press and drags the card instead.
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return [otherGestureRecognizer isKindOfClass:UILongPressGestureRecognizer.class];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return NO;
}

@end

@implementation YMBottomCardAnimator

- (instancetype)initWithPresenting:(BOOL)presenting {
    self = [super init];
    if (self) _presenting = presenting;
    return self;
}

- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext {
    return 0.15;
}

// Slide up from below the screen on present, back down on dismiss.
- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    UIView *container = transitionContext.containerView;
    if (self.presenting) {
        UIView *toView = [transitionContext viewForKey:UITransitionContextToViewKey];
        UIViewController *toVC = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
        [container addSubview:toView];
        toView.frame = [transitionContext finalFrameForViewController:toVC];
        toView.transform = CGAffineTransformMakeTranslation(0, container.bounds.size.height - toView.frame.origin.y);
        [UIView animateWithDuration:[self transitionDuration:transitionContext] delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            toView.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            [transitionContext completeTransition:YES];
        }];
    } else {
        UIView *fromView = [transitionContext viewForKey:UITransitionContextFromViewKey];
        // Compose with the current transform (keyboard lift / active drag) instead
        // of replacing it, so the exit starts exactly where the card is.
        CGFloat exit = container.bounds.size.height - fromView.frame.origin.y;
        CGAffineTransform target = CGAffineTransformTranslate(fromView.transform, 0, exit);
        [UIView animateWithDuration:[self transitionDuration:transitionContext] delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            fromView.transform = target;
        } completion:^(BOOL finished) {
            [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
        }];
    }
}

@end

@implementation YMBottomCardTransitioning

+ (instancetype)shared {
    static YMBottomCardTransitioning *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (UIPresentationController *)presentationControllerForPresentedViewController:(UIViewController *)presented presentingViewController:(UIViewController *)presenting sourceViewController:(UIViewController *)source {
    return [[YMBottomCardPresentationController alloc] initWithPresentedViewController:presented presentingViewController:presenting];
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source {
    return [[YMBottomCardAnimator alloc] initWithPresenting:YES];
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
    return [[YMBottomCardAnimator alloc] initWithPresenting:NO];
}

@end

#pragma mark - Selected languages sheet

@implementation YMLanguageListViewController

- (instancetype)initWithDefaultsKey:(NSString *)key title:(NSString *)title {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _defaultsKey = [key copy];
        _editorTitle = [title copy];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    // Small grabber pill up top, like a bottom sheet card.
    UIView *grabber = [[UIView alloc] init];
    grabber.translatesAutoresizingMaskIntoConstraints = NO;
    grabber.backgroundColor = [UIColor tertiaryLabelColor];
    grabber.layer.cornerRadius = 2.5;
    [self.view addSubview:grabber];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = self.editorTitle;
    titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = [UIColor labelColor];
    [self.view addSubview:titleLabel];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.tableFooterView = [UIView new];
    UILongPressGestureRecognizer *reorder = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleReorder:)];
    reorder.minimumPressDuration = 0.2; // faster pickup than the 0.5s default
    [self.tableView addGestureRecognizer:reorder];
    [self.view addSubview:self.tableView];

    UIButton *addButton = [UIButton buttonWithType:UIButtonTypeSystem];
    addButton.translatesAutoresizingMaskIntoConstraints = NO;
    [addButton setTitle:LOC(@"ADD_LANGUAGE") forState:UIControlStateNormal];
    [addButton setTitleColor:[YMHelpers accentColor] forState:UIControlStateNormal];
    addButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    addButton.backgroundColor = [UIColor secondarySystemBackgroundColor];
    addButton.layer.cornerRadius = 14;
    [addButton addTarget:self action:@selector(addLanguageTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:addButton];

    [NSLayoutConstraint activateConstraints:@[
        [grabber.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:8],
        [grabber.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [grabber.widthAnchor constraintEqualToConstant:36],
        [grabber.heightAnchor constraintEqualToConstant:5],

        [titleLabel.topAnchor constraintEqualToAnchor:grabber.bottomAnchor constant:8],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],

        [self.tableView.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:16],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [addButton.topAnchor constraintEqualToAnchor:self.tableView.bottomAnchor constant:12],
        [addButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [addButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [addButton.heightAnchor constraintEqualToConstant:52],
        [addButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16]
    ]];

    [self reloadCodes];
}

- (void)presentFrom:(UIViewController *)presenter {
    // Bottom card sliding up from below the screen edge.
    BOOL isPad = [YMHelpers isPad];
    CGFloat width = isPad ? 420 : [UIScreen mainScreen].bounds.size.width;
    self.preferredContentSize = CGSizeMake(width, isPad ? 560 : 480);
    self.modalPresentationStyle = UIModalPresentationCustom;
    self.transitioningDelegate = [YMBottomCardTransitioning shared];
    [presenter presentViewController:self animated:YES completion:nil];
}

- (void)reloadCodes {
    self.codes = [[YMLanguageStore codesForKey:self.defaultsKey] mutableCopy];
    self.names = [[YMLanguageStore namesForCodes:self.codes] mutableCopy];
    [self.tableView reloadData];
    if (self.onChange) self.onChange();
}

- (void)addLanguageTapped {
    YMAddLanguageViewController *picker = [[YMAddLanguageViewController alloc] initWithDefaultsKey:self.defaultsKey];
    __weak YMLanguageListViewController *weakSelf = self;
    picker.onChange = ^{ [weakSelf reloadCodes]; };
    [picker presentFrom:self];
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.codes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.text = self.names[indexPath.row];
    cell.textLabel.textColor = [UIColor labelColor];
    cell.textLabel.font = [UIFont systemFontOfSize:16];
    // Drag affordance: long-press anywhere on the row to reorder.
    UIImageView *grip = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"line.3.horizontal"]];
    grip.tintColor = [UIColor tertiaryLabelColor];
    cell.accessoryView = grip;
    return cell;
}

#pragma mark - Swipe to delete (trash icon)

// Removes one row and persists the list; shared by the swipe action and the
// legacy editing-style path. The last language must stay: the list is the
// fallback for track selection, so it never empties through this UI.
- (void)deleteRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.codes.count <= 1) return;
    [self.codes removeObjectAtIndex:indexPath.row];
    [self.names removeObjectAtIndex:indexPath.row];
    [YMLanguageStore saveCodes:self.codes forKey:self.defaultsKey];
    // System row-delete animation instead of a full reload.
    [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    if (self.onChange) self.onChange();
}

// The delete button is a trash icon instead of the localized "Delete" label.
// Leaving the title nil keeps the button icon-only. With one language left
// there is no swipe at all, so the row cannot be deleted.
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.codes.count <= 1) return [UISwipeActionsConfiguration configurationWithActions:@[]];
    __weak YMLanguageListViewController *weakSelf = self;
    UIContextualAction *delete = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:nil handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        [weakSelf deleteRowAtIndexPath:indexPath];
        completionHandler(YES);
    }];
    delete.image = [[UIImage systemImageNamed:@"trash"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UISwipeActionsConfiguration *configuration = [UISwipeActionsConfiguration configurationWithActions:@[delete]];
    // A full swipe must not delete right away: the icon still needs a tap,
    // matching the old "Delete" button behavior.
    configuration.performsFirstActionWithFullSwipe = NO;
    return configuration;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.codes.count > 1 ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    [self deleteRowAtIndexPath:indexPath];
}

#pragma mark - Reordering (manual drag: UITableView has no interactive-movement API)

- (void)handleReorder:(UILongPressGestureRecognizer *)gesture {
    CGPoint location = [gesture locationInView:self.tableView];
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan: {
            NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
            if (!indexPath) return;
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
            self.dragIndexPath = indexPath;
            self.dragOriginalCodes = [self.codes copy];
            self.dragOriginalNames = [self.names copy];
            self.dragStartPoint = [gesture locationInView:self.view];
            self.dragStartFrame = [self.tableView convertRect:cell.frame toView:self.view];
            self.dragSnapshot = [cell snapshotViewAfterScreenUpdates:NO];
            self.dragSnapshot.frame = self.dragStartFrame;
            // Default system backdrop under the lifted row (cells are clear-backed).
            self.dragSnapshot.backgroundColor = [UIColor systemBackgroundColor];
            self.dragSnapshot.layer.cornerRadius = 12;
            self.dragSnapshot.layer.shadowColor = [UIColor blackColor].CGColor;
            self.dragSnapshot.layer.shadowOpacity = 0.25;
            self.dragSnapshot.layer.shadowRadius = 8;
            self.dragSnapshot.layer.shadowOffset = CGSizeMake(0, 4);
            [self.view addSubview:self.dragSnapshot];
            cell.hidden = YES;
            // Lift like the system reorder ("Manage overlay buttons"): the row
            // grows slightly as it leaves the list.
            [UIView animateWithDuration:0.15 animations:^{
                self.dragSnapshot.transform = CGAffineTransformMakeScale(1.03, 1.03);
            }];
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (!self.dragIndexPath) return;
            CGPoint point = [gesture locationInView:self.view];
            // Center-driven so the lift scale doesn't fight a frame assignment.
            self.dragSnapshot.center = CGPointMake(CGRectGetMidX(self.dragStartFrame) + point.x - self.dragStartPoint.x,
                                                  CGRectGetMidY(self.dragStartFrame) + point.y - self.dragStartPoint.y);
            NSIndexPath *target = [self.tableView indexPathForRowAtPoint:location];
            if (target && ![target isEqual:self.dragIndexPath]) {
                [self moveCodeFrom:self.dragIndexPath to:target];
                [self.tableView beginUpdates];
                [self.tableView moveRowAtIndexPath:self.dragIndexPath toIndexPath:target];
                [self.tableView endUpdates];
                self.dragIndexPath = target;
            }
            break;
        }
        case UIGestureRecognizerStateEnded:
            if (self.dragIndexPath) [self finishDragRestoringOriginal:NO];
            break;
        default:
            if (self.dragIndexPath) [self finishDragRestoringOriginal:YES];
            break;
    }
}

// Model-side row move, one place for both code and display names.
- (void)moveCodeFrom:(NSIndexPath *)from to:(NSIndexPath *)to {
    NSString *code = self.codes[from.row];
    [self.codes removeObjectAtIndex:from.row];
    [self.codes insertObject:code atIndex:to.row];
    NSString *name = self.names[from.row];
    [self.names removeObjectAtIndex:from.row];
    [self.names insertObject:name atIndex:to.row];
}

- (void)finishDragRestoringOriginal:(BOOL)restore {
    BOOL restoring = restore && self.dragOriginalCodes != nil;
    if (restoring) {
        self.codes = [self.dragOriginalCodes mutableCopy];
        self.names = [self.dragOriginalNames mutableCopy];
    } else {
        [YMLanguageStore saveCodes:self.codes forKey:self.defaultsKey];
    }
    NSIndexPath *droppedAt = self.dragIndexPath;
    self.dragIndexPath = nil;
    self.dragOriginalCodes = nil;
    self.dragOriginalNames = nil;
    UIView *snapshot = self.dragSnapshot;
    self.dragSnapshot = nil;
    if (self.onChange) self.onChange();
    if (!snapshot) return;

    // Land the lifted row in its slot (or slide it back where the drag started)
    // instead of fading it out mid-air — the settle the system reorder does in
    // "Manage overlay buttons". The hidden dragged cell is rebuilt underneath
    // first, so the snapshot settles right onto it.
    CGRect targetFrame = self.dragStartFrame;
    if (!restoring && droppedAt) {
        targetFrame = [self.tableView convertRect:[self.tableView rectForRowAtIndexPath:droppedAt] toView:self.view];
    }
    [UIView performWithoutAnimation:^{ [self.tableView reloadData]; }];
    [UIView animateWithDuration:0.25
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         snapshot.transform = CGAffineTransformIdentity;
                         snapshot.center = CGPointMake(CGRectGetMidX(targetFrame), CGRectGetMidY(targetFrame));
                     }
                     completion:^(BOOL finished) {
                         [snapshot removeFromSuperview];
                     }];
}

@end

#pragma mark - Add language sheet

@implementation YMAddLanguageViewController

- (instancetype)initWithDefaultsKey:(NSString *)key {
    self = [super initWithNibName:nil bundle:nil];
    if (self) _defaultsKey = [key copy];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.allTitles = [YMHelpers allSystemLanguageTitles];
    self.allValues = [YMHelpers allSystemLanguageValues];
    self.filteredTitles = self.allTitles;
    self.filteredValues = self.allValues;

    // Small grabber pill up top, like a bottom sheet card.
    UIView *grabber = [[UIView alloc] init];
    grabber.translatesAutoresizingMaskIntoConstraints = NO;
    grabber.backgroundColor = [UIColor tertiaryLabelColor];
    grabber.layer.cornerRadius = 2.5;
    [self.view addSubview:grabber];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = LOC(@"ADD_LANGUAGE");
    titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.textColor = [UIColor labelColor];
    [self.view addSubview:titleLabel];

    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchBar.delegate = self;
    self.searchBar.placeholder = LOC(@"SEARCH");
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    [self.view addSubview:self.searchBar];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.tableFooterView = [UIView new];
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [grabber.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:8],
        [grabber.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [grabber.widthAnchor constraintEqualToConstant:36],
        [grabber.heightAnchor constraintEqualToConstant:5],

        [titleLabel.topAnchor constraintEqualToAnchor:grabber.bottomAnchor constant:8],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],

        [self.searchBar.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:8],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],

        [self.tableView.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboardWillChangeFrame:) name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

// Lift the bottom card above the keyboard while typing.
- (void)keyboardWillChangeFrame:(NSNotification *)note {
    CGRect keyboardFrame = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    // Measure the untransformed card: convertRect: includes the current lift,
    // and counting it again would re-animate to a wrong offset on every keystroke.
    CGFloat lift = self.view.transform.ty;
    CGRect screenFrame = CGRectOffset([self.view convertRect:self.view.bounds toView:nil], 0, -lift);
    CGFloat overlap = MAX(0, CGRectGetMaxY(screenFrame) - CGRectGetMinY(keyboardFrame));
    self.keyboardVisible = overlap > 0;
    CGFloat target = -overlap;
    if (target == lift) return; // keyboard didn't move: keep the card still
    NSTimeInterval duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    NSInteger curve = [note.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    [UIView animateWithDuration:duration delay:0 options:(curve << 16) animations:^{
        self.view.transform = CGAffineTransformMakeTranslation(0, target);
    } completion:nil];
}

// Backdrop tap hides the keyboard first; only a later tap dismisses the sheet.
- (BOOL)bottomCardConsumeBackdropTap {
    if (!self.keyboardVisible) return NO;
    [self.view endEditing:YES];
    return YES;
}

- (void)presentFrom:(UIViewController *)presenter {
    // Bottom card sliding up from below the screen edge.
    BOOL isPad = [YMHelpers isPad];
    CGFloat width = isPad ? 420 : [UIScreen mainScreen].bounds.size.width;
    self.preferredContentSize = CGSizeMake(width, isPad ? 560 : 480);
    self.modalPresentationStyle = UIModalPresentationCustom;
    self.transitioningDelegate = [YMBottomCardTransitioning shared];
    [presenter presentViewController:self animated:YES completion:nil];
}

#pragma mark - Search

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        self.filteredTitles = self.allTitles;
        self.filteredValues = self.allValues;
    } else {
        NSIndexSet *matches = [self.allTitles indexesOfObjectsPassingTest:^BOOL(NSString *title, NSUInteger idx, BOOL *stop) {
            return [title localizedCaseInsensitiveContainsString:searchText];
        }];
        self.filteredTitles = [self.allTitles objectsAtIndexes:matches];
        self.filteredValues = [self.allValues objectsAtIndexes:matches];
    }
    // No implicit animations: animated reloads on every keystroke flash the list.
    [UIView performWithoutAnimation:^{ [self.tableView reloadData]; }];
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.filteredTitles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.backgroundColor = [UIColor clearColor];
    cell.textLabel.text = self.filteredTitles[indexPath.row];
    cell.textLabel.textColor = [UIColor labelColor];
    cell.textLabel.font = [UIFont systemFontOfSize:16];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *code = self.filteredValues[indexPath.row];
    NSMutableArray<NSString *> *codes = [[YMLanguageStore codesForKey:self.defaultsKey] mutableCopy];
    if (![codes containsObject:code]) {
        [codes addObject:code];
        [YMLanguageStore saveCodes:codes forKey:self.defaultsKey];
        if (self.onChange) self.onChange();
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

#pragma mark - Settings row

YMSettingsItem *YMLanguagePickerRow(NSString *title, NSString *fallbackSubtitle, NSString *key) {
    NSString *summary = [YMLanguageStore summaryForKey:key];
    YMSettingsItem *item = [YMSettingsItem navActionWithTitle:title subtitle:summary.length > 0 ? summary : fallbackSubtitle action:nil];
    __weak YMSettingsItem *weakItem = item;
    item.action = ^(UIViewController *vc) {
        YMLanguageListViewController *list = [[YMLanguageListViewController alloc] initWithDefaultsKey:key title:title];
        list.onChange = ^{
            NSString *updated = [YMLanguageStore summaryForKey:key];
            weakItem.subtitle = updated.length > 0 ? updated : fallbackSubtitle;
            UITableView *table = [(YMSubSettingsViewController *)vc tableView];
            [table reloadData];
        };
        [list presentFrom:vc];
    };
    return item;
}

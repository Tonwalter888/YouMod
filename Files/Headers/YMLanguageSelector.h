#import "YMSettingsItem.h"

#pragma mark - Preferred-language selection (YMLanguageSelector.x)

// Saved language codes in priority order under AudioTrackLangs /
// CaptionTrackLangs, with a one-time migration from the legacy index keys.
@interface YMLanguageStore : NSObject
+ (NSArray<NSString *> *)codesForKey:(NSString *)key;
+ (void)saveCodes:(NSArray<NSString *> *)codes forKey:(NSString *)key;
// "English, Thai" for the settings row subtitle ("" when the list is empty).
+ (NSString *)summaryForKey:(NSString *)key;
@end

// A sheet can consume the backdrop tap (e.g. to hide the keyboard first).
@protocol YMBottomCardTapHandler <NSObject>
- (BOOL)bottomCardConsumeBackdropTap;
@end

// Bottom-anchored card presentation with a slide-up animation.
@interface YMBottomCardPresentationController : UIPresentationController <UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIView *dimmingView;
@property (nonatomic, assign) CGAffineTransform dragStartTransform;
- (void)dismissTapped;
- (void)handleDismissPan:(UIPanGestureRecognizer *)pan;
@end

@interface YMBottomCardAnimator : NSObject <UIViewControllerAnimatedTransitioning>
@property (nonatomic, assign, getter=isPresenting) BOOL presenting;
- (instancetype)initWithPresenting:(BOOL)presenting;
@end

@interface YMBottomCardTransitioning : NSObject <UIViewControllerTransitioningDelegate>
+ (instancetype)shared;
@end

// Sheet listing the saved languages: drag to reorder, swipe to delete (trash
// icon) and an "Add language" button opening YMAddLanguageViewController. The
// last remaining language cannot be deleted.
@interface YMLanguageListViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, copy) NSString *defaultsKey;
@property (nonatomic, copy) NSString *editorTitle;
@property (nonatomic, copy) void (^onChange)(void);
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray<NSString *> *codes;
@property (nonatomic, strong) NSMutableArray<NSString *> *names;
// Manual drag-reorder state (snapshot follows the finger).
@property (nonatomic, strong) NSIndexPath *dragIndexPath;
@property (nonatomic, strong) UIView *dragSnapshot;
@property (nonatomic, assign) CGPoint dragStartPoint;
@property (nonatomic, assign) CGRect dragStartFrame;
@property (nonatomic, strong) NSArray<NSString *> *dragOriginalCodes;
@property (nonatomic, strong) NSArray<NSString *> *dragOriginalNames;
- (instancetype)initWithDefaultsKey:(NSString *)key title:(NSString *)title;
- (void)presentFrom:(UIViewController *)presenter;
- (void)reloadCodes;
@end

// Sheet listing every language behind a search bar; tapping one adds it.
@interface YMAddLanguageViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, YMBottomCardTapHandler>
@property (nonatomic, copy) NSString *defaultsKey;
@property (nonatomic, copy) void (^onChange)(void);
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, assign) BOOL keyboardVisible;
@property (nonatomic, strong) NSArray<NSString *> *allTitles;
@property (nonatomic, strong) NSArray<NSString *> *allValues;
@property (nonatomic, strong) NSArray<NSString *> *filteredTitles;
@property (nonatomic, strong) NSArray<NSString *> *filteredValues;
- (instancetype)initWithDefaultsKey:(NSString *)key;
- (void)presentFrom:(UIViewController *)presenter;
// Lifts the card above the keyboard while the search bar is focused.
- (void)keyboardWillChangeFrame:(NSNotification *)note;
// Backdrop tap: hides the keyboard first, returns YES when consumed.
- (BOOL)bottomCardConsumeBackdropTap;
@end

// Settings row builder (YMLanguageSelector.x): title + selected-languages
// subtitle (fallbackSubtitle while the list is empty); opens the editor sheet.
extern YMSettingsItem *YMLanguagePickerRow(NSString *title, NSString *fallbackSubtitle, NSString *key);

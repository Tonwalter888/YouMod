#import "YTQTMButton.h"

@interface YTFirstTimeSignInView : UIView
- (YTQTMButton *)chooseAccountButton;
- (YTQTMButton *)alternateAccountButton;
@end

// Custom perferences logics
@interface YouModPrefsManager : NSObject <UIDocumentPickerDelegate>
+ (instancetype)sharedManager;
- (void)exportYouModSettingsFromVC:(UIViewController *)vc;
- (void)importYouModSettingsFromVC:(UIViewController *)vc;
- (void)restoreYouModDefaults;
@end

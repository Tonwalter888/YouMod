#import "Headers.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h> // For import

#define Prefix @"YouMod"

static NSBundle *YouModBundle() {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:Prefix ofType:@"bundle"];
        if (tweakBundlePath)
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        else
            bundle = [NSBundle bundleWithPath:[NSString stringWithFormat:PS_ROOT_PATH_NS(@"/Library/Application Support/%@.bundle"), Prefix]];
    });
    return bundle;
}

#define LOC(x) [YouModBundle() localizedStringForKey:x value:nil table:nil]

@implementation YouModPrefsManager

+ (instancetype)sharedManager {
    static YouModPrefsManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

// Import
- (void)importYouModSettingsFromVC:(UIViewController *)vc {
    NSArray<UTType *> *types = @[UTTypePropertyList, UTTypeData];

    // Modern constructor for iOS 14+
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
    picker.delegate = self;
    picker.modalPresentationStyle = UIModalPresentationFormSheet;

    // Ensure it looks right on iPad
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        picker.popoverPresentationController.sourceView = vc.view;
        picker.popoverPresentationController.sourceRect = CGRectMake(vc.view.bounds.size.width/2, vc.view.bounds.size.height/2, 0, 0);
        picker.popoverPresentationController.permittedArrowDirections = 0;
    }
    
    [vc presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *selectedFileURL = urls.firstObject;
    if (!selectedFileURL) return;
    NSDictionary *importedData = [NSDictionary dictionaryWithContentsOfURL:selectedFileURL];
    // Vaild plist check
    if (!importedData || ![importedData isKindOfClass:[NSDictionary class]]) {
        YTAlertView *alertView = [%c(YTAlertView) infoDialog];
        alertView.title = LOC(@"ERROR");
        alertView.subtitle = LOC(@"ERROR_INVALID_FILE");
        alertView.shouldDismissOnBackgroundTap = YES;
        [alertView show];
        return;
    }
    BOOL foundKeys = NO;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    // Remove old keys
    for (NSString *key in [defaults dictionaryRepresentation]) {
        if ([key hasPrefix:Prefix]) {
            [defaults removeObjectForKey:key];
        }
    }
    [defaults synchronize];
    // Set new key from file
    for (NSString *key in importedData) {
        if ([key hasPrefix:Prefix]) {
            [defaults setObject:importedData[key] forKey:key];
            foundKeys = YES;
        }
    }
    // Check if there's any YouMod key
    if (!foundKeys) {
        YTAlertView *alertView = [%c(YTAlertView) infoDialog];
        alertView.title = LOC(@"ERROR");
        alertView.subtitle = LOC(@"ERROR_NO_KEYS_IMPORT");
        alertView.shouldDismissOnBackgroundTap = YES;
        [alertView show];
        return;
    }
    [defaults synchronize];
    // Success Alert with Restart
    YTAlertView *alertView = [%c(YTAlertView) confirmationDialogWithAction:^{
        [[UIApplication sharedApplication] performSelector:@selector(suspend)];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            exit(0);
        });
    } actionTitle:LOC(@"YES")];
    alertView.title = LOC(@"IMPORT_DONE");
    alertView.subtitle = LOC(@"APPLY_DESC"); // "Restart required"
    alertView.shouldDismissOnBackgroundTap = YES;
    [alertView show];
}

// Export
- (void)exportYouModSettingsFromVC:(UIViewController *)vc {
    NSDictionary *allSettings = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    NSMutableDictionary *youModOnly = [NSMutableDictionary dictionary];
    for (NSString *key in allSettings) {
        if ([key hasPrefix:Prefix]) {
            youModOnly[key] = allSettings[key];
        }
    }
    if (youModOnly.count == 0) {
        YTAlertView *alertView = [%c(YTAlertView) infoDialog];
        alertView.title = LOC(@"ERROR");
        alertView.subtitle = LOC(@"ERROR_NO_KEYS_EXPORT");
        alertView.shouldDismissOnBackgroundTap = YES;
        [alertView show];
        return;
    }
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"YouMod_Preferences.plist"];
    NSURL *fileURL = [NSURL fileURLWithPath:tempPath];
    [youModOnly writeToURL:fileURL atomically:YES];

    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:@[fileURL] asCopy:YES];
    picker.modalPresentationStyle = UIModalPresentationFormSheet;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        picker.popoverPresentationController.sourceView = vc.view;
    }
    [vc presentViewController:picker animated:YES completion:nil];
}

// Reset
- (void)restoreYouModDefaults {
    YTAlertView *alertView = [%c(YTAlertView) confirmationDialogWithAction:^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        for (NSString *key in [defaults dictionaryRepresentation]) {
            if ([key hasPrefix:Prefix]) {
                [defaults removeObjectForKey:key];
            }
        }
        [defaults setBool:YES forKey:AutoClearCache];
        [defaults setBool:YES forKey:YTPremiumLogo];
        [defaults setBool:YES forKey:HideCastButtonNav];
        [defaults setBool:YES forKey:HideCastButtonPlayer];
        [defaults setBool:YES forKey:BackgroundPlayback];
        [defaults setBool:YES forKey:DisableHints];
        [defaults setInteger:1 forKey:GestureActivationArea];
        [defaults setInteger:1 forKey:LeftSideGesture];
        [defaults setInteger:2 forKey:RightSideGesture];
        [defaults setInteger:1 forKey:GestureHUDSize];
        [defaults synchronize];
        [[UIApplication sharedApplication] performSelector:@selector(suspend)];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            exit(0);
        });
    } actionTitle:LOC(@"YES")];
    alertView.title = LOC(@"WARNING");
    alertView.subtitle = LOC(@"RESETDEFAULT");
    alertView.shouldDismissOnBackgroundTap = YES;
    [alertView show];
}

@end

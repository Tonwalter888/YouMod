#import "Headers.h"

@implementation YMIconProvider

// respondsToSelector:: delhiIconsEnabled exists only on newer YouTube versions.
+ (BOOL)delhiIcons {
    return [%c(YTUIResources) respondsToSelector:@selector(delhiIconsEnabled)] && [%c(YTUIResources) delhiIconsEnabled];
}

+ (UIImage *)tabIcon:(NSString *)name selected:(BOOL)selected {
    static YTAssetLoader *loader = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loader = [[%c(YTAssetLoader) alloc] initWithBundle:[YMHelpers bundle]];
    });
    if (!loader || name.length == 0) return nil;
    NSString *folder = [self delhiIcons] ? @"new" : @"old";
    NSString *base = selected ? [NSString stringWithFormat:@"%@_selected", name] : name;
    return [loader imageNamed:[NSString stringWithFormat:@"icons/%@/%@", folder, base]];
}

+ (UIImage *)settingsIcon:(NSString *)name {
    return [self tabIcon:name selected:NO];
}

@end

@implementation YMHelpers

+ (NSBundle *)bundle {
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *tweakBundlePath = [[NSBundle mainBundle] pathForResource:@"YouMod" ofType:@"bundle"];
        if (tweakBundlePath) {
            bundle = [NSBundle bundleWithPath:tweakBundlePath];
        } else {
            bundle = [NSBundle bundleWithPath:jbroot(@"/Library/Application Support/YouMod.bundle")];
        }
    });
    return bundle;
}

+ (UIColor *)accentColor {
    return [UIColor colorWithRed:40.0 / 255.0 green:133.0 / 255.0 blue:255.0 / 255.0 alpha:1.0];
}

+ (UIImage *)ytIconImage:(NSInteger)iconType useCustomColor:(BOOL)useCustomColor customColor:(UIColor *)customColor {
    YTIIcon *icon = [%c(YTIIcon) new];
    icon.iconType = iconType;
    UIColor *targetColor = (useCustomColor && customColor) ? customColor : [UIColor labelColor];
    return [[icon iconImageWithColor:targetColor] imageWithTintColor:targetColor];
}

+ (UIImage *)symbolImageInCanvas:(NSString *)symbolName canvasSize:(CGFloat)canvasSize pointSize:(CGFloat)pointSize weight:(UIImageSymbolWeight)weight {
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:pointSize weight:weight];
    UIImage *symbol = [UIImage systemImageNamed:symbolName withConfiguration:config];
    if (!symbol) return nil;
    symbol = [symbol imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(canvasSize, canvasSize) format:format];
    UIImage *canvas = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGFloat width = symbol.size.width;
        CGFloat height = symbol.size.height;
        if (width <= 0 || height <= 0) return;
        CGFloat scale = MIN(canvasSize / width, canvasSize / height);
        CGSize fitted = CGSizeMake(width * scale, height * scale);
        [symbol drawInRect:CGRectMake((canvasSize - fitted.width) / 2.0, (canvasSize - fitted.height) / 2.0, fitted.width, fitted.height)];
    }];
    return [canvas imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

// Unique languages by code, display names sorted for pickers.
+ (NSArray *)allSystemLanguageTitles {
    NSMutableArray *titles = [NSMutableArray array];
    NSArray *allLocales = [%c(YTLanguages) languageList];
    NSMutableSet *seenLanguages = [NSMutableSet set];
    NSLocale *currentLocale = [NSLocale currentLocale];

    for (NSString *localeId in allLocales) {
        NSString *langCode = [NSLocale componentsFromLocaleIdentifier:localeId][NSLocaleLanguageCode];
        if (langCode && ![seenLanguages containsObject:langCode]) {
            [seenLanguages addObject:langCode];
            NSString *displayName = [currentLocale localizedStringForLocaleIdentifier:langCode];
            if (displayName) [titles addObject:displayName];
        }
    }
    return [titles sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

+ (NSArray *)allSystemLanguageValues {
    NSArray *allLocales = [%c(YTLanguages) languageList];
    NSLocale *currentLocale = [NSLocale currentLocale];
    NSMutableDictionary *titleToCodeMap = [NSMutableDictionary dictionary];
    for (NSString *localeId in allLocales) {
        NSString *langCode = [NSLocale componentsFromLocaleIdentifier:localeId][NSLocaleLanguageCode];
        if (langCode) {
            NSString *displayName = [currentLocale localizedStringForLocaleIdentifier:langCode];
            if (displayName) titleToCodeMap[displayName] = langCode;
        }
    }

    NSMutableArray *sortedCodes = [NSMutableArray array];
    for (NSString *title in [self allSystemLanguageTitles]) {
        [sortedCodes addObject:titleToCodeMap[title] ?: @"en"];
    }
    return [sortedCodes copy];
}

// Deliberately no activation-state filter: a key window in an inactive scene
// beats no window (matches old UIApplication.windows behavior).
+ (UIWindow *)keyWindow {
    UIWindow *keyWindow = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
        if (keyWindow) break;
    }
    return keyWindow;
}

+ (UIViewController *)topViewController:(UIViewController *)root {
    if (!root) {
        root = [self keyWindow].rootViewController;
    }
    while (root.presentedViewController) root = root.presentedViewController;
    if ([root isKindOfClass:UINavigationController.class])
        return [self topViewController:((UINavigationController *)root).topViewController];
    else if ([root isKindOfClass:UITabBarController.class])
        return [self topViewController:((UITabBarController *)root).selectedViewController];
    return root;
}

// respondsToSelector:: _mapkit_isDarkModeEnabled is an optional private helper.
+ (BOOL)isDarkMode:(UIView *)view {
    if ([view respondsToSelector:@selector(_mapkit_isDarkModeEnabled)]) return view._mapkit_isDarkModeEnabled;
    return view.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
}

+ (BOOL)isPad {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
}

+ (BOOL)isPadHardware {
    return [UIDevice.currentDevice.model isEqualToString:@"iPad"];
}

+ (void)configureSharePopover:(UIActivityViewController *)activityVC sourceView:(UIView *)sourceView {
    if ([self isPad] && activityVC) {
        UIView *targetView = sourceView ?: [self topViewController:nil].view;
        if (targetView) {
            activityVC.popoverPresentationController.sourceView = targetView;
            CGRect bounds = targetView.bounds;
            if (CGRectIsEmpty(bounds) && targetView.window) {
                bounds = targetView.window.bounds;
            }
            activityVC.popoverPresentationController.sourceRect = CGRectMake(bounds.size.width / 2, bounds.size.height, 0, 0);
            activityVC.popoverPresentationController.permittedArrowDirections = 0;
        }
    }
}

+ (NSString *)extractYouTubeVideoID:(NSString *)urlString {
    if (!urlString || urlString.length == 0) return nil;
    NSString *cleanString = [urlString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (cleanString.length == 11 && ![cleanString containsString:@"/"] && ![cleanString containsString:@"?"]) return cleanString;

    static NSRegularExpression *thumbRegex = nil; // thumbnail URLs: /vi/<id>/… or /vi_webp/<id>/…
    static NSRegularExpression *anyRegex = nil;   // fallback: v= | /shorts|live|clip/ | youtu.be/ | /vi…
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        thumbRegex = [NSRegularExpression regularExpressionWithPattern:@"\\/vi(?:_webp)?\\/([a-zA-Z0-9_-]{11})" options:NSRegularExpressionCaseInsensitive error:nil];
        anyRegex = [NSRegularExpression regularExpressionWithPattern:@"(?:v=|\\/(?:shorts|live|clip)\\/|youtu\\.be\\/|\\/vi(?:_webp)?\\/)([a-zA-Z0-9_-]{11})" options:NSRegularExpressionCaseInsensitive error:nil];
    });

    NSString *extractedID = nil;
    NSURL *url = [NSURL URLWithString:cleanString];
    if (url) {
        if ([url.host containsString:@"ytimg.com"]) {
            NSTextCheckingResult *hit = [thumbRegex firstMatchInString:url.path options:0 range:NSMakeRange(0, url.path.length)];
            if (hit && hit.numberOfRanges > 1) extractedID = [url.path substringWithRange:[hit rangeAtIndex:1]];
        } else if ([url.host containsString:@"youtu.be"]) {
            NSString *path = [url.path stringByReplacingOccurrencesOfString:@"/" withString:@""];
            if (path.length >= 11) extractedID = [path substringToIndex:11];
        } else if ([url.host containsString:@"youtube.com"]) {
            if ([url.path containsString:@"/shorts/"] || [url.path containsString:@"/live/"] || [url.path containsString:@"/clip/"]) {
                NSString *lastPath = [url.path lastPathComponent];
                if ([lastPath containsString:@"?"]) lastPath = [[lastPath componentsSeparatedByString:@"?"] firstObject];
                if (lastPath.length >= 11) extractedID = [lastPath substringToIndex:11];
            } else {
                NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
                for (NSURLQueryItem *item in components.queryItems) {
                    if ([item.name isEqualToString:@"v"] && item.value.length >= 11) {
                        extractedID = [item.value substringToIndex:11];
                        break;
                    }
                }
            }
        }
    }
    if (!extractedID) {
        NSTextCheckingResult *match = [anyRegex firstMatchInString:cleanString options:0 range:NSMakeRange(0, cleanString.length)];
        if (match && match.numberOfRanges > 1) extractedID = [cleanString substringWithRange:[match rangeAtIndex:1]];
    }
    return (extractedID && extractedID.length == 11) ? extractedID : @"";
}

@end

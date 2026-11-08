#import "Headers.h"

// YouMod's bundle (For localizations)
NSBundle *YouModBundle() {
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

// YouTube icon image (YTIIcon)
UIImage *YouModYTIconImage(NSInteger iconType, BOOL useCustomColor, UIColor *customColor) {
    YTIIcon *icon = [%c(YTIIcon) new];
    icon.iconType = iconType;
    UIColor *targetColor = (useCustomColor && customColor) ? customColor : [UIColor labelColor];
    return [[icon iconImageWithColor:targetColor] imageWithTintColor:targetColor];
}

// Render an SF Symbol into an exact square canvas (aspect-fit, centered) so icon
// boxes match; result stays template-rendered for later tinting.
UIImage *YouModSymbolImageInCanvas(NSString *symbolName, CGFloat canvasSize, CGFloat pointSize, UIImageSymbolWeight weight) {
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

// Language list
NSArray *getAllSystemLanguageTitles() {
    NSMutableArray *titles = [NSMutableArray array];
    NSArray *allLocales = [%c(YTLanguages) languageList];
    NSMutableSet *seenLanguages = [NSMutableSet set];
    NSLocale *currentLocale = [NSLocale currentLocale];
    
    for (NSString *localeId in allLocales) {
        NSDictionary *components = [NSLocale componentsFromLocaleIdentifier:localeId];
        NSString *langCode = components[NSLocaleLanguageCode];
        
        if (langCode && ![seenLanguages containsObject:langCode]) {
            [seenLanguages addObject:langCode];
            NSString *displayName = [currentLocale localizedStringForLocaleIdentifier:langCode];
            if (displayName) [titles addObject:displayName];
        }
    }
    return [titles sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

NSArray *getAllSystemLanguageValues() {
    NSArray *sortedTitles = getAllSystemLanguageTitles();
    NSMutableArray *sortedCodes = [NSMutableArray array];
    NSArray *allLocales = [%c(YTLanguages) languageList];
    NSLocale *currentLocale = [NSLocale currentLocale];
    
    NSMutableDictionary *titleToCodeMap = [NSMutableDictionary dictionary];
    for (NSString *localeId in allLocales) {
        NSDictionary *components = [NSLocale componentsFromLocaleIdentifier:localeId];
        NSString *langCode = components[NSLocaleLanguageCode];
        if (langCode) {
            NSString *displayName = [currentLocale localizedStringForLocaleIdentifier:langCode];
            if (displayName) titleToCodeMap[displayName] = langCode;
        }
    }
    
    for (NSString *title in sortedTitles) {
        [sortedCodes addObject:titleToCodeMap[title] ? titleToCodeMap[title] : @"en"];
    }
    return [sortedCodes copy];
}

// Get TopViewController
UIViewController *YouModTopViewController(UIViewController *root) {
    if (!root) {
        UIWindow *keyWindow = nil;
        for (UIWindow *window in UIApplication.sharedApplication.windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
        root = keyWindow.rootViewController;
    }
    while (root.presentedViewController) root = root.presentedViewController;
    if ([root isKindOfClass:UINavigationController.class])
        return YouModTopViewController(((UINavigationController *)root).topViewController);
    else if ([root isKindOfClass:UITabBarController.class])
        return YouModTopViewController(((UITabBarController *)root).selectedViewController);
    return root;
}

// OLEDKeyboard (https://github.com/dayanch96/OledKeyboard)
BOOL isDarkMode(UIView *view) {
    if ([view respondsToSelector:@selector(_mapkit_isDarkModeEnabled)]) return view._mapkit_isDarkModeEnabled;
    return view.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
}

BOOL isPad() {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
}

// Physical iPad hardware only: UIDevice.model is not affected by the Device UI
// override (which hooks userInterfaceIdiom), so settings layout decisions that
// must ignore that override use this instead of isPad().
BOOL isPadHardware(void) {
    return [UIDevice.currentDevice.model isEqualToString:@"iPad"];
}

void YouModConfigureSharePopover(UIActivityViewController *activityVC, UIView *sourceView) {
    if (isPad() && activityVC) {
        UIView *targetView = sourceView ?: YouModTopViewController(nil).view;
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

NSString *YMExtractYouTubeVideoID(NSString *urlString) {
    if (!urlString || urlString.length == 0) return nil;
    NSString *cleanString = [urlString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (cleanString.length == 11 && ![cleanString containsString:@"/"] && ![cleanString containsString:@"?"]) return cleanString;
    NSString *extractedID = nil;
    NSURL *url = [NSURL URLWithString:cleanString];
    if (url) {
        if ([url.host containsString:@"ytimg.com"]) {
            // Thumbnail URLs: /vi/<id>/... or /vi_webp/<id>/...
            NSRegularExpression *thumbRegex = [NSRegularExpression regularExpressionWithPattern:@"\\/vi(?:_webp)?\\/([a-zA-Z0-9_-]{11})" options:NSRegularExpressionCaseInsensitive error:nil];
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
        NSError *error = nil;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(?:v=|\\/(?:shorts|live|clip)\\/|youtu\\.be\\/|\\/vi(?:_webp)?\\/)([a-zA-Z0-9_-]{11})"
                                                                                options:NSRegularExpressionCaseInsensitive
                                                                                  error:&error];
        NSTextCheckingResult *match = [regex firstMatchInString:cleanString options:0 range:NSMakeRange(0, cleanString.length)];
        if (match && match.numberOfRanges > 1) extractedID = [cleanString substringWithRange:[match rangeAtIndex:1]];
    }
    return (extractedID && extractedID.length == 11) ? extractedID : @"";
}
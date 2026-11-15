// YMHelpers — app-global helpers: bundle/localization, accent color, icons,
// key window, top view controller, device idiom, share popover, video ID.
@interface YMHelpers : NSObject
// YouMod's resource bundle (localizations).
+ (NSBundle *)bundle;
// YouMod's accent color (#2885FF).
+ (UIColor *)accentColor;
// YouTube icon image (YTIIcon), optionally tinted.
+ (UIImage *)ytIconImage:(NSInteger)iconType useCustomColor:(BOOL)useCustomColor customColor:(UIColor *)customColor;
// SF Symbol in an exact square canvas (aspect-fit, centered); template-rendered.
+ (UIImage *)symbolImageInCanvas:(NSString *)symbolName canvasSize:(CGFloat)canvasSize pointSize:(CGFloat)pointSize weight:(UIImageSymbolWeight)weight;
// Display names of unique system languages, sorted.
+ (NSArray *)allSystemLanguageTitles;
// Language codes matching allSystemLanguageTitles ("en" when unknown).
+ (NSArray *)allSystemLanguageValues;
// Key window across connected scenes; matches old UIApplication.windows behavior.
+ (UIWindow *)keyWindow;
// Top-most view controller from root (or the key window's root when nil).
+ (UIViewController *)topViewController:(UIViewController *)root;
// YES when view is in dark mode (mapkit helper when available).
+ (BOOL)isDarkMode:(UIView *)view;
// YES on iPad device UI idiom (respects the Device UI override).
+ (BOOL)isPad;
// YES on physical iPad hardware only (ignores the Device UI override).
+ (BOOL)isPadHardware;
// Centers an activity sheet popover on iPad.
+ (void)configureSharePopover:(UIActivityViewController *)activityVC sourceView:(UIView *)sourceView;
// 11-char video ID from a watch/thumbnail/share URL, or @"" when not found.
+ (NSString *)extractYouTubeVideoID:(NSString *)urlString;
@end

// YMIconProvider — loads YouMod tab/settings icons from the bundle, picking the
// old/ or new/ icon set the running YouTube uses (YTUIResources.delhiIconsEnabled).

// YouTube private resource class; delhiIconsEnabled exists only on newer versions,
// which is why the provider checks respondsToSelector: before calling it.
@interface YTUIResources : NSObject
+ (BOOL)delhiIconsEnabled;
@end

@interface YMIconProvider : NSObject
// YES when YouTube's Delhi (new) icon set is enabled; NO for the classic set
// or older YouTube versions without the selector.
+ (BOOL)delhiIcons;
// Tab bar icon by bundle name ("history", "charts", …) from icons/old|new/.
+ (UIImage *)tabIcon:(NSString *)name selected:(BOOL)selected;
// Settings icon by bundle name ("appearance_settings", "video", …) — same folders.
+ (UIImage *)settingsIcon:(NSString *)name;
@end

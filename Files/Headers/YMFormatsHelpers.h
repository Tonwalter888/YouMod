// YMFormatsHelpers — debug file log and xtags parsing for the formats parser (YMFormats.x).
@interface YMFormatsHelpers : NSObject
// Path of the per-launch debug log in NSTemporaryDirectory().
+ (NSString *)logPath;
// Appends one line to the debug log (creates the file on first write).
+ (void)logMsg:(NSString *)format, ...;
// Value for a key in the base64 xtags TLV blob (e.g. "acont", "drc"); nil when absent.
+ (NSString *)valueForXtags:(NSString *)xtags forKey:(NSString *)key;
// Video codecs listed first when grouping formats (av01, vp09, avc1).
+ (NSArray<NSString *> *)videoCodecPreference;
// Audio codecs listed first when grouping formats (opus, mp4a).
+ (NSArray<NSString *> *)audioCodecPreference;
@end

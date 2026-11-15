// YMDownloadSheetHelpers — formatting helpers for the download sheet UI.
#import <UIKit/UIKit.h>

@interface YMDownloadSheetHelpers : NSObject
// Byte size like "1.2 MB"; nil when the size is unknown (0).
+ (NSString *)byteCountString:(unsigned long long)bytes;
@end

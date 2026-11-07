#import <Foundation/Foundation.h>

@interface YTIStreamingData : NSObject
- (NSString *)hlsManifestURL;
- (NSString *)dashManifestURL;
- (NSArray *)formatsArray;
- (NSArray *)adaptiveFormatsArray;
@end

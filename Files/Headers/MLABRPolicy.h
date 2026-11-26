#import <Foundation/NSObject.h>

@interface MLABRPolicy : NSObject
- (void)requestFormatReselection;
- (void)setFormats:(NSArray *)formats;
@end
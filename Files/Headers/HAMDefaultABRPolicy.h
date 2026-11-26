#import <Foundation/NSObject.h>

@interface HAMDefaultABRPolicy : NSObject
- (void)setFormats:(NSArray *)formats;
- (NSArray *)filterFormats:(NSArray *)formats;
- (id)getSelectableFormatDataAndReturnError:(NSError **)error;
@end

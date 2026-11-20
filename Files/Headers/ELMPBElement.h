#import "ELMPBProperties.h"
#import "ELMPBType.h"

@interface ELMPBElement : GPBMessage
@property (nonatomic, readwrite, strong) ELMPBType *type;
@property (nonatomic, readwrite, strong) ELMPBProperties *properties;
@end

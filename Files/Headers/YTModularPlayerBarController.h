#import "YTModularPlayerBarView.h"
#import "YTPlayerBarProtocol.h"
#import "YTIModularPlayerBarModel.h"

@interface YTModularPlayerBarController : NSObject <YTPlayerBarProtocol>
@property (nonatomic, strong, readwrite) YTModularPlayerBarView *view;
@property (nonatomic, strong, readwrite) YTIModularPlayerBarModel *model;
@end

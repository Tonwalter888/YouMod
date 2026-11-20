#import "YTActionSheetDialogViewControllerDelegate.h"
#import "YTResponder.h"
#import "YTActionSheetAction.h"

@interface YTDefaultSheetController : NSObject <YTActionSheetDialogViewControllerDelegate, YTResponder>
@end

@interface YTDefaultSheetController (YouMod)
+ (instancetype)sheetControllerWithParentResponder:(id)parentResponder;
- (void)addAction:(YTActionSheetAction *)action;
- (void)presentFromView:(UIView *)view animated:(BOOL)animated completion:(void (^)(void))completion;
- (void)presentFromViewController:(UIViewController *)vc animated:(BOOL)animated completion:(void (^)(void))completion;
- (void)addHeaderWithTitle:(NSString *)arg1 subtitle:(NSString *)arg2;
- (void)dismissViewControllerAnimated:(BOOL)arg1 completion:(void (^)(void))arg2;
@end

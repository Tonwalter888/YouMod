// 20.x and earlier use the pre-split YTPlayabilityResolutionUserActionUIController;
// 21.x+ uses YTPlayabilityResolutionUserActionUIControllerImpl (same API).
@interface YTPlayabilityResolutionUserActionUIController : NSObject
- (void)confirmAlertDidPressConfirm;
@end

@interface YTPlayabilityResolutionUserActionUIControllerImpl : NSObject
- (void)confirmAlertDidPressConfirm;
@end

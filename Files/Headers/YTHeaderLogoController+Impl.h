// 20.x and earlier use the pre-split YTHeaderLogoController; 21.x+ uses
// YTHeaderLogoControllerImpl (same API).
@interface YTHeaderLogoController : NSObject
@property (nonatomic, readwrite, assign, getter=isPremiumLogo) BOOL premiumLogo;
@end

@interface YTHeaderLogoControllerImpl : NSObject
@property (nonatomic, readwrite, assign, getter=isPremiumLogo) BOOL premiumLogo;
@end

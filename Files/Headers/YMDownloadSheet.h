#import "YTPlayerViewController.h"

typedef NS_ENUM(NSInteger, YMDownloadDestination) {
    YMDownloadDestinationPhotos,
    YMDownloadDestinationFiles,
};

@interface YMDownloadSheet : UIViewController
+ (void)presentForPlayer:(YTPlayerViewController *)player
            destination:(YMDownloadDestination)destination
                isShorts:(BOOL)isShorts
              presenter:(UIViewController *)presenter;
@end

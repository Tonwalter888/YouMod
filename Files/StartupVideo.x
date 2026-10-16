#import "Headers.h"
#import <AVFoundation/AVFoundation.h>
#import <PhotosUI/PhotosUI.h>

@interface YTTimedAction : NSObject
+ (instancetype)scheduledTimedActionWithTimeInterval:(CFTimeInterval)timeInterval
                                            repeats:(BOOL)repeats
                                              queue:(dispatch_queue_t)queue
                                              block:(dispatch_block_t)block;
- (void)invalidate;
@end

@interface UIViewController (YouModStartupVideoSettingsRefresh)
- (void)updateDisplayedItemsAnimated:(BOOL)animated;
@end

static const void *kYMStartupPlayerKey = &kYMStartupPlayerKey;
static const void *kYMStartupLayerKey = &kYMStartupLayerKey;
static const void *kYMStartupEndObserverKey = &kYMStartupEndObserverKey;
static const void *kYMStartupDismissedKey = &kYMStartupDismissedKey;
static const void *kYMStartupPickerDelegateKey = &kYMStartupPickerDelegateKey;
static const void *kYMStartupGestureHandlerKey = &kYMStartupGestureHandlerKey;

static NSURL *YMStartupVideoDirectoryURL() {
    NSURL *support = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    return [support URLByAppendingPathComponent:@"YouMod" isDirectory:YES];
}

static NSURL *YMStartupVideoURL() {
    return [YMStartupVideoDirectoryURL() URLByAppendingPathComponent:@"StartupAnimation.mp4"];
}

BOOL YMStartupVideoFileExists() {
    NSNumber *size = nil;
    return [YMStartupVideoURL() getResourceValue:&size forKey:NSURLFileSizeKey error:nil] && size.unsignedLongLongValue > 0;
}

static void YMStartupVideoRefreshSettings(UIViewController *presenter) {
    [presenter updateDisplayedItemsAnimated:YES];
}

@interface YMStartupVideoTapHandler : NSObject
@property (nonatomic, weak) YTStartupAnimationViewController *controller;
- (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer;
@end

static void YMStartupVideoDismissInternal(YTStartupAnimationViewController *controller);

@implementation YMStartupVideoTapHandler
- (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateRecognized) YMStartupVideoDismissInternal(self.controller);
}
@end

@interface YMStartupVideoPickerDelegate : NSObject <PHPickerViewControllerDelegate>
@property (nonatomic, weak) UIViewController *presenter;
@end

@implementation YMStartupVideoPickerDelegate
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    PHPickerResult *result = results.firstObject;
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (!result) return;

    UIViewController *presenter = self.presenter;
    NSItemProvider *provider = result.itemProvider;
    if (![provider hasItemConformingToTypeIdentifier:@"public.movie"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            YouModShowPill(LOC(@"STARTUP_VIDEO_INVALID"), NO);
        });
        return;
    }

    [provider loadFileRepresentationForTypeIdentifier:@"public.movie" completionHandler:^(NSURL *temporaryURL, NSError *loadError) {
        if (!temporaryURL || loadError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                YouModShowPill(LOC(@"STARTUP_VIDEO_IMPORT_FAILED"), NO);
            });
            return;
        }

        NSString *inputPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"YouModStartup-%@.%@", NSUUID.UUID.UUIDString, temporaryURL.pathExtension.length ? temporaryURL.pathExtension : @"mov"]];
        NSURL *inputURL = [NSURL fileURLWithPath:inputPath];
        NSError *copyError = nil;
        if (![[NSFileManager defaultManager] copyItemAtURL:temporaryURL toURL:inputURL error:&copyError]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                YouModShowPill(LOC(@"STARTUP_VIDEO_IMPORT_FAILED"), NO);
            });
            return;
        }

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            NSFileManager *fm = [NSFileManager defaultManager];
            NSURL *directoryURL = YMStartupVideoDirectoryURL();
            NSError *directoryError = nil;
            [fm createDirectoryAtURL:directoryURL withIntermediateDirectories:YES attributes:nil error:&directoryError];
            NSURL *convertedURL = [directoryURL URLByAppendingPathComponent:[NSString stringWithFormat:@"StartupAnimation-%@.mp4", NSUUID.UUID.UUIDString]];
            NSString *failure = directoryError.localizedDescription;
            BOOL success = !directoryError && YMFFmpegConvertStartupVideo(inputURL, convertedURL, &failure);
            [fm removeItemAtURL:inputURL error:nil];

            if (success) {
                NSURL *savedURL = YMStartupVideoURL();
                NSError *replaceError = nil;
                if ([fm fileExistsAtPath:savedURL.path]) [fm removeItemAtURL:savedURL error:&replaceError];
                if (!replaceError) [fm moveItemAtURL:convertedURL toURL:savedURL error:&replaceError];
                if (replaceError) {
                    success = NO;
                    failure = replaceError.localizedDescription;
                    [fm removeItemAtURL:convertedURL error:nil];
                }
            } else {
                [fm removeItemAtURL:convertedURL error:nil];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                YMStartupVideoRefreshSettings(presenter);
                YouModShowPill(LOC(success ? @"STARTUP_VIDEO_SAVED" : @"STARTUP_VIDEO_CONVERT_FAILED"), success);
            });
        });
    }];
}
@end

void YMStartupVideoPresentPicker(UIViewController *presenter) {
    if (!presenter || ![PHPickerViewController class]) return;
    PHPickerConfiguration *configuration = [[PHPickerConfiguration alloc] init];
    configuration.filter = [PHPickerFilter videosFilter];
    configuration.selectionLimit = 1;
    configuration.preferredAssetRepresentationMode = PHPickerConfigurationAssetRepresentationModeCompatible;

    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:configuration];
    YMStartupVideoPickerDelegate *delegate = [YMStartupVideoPickerDelegate new];
    delegate.presenter = presenter;
    picker.delegate = delegate;
    objc_setAssociatedObject(picker, kYMStartupPickerDelegateKey, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [presenter presentViewController:picker animated:YES completion:nil];
}

void YMStartupVideoDelete(UIViewController *presenter) {
    if (!presenter || !YMStartupVideoFileExists()) return;
    YTAlertView *confirm = [%c(YTAlertView) confirmationDialogWithAction:^{
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtURL:YMStartupVideoURL() error:&error];
        YMStartupVideoRefreshSettings(presenter);
        YouModShowPill(error.localizedDescription ?: LOC(error ? @"STARTUP_VIDEO_DELETE_FAILED" : @"STARTUP_VIDEO_DELETED"), error == nil);
    } actionTitle:LOC(@"DELETE")];
    confirm.title = LOC(@"STARTUP_VIDEO_DELETE_CONFIRM");
    confirm.subtitle = LOC(@"STARTUP_VIDEO_DELETE_CONFIRM_DESC");
    confirm.shouldDismissOnBackgroundTap = YES;
    [confirm show];
}

BOOL YMStartupVideoPrepare(YTStartupAnimationViewController *controller) {
    if (!controller || !YMStartupVideoFileExists()) return NO;
    if (YMStartupVideoIsPrepared(controller)) return YES;
    NSURL *url = YMStartupVideoURL();
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:url];
    AVPlayer *player = [AVPlayer playerWithPlayerItem:item];
    AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:player];
    layer.videoGravity = AVLayerVideoGravityResize; // Stretch to the full startup screen.
    layer.frame = controller.view.bounds;
    controller.view.backgroundColor = UIColor.blackColor;
    [controller.view.layer addSublayer:layer];
    YMStartupVideoTapHandler *tapHandler = [YMStartupVideoTapHandler new];
    tapHandler.controller = controller;
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:tapHandler action:@selector(handleDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    doubleTap.cancelsTouchesInView = NO;
    [controller.view addGestureRecognizer:doubleTap];
    objc_setAssociatedObject(controller, kYMStartupPlayerKey, player, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller, kYMStartupLayerKey, layer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller, kYMStartupDismissedKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller, kYMStartupGestureHandlerKey, tapHandler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return YES;
}

BOOL YMStartupVideoIsPrepared(YTStartupAnimationViewController *controller) {
    return objc_getAssociatedObject(controller, kYMStartupPlayerKey) != nil;
}

static void YMStartupVideoStopSafeguardTimer(YTStartupAnimationViewController *controller) {
    if (!controller) return;
    YTTimedAction *action = [controller valueForKey:@"_safeguardToDismissAnimationAction"];
    [action invalidate];
    [controller setValue:nil forKey:@"_safeguardToDismissAnimationAction"];
}

static void YMStartupVideoStartSafeguardTimer(YTStartupAnimationViewController *controller) {
    if (!controller) return;
    YMStartupVideoStopSafeguardTimer(controller);

    __weak YTStartupAnimationViewController *weakController = controller;
    YTTimedAction *action = [%c(YTTimedAction) scheduledTimedActionWithTimeInterval:10.0
                                                                           repeats:NO
                                                                             queue:dispatch_get_main_queue()
                                                                             block:^{
        YMStartupVideoDismissInternal(weakController);
    }];
    if (action) [controller setValue:action forKey:@"_safeguardToDismissAnimationAction"];
}

void YMStartupVideoLayout(YTStartupAnimationViewController *controller) {
    AVPlayerLayer *layer = objc_getAssociatedObject(controller, kYMStartupLayerKey);
    if (layer) layer.frame = controller.view.bounds;
}

static void YMStartupVideoDismissInternal(YTStartupAnimationViewController *controller) {
    if (!controller || [objc_getAssociatedObject(controller, kYMStartupDismissedKey) boolValue]) return;
    objc_setAssociatedObject(controller, kYMStartupDismissedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    AVPlayer *player = objc_getAssociatedObject(controller, kYMStartupPlayerKey);
    [player pause];
    YMStartupVideoStopSafeguardTimer(controller);
    id observer = objc_getAssociatedObject(controller, kYMStartupEndObserverKey);
    if (observer) [[NSNotificationCenter defaultCenter] removeObserver:observer];
    objc_setAssociatedObject(controller, kYMStartupEndObserverKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    dispatch_async(dispatch_get_main_queue(), ^{
        [controller forceDismissStartupAnimationAnimated:YES];
    });
}

void YMStartupVideoPlay(YTStartupAnimationViewController *controller) {
    AVPlayer *player = objc_getAssociatedObject(controller, kYMStartupPlayerKey);
    AVPlayerItem *item = player.currentItem;
    if (!player || !item) {
        YMStartupVideoDismissInternal(controller);
        return;
    }
    YMStartupVideoStartSafeguardTimer(controller);
    __weak YTStartupAnimationViewController *weakController = controller;
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification object:item queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
        YMStartupVideoDismissInternal(weakController);
    }];
    objc_setAssociatedObject(controller, kYMStartupEndObserverKey, observer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [player play];
}

%hook YTStartupAnimationViewController
- (void)setUpLottieAnimation {
    %orig;
    if (INTFORVAL(StartupAnimation) == 3 && YMStartupVideoFileExists()) YMStartupVideoPrepare(self);
}
- (void)playLottieAnimation {
    if (INTFORVAL(StartupAnimation) == 3 && YMStartupVideoIsPrepared(self)) {
        YMStartupVideoPlay(self);
        return;
    }
    %orig;
}
- (void)viewWillAppear:(BOOL)animated {
    if (INTFORVAL(StartupAnimation) == 3 && YMStartupVideoIsPrepared(self)) YMStartupVideoLayout(self);
    %orig;
}
- (void)startSafeguardAnimationTimer {
    if (INTFORVAL(StartupAnimation) == 3 && YMStartupVideoIsPrepared(self)) {
        YMStartupVideoStartSafeguardTimer(self);
        return;
    }
    %orig;
}
- (void)stopAnimationTimer {
    if (INTFORVAL(StartupAnimation) == 3 && YMStartupVideoIsPrepared(self)) {
        YMStartupVideoStopSafeguardTimer(self);
        return;
    }
    %orig;
}
%end
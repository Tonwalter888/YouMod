#import "Headers.h"
#import <AVFoundation/AVFoundation.h>
#import <PhotosUI/PhotosUI.h>

@interface UIViewController (YouModStartupVideoSettingsRefresh)
- (void)updateDisplayedItemsAnimated:(BOOL)animated;
@end

static const void *kYMStartupPickerDelegateKey = &kYMStartupPickerDelegateKey;
static UIWindow *sStartupVideoWindow;

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

@interface YMStartupVideoView : UIView
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) id endObserver;
@property (nonatomic, assign) BOOL dismissed;
@property (nonatomic, copy) NSString *previousAudioCategory;
@property (nonatomic, copy) NSString *previousAudioMode;
@property (nonatomic, assign) AVAudioSessionCategoryOptions previousAudioCategoryOptions;
@property (nonatomic, assign) BOOL changedAudioSessionCategory;
- (void)dismiss;
@end

static YMStartupVideoView *sStartupVideoView;
static __weak YTStartupAnimationViewController *sStartupAnimationController;

@implementation YMStartupVideoView
+ (Class)layerClass {
    return AVPlayerLayer.class;
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateRecognized) [self dismiss];
}

- (void)dismiss {
    if (self.dismissed) return;
    self.dismissed = YES;
    [self.player pause];
    if (self.changedAudioSessionCategory) {
        AVAudioSession *audioSession = AVAudioSession.sharedInstance;
        [audioSession setCategory:self.previousAudioCategory
                             mode:self.previousAudioMode
                          options:self.previousAudioCategoryOptions
                            error:nil];
        self.changedAudioSessionCategory = NO;
    }
    if (self.endObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.endObserver];
    self.endObserver = nil;
    UIWindow *videoWindow = self.window ?: sStartupVideoWindow;

    YTStartupAnimationViewController *controller = sStartupAnimationController;
    dispatch_async(dispatch_get_main_queue(), ^{
        [controller forceDismissStartupAnimationAnimated:YES];
        [UIView animateWithDuration:0.2 animations:^{
            self.alpha = 0;
        } completion:^(BOOL finished) {
            for (UIGestureRecognizer *gesture in self.gestureRecognizers) [self removeGestureRecognizer:gesture];
            [self removeFromSuperview];
            if (sStartupVideoView == self) sStartupVideoView = nil;
            if (sStartupVideoWindow == videoWindow) videoWindow.hidden = YES;
        }];
    });
}
@end

static UIWindowScene *YMStartupVideoScene(YTStartupAnimationViewController *controller) {
    // Prefer the scene that owns YouTube's startup controller (multiple scenes).
    UIWindowScene *controllerScene = controller.viewIfLoaded.window.windowScene;
    if (controllerScene && controllerScene.activationState != UISceneActivationStateUnattached) return controllerScene;

    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) return (UIWindowScene *)scene;
        }
    }
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
        return (UIWindowScene *)scene;
    }
    return nil;
}

static UIWindow *YMStartupVideoWindow(YTStartupAnimationViewController *controller) {
    UIWindowScene *scene = YMStartupVideoScene(controller);
    if (!scene) return nil;

    if (sStartupVideoWindow && sStartupVideoWindow.windowScene == scene) {
        sStartupVideoWindow.frame = scene.coordinateSpace.bounds;
        sStartupVideoWindow.windowLevel = UIWindowLevelAlert + 1;
        sStartupVideoWindow.hidden = NO;
        return sStartupVideoWindow;
    }

    if (sStartupVideoWindow) {
        sStartupVideoWindow.hidden = YES;
    }

    UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
    window.frame = scene.coordinateSpace.bounds;
    window.windowLevel = UIWindowLevelAlert + 1;
    window.backgroundColor = UIColor.blackColor;

    UIViewController *rootController = [UIViewController new];
    rootController.view.backgroundColor = UIColor.blackColor;
    rootController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    window.rootViewController = rootController;
    window.hidden = NO;
    sStartupVideoWindow = window;
    return window;
}

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

static BOOL YMStartupVideoPrepare() {
    if (!YMStartupVideoFileExists()) return NO;
    if (sStartupVideoView && !sStartupVideoView.dismissed) return YES;

    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:YMStartupVideoURL()];
    AVPlayer *player = [AVPlayer playerWithPlayerItem:item];
    YMStartupVideoView *videoView = [[YMStartupVideoView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    videoView.backgroundColor = UIColor.blackColor;
    videoView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    AVPlayerLayer *layer = (AVPlayerLayer *)videoView.layer;
    layer.player = player;
    layer.videoGravity = AVLayerVideoGravityResize; // Stretch to the full startup screen.
    videoView.player = player;

    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:videoView action:@selector(handleDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    doubleTap.cancelsTouchesInView = NO;
    [videoView addGestureRecognizer:doubleTap];

    sStartupVideoView = videoView;
    return YES;
}

static void YMStartupVideoPlay(YTStartupAnimationViewController *controller) {
    YMStartupVideoView *videoView = sStartupVideoView;
    AVPlayer *player = videoView.player;
    sStartupAnimationController = controller;
    if (!player.currentItem) {
        [controller forceDismissStartupAnimationAnimated:YES];
        return;
    }

    UIWindow *window = YMStartupVideoWindow(controller);
    if (!window) {
        [controller forceDismissStartupAnimationAnimated:YES];
        return;
    }

    UIView *contentView = window.rootViewController.view;
    videoView.frame = contentView.bounds;
    if (videoView.superview != contentView) [contentView addSubview:videoView];
    [contentView bringSubviewToFront:videoView];

    AVAudioSession *audioSession = AVAudioSession.sharedInstance;
    if (![audioSession.category isEqualToString:AVAudioSessionCategoryPlayback]) {
        videoView.previousAudioCategory = audioSession.category;
        videoView.previousAudioMode = audioSession.mode;
        videoView.previousAudioCategoryOptions = audioSession.categoryOptions;
        videoView.changedAudioSessionCategory = [audioSession setCategory:AVAudioSessionCategoryPlayback
                                                                     mode:AVAudioSessionModeMoviePlayback
                                                                  options:0
                                                                    error:nil];
    }
    [audioSession setActive:YES error:nil];
    player.muted = NO;
    player.volume = 1.0;

    __weak YMStartupVideoView *weakView = videoView;
    videoView.endObserver = [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification object:player.currentItem queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
        [weakView dismiss];
    }];
    [player play];
}

%hook YTStartupAnimationViewController
- (void)setUpLottieAnimation {
    if (INTFORVAL(StartupAnimation) == 3) YMStartupVideoPrepare();
    %orig;
}
- (void)playLottieAnimation {
    %orig;
    if (INTFORVAL(StartupAnimation) == 3 && sStartupVideoView && !sStartupVideoView.dismissed) YMStartupVideoPlay(self);
}
%end

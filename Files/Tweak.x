#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AVKit/AVKit.h>
#import <Photos/Photos.h>
#import <objc/runtime.h>

static char kAssociatedOutURLKey;

// UI utility functions for iOS (Main Thread Safe)
static UIWindow *getKeyWindow(void) {
    UIWindow *keyWindow = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
            for (UIWindow *window in [(UIWindowScene *)scene windows]) {
                if (window.isKeyWindow) {
                    keyWindow = window;
                    break;
                }
            }
        }
        if (keyWindow) break;
    }
    if (!keyWindow) {
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
    }
    if (!keyWindow) keyWindow = [UIApplication sharedApplication].windows.firstObject;
    return keyWindow;
}

static UIViewController *getTopMostController(void) {
    UIWindow *window = getKeyWindow();
    UIViewController *root = window.rootViewController;
    while (root.presentedViewController) {
        root = root.presentedViewController;
    }
    return root;
}

// ============================================================================
// ANIMATED PROGRESS HUD
// ============================================================================
@interface YTDMProgressHUD : UIView
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *feedbackIconLabel;

+ (instancetype)sharedHUD;
- (void)showInView:(UIView *)parentView;
- (void)updateProgress:(float)progress status:(NSString *)status;
- (void)showSuccessWithStatus:(NSString *)status;
- (void)showError:(NSString *)errorMessage;
- (void)dismiss;
@end

@implementation YTDMProgressHUD
+ (instancetype)sharedHUD {
    static YTDMProgressHUD *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] initWithFrame:CGRectMake(0, 0, 240, 170)];
    });
    return shared;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.layer.cornerRadius = 18;
        self.layer.masksToBounds = YES;
        
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        _blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        _blurView.frame = self.bounds;
        [self addSubview:_blurView];
        
        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
        _spinner.color = [UIColor whiteColor];
        _spinner.center = CGPointMake(frame.size.width / 2, 45);
        [_blurView.contentView addSubview:_spinner];

        _feedbackIconLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, frame.size.width, 60)];
        _feedbackIconLabel.textColor = [UIColor whiteColor];
        _feedbackIconLabel.font = [UIFont systemFontOfSize:50 weight:UIFontWeightMedium];
        _feedbackIconLabel.textAlignment = NSTextAlignmentCenter;
        _feedbackIconLabel.hidden = YES;
        [_blurView.contentView addSubview:_feedbackIconLabel];
        
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 85, frame.size.width - 20, 20)];
        _titleLabel.text = @"YTDM Suite";
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.font = [UIFont boldSystemFontOfSize:15];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        [_blurView.contentView addSubview:_titleLabel];
        
        _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        _progressView.frame = CGRectMake(25, 115, frame.size.width - 50, 4);
        _progressView.progressTintColor = [UIColor systemGreenColor];
        _progressView.trackTintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.2];
        _progressView.hidden = YES;
        [_blurView.contentView addSubview:_progressView];
        
        _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 122, frame.size.width - 20, 38)];
        _statusLabel.text = @"Connecting...";
        _statusLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.85];
        _statusLabel.font = [UIFont systemFontOfSize:12];
        _statusLabel.textAlignment = NSTextAlignmentCenter;
        _statusLabel.numberOfLines = 2;
        [_blurView.contentView addSubview:_statusLabel];
    }
    return self;
}

- (void)showInView:(UIView *)parentView {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.alpha = 0.0;
        self.center = CGPointMake(parentView.bounds.size.width / 2, parentView.bounds.size.height / 2);
        [parentView addSubview:self];
        [parentView bringSubviewToFront:self];
        
        self.progressView.progress = 0.0;
        self.progressView.hidden = YES;
        self.feedbackIconLabel.hidden = YES;
        self.spinner.hidden = NO;
        [self.spinner startAnimating];
        self.statusLabel.text = @"Contacting the server...";
        
        [UIView animateWithDuration:0.25 animations:^{ self.alpha = 1.0; }];
    });
}

- (void)updateProgress:(float)progress status:(NSString *)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (progress >= 0.0) {
            self.spinner.hidden = YES;
            [self.spinner stopAnimating];
            self.progressView.hidden = NO;
            self.progressView.progress = progress;
        }
        if (status) self.statusLabel.text = status;
    });
}

- (void)showSuccessWithStatus:(NSString *)status {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.alpha = 1.0;
        if (!self.superview) {
            [getKeyWindow() addSubview:self];
            [getKeyWindow() bringSubviewToFront:self];
            self.center = CGPointMake(getKeyWindow().bounds.size.width / 2, getKeyWindow().bounds.size.height / 2);
        }
        self.spinner.hidden = YES;
        [self.spinner stopAnimating];
        self.progressView.hidden = YES;
        self.feedbackIconLabel.text = @"✓";
        self.feedbackIconLabel.textColor = [UIColor systemGreenColor];
        self.feedbackIconLabel.hidden = NO;
        if (status) self.statusLabel.text = status;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self dismiss]; });
    });
}

- (void)showError:(NSString *)errorMessage {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.alpha = 1.0;
        if (!self.superview) {
            [getKeyWindow() addSubview:self];
            [getKeyWindow() bringSubviewToFront:self];
            self.center = CGPointMake(getKeyWindow().bounds.size.width / 2, getKeyWindow().bounds.size.height / 2);
        }
        self.spinner.hidden = YES;
        [self.spinner stopAnimating];
        self.progressView.hidden = YES;
        self.feedbackIconLabel.text = @"✗";
        self.feedbackIconLabel.textColor = [UIColor systemRedColor];
        self.feedbackIconLabel.hidden = NO;
        self.statusLabel.text = errorMessage ?: @"Error occurred.";
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self dismiss]; });
    });
}

- (void)dismiss {
    [UIView animateWithDuration:0.25 animations:^{ self.alpha = 0.0; } completion:^(BOOL finished) { [self removeFromSuperview]; }];
}
@end

// ============================================================================
// SERVER COMMUNICATION SERVICE
// ============================================================================
@interface YTDownloadManagerService : NSObject
+ (instancetype)sharedInstance;
- (void)requestDownloadForVideoId:(NSString *)vId isAudio:(BOOL)isAudio quality:(NSString *)quality completion:(void (^)(NSArray<NSURL *> *localURLs, NSString *errorMsg))completionBlock;
- (void)requestStreamURLForVideoId:(NSString *)vId completion:(void (^)(NSString *streamURL, NSString *errorMsg))completionBlock;
@end

@implementation YTDownloadManagerService
+ (instancetype)sharedInstance {
    static YTDownloadManagerService *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (NSString *)serverEndpoint {
    return @"https://appropriatenet.tail6a9ca7.ts.net/"
}

- (void)requestDownloadForVideoId:(NSString *)vId isAudio:(BOOL)isAudio quality:(NSString *)quality completion:(void (^)(NSArray<NSURL *> *localURLs, NSString *errorMsg))completionBlock {
    NSString *watchURL = [NSString stringWithFormat:@"https://www.youtube.com/watch?v=%@", vId];
    [self startYTDMDownloadWithWatchURL:watchURL format:isAudio ? @"audio" : @"video" formatId:quality completion:completionBlock];
}

- (void)requestStreamURLForVideoId:(NSString *)vId completion:(void (^)(NSString *streamURL, NSString *errorMsg))completionBlock {
    NSString *urlStr = [[self serverEndpoint] stringByAppendingString:@"/api/stream"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSDictionary *payload = @{@"url": [NSString stringWithFormat:@"https://www.youtube.com/watch?v=%@", vId]};
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) { completionBlock(nil, @"Stream Connection Error"); return; }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (json[@"stream_url"]) completionBlock(json[@"stream_url"], nil);
        else completionBlock(nil, json[@"error"] ?: @"Stream failed");
    }] resume];
}

- (void)startYTDMDownloadWithWatchURL:(NSString *)watchURL format:(NSString *)format formatId:(NSString *)formatId completion:(void (^)(NSArray<NSURL *> *localURLs, NSString *errorMsg))completionBlock {
    NSString *urlStr = [[self serverEndpoint] stringByAppendingString:@"/api/download"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSMutableDictionary *payload = [@{@"url": watchURL, @"format": format} mutableCopy];
    if (formatId) payload[@"format_id"] = formatId;
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) { completionBlock(nil, @"Server unreachable."); return; }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (json[@"job_id"]) [self pollJobStatus:json[@"job_id"] completion:completionBlock];
        else completionBlock(nil, json[@"error"] ?: @"Job init failed.");
    }] resume];
}

- (void)pollJobStatus:(NSString *)jobId completion:(void (^)(NSArray<NSURL *> *localURLs, NSString *errorMsg))completionBlock {
    NSString *urlStr = [NSString stringWithFormat:@"%@/api/status/%@", [self serverEndpoint], jobId];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self pollJobStatus:jobId completion:completionBlock]; });
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSString *status = json[@"status"];
        
        if ([status isEqualToString:@"done"]) {
            id filesData = json[@"files"] ?: json[@"filenames"] ?: json[@"filename"] ?: json[@"file_path"];
            NSMutableArray<NSString *> *filesToDownload = [NSMutableArray array];
            
            if ([filesData isKindOfClass:[NSArray class]]) {
                for (id fileItem in filesData) {
                    if ([fileItem isKindOfClass:[NSString class]]) [filesToDownload addObject:[fileItem lastPathComponent]];
                }
            } else if ([filesData isKindOfClass:[NSString class]]) {
                [filesToDownload addObject:[filesData lastPathComponent]];
            }
            
            if (filesToDownload.count == 0) {
                completionBlock(nil, @"No files found in job.");
                return;
            }
            
            [self downloadMultipleFiles:filesToDownload forJobId:jobId completion:completionBlock];
        } else if ([status isEqualToString:@"error"]) {
            completionBlock(nil, json[@"error"] ?: @"Server Error.");
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{ [[YTDMProgressHUD sharedHUD] updateProgress:-1.0 status:@"Downloading on the server..."]; });
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self pollJobStatus:jobId completion:completionBlock]; });
        }
    }] resume];
}

- (void)downloadMultipleFiles:(NSArray<NSString *> *)filenames forJobId:(NSString *)jobId completion:(void (^)(NSArray<NSURL *> *localURLs, NSString *errorMsg))completionBlock {
    NSMutableArray<NSURL *> *localURLs = [NSMutableArray array];
    __block NSInteger remaining = filenames.count;
    __block NSString *errStr = nil;
    NSInteger totalCount = filenames.count;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[YTDMProgressHUD sharedHUD] updateProgress:0.0 status:[NSString stringWithFormat:@"Syncing files: 0/%lu", (unsigned long)totalCount]];
    });

    for (NSString *filename in filenames) {
        NSString *encodedName = [filename stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSString *urlString = [NSString stringWithFormat:@"%@/api/file/%@?filename=%@", [self serverEndpoint], jobId, encodedName];
        
        [[[NSURLSession sharedSession] downloadTaskWithURL:[NSURL URLWithString:urlString] completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            if (error || !location) {
                errStr = error.localizedDescription;
            } else {
                NSString *tempDir = NSTemporaryDirectory();
                NSURL *destURL = [NSURL fileURLWithPath:[tempDir stringByAppendingPathComponent:filename]];
                [[NSFileManager defaultManager] removeItemAtURL:destURL error:nil];
                
                if ([[NSFileManager defaultManager] moveItemAtURL:location toURL:destURL error:nil]) {
                    @synchronized(localURLs) { [localURLs addObject:destURL]; }
                }
            }
            
            @synchronized(self) {
                remaining--;
                float progress = (float)(totalCount - remaining) / (float)totalCount;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[YTDMProgressHUD sharedHUD] updateProgress:progress status:[NSString stringWithFormat:@"Syncing files: %lu/%lu", (unsigned long)(totalCount - remaining), (unsigned long)totalCount]];
                });
                
                if (remaining == 0) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (localURLs.count > 0) completionBlock(localURLs, nil);
                        else completionBlock(nil, errStr ?: @"Download sync failed.");
                    });
                }
            }
        }] resume];
    }
}
@end

// ============================================================================
// METADATA TRACKING HOOKS (MULTILAYER EXTRACTOR)
// ============================================================================
%hook YTIVideoDetails
- (NSString *)title { 
    NSString *t = %orig;
    if (t) {
        capturedVideoTitle = [safeString(t) copy];
    }
    return t;
}
- (NSString *)author {
    NSString * a = %orig;
    if (a) { 
        capturedChannelName = [safeString(a) copy];
    }
    return a;
}
- (NSString *)shortDescription {
    NSString *desc = %orig;
    if (desc) {
        capturedDescription = [safeString(desc) copy];
    }
    return desc;
}
%end

// ============================================================================
// REAL-TIME TIMING TRACKING HOOKS (FIX FOR TIMESTAMP ALWAYS 0)
// ============================================================================
%hook YTPlayerViewController
- (CGFloat)currentVideoMediaTime {
    CGFloat orig = %orig;
    capturedCurrentTime = orig;
    return orig;
}
- (NSString *)currentVideoID {
    NSString *orig = %orig;
    capturedVideoId = orig;
    return orig;
}
%end

// ============================================================================
// INTERFACE CONTROLS OVERLAY HOOK
// ============================================================================
@interface YTMainAppControlsOverlayView : UIView <UIDocumentPickerDelegate>
- (void)ytdm_triggerSilentDownloadWithQuality:(NSString *)quality isAudio:(BOOL)isAudio;
- (void)ytdm_presentSaveOptionsForURLs:(NSArray<NSURL *> *)outURLs isAudio:(BOOL)isAudio;
- (void)ytdm_presentShareSheetForURLs:(NSArray<NSURL *> *)outURLs;
- (void)ytdm_playInSystemPlayer;
- (void)ytdm_downloadThumbnailToPhotos;
- (void)ytdm_copyToClipboardWithText:(NSString *)text alertMsg:(NSString *)alertMsg;
- (UIViewController *)ytdm_parentViewController;
@end

@interface YTMainAppVideoPlayerOverlayViewController : UIViewController
@end

@interface YTPlayerViewController : UIViewController
- (NSString *)currentVideoID;
- (CGFloat)currentVideoMediaTime;
@end

%hook YTMainAppControlsOverlayView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIButton *downloadBtn = [self viewWithTag:9912];
    if (downloadBtn && !downloadBtn.hidden && downloadBtn.alpha > 0.01) {
        CGPoint localPoint = [downloadBtn convertPoint:point fromView:self];
        if ([downloadBtn pointInside:localPoint withEvent:event]) return downloadBtn;
    }
    return %orig;
}

- (void)layoutSubviews {
    %orig;
    UIButton *downloadBtn = [self viewWithTag:9912];
    if (!downloadBtn) {
        downloadBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        downloadBtn.tag = 9912;
        [downloadBtn setTitle:@"⬇️" forState:UIControlStateNormal];
        downloadBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        downloadBtn.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
        downloadBtn.layer.cornerRadius = 16;
        downloadBtn.layer.borderWidth = 0.5;
        downloadBtn.layer.borderColor = [[UIColor whiteColor] colorWithAlphaComponent:0.35].CGColor;
        downloadBtn.userInteractionEnabled = YES;
        [self addSubview:downloadBtn];
    }
    downloadBtn.frame = CGRectMake(12, 120, 32, 32);
    [self bringSubviewToFront:downloadBtn];
    
    if (@available(iOS 14.0, *)) {
        downloadBtn.showsMenuAsPrimaryAction = YES;
        __weak typeof(self) weakSelf = self;
        
        YTMainAppVideoPlayerOverlayViewController *ovcon = [self valueForKey:@"_eventsDelegate"];
        YTPlayerViewController *pvcon = (YTPlayerViewController *)ovcon.parentViewController;
        UIAction *v1080 = [UIAction actionWithTitle:@"Video (1080p)" image:[UIImage systemImageNamed:@"hd"] identifier:nil handler:^(UIAction *a) { [weakSelf ytdm_triggerSilentDownloadWithQuality:@"1080" isAudio:NO videoID:pvcon.currentVideoID]; }];
        UIAction *v720 = [UIAction actionWithTitle:@"Video (720p)" image:[UIImage systemImageNamed:@"play.rectangle"] identifier:nil handler:^(UIAction *a) { [weakSelf ytdm_triggerSilentDownloadWithQuality:@"720" isAudio:NO videoID:pvcon.currentVideoID]; }];
        UIAction *v360 = [UIAction actionWithTitle:@"Video (360p)" image:[UIImage systemImageNamed:@"play.circle"] identifier:nil handler:^(UIAction *a) { [weakSelf ytdm_triggerSilentDownloadWithQuality:@"360" isAudio:NO videoID:pvcon.currentVideoID]; }];
        UIMenu *videoSubmenu = [UIMenu menuWithTitle:@"Download Video" image:[UIImage systemImageNamed:@"video"] identifier:nil options:0 children:@[v1080, v720, v360]];
        
        UIAction *audioOnly = [UIAction actionWithTitle:@"Audio Only (M4A)" image:[UIImage systemImageNamed:@"waveform"] identifier:nil handler:^(UIAction *a) { [weakSelf ytdm_triggerSilentDownloadWithQuality:nil isAudio:YES videoID:pvcon.currentVideoID]; }];
        UIAction *sysPlayer = [UIAction actionWithTitle:@"Play in System Player" image:[UIImage systemImageNamed:@"arrow.up.right.video"] identifier:nil handler:^(UIAction *a) { [weakSelf ytdm_playInSystemPlayer:nil videoID:pvcon.currentVideoID]; }];
        UIAction *dlThumb = [UIAction actionWithTitle:@"Download Thumbnail" image:[UIImage systemImageNamed:@"photo"] identifier:nil handler:^(UIAction *a) { [weakSelf ytdm_downloadThumbnailToPhotos]; }];
        
        UIAction *copyTitle = [UIAction actionWithTitle:@"Copy Video Title" image:[UIImage systemImageNamed:@"doc.on.clipboard"] identifier:nil handler:^(UIAction *a) {
            [weakSelf ytdm_copyToClipboardWithText:capturedVideoTitle alertMsg:@"Copied Title!"];
        }];
        
        UIAction *copyLink = [UIAction actionWithTitle:@"Copy Video Link" image:[UIImage systemImageNamed:@"link"] identifier:nil handler:^(UIAction *a) {
            NSString *cleanLink = capturedVideoId ? [NSString stringWithFormat:@"https://youtu.be/%@", capturedVideoId] : nil;
            NSString *formattedText = (capturedVideoTitle && cleanLink) ? [NSString stringWithFormat:@"%@ - %@", capturedVideoTitle, cleanLink] : cleanLink;
            [weakSelf ytdm_copyToClipboardWithText:formattedText alertMsg:@"Copied Link with Title!"];
        }];
        
        UIAction *copyTimestamp = [UIAction actionWithTitle:@"Copy Link with Timestamp" image:[UIImage systemImageNamed:@"clock"] identifier:nil handler:^(UIAction *a) {
            int seconds = (int)capturedCurrentTime;
            NSString *tsLink = capturedVideoId ? [NSString stringWithFormat:@"https://youtu.be/%@?t=%d", capturedVideoId, seconds] : nil;
            NSString *formattedText = (capturedVideoTitle && tsLink) ? [NSString stringWithFormat:@"%@ - %@", capturedVideoTitle, tsLink] : tsLink;
            [weakSelf ytdm_copyToClipboardWithText:formattedText alertMsg:@"Copied Link with Timestamp!"];
        }];
        
        UIAction *copyDesc = [UIAction actionWithTitle:@"Copy Description" image:[UIImage systemImageNamed:@"text.justifyleft"] identifier:nil handler:^(UIAction *a) {
            [weakSelf ytdm_copyToClipboardWithText:capturedDescription alertMsg:@"Copied Description!"];
        }];
        
        UIAction *copyChannel = [UIAction actionWithTitle:@"Copy Channel Name" image:[UIImage systemImageNamed:@"person.crop.circle"] identifier:nil handler:^(UIAction *a) {
            [weakSelf ytdm_copyToClipboardWithText:capturedChannelName alertMsg:@"Copied Channel!"];
        }];
        
        UIMenu *copySubmenu = [UIMenu menuWithTitle:@"Copy Info..." image:[UIImage systemImageNamed:@"doc.on.doc"] identifier:nil options:0 children:@[copyTitle, copyLink, copyTimestamp, copyDesc, copyChannel]];
        
        downloadBtn.menu = [UIMenu menuWithTitle:@"YTDM Suite" children:@[
            videoSubmenu,
            [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[audioOnly]],
            [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[sysPlayer, dlThumb]],
            [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:@[copySubmenu]]
        ]];
    }
}

%new
- (UIViewController *)ytdm_parentViewController {
    UIResponder *responder = self;
    while ([responder nextResponder]) {
        responder = [responder nextResponder];
        if ([responder isKindOfClass:[UIViewController class]]) return (UIViewController *)responder;
    }
    return nil;
}

%new
- (void)ytdm_triggerSilentDownloadWithQuality:(NSString *)quality isAudio:(BOOL)isAudio {
    if (capturedVideoId.length == 0) { [[YTDMProgressHUD sharedHUD] showError:@"No video detected."]; return; }
    
    [[YTDMProgressHUD sharedHUD] showInView:getKeyWindow()];
    [[YTDownloadManagerService sharedInstance] requestDownloadForVideoId:capturedVideoId isAudio:isAudio quality:quality completion:^(NSArray<NSURL *> *localURLs, NSString *errorMsg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!localURLs) { [[YTDMProgressHUD sharedHUD] showError:errorMsg]; return; }
            [[YTDMProgressHUD sharedHUD] showSuccessWithStatus:@"Download complete!"];
            [self ytdm_presentSaveOptionsForURLs:localURLs isAudio:isAudio];
        });
    }];
}

%new
- (void)ytdm_presentSaveOptionsForURLs:(NSArray<NSURL *> *)outURLs isAudio:(BOOL)isAudio {
    UIViewController *topController = [self ytdm_parentViewController] ?: getTopMostController();
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"File Ready!" message:@"Where would you like to save the file?" preferredStyle:UIAlertControllerStyleActionSheet];
    
    if (!isAudio) {
        NSURL *outURL = outURLs.firstObject;
        UIAlertAction *saveToPhotos = [UIAlertAction actionWithTitle:@"Save to Photos (Camera Roll)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [[YTDMProgressHUD sharedHUD] showInView:getKeyWindow()];
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:outURL];
            } completionHandler:^(BOOL success, NSError *err) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) [[YTDMProgressHUD sharedHUD] showSuccessWithStatus:@"Saved to Gallery!"];
                    else [[YTDMProgressHUD sharedHUD] showError:@"Gallery save failed."];
                    [[NSFileManager defaultManager] removeItemAtURL:outURL error:nil];
                });
            }];
        }];
        [actionSheet addAction:saveToPhotos];
    }
    
    UIAlertAction *saveToFiles = [UIAlertAction actionWithTitle:@"📁 Save to Files App" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        if (@available(iOS 14.0, *)) {
            UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForExportingURLs:outURLs asCopy:YES];
            picker.delegate = (id<UIDocumentPickerDelegate>)self;
            objc_setAssociatedObject(picker, &kAssociatedOutURLKey, outURLs, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [topController presentViewController:picker animated:YES completion:nil];
        } else {
            [self ytdm_presentShareSheetForURLs:outURLs];
        }
    }];
    [actionSheet addAction:saveToFiles];
    
    UIAlertAction *openShare = [UIAlertAction actionWithTitle:@"📤 Open Share Sheet" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [self ytdm_presentShareSheetForURLs:outURLs];
    }];
    [actionSheet addAction:openShare];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a) {
        for (NSURL *url in outURLs) [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    }];
    [actionSheet addAction:cancel];
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        UIButton *btn = [self viewWithTag:9912];
        actionSheet.popoverPresentationController.sourceView = btn ?: topController.view;
        actionSheet.popoverPresentationController.sourceRect = btn ? btn.bounds : topController.view.bounds;
    }
    [topController presentViewController:actionSheet animated:YES completion:nil];
}

%new
- (void)ytdm_presentShareSheetForURLs:(NSArray<NSURL *> *)outURLs {
    UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:outURLs applicationActivities:nil];
    share.completionWithItemsHandler = ^(UIActivityType actType, BOOL completed, NSArray *retItems, NSError *err) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            for (NSURL *url in outURLs) [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        });
    };
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        UIButton *btn = [self viewWithTag:9912];
        share.popoverPresentationController.sourceView = btn ?: getTopMostController().view;
        share.popoverPresentationController.sourceRect = btn ? btn.bounds : getTopMostController().view.bounds;
    }
    [[self ytdm_parentViewController] ?: getTopMostController() presentViewController:share animated:YES completion:nil];
}

%new
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSArray<NSURL *> *outURLs = objc_getAssociatedObject(controller, &kAssociatedOutURLKey);
    if (outURLs) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            for (NSURL *url in outURLs) [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
        });
    }
}

%new
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
    NSArray<NSURL *> *outURLs = objc_getAssociatedObject(controller, &kAssociatedOutURLKey);
    if (outURLs) { for (NSURL *url in outURLs) [[NSFileManager defaultManager] removeItemAtURL:url error:nil]; }
}

%new
- (void)ytdm_playInSystemPlayer {
    if (capturedVideoId.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{ [[YTDMProgressHUD sharedHUD] showError:@"No video detected."]; });
        return;
    }
    
    [[YTDMProgressHUD sharedHUD] showInView:getKeyWindow()];
    [[YTDownloadManagerService sharedInstance] requestStreamURLForVideoId:capturedVideoId completion:^(NSString *streamURL, NSString *errorMsg) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!streamURL) { [[YTDMProgressHUD sharedHUD] showError:errorMsg]; return; }
            [[YTDMProgressHUD sharedHUD] showSuccessWithStatus:@"Playing..."];
            
            AVPlayer *p = [AVPlayer playerWithURL:[NSURL URLWithString:streamURL]];
            AVPlayerViewController *vc = [[AVPlayerViewController alloc] init];
            vc.player = p; vc.entersFullScreenWhenPlaybackBegins = YES;
            vc.allowsPictureInPicturePlayback = YES;
            
            UIViewController *topController = [self ytdm_parentViewController] ?: getTopMostController();
            [topController presentViewController:vc animated:YES completion:^{ [p play]; }];
        });
    }];
}

%new
- (void)ytdm_downloadThumbnailToPhotos {
    if (capturedVideoId.length == 0) return;
    [[YTDMProgressHUD sharedHUD] showInView:getKeyWindow()];
    NSString *url = [NSString stringWithFormat:@"https://img.youtube.com/vi/%@/hqdefault.jpg", capturedVideoId];
    [[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        UIImage *img = [UIImage imageWithData:d];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (img) {
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{ [PHAssetChangeRequest creationRequestForAssetFromImage:img]; } completionHandler:^(BOOL s, NSError *err) {
                    dispatch_async(dispatch_get_main_queue(), ^{ if (s) [[YTDMProgressHUD sharedHUD] showSuccessWithStatus:@"Saved Thumbnail!"]; else [[YTDMProgressHUD sharedHUD] showError:@"Save failed."]; });
                }];
            } else { [[YTDMProgressHUD sharedHUD] showError:@"Not found."]; }
        });
    }] resume];
}

%new
- (void)ytdm_copyToClipboardWithText:(NSString *)text alertMsg:(NSString *)alertMsg {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (text && text.length > 0) {
            [UIPasteboard generalPasteboard].string = text;
            [[YTDMProgressHUD sharedHUD] showSuccessWithStatus:alertMsg];
        } else {
            [[YTDMProgressHUD sharedHUD] showError:@"Metadata unavailable."];
        }
    });
}
%end

// ============================================================================
// ATS BYPASS (PREVENTS CRASHES)
// ============================================================================
%hook NSBundle
- (NSDictionary *)infoDictionary {
    NSDictionary *origDict = %orig;
    if (origDict) {
        if (origDict[@"NSAppTransportSecurity"] && [origDict[@"NSAppTransportSecurity"][@"NSAllowsArbitraryLoads"] boolValue]) {
            return origDict;
        }
        NSMutableDictionary *m = [origDict mutableCopy];
        NSMutableDictionary *ats = [m[@"NSAppTransportSecurity"] mutableCopy] ?: [NSMutableDictionary dictionary];
        ats[@"NSAllowsArbitraryLoads"] = @YES;
        m[@"NSAppTransportSecurity"] = ats;
        return m;
    }
    return origDict;
}
%end
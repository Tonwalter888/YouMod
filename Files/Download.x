#import "Headers.h"

@interface YouModMenuItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, strong) UIImage *iconImage;
@property (nonatomic, copy) void (^handler)(void);
+ (instancetype)itemWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(UIImage *)icon handler:(void (^)(void))handler;
@end

@implementation YouModMenuItem
+ (instancetype)itemWithTitle:(NSString *)title subtitle:(NSString *)subtitle icon:(UIImage *)icon handler:(void (^)(void))handler {
    YouModMenuItem *item = [YouModMenuItem new];
    item.title = title;
    item.subtitle = subtitle;
    item.iconImage = icon;
    item.handler = handler;
    return item;
}
@end

typedef void (^YouModFileDownloadCompletion)(NSURL *fileURL, NSError *error);
typedef void (^YouModMergeCompletion)(BOOL success, NSError *error);
typedef void (^YouModRangeDownloadProgress)(unsigned long long completedBytes);

YTPlayerViewController *YouModCurrentPlayerViewController = nil;

static YTIPlayerResponse *YouModPlayerDataForPlayer(YTPlayerViewController *player) {
    YTPlayerResponse *response;
    if ([player respondsToSelector:@selector(contentPlayerResponse)]) {
        response = player.contentPlayerResponse;
    } else {
        response = player.playerResponse;
    }
    YTIPlayerResponse *playerData = response.playerData;
    return playerData;
}

static YTIVideoDetails *YouModVideoDetailsForPlayer(YTPlayerViewController *player) {
    YTIPlayerResponse *ires = YouModPlayerDataForPlayer(player);
    return ires.videoDetails;
}

NSString *YouModAuthorForPlayer(YTPlayerViewController *player) {
    YTIVideoDetails *details = YouModVideoDetailsForPlayer(player);
    return details.author;
}

NSString *YouModTitleForPlayer(YTPlayerViewController *player) {
    YTIVideoDetails *details = YouModVideoDetailsForPlayer(player);
    return details.title;
}

NSString *YouModVideoIDForPlayer(YTPlayerViewController *player) {
    YTIVideoDetails *details = YouModVideoDetailsForPlayer(player);
    return details.videoId;
}

static NSString *YouModDescriptionForPlayer(YTPlayerViewController *player) {
    YTIVideoDetails *details = YouModVideoDetailsForPlayer(player);
    return details.shortDescription;
}

NSURL *YouModThumbnailURL(YTPlayerViewController *player) {
    if (!player) return nil;
    YTIVideoDetails *details = YouModVideoDetailsForPlayer(player);
    YTIThumbnailDetails *thumbmain = details.thumbnail;
    YTIThumbnailDetails_Thumbnail *bestThumbnail = nil;
    NSUInteger maxPixels = 0;
    
    for (YTIThumbnailDetails_Thumbnail *thumb in thumbmain.thumbnailsArray) {
        NSUInteger pixels = (NSUInteger)thumb.width * (NSUInteger)thumb.height;
        if (pixels > maxPixels) {
            maxPixels = pixels;
            bestThumbnail = thumb;
        }
    }

    return [NSURL URLWithString:bestThumbnail.URL];
}

static id parentResponder = nil;

static void YouModPresentMenu(YTPlayerViewController *player, NSArray <YouModMenuItem *> *items, UIViewController *presenter, UIView *sender) {
    YTDefaultSheetController *sheet = [%c(YTDefaultSheetController) sheetControllerWithParentResponder:parentResponder];
    for (YouModMenuItem *item in items) {
        YTActionSheetAction *action;
        if (item.subtitle == nil) {
            action = [%c(YTActionSheetAction) actionWithTitle:item.title iconImage:item.iconImage style:0 handler:^(__unused YTActionSheetAction *action) {
                item.handler();
            }];
        } else {
            action = [%c(YTActionSheetAction) actionWithTitle:item.title subtitle:item.subtitle iconImage:item.iconImage handler:^(__unused YTActionSheetAction *action) {
                item.handler();
            }];
        }
        [sheet addAction:action];
    }
    if (player && player != nil) {
        [sheet addHeaderWithTitle:YouModAuthorForPlayer(player) subtitle:YouModTitleForPlayer(player)];
    }
    if (sender) {
        [sheet presentFromView:sender animated:YES completion:nil];
    } else {
        [sheet presentFromViewController:presenter animated:YES completion:nil];
    }
}


static void YouModShowThumbnailViewer(YTPlayerViewController *player, UIViewController *presenter) {
    NSURL *thumbnailURL = YouModThumbnailURL(player);
    if (!thumbnailURL) {
        YouModSendError(LOC(@"NO_THUMBNAIL_FOUND"));
        return;
    }

    [[NSURLSession.sharedSession dataTaskWithURL:thumbnailURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        UIImage *image = data ? [UIImage imageWithData:data] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!image || error) {
                YouModSendError(error.localizedDescription ?: LOC(@"THUMBNAIL_FAILED"));
                return;
            }
            
            YouModThumbnailViewController *viewerVC = [[YouModThumbnailViewController alloc] init];
            viewerVC.thumbnailImage = image;
            viewerVC.modalPresentationStyle = UIModalPresentationFormSheet;
            viewerVC.modalTransitionStyle = UIModalTransitionStyleCoverVertical; 
            
            [presenter presentViewController:viewerVC animated:YES completion:nil];
        });
    }] resume];
}

static void YouModCopyThumbnail(YTPlayerViewController *player, UIViewController *presenter) {
    NSURL *thumbnailURL = YouModThumbnailURL(player);
    if (!thumbnailURL) {
        YouModSendError(LOC(@"NO_THUMBNAIL_FOUND"));
        return;
    }

    YouModSendToast(LOC(@"DOWNLOADING_THUMBNAIL"));
    [[NSURLSession.sharedSession dataTaskWithURL:thumbnailURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        UIImage *image = data ? [UIImage imageWithData:data] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!image || error) {
                YouModSendError(error.localizedDescription ?: LOC(@"THUMBNAIL_FAILED"));
                return;
            }
            [[UIPasteboard generalPasteboard] setImage:image];
            YouModSendSuccess(LOC(@"COPIED_TO_CLIPBOARD"));
        });
    }] resume];
}

static void YouModDownloadThumbnail(YTPlayerViewController *player, UIViewController *presenter) {
    NSURL *thumbnailURL = YouModThumbnailURL(player);
    if (!thumbnailURL) {
        YouModSendError(LOC(@"NO_THUMBNAIL_FOUND"));
        return;
    }

    YouModSendToast(LOC(@"DOWNLOADING_THUMBNAIL"));
    [[NSURLSession.sharedSession dataTaskWithURL:thumbnailURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        UIImage *image = data ? [UIImage imageWithData:data] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!image || error) {
                YouModSendError(error.localizedDescription ?: LOC(@"THUMBNAIL_FAILED"));
                return;
            }
            YouModHandlePostDownloadImage(image, presenter);
        });
    }] resume];
}

static void YouModCopyTextToPasteboard(NSString *text, NSString *successKey) {
    UIPasteboard.generalPasteboard.string = text;
    YouModSendSuccess(LOC(successKey));
}

static void YouModCopyImageToPasteboard(UIImage *image, NSString *successKey) {
    UIPasteboard.generalPasteboard.image = image;
    YouModSendSuccess(LOC(successKey));
}

static void YouModShowCopyVideoInfoSheet(YTPlayerViewController *player, UIViewController *presenter, UIView *sender) {
    NSString *author = YouModAuthorForPlayer(player);
    NSString *title = YouModTitleForPlayer(player);
    NSString *description = YouModDescriptionForPlayer(player);
    NSString *all = [NSString stringWithFormat:@"%@ - %@\n%@", author, title, description];

    NSMutableArray *items = [NSMutableArray array];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_ALL_VID_INFO") subtitle:nil icon:YouModYTIconImage(250, NO, nil) handler:^{
        YouModCopyTextToPasteboard(all, @"COPIED_VID_INFO");
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_AUTHOR") subtitle:nil icon:YouModYTIconImage(250, NO, nil) handler:^{
        YouModCopyTextToPasteboard(author, @"COPIED_AUTHOR");
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_TITLE") subtitle:nil icon:YouModYTIconImage(250, NO, nil) handler:^{
        YouModCopyTextToPasteboard(title, @"COPIED_TITLE");
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_DESCRIPTION") subtitle:nil icon:YouModYTIconImage(250, NO, nil) handler:^{
        YouModCopyTextToPasteboard(description, @"COPIED_DESCRIPTION");
    }]];

    YouModPresentMenu(nil, items, presenter, sender);
}

static void YouModShowThumbnailSheet(YTPlayerViewController *player, UIViewController *presenter, UIView *sender) {
    NSMutableArray *items = [NSMutableArray array];

    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"SAVE_THUMBNAIL") subtitle:nil icon:YouModYTIconImage(57, NO, nil) handler:^{
        YouModDownloadThumbnail(player, presenter);
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"SHOW_THUMBNAIL") subtitle:nil icon:YouModYTIconImage(208, NO, nil) handler:^{
        YouModShowThumbnailViewer(player, presenter);
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_THUMBNAIL") subtitle:nil icon:YouModYTIconImage(250, NO, nil) handler:^{
        YouModCopyThumbnail(player, presenter);
    }]];

    YouModPresentMenu(nil, items, presenter, sender);
}

static void YouModShowDownloadManager(YTPlayerViewController *player, UIViewController *presenter, UIView *sender, BOOL isShorts) {
    if (!player) {
        YouModSendError(LOC(@"OPEN_VID_BEFORE"));
        return;
    }
    NSMutableArray *items = [NSMutableArray array];
    YTSingleVideoController *sgvidcon = player.activeVideo;
    YTSingleVideo *sgvid = sgvidcon.singleVideo;

    if (!sgvid.isLivePlayback) {
        [items addObject:[YouModMenuItem itemWithTitle:LOC(@"DOWNLOAD_TO_PHOTOS") subtitle:nil icon:YouModYTIconImage(57, NO, nil) handler:^{
            [YMDownloadSheet presentForPlayer:player destination:YMDownloadDestinationPhotos presenter:presenter];
        }]];
        [items addObject:[YouModMenuItem itemWithTitle:LOC(@"DOWNLOAD_TO_FILES") subtitle:LOC(@"DOWNLOAD_TO_FILES_DESC") icon:YouModYTIconImage(isShorts ? 769 : 658, NO, nil) handler:^{
            [YMDownloadSheet presentForPlayer:player destination:YMDownloadDestinationFiles presenter:presenter];
        }]];
    }
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"DOWNLOAD_THUMBNAIL") subtitle:nil icon:YouModYTIconImage(367, NO, nil) handler:^{
        YouModShowThumbnailSheet(player, presenter, sender);
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_VID_INFO") subtitle:nil icon:YouModYTIconImage(250, NO, nil) handler:^{
        YouModShowCopyVideoInfoSheet(player, presenter, sender);
    }]];
    YouModPresentMenu(player, items, presenter, sender);
}

%hook YTPlayerViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    YouModCurrentPlayerViewController = self;
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    if (YouModCurrentPlayerViewController == self)
        YouModCurrentPlayerViewController = nil;
}

%end

NSString *YouModGlobalAuthHeader = nil;

%hook SSOAuthorization
- (id)accessToken {
    id token = %orig;
    if ([token isKindOfClass:[NSString class]] && [(NSString *)token length] > 0) {
        YouModGlobalAuthHeader = [NSString stringWithFormat:@"Bearer %@", token];
    }
    return token;
}
%end

%hook SSOAuthorizationImpl
- (id)accessToken {
    id token = %orig;
    if ([token isKindOfClass:[NSString class]] && [(NSString *)token length] > 0) {
        YouModGlobalAuthHeader = [NSString stringWithFormat:@"Bearer %@", token];
    }
    return token;
}
%end

%hook GNPSSOAuthorizationService
- (id)authToken {
    id token = %orig;
    if ([token isKindOfClass:[NSString class]] && [(NSString *)token length] > 0) {
        YouModGlobalAuthHeader = [NSString stringWithFormat:@"Bearer %@", token];
    }
    return token;
}
%end

void YouModConfigureDownloadButton(_ASDisplayView *view, NSString *iden) {
    if (!IS_ENABLED(DownloadManager) || INTFORVAL(DownloadButtonPosition) == DownloadButtonPositionOverlay) return;
    if ([iden isEqualToString:@"id.ui.add_to.offline.button"]) {
        view.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:view action:@selector(YouModDownloadButtonTapped:)];
        tap.cancelsTouchesInView = YES;
        tap.delaysTouchesBegan = YES;
        tap.delaysTouchesEnded = YES;
        [view addGestureRecognizer:tap];
        objc_setAssociatedObject(view, @selector(YouModDownloadButtonTapped:), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if ([iden isEqualToString:@"id.elements.list_item"]) {
        NSString *desc = nil;
        @try {
            desc = [[[view.keepalive_node.nodeController performSelector:@selector(owningComponent)] performSelector:@selector(owningComponent)] description];
        } @catch (id ex) {
            return;
        }
        if ([desc containsString:@"download_button_inner.eml"]) {
            view.userInteractionEnabled = YES;
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:view action:@selector(YouModHandleNewDownloadButtonTapped:)];
            tap.cancelsTouchesInView = YES;
            tap.delaysTouchesBegan = YES;
            tap.delaysTouchesEnded = YES;
            [view addGestureRecognizer:tap];
            view.currentDownloadButton = view;
            objc_setAssociatedObject(view, @selector(YouModHandleNewDownloadButtonTapped:), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}

static void YouModShowTranslationDialog(NSString *text, UIViewController *presenter) {
    if (!text || text.length == 0 || !presenter) return;
    
    YouModTranslationViewController *vc = [[YouModTranslationViewController alloc] init];
    vc.originalText = text;
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    
    if ([nav respondsToSelector:@selector(sheetPresentationController)]) {
        UISheetPresentationController *sheet = nav.sheetPresentationController;
        if (sheet) {
            sheet.detents = @[ 
                [UISheetPresentationControllerDetent mediumDetent],
                [UISheetPresentationControllerDetent largeDetent]
            ];
            sheet.prefersGrabberVisible = YES;
            sheet.preferredCornerRadius = 24.0;
        }
    } else {
        // Fallback for iOS 14
        nav.modalPresentationStyle = UIModalPresentationFormSheet;
    }
    [presenter presentViewController:nav animated:YES completion:nil];
}

static NSString *YouModExtractCommentText(UIView *cellView, BOOL isPost) {
    NSString *resultText = nil;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:cellView];

    while (queue.count > 0) {
        UIView *current = queue.firstObject;
        [queue removeObjectAtIndex:0];

        if ([current isKindOfClass:%c(_ASDisplayView)]) {
            if (!isPost) {
                BOOL isCommentLabel = [current.accessibilityIdentifier isEqualToString:@"id.comment.content.label"];
                if (isCommentLabel) {
                    resultText = current.accessibilityLabel;
                    break;
                }
                ASDisplayNode *node = [current performSelector:@selector(keepalive_node)];
                if (![node isKindOfClass:%c(ELMTextNode)]) {
                    for (id child in node.yogaChildren) {
                        if ([child isKindOfClass:%c(ELMTextNode)]) {
                            node = child;
                            break;
                        }
                    }
                }
                if ([[node description] containsString:@"id.comment.content.label"]) {
                    NSAttributedString *strings = [node valueForKey:@"_attributedText"];
                    resultText = strings.string;
                    break;
                }
            } else {
                ASDisplayNode *node = [current performSelector:@selector(keepalive_node)];
                if (![node isKindOfClass:%c(ELMTextNode)]) {
                    for (id child in node.yogaChildren) {
                        if ([child isKindOfClass:%c(ELMTextNode)]) {
                            node = child;
                            break;
                        }
                    }
                }
                NSString *desc = nil;
                @try {
                    desc = [[[[node nodeController] performSelector:@selector(parent)] performSelector:@selector(owningComponent)] description];
                } @catch (id ex) {}
                if (desc != nil && [desc containsString:@"post_text.eml"]) {
                    NSAttributedString *strings = [node valueForKey:@"_attributedText"];
                    resultText = strings.string;
                    break;
                }
            }
        }

        [queue addObjectsFromArray:current.subviews];
    }

    return resultText;
}

static UIImage *YouModRenderViewToImage(_ASDisplayView *view) {
    if (!view || view.bounds.size.width <= 0 || view.bounds.size.height <= 0) return nil;
    
    UIColor *realBgColor = isDarkMode(view) ? [%c(YTColor) black3] : [%c(YTColor) white1];  
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, [UIScreen mainScreen].scale);
    CGContextRef context = UIGraphicsGetCurrentContext();    
    [realBgColor setFill];
    CGContextFillRect(context, view.bounds);
    [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();    
    return image;
}

/*
static UIImage *YouModExtractPostImage(UIView *cellView) {
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:cellView];
    Class asDisplayClass = NSClassFromString(@"_ASDisplayView");
    Class imageZoomNodeClass = NSClassFromString(@"YTImageZoomNode");
    UIView *targetViewForRender = nil;

    while (queue.count > 0) {
        UIView *current = queue.firstObject;
        [queue removeObjectAtIndex:0];

        if (asDisplayClass && [current isKindOfClass:asDisplayClass]) {
            id node = [current performSelector:@selector(keepalive_node)];
            
            if (imageZoomNodeClass && [node isKindOfClass:imageZoomNodeClass]) {
                if (!targetViewForRender) {
                    targetViewForRender = current;
                }
            }
        }

        @synchronized (current) {
            [queue addObjectsFromArray:current.subviews];
        }
    }

    if (targetViewForRender && targetViewForRender.bounds.size.width > 0 && targetViewForRender.bounds.size.height > 0) {
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:targetViewForRender.bounds.size];
        return [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
            [targetViewForRender.layer renderInContext:rendererContext.CGContext];
        }];
    }

    return nil;
}
*/

void YouModSetupDownloadGestures(_ASDisplayView *view, NSString *iden) {
    if ([iden isEqualToString:@"id.ui.comment_cell"] && IS_ENABLED(DownloadComment)) {
        BOOL hasGesture = NO;
        for (UIGestureRecognizer *g in view.gestureRecognizers) {
            if ([g.name isEqualToString:@"YouModCommentLongPress"]) {
                hasGesture = YES;
                break;
            }
        }
        
        if (!hasGesture) {
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:view action:@selector(YouModHandleCommentLongPress:)];
            longPress.name = @"YouModCommentLongPress";
            longPress.minimumPressDuration = 0.3;
            [view addGestureRecognizer:longPress];
        }
    } else if ([iden isEqualToString:@"id.ui.backstage.original_post"] && IS_ENABLED(DownloadPost)) {
        BOOL hasGesture = NO;
        for (UIGestureRecognizer *g in view.gestureRecognizers) {
            if ([g.name isEqualToString:@"YouModPostLongPress"]) {
                hasGesture = YES;
                break;
            }
        }
        
        if (!hasGesture) {
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:view action:@selector(YouModHandlePostLongPress:)];
            longPress.name = @"YouModPostLongPress";
            longPress.minimumPressDuration = 0.3;
            [view addGestureRecognizer:longPress];
        }
    }
}

void YouModHandleCommentLongPressAction(_ASDisplayView *view) {
    NSMutableArray *items = [NSMutableArray array];
    NSString *commentText = YouModExtractCommentText(view, NO);

    if (commentText && commentText.length > 0) {
        [items addObject:[YouModMenuItem itemWithTitle:LOC(@"TRANSLATE_COMMENT") subtitle:nil icon:YouModYTIconImage(897, NO, nil) handler:^{
            UIViewController *presenter = view._viewControllerForAncestor;
            YouModShowTranslationDialog(commentText, presenter);
        }]];

        [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_COMMENT_TEXT") subtitle:nil icon:YouModYTIconImage(243, NO, nil) handler:^{
            YouModCopyTextToPasteboard(commentText, @"COPIED_TO_CLIPBOARD");
        }]];
    }

    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"SAVE_COMMENT_IMAGE") subtitle:nil icon:YouModYTIconImage(367, NO, nil) handler:^{
        UIImage *image = YouModRenderViewToImage(view);
        if (image) {
            UIViewController *p = view._viewControllerForAncestor;
            YouModHandlePostDownloadImage(image, p);
        }
    }]];

    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_COMMENT_IMAGE") subtitle:nil icon:YouModYTIconImage(208, NO, nil) handler:^{
        UIImage *image = YouModRenderViewToImage(view);
        if (image) {
            YouModCopyImageToPasteboard(image, @"COPIED_TO_CLIPBOARD");
        }
    }]];

    UIViewController *presenter = view._viewControllerForAncestor;
    if (!presenter) return;

    YouModPresentMenu(nil, items, presenter, view);
}

void YouModHandlePostLongPressAction(_ASDisplayView *view) {
    NSMutableArray *items = [NSMutableArray array];
    NSString *postText = YouModExtractCommentText(view, YES);

    if (postText && postText.length > 0) {
        [items addObject:[YouModMenuItem itemWithTitle:LOC(@"TRANSLATE_POST") subtitle:nil icon:YouModYTIconImage(897, NO, nil) handler:^{
            UIViewController *presenter = view._viewControllerForAncestor;
            YouModShowTranslationDialog(postText, presenter);
        }]];

        [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_POST_TEXT") subtitle:nil icon:YouModYTIconImage(243, NO, nil) handler:^{
            YouModCopyTextToPasteboard(postText, @"COPIED_TO_CLIPBOARD");
        }]];
    }

    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"SAVE_POST_IMAGE") subtitle:nil icon:YouModYTIconImage(367, NO, nil) handler:^{
        UIImage *image = YouModRenderViewToImage(view);
        if (image) {
            UIViewController *p = view._viewControllerForAncestor;
            YouModHandlePostDownloadImage(image, p);
        }
    }]];

    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_POST_IMAGE") subtitle:nil icon:YouModYTIconImage(208, NO, nil) handler:^{
        UIImage *image = YouModRenderViewToImage(view);
        if (image) {
            YouModCopyImageToPasteboard(image, @"COPIED_TO_CLIPBOARD");
        }
    }]];

    UIViewController *presenter = view._viewControllerForAncestor;
    if (!presenter) return;

    YouModPresentMenu(nil, items, presenter, view);
}

void YouModHandleDownloadButtonAction(_ASDisplayView *view) {
    UIViewController *presenter = view._viewControllerForAncestor;
    parentResponder = [presenter valueForKey:@"_parentResponder"];
    YouModShowDownloadManager(YouModCurrentPlayerViewController, presenter, view, NO);
}

%hook YTReelWatchPlaybackOverlayView
- (void)layoutSubviews {
    %orig;
    if (!IS_ENABLED(AddDownloadToShorts)) return;
    YTQTMButton *downloadBtn = (YTQTMButton *)[self viewWithTag:1501];
    if (!downloadBtn) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
        UIImage *icon = [UIImage systemImageNamed:@"arrow.down.circle" withConfiguration:config];
        downloadBtn = [%c(YTQTMButton) iconButton];
        [downloadBtn setImage:icon forState:UIControlStateNormal];
        [downloadBtn setTintColor:[UIColor whiteColor]];
        downloadBtn.exclusiveTouch = YES;
        downloadBtn.tag = 1501;
        [downloadBtn addTarget:self action:@selector(didTapYouModShortsDownload:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:downloadBtn];
    }
    CGFloat btnWidth = 64.0;
    CGFloat btnHeight = 60.0;
    YTReelElementAsyncComponentView *pov = nil;
    @try {
        pov = [self valueForKey:@"_playerOverlayView"];
    } @catch (...) {}
    YTReelElementAsyncComponentView *actionBar = [self valueForKey:@"_actionBarComponentView"];
    CGFloat X = actionBar.frame.origin.x;
    CGFloat Y = 0.0;
    if (pov == nil) {
        Y = actionBar.frame.origin.y - 76.0;
        btnHeight = btnHeight + 16.0;
    } else {
        Y = pov.frame.origin.y - 60.0;
        [downloadBtn enableNewTouchFeedback];
    }
    downloadBtn.frame = CGRectMake(X, Y, btnWidth, btnHeight);
    [self bringSubviewToFront:downloadBtn];
}
%new
- (void)didTapYouModShortsDownload:(YTQTMButton *)button {
    YTShortsPlayerViewController *shortsPlayerView = (YTShortsPlayerViewController *)self._viewControllerForAncestor;
    YTPlayerViewController *player = (YTPlayerViewController *)shortsPlayerView.childViewControllers[0];
    UIViewController *presenter = button._viewControllerForAncestor;
    parentResponder = [presenter valueForKey:@"_parentResponder"];
    YouModShowDownloadManager(player, presenter, button, YES);
}
%end

%ctor {
    %init;
    YMOverlayButtonSpec *download = [[YMOverlayButtonSpec alloc] init];
    download.identifier = @"download.video";
    download.symbolName = @"arrow.down.circle";
    download.settingsSymbolName = @"arrow.down.circle";
    download.displayName = LOC(@"DOWNLOAD_BUTTON");
    download.sortOrder = 200;
    download.isVisible = ^BOOL(YTPlayerViewController *player) {
        return YMIsOverlayButtonEnabled(@"download.video");
    };
    download.onTap = ^(YTPlayerViewController *player, UIButton *button) {
        UIViewController *presenter = button._viewControllerForAncestor;
        parentResponder = [presenter valueForKey:@"_parentResponder"];
        YouModShowDownloadManager(YouModCurrentPlayerViewController, presenter, button, NO);
    };
    YMRegisterOverlayButton(download);
}

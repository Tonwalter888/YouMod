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

@protocol YouModDownloadComponentAccess
- (id)parent;
- (id)owningComponent;
@end

@interface YouModDownloadActions : NSObject
+ (YTIPlayerResponse *)playerDataForPlayer:(YTPlayerViewController *)player;
+ (YTIVideoDetails *)videoDetailsForPlayer:(YTPlayerViewController *)player;
+ (NSString *)authorForPlayer:(YTPlayerViewController *)player;
+ (NSString *)titleForPlayer:(YTPlayerViewController *)player;
+ (NSString *)videoIDForPlayer:(YTPlayerViewController *)player;
+ (NSString *)descriptionForPlayer:(YTPlayerViewController *)player;
+ (NSURL *)thumbnailURLForPlayer:(YTPlayerViewController *)player;
+ (void)presentMenuForPlayer:(YTPlayerViewController *)player items:(NSArray<YouModMenuItem *> *)items presenter:(UIViewController *)presenter sender:(UIView *)sender;
+ (void)showThumbnailViewerForPlayer:(YTPlayerViewController *)player presenter:(UIViewController *)presenter;
+ (void)copyThumbnailForPlayer:(YTPlayerViewController *)player presenter:(UIViewController *)presenter;
+ (void)downloadThumbnailForPlayer:(YTPlayerViewController *)player presenter:(UIViewController *)presenter;
+ (void)copyTextToPasteboard:(NSString *)text successKey:(NSString *)successKey;
+ (void)copyImageToPasteboard:(UIImage *)image successKey:(NSString *)successKey;
+ (void)showCopyVideoInfoSheetForPlayer:(YTPlayerViewController *)player presenter:(UIViewController *)presenter sender:(UIView *)sender;
+ (void)showThumbnailSheetForPlayer:(YTPlayerViewController *)player presenter:(UIViewController *)presenter sender:(UIView *)sender;
+ (void)showDownloadManagerForPlayer:(YTPlayerViewController *)player presenter:(UIViewController *)presenter sender:(UIView *)sender isShorts:(BOOL)isShorts;
@end

@interface YouModDownloadActions (ContentActions)
+ (void)configureDownloadButtonForView:(_ASDisplayView *)view identifier:(NSString *)identifier;
+ (void)showTranslationDialog:(NSString *)text presenter:(UIViewController *)presenter;
+ (NSString *)extractCommentTextFromView:(UIView *)cellView isPost:(BOOL)isPost;
+ (UIImage *)renderImageFromView:(_ASDisplayView *)view;
+ (void)setupDownloadGesturesForView:(_ASDisplayView *)view identifier:(NSString *)identifier;
+ (void)handleCommentLongPressForView:(_ASDisplayView *)view;
+ (void)handlePostLongPressForView:(_ASDisplayView *)view;
+ (void)handleDownloadButtonForView:(_ASDisplayView *)view;
@end

YTPlayerViewController *YouModCurrentPlayerViewController = nil;
static id YouModDownloadParentResponder = nil;

#pragma mark - Player and download menu actions

@implementation YouModDownloadActions

+ (YTIPlayerResponse *)playerDataForPlayer:(YTPlayerViewController *)player {
    YTPlayerResponse *response;
    // YouTube has exposed both response properties across app versions.
    if ([player respondsToSelector:@selector(contentPlayerResponse)]) {
        response = player.contentPlayerResponse;
    } else {
        response = player.playerResponse;
    }
    YTIPlayerResponse *playerData = response.playerData;
    return playerData;
}

+ (YTIVideoDetails *)videoDetailsForPlayer:(YTPlayerViewController *)player {
    YTIPlayerResponse *ires = [self playerDataForPlayer:player];
    return ires.videoDetails;
}

+ (NSString *)authorForPlayer:(YTPlayerViewController *)player {
    YTIVideoDetails *details = [self videoDetailsForPlayer:player];
    return details.author;
}

+ (NSString *)titleForPlayer:(YTPlayerViewController *)player {
    YTIVideoDetails *details = [self videoDetailsForPlayer:player];
    return details.title;
}

+ (NSString *)videoIDForPlayer:(YTPlayerViewController *)player {
    YTIVideoDetails *details = [self videoDetailsForPlayer:player];
    return details.videoId;
}

+ (NSString *)descriptionForPlayer:(YTPlayerViewController *)player {
    YTIVideoDetails *details = [self videoDetailsForPlayer:player];
    return details.shortDescription;
}

+ (NSURL *)thumbnailURLForPlayer:(YTPlayerViewController *)player {
    if (!player) return nil;
    YTIVideoDetails *details = [self videoDetailsForPlayer:player];
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

+ (void)presentMenuForPlayer:(YTPlayerViewController *)player items:(NSArray<YouModMenuItem *> *)items presenter:(UIViewController *)presenter sender:(UIView *)sender {
    YTDefaultSheetController *sheet = [%c(YTDefaultSheetController) sheetControllerWithParentResponder:YouModDownloadParentResponder];
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
    if (player) {
        [sheet addHeaderWithTitle:[self authorForPlayer:player] subtitle:[self titleForPlayer:player]];
    }
    if (sender) {
        [sheet presentFromView:sender animated:YES completion:nil];
    } else {
        [sheet presentFromViewController:presenter animated:YES completion:nil];
    }
}


+ (void)showThumbnailViewerForPlayer:(YTPlayerViewController *)player presenter:(UIViewController *)presenter {
    NSURL *thumbnailURL = [self thumbnailURLForPlayer:player];
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

+ (void)copyThumbnailForPlayer:(YTPlayerViewController *)player presenter:(UIViewController *)presenter {
    NSURL *thumbnailURL = [self thumbnailURLForPlayer:player];
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

+ (void)downloadThumbnailForPlayer:(YTPlayerViewController *)player presenter:(UIViewController *)presenter {
    NSURL *thumbnailURL = [self thumbnailURLForPlayer:player];
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

+ (void)copyTextToPasteboard:(NSString *)text successKey:(NSString *)successKey {
    UIPasteboard.generalPasteboard.string = text;
    YouModSendSuccess(LOC(successKey));
}

+ (void)copyImageToPasteboard:(UIImage *)image successKey:(NSString *)successKey {
    UIPasteboard.generalPasteboard.image = image;
    YouModSendSuccess(LOC(successKey));
}

+ (void)showCopyVideoInfoSheetForPlayer:(YTPlayerViewController *)player presenter:(UIViewController *)presenter sender:(UIView *)sender {
    NSString *author = [self authorForPlayer:player];
    NSString *title = [self titleForPlayer:player];
    NSString *description = [self descriptionForPlayer:player];
    NSString *all = [NSString stringWithFormat:@"%@ - %@\n%@", author, title, description];

    NSMutableArray *items = [NSMutableArray array];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_ALL_VID_INFO") subtitle:nil icon:YouModYTIconImage(250, NO, nil) handler:^{
        [self copyTextToPasteboard:all successKey:@"COPIED_VID_INFO"];
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_AUTHOR") subtitle:nil icon:YouModYTIconImage(250, NO, nil) handler:^{
        [self copyTextToPasteboard:author successKey:@"COPIED_AUTHOR"];
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_TITLE") subtitle:nil icon:YouModYTIconImage(250, NO, nil) handler:^{
        [self copyTextToPasteboard:title successKey:@"COPIED_TITLE"];
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_DESCRIPTION") subtitle:nil icon:YouModYTIconImage(250, NO, nil) handler:^{
        [self copyTextToPasteboard:description successKey:@"COPIED_DESCRIPTION"];
    }]];

    [self presentMenuForPlayer:nil items:items presenter:presenter sender:sender];
}

+ (void)showThumbnailSheetForPlayer:(YTPlayerViewController *)player presenter:(UIViewController *)presenter sender:(UIView *)sender {
    NSMutableArray *items = [NSMutableArray array];

    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"SAVE_THUMBNAIL") subtitle:nil icon:YouModYTIconImage(57, NO, nil) handler:^{
        [self downloadThumbnailForPlayer:player presenter:presenter];
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"SHOW_THUMBNAIL") subtitle:nil icon:YouModYTIconImage(208, NO, nil) handler:^{
        [self showThumbnailViewerForPlayer:player presenter:presenter];
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_THUMBNAIL") subtitle:nil icon:YouModYTIconImage(250, NO, nil) handler:^{
        [self copyThumbnailForPlayer:player presenter:presenter];
    }]];

    [self presentMenuForPlayer:nil items:items presenter:presenter sender:sender];
}

+ (void)showDownloadManagerForPlayer:(YTPlayerViewController *)player presenter:(UIViewController *)presenter sender:(UIView *)sender isShorts:(BOOL)isShorts {
    if (!player) {
        YouModSendError(LOC(@"OPEN_VID_BEFORE"));
        return;
    }
    NSMutableArray *items = [NSMutableArray array];
    YTSingleVideoController *sgvidcon = player.activeVideo;
    YTSingleVideo *sgvid = sgvidcon.singleVideo;

    if (!sgvid.isLivePlayback) {
        [items addObject:[YouModMenuItem itemWithTitle:LOC(@"DOWNLOAD_TO_PHOTOS") subtitle:nil icon:YouModYTIconImage(57, NO, nil) handler:^{
            [YMDownloadSheet presentForPlayer:player destination:YMDownloadDestinationPhotos isShorts:isShorts presenter:presenter];
        }]];
        [items addObject:[YouModMenuItem itemWithTitle:LOC(@"DOWNLOAD_TO_FILES") subtitle:LOC(@"DOWNLOAD_TO_FILES_DESC") icon:YouModYTIconImage(isShorts ? 769 : 658, NO, nil) handler:^{
            [YMDownloadSheet presentForPlayer:player destination:YMDownloadDestinationFiles isShorts:isShorts presenter:presenter];
        }]];
    }
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"DOWNLOAD_THUMBNAIL") subtitle:nil icon:YouModYTIconImage(367, NO, nil) handler:^{
        [self showThumbnailSheetForPlayer:player presenter:presenter sender:sender];
    }]];
    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_VID_INFO") subtitle:nil icon:YouModYTIconImage(250, NO, nil) handler:^{
        [self showCopyVideoInfoSheetForPlayer:player presenter:presenter sender:sender];
    }]];
    [self presentMenuForPlayer:player items:items presenter:presenter sender:sender];
}

@end

NSString *YouModAuthorForPlayer(YTPlayerViewController *player) {
    return [YouModDownloadActions authorForPlayer:player];
}

NSString *YouModTitleForPlayer(YTPlayerViewController *player) {
    return [YouModDownloadActions titleForPlayer:player];
}

NSString *YouModVideoIDForPlayer(YTPlayerViewController *player) {
    return [YouModDownloadActions videoIDForPlayer:player];
}

NSURL *YouModThumbnailURL(YTPlayerViewController *player) {
    return [YouModDownloadActions thumbnailURLForPlayer:player];
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

@implementation YouModDownloadActions (ContentActions)

+ (void)configureDownloadButtonForView:(_ASDisplayView *)view identifier:(NSString *)identifier {
    if (!IS_ENABLED(DownloadManager) || INTFORVAL(DownloadButtonPosition) == DownloadButtonPositionOverlay) return;
    if ([identifier isEqualToString:@"id.ui.add_to.offline.button"]) {
        view.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:view action:@selector(YouModDownloadButtonTapped:)];
        tap.cancelsTouchesInView = YES;
        tap.delaysTouchesBegan = YES;
        tap.delaysTouchesEnded = YES;
        [view addGestureRecognizer:tap];
        objc_setAssociatedObject(view, @selector(YouModDownloadButtonTapped:), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if ([identifier isEqualToString:@"id.elements.list_item"]) {
        NSString *desc = nil;
        @try {
            id<YouModDownloadComponentAccess> nodeController = (id<YouModDownloadComponentAccess>)view.keepalive_node.nodeController;
            id firstOwner = [nodeController owningComponent];
            id<YouModDownloadComponentAccess> firstOwnerAccess = (id<YouModDownloadComponentAccess>)firstOwner;
            id secondOwner = [firstOwnerAccess owningComponent];
            desc = [secondOwner description];
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
            objc_setAssociatedObject(view, @selector(YouModHandleNewDownloadButtonTapped:), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}

#pragma mark - Community post and comment actions

+ (void)showTranslationDialog:(NSString *)text presenter:(UIViewController *)presenter {
    if (!text || text.length == 0 || !presenter) return;
    
    YouModTranslationViewController *vc = [[YouModTranslationViewController alloc] init];
    vc.originalText = text;
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    
    // Runtime version check: this toolchain can't link the @available helper.
    if ([NSProcessInfo processInfo].operatingSystemVersion.majorVersion >= 15) {
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

+ (NSString *)extractCommentTextFromView:(UIView *)cellView isPost:(BOOL)isPost {
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
                ASDisplayNode *node = ((_ASDisplayView *)current).keepalive_node;
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
                ASDisplayNode *node = ((_ASDisplayView *)current).keepalive_node;
                if (![node isKindOfClass:%c(ELMTextNode)]) {
                    for (id child in node.yogaChildren) {
                        if ([child isKindOfClass:%c(ELMTextNode)] || [child isKindOfClass:%c(ELMExpandableTextNode)]) {
                            node = child;
                            break;
                        }
                    }
                }
                NSString *desc = nil;
                @try {
                    id<YouModDownloadComponentAccess> nodeController = (id<YouModDownloadComponentAccess>)[node nodeController];
                    id parentController = [nodeController parent];
                    id<YouModDownloadComponentAccess> parentAccess = (id<YouModDownloadComponentAccess>)parentController;
                    id owningComponent = [parentAccess owningComponent];
                    desc = [owningComponent description];
                } @catch (id ex) {}
                if (desc != nil && [desc containsString:@"post_text.eml"]) {
                    if ([node isKindOfClass:%c(ELMExpandableTextNode)]) node = [node performSelector:@selector(currentTextNode)];
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

+ (UIImage *)renderImageFromView:(_ASDisplayView *)view {
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

+ (void)setupDownloadGesturesForView:(_ASDisplayView *)view identifier:(NSString *)identifier {
    if ([identifier isEqualToString:@"id.ui.comment_cell"] && IS_ENABLED(DownloadComment)) {
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
    } else if ([identifier isEqualToString:@"id.ui.backstage.original_post"] && IS_ENABLED(DownloadPost)) {
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

+ (void)handleCommentLongPressForView:(_ASDisplayView *)view {
    NSMutableArray *items = [NSMutableArray array];
    NSString *commentText = [self extractCommentTextFromView:view isPost:NO];

    if (commentText && commentText.length > 0) {
        [items addObject:[YouModMenuItem itemWithTitle:LOC(@"TRANSLATE_COMMENT") subtitle:nil icon:YouModYTIconImage(897, NO, nil) handler:^{
            UIViewController *presenter = view._viewControllerForAncestor;
            [self showTranslationDialog:commentText presenter:presenter];
        }]];

        [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_COMMENT_TEXT") subtitle:nil icon:YouModYTIconImage(243, NO, nil) handler:^{
            [self copyTextToPasteboard:commentText successKey:@"COPIED_TO_CLIPBOARD"];
        }]];
    }

    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"SAVE_COMMENT_IMAGE") subtitle:nil icon:YouModYTIconImage(367, NO, nil) handler:^{
        UIImage *image = [self renderImageFromView:view];
        if (image) {
            UIViewController *p = view._viewControllerForAncestor;
            YouModHandlePostDownloadImage(image, p);
        }
    }]];

    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_COMMENT_IMAGE") subtitle:nil icon:YouModYTIconImage(208, NO, nil) handler:^{
        UIImage *image = [self renderImageFromView:view];
        if (image) {
            [self copyImageToPasteboard:image successKey:@"COPIED_TO_CLIPBOARD"];
        }
    }]];

    UIViewController *presenter = view._viewControllerForAncestor;
    if (!presenter) return;

    [self presentMenuForPlayer:nil items:items presenter:presenter sender:view];
}

+ (void)handlePostLongPressForView:(_ASDisplayView *)view {
    NSMutableArray *items = [NSMutableArray array];
    NSString *postText = [self extractCommentTextFromView:view isPost:YES];

    if (postText && postText.length > 0) {
        [items addObject:[YouModMenuItem itemWithTitle:LOC(@"TRANSLATE_POST") subtitle:nil icon:YouModYTIconImage(897, NO, nil) handler:^{
            UIViewController *presenter = view._viewControllerForAncestor;
            [self showTranslationDialog:postText presenter:presenter];
        }]];

        [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_POST_TEXT") subtitle:nil icon:YouModYTIconImage(243, NO, nil) handler:^{
            [self copyTextToPasteboard:postText successKey:@"COPIED_TO_CLIPBOARD"];
        }]];
    }

    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"SAVE_POST_IMAGE") subtitle:nil icon:YouModYTIconImage(367, NO, nil) handler:^{
        UIImage *image = [self renderImageFromView:view];
        if (image) {
            UIViewController *p = view._viewControllerForAncestor;
            YouModHandlePostDownloadImage(image, p);
        }
    }]];

    [items addObject:[YouModMenuItem itemWithTitle:LOC(@"COPY_POST_IMAGE") subtitle:nil icon:YouModYTIconImage(208, NO, nil) handler:^{
        UIImage *image = [self renderImageFromView:view];
        if (image) {
            [self copyImageToPasteboard:image successKey:@"COPIED_TO_CLIPBOARD"];
        }
    }]];

    UIViewController *presenter = view._viewControllerForAncestor;
    if (!presenter) return;

    [self presentMenuForPlayer:nil items:items presenter:presenter sender:view];
}

+ (void)handleDownloadButtonForView:(_ASDisplayView *)view {
    UIViewController *presenter = view._viewControllerForAncestor;
    YouModDownloadParentResponder = [presenter valueForKey:@"_parentResponder"];
    [self showDownloadManagerForPlayer:YouModCurrentPlayerViewController presenter:presenter sender:view isShorts:NO];
}

@end

void YouModConfigureDownloadButton(_ASDisplayView *view, NSString *iden) {
    [YouModDownloadActions configureDownloadButtonForView:view identifier:iden];
}

void YouModSetupDownloadGestures(_ASDisplayView *view, NSString *iden) {
    [YouModDownloadActions setupDownloadGesturesForView:view identifier:iden];
}

void YouModHandleCommentLongPressAction(_ASDisplayView *view) {
    [YouModDownloadActions handleCommentLongPressForView:view];
}

void YouModHandlePostLongPressAction(_ASDisplayView *view) {
    [YouModDownloadActions handlePostLongPressForView:view];
}

void YouModHandleDownloadButtonAction(_ASDisplayView *view) {
    [YouModDownloadActions handleDownloadButtonForView:view];
}

%hook YTReelWatchRootViewController
- (void)viewDidLayoutSubviews {
    %orig;
    if (!IS_ENABLED(AddDownloadToShorts)) return;
    UIView *rootView = self.view;
    YTQTMButton *downloadBtn = (YTQTMButton *)[rootView viewWithTag:1501];
    @try {
        YTReelModel *model = [[self valueForKey:@"_playerParentPlaybackSequentialItemController"] valueForKey:@"_model"];
        if (model.videoType == 9) {
            if (downloadBtn) [downloadBtn removeFromSuperview];
            return;
        }
    } @catch (id ex) {
        if (downloadBtn) [downloadBtn removeFromSuperview];
        return;
    }
    UIView *topView = nil;
    for (UIView *sub in rootView.subviews) {
        if ([sub isKindOfClass:%c(YTReelTopBarView)] 
            || [sub isKindOfClass:%c(YTReelPausedStateCarouselView)]) {
            topView = sub;
            break;
        }
    }
    if (topView == nil) {
        if (downloadBtn) [downloadBtn removeFromSuperview];
        return;
    }
    if (!downloadBtn) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightMedium];
        UIImage *icon = [UIImage systemImageNamed:@"arrow.down.circle" withConfiguration:config];
        downloadBtn = [%c(YTQTMButton) iconButton];
        [downloadBtn setImage:icon forState:UIControlStateNormal];
        [downloadBtn setTintColor:[UIColor whiteColor]];
        downloadBtn.exclusiveTouch = YES;
        downloadBtn.tag = 1501;
        [downloadBtn addTarget:self action:@selector(didTapYouModShortsDownload:) forControlEvents:UIControlEventTouchUpInside];
        [rootView addSubview:downloadBtn];
    }
    CGRect rect = [topView convertRect:topView.bounds toView:rootView];
    downloadBtn.frame = CGRectMake(CGRectGetMaxX(rect) - 10, CGRectGetMaxY(rect) + 50, 40, 40);
    [rootView bringSubviewToFront:downloadBtn];
}
%new
- (void)didTapYouModShortsDownload:(YTQTMButton *)button {
    YTReelWatchRootViewController *presenter = (YTReelWatchRootViewController *)button._viewControllerForAncestor;
    YouModDownloadParentResponder = [presenter valueForKey:@"_parentResponder"];
    [YouModDownloadActions showDownloadManagerForPlayer:presenter.player presenter:presenter sender:button isShorts:YES];
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
        YouModDownloadParentResponder = [presenter valueForKey:@"_parentResponder"];
        [YouModDownloadActions showDownloadManagerForPlayer:YouModCurrentPlayerViewController presenter:presenter sender:button isShorts:NO];
    };
    YMRegisterOverlayButton(download);
}
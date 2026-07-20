#import <Photos/Photos.h>
#import "Headers.h"

static BOOL isPad() {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
}

@implementation YouModThumbnailViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.clipsToBounds = YES;
    container.backgroundColor = [UIColor clearColor];
    [self.view addSubview:container];

    UIImageView *bgImageView = [[UIImageView alloc] initWithImage:self.thumbnailImage];
    bgImageView.contentMode = UIViewContentModeScaleAspectFill;
    bgImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:bgImageView];

    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:blurView];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.delegate = self;
    self.scrollView.minimumZoomScale = 1.0;
    self.scrollView.maximumZoomScale = 4.0;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:self.scrollView];

    self.imageView = [[UIImageView alloc] initWithImage:self.thumbnailImage];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.scrollView addSubview:self.imageView];

    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
    doubleTap.numberOfTapsRequired = 2;
    [self.scrollView addGestureRecognizer:doubleTap];

    UIImageSymbolConfiguration *iconConfig = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightSemibold];
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [closeBtn setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:iconConfig] forState:UIControlStateNormal];
    closeBtn.tintColor = [UIColor whiteColor];
    closeBtn.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
    closeBtn.layer.cornerRadius = 25; 
    closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [closeBtn addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:closeBtn];

    UIButton *moreBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [moreBtn setImage:[UIImage systemImageNamed:@"ellipsis" withConfiguration:iconConfig] forState:UIControlStateNormal];
    moreBtn.tintColor = [UIColor whiteColor];
    moreBtn.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
    moreBtn.layer.cornerRadius = 25;
    moreBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [moreBtn addTarget:self action:@selector(moreTapped:) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:moreBtn];

    NSMutableArray *constraints = [NSMutableArray array];

    if (isPad()) {
        self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
        container.layer.cornerRadius = 16;
        
        [constraints addObject:[container.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]];
        [constraints addObject:[container.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]];
        [constraints addObject:[container.widthAnchor constraintEqualToAnchor:container.heightAnchor]];
        [constraints addObject:[container.widthAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.widthAnchor multiplier:0.9]];
        [constraints addObject:[container.heightAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.heightAnchor multiplier:0.9]];
        
        NSLayoutConstraint *expandBox = [container.widthAnchor constraintEqualToConstant:2000];
        expandBox.priority = UILayoutPriorityDefaultHigh; 
        [constraints addObject:expandBox];

        [constraints addObjectsFromArray:@[
            [closeBtn.topAnchor constraintEqualToAnchor:container.topAnchor constant:12],
            [closeBtn.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:12],
            [moreBtn.topAnchor constraintEqualToAnchor:container.topAnchor constant:12],
            [moreBtn.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-12],
        ]];
    } else {
        self.view.backgroundColor = [UIColor clearColor];
        container.layer.cornerRadius = 0;
        
        [constraints addObjectsFromArray:@[
            [container.topAnchor constraintEqualToAnchor:self.view.topAnchor],
            [container.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
            [container.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
            [container.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
        ]];

        [constraints addObjectsFromArray:@[
            [closeBtn.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
            [closeBtn.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:12],
            [moreBtn.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
            [moreBtn.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-12],
        ]];
    }

    [constraints addObjectsFromArray:@[
        [bgImageView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [bgImageView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [bgImageView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [bgImageView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [blurView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor]
    ]];

    [constraints addObjectsFromArray:@[
        [self.scrollView.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [self.scrollView.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [self.scrollView.widthAnchor constraintEqualToAnchor:self.scrollView.heightAnchor multiplier:16.0/9.0],
        [self.scrollView.widthAnchor constraintLessThanOrEqualToAnchor:container.widthAnchor],
        [self.scrollView.heightAnchor constraintLessThanOrEqualToAnchor:container.heightAnchor]
    ]];
    
    NSLayoutConstraint *expandSV = [self.scrollView.widthAnchor constraintEqualToConstant:2000];
    expandSV.priority = UILayoutPriorityDefaultHigh;
    [constraints addObject:expandSV];

    [constraints addObjectsFromArray:@[
        [self.imageView.topAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.topAnchor],
        [self.imageView.bottomAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.bottomAnchor],
        [self.imageView.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
        [self.imageView.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
        [self.imageView.widthAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.widthAnchor],
        [self.imageView.heightAnchor constraintEqualToAnchor:self.scrollView.frameLayoutGuide.heightAnchor]
    ]];

    [constraints addObjectsFromArray:@[
        [closeBtn.widthAnchor constraintEqualToConstant:50],
        [closeBtn.heightAnchor constraintEqualToConstant:50],
        [moreBtn.widthAnchor constraintEqualToConstant:50],
        [moreBtn.heightAnchor constraintEqualToConstant:50],
    ]];

    [NSLayoutConstraint activateConstraints:constraints];

    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    panGesture.delegate = self;
    [self.view addGestureRecognizer:panGesture];
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return self.imageView;
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)gesture {
    if (self.scrollView.zoomScale > self.scrollView.minimumZoomScale) {
        [self.scrollView setZoomScale:self.scrollView.minimumZoomScale animated:YES];
    } else {
        CGFloat targetZoomScale = 3.0; 
        CGPoint touchPoint = [gesture locationInView:self.imageView];
        CGFloat zoomWidth = self.scrollView.bounds.size.width / targetZoomScale;
        CGFloat zoomHeight = self.scrollView.bounds.size.height / targetZoomScale;
        CGFloat zoomX = touchPoint.x - (zoomWidth / 2.0);
        CGFloat zoomY = touchPoint.y - (zoomHeight / 2.0);
        [self.scrollView zoomToRect:CGRectMake(zoomX, zoomY, zoomWidth, zoomHeight) animated:YES];
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        if (self.scrollView.zoomScale > 1.0) return NO;
    }
    return YES;
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)gesture {
    CGPoint translation = [gesture translationInView:self.view];
    CGPoint velocity = [gesture velocityInView:self.view];
    
    if (gesture.state == UIGestureRecognizerStateChanged) {
        if (translation.y > 0) {
            self.view.transform = CGAffineTransformMakeTranslation(0, translation.y);
            if (isPad()) {
                CGFloat alpha = MAX(0.0, 0.5 - (translation.y / self.view.bounds.size.height));
                self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:alpha];
            }
        } else {
            self.view.transform = CGAffineTransformMakeTranslation(0, translation.y * 0.1);
        }
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        if (translation.y > 150 || velocity.y > 1000) {
            [self dismissViewControllerAnimated:YES completion:nil];
        } else {
            [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:velocity.y / 1000.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.view.transform = CGAffineTransformIdentity;
                if (isPad()) self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
            } completion:nil];
        }
    }
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)moreTapped:(UIButton *)sender {
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[self.thumbnailImage] applicationActivities:nil];
    if (isPad()) {
        activityVC.popoverPresentationController.sourceView = sender;
        activityVC.popoverPresentationController.sourceRect = sender.bounds;
    }
    [self presentViewController:activityVC animated:YES completion:nil];
}

@end

#import <Photos/Photos.h>
#import "Headers.h"

@implementation YouModThumbnailViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.preferredContentSize = CGSizeMake(650, 650);
    self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.85];

    UIView *bgContainer = [[UIView alloc] init];
    bgContainer.translatesAutoresizingMaskIntoConstraints = NO;
    bgContainer.clipsToBounds = YES;
    bgContainer.backgroundColor = [UIColor clearColor];
    bgContainer.layer.cornerRadius = 0;
    [self.view addSubview:bgContainer];

    UIImageView *bgImageView = [[UIImageView alloc] initWithImage:self.thumbnailImage];
    bgImageView.contentMode = UIViewContentModeScaleAspectFill;
    bgImageView.translatesAutoresizingMaskIntoConstraints = NO;
    [bgContainer addSubview:bgImageView];

    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [bgContainer addSubview:blurView];

    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.delegate = self;
    self.scrollView.clipsToBounds = YES;
    self.scrollView.minimumZoomScale = 1.0;
    self.scrollView.maximumZoomScale = 4.0;
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.showsHorizontalScrollIndicator = NO;
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    [bgContainer addSubview:self.scrollView];

    self.imageView = [[UIImageView alloc] initWithImage:self.thumbnailImage];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.imageView.clipsToBounds = YES;
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
    [bgContainer addSubview:closeBtn];

    UIButton *moreBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [moreBtn setImage:[UIImage systemImageNamed:@"square.and.arrow.up" withConfiguration:iconConfig] forState:UIControlStateNormal];
    moreBtn.tintColor = [UIColor whiteColor];
    moreBtn.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
    moreBtn.layer.cornerRadius = 25;
    moreBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [moreBtn addTarget:self action:@selector(moreTapped:) forControlEvents:UIControlEventTouchUpInside];
    [bgContainer addSubview:moreBtn];

    NSMutableArray *constraints = [NSMutableArray array];

    [constraints addObjectsFromArray:@[
        [bgContainer.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [bgContainer.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [bgContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [bgContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];

    [constraints addObjectsFromArray:@[
        [closeBtn.topAnchor constraintEqualToAnchor:bgContainer.safeAreaLayoutGuide.topAnchor constant:12],
        [closeBtn.leadingAnchor constraintEqualToAnchor:bgContainer.safeAreaLayoutGuide.leadingAnchor constant:12],
        [moreBtn.topAnchor constraintEqualToAnchor:bgContainer.safeAreaLayoutGuide.topAnchor constant:12],
        [moreBtn.trailingAnchor constraintEqualToAnchor:bgContainer.trailingAnchor constant:-12],
    ]];

    [constraints addObjectsFromArray:@[
        [bgImageView.topAnchor constraintEqualToAnchor:bgContainer.topAnchor],
        [bgImageView.bottomAnchor constraintEqualToAnchor:bgContainer.bottomAnchor],
        [bgImageView.leadingAnchor constraintEqualToAnchor:bgContainer.leadingAnchor],
        [bgImageView.trailingAnchor constraintEqualToAnchor:bgContainer.trailingAnchor],
        [blurView.topAnchor constraintEqualToAnchor:bgContainer.topAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:bgContainer.bottomAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:bgContainer.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:bgContainer.trailingAnchor]
    ]];

    [constraints addObjectsFromArray:@[
        [self.scrollView.topAnchor constraintEqualToAnchor:bgContainer.topAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:bgContainer.bottomAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:bgContainer.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:bgContainer.trailingAnchor]
    ]];

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
            CGFloat alpha = MAX(0.0, 0.85 - (translation.y / self.view.bounds.size.height));
            self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:alpha];
        } else {
            self.view.transform = CGAffineTransformMakeTranslation(0, translation.y * 0.1);
        }
    } else if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        if (translation.y > 150 || velocity.y > 1000) {
            [self dismissViewControllerAnimated:YES completion:nil];
        } else {
            [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:velocity.y / 1000.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.view.transform = CGAffineTransformIdentity;
                self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.85];
            } completion:nil];
        }
    }
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)moreTapped:(UIButton *)sender {
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[self.thumbnailImage] applicationActivities:nil];
    YouModConfigureSharePopover(activityVC, self.view);
    [self presentViewController:activityVC animated:YES completion:nil];
}

@end
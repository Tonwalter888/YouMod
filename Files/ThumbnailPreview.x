#import <Photos/Photos.h>
#import "Headers.h"

@implementation YouModThumbnailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    UIImageView *bgImageView = [[UIImageView alloc] initWithImage:self.thumbnailImage];
    bgImageView.frame = self.view.bounds;
    bgImageView.contentMode = UIViewContentModeScaleAspectFill;
    bgImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:bgImageView];

    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.frame = self.view.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:blurView];

    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.backgroundColor = [UIColor clearColor];
    [self.view addSubview:container];

    UIImageView *imageView = [[UIImageView alloc] initWithImage:self.thumbnailImage];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    imageView.layer.cornerRadius = 12;
    imageView.clipsToBounds = YES;
    [container addSubview:imageView];

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [closeBtn setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    closeBtn.tintColor = [UIColor whiteColor];
    closeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    closeBtn.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
    closeBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    [closeBtn addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:closeBtn];

    UIButton *moreBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [moreBtn setImage:[UIImage systemImageNamed:@"ellipsis.circle.fill"] forState:UIControlStateNormal];
    moreBtn.tintColor = [UIColor whiteColor];
    moreBtn.translatesAutoresizingMaskIntoConstraints = NO;
    moreBtn.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
    moreBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    [moreBtn addTarget:self action:@selector(moreTapped:) forControlEvents:UIControlEventTouchUpInside];
    [container addSubview:moreBtn];

    [NSLayoutConstraint activateConstraints:@[
        [container.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [container.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [container.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:0.85],
        [container.heightAnchor constraintEqualToAnchor:container.widthAnchor multiplier:9.0/16.0],

        [imageView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [imageView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [imageView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [imageView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],

        [closeBtn.widthAnchor constraintEqualToConstant:40],
        [closeBtn.heightAnchor constraintEqualToConstant:40],
        [closeBtn.topAnchor constraintEqualToAnchor:container.topAnchor constant:-15],
        [closeBtn.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:-15],

        [moreBtn.widthAnchor constraintEqualToConstant:40],
        [moreBtn.heightAnchor constraintEqualToConstant:40],
        [moreBtn.topAnchor constraintEqualToAnchor:container.topAnchor constant:-15],
        [moreBtn.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:15],
    ]];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)moreTapped:(UIButton *)sender {
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[self.thumbnailImage] applicationActivities:nil];
    
    if ([UIDevice userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = sender;
        activityVC.popoverPresentationController.sourceRect = sender.bounds;
    }
    
    [self presentViewController:activityVC animated:YES completion:nil];
}

@end
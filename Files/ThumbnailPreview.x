#import <Photos/Photos.h>
#import "Headers.h"

@implementation YouModThumbnailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];

    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.layer.cornerRadius = 16;
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

    UIImageView *imageView = [[UIImageView alloc] initWithImage:self.thumbnailImage];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    imageView.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:imageView];

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
    [constraints addObject:[container.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor]];
    [constraints addObject:[container.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]];
    [constraints addObject:[container.widthAnchor constraintEqualToAnchor:container.heightAnchor]];
    [constraints addObject:[container.widthAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.widthAnchor multiplier:0.9]];
    [constraints addObject:[container.heightAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.heightAnchor multiplier:0.9]];

    NSLayoutConstraint *expandConstraint = [container.widthAnchor constraintEqualToConstant:2000];
    expandConstraint.priority = UILayoutPriorityDefaultHigh;
    [constraints addObject:expandConstraint];

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
        [imageView.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [imageView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [imageView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [imageView.heightAnchor constraintEqualToAnchor:container.widthAnchor multiplier:9.0/16.0]
    ]];

    [constraints addObjectsFromArray:@[
        [closeBtn.widthAnchor constraintEqualToConstant:50],
        [closeBtn.heightAnchor constraintEqualToConstant:50],
        [closeBtn.topAnchor constraintEqualToAnchor:container.topAnchor constant:12],
        [closeBtn.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:12],

        [moreBtn.widthAnchor constraintEqualToConstant:50],
        [moreBtn.heightAnchor constraintEqualToConstant:50],
        [moreBtn.topAnchor constraintEqualToAnchor:container.topAnchor constant:12],
        [moreBtn.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-12],
    ]];

    [NSLayoutConstraint activateConstraints:constraints];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)moreTapped:(UIButton *)sender {
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[self.thumbnailImage] applicationActivities:nil];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        activityVC.popoverPresentationController.sourceView = sender;
        activityVC.popoverPresentationController.sourceRect = sender.bounds;
    }
    [self presentViewController:activityVC animated:YES completion:nil];
}

@end
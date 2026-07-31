#import "Headers.h"

static void YouModTranslateText(NSString *text, NSString *targetLang, void (^completion)(NSString *translatedText, NSError *error)) {
    if (!text || text.length == 0) {
        if (completion) completion(@"", nil);
        return;
    }
    
    NSString *encodedText = [text stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=%@&dt=t&q=%@", targetLang ?: @"en", encodedText];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error || !data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(nil, error);
            });
            return;
        }
        
        @try {
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([json isKindOfClass:[NSArray class]] && [json count] > 0) {
                NSArray *sentences = json[0];
                NSMutableString *result = [NSMutableString string];
                for (id sentence in sentences) {
                    if ([sentence isKindOfClass:[NSArray class]] && [sentence count] > 0) {
                        [result appendString:sentence[0]];
                    }
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) completion(result, nil);
                });
                return;
            }
        } @catch (NSException *e) {}
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(nil, [NSError errorWithDomain:@"YouModTranslate" code:-1 userInfo:nil]);
        });
    }];
    [task resume];
}

@implementation YouModLanguagePickerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissPicker)];
    tap.delegate = self;
    [self.view addGestureRecognizer:tap];
    
    self.containerView = [[UIView alloc] init];
    self.containerView.backgroundColor = [UIColor systemGray6Color];
    self.containerView.layer.cornerRadius = 20.0;
    self.containerView.clipsToBounds = YES;
    self.containerView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.containerView];
    
    UILabel *headerLabel = [[UILabel alloc] init];
    headerLabel.text = LOC(@"LANGUAGE");
    headerLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    headerLabel.textColor = [UIColor systemGrayColor];
    headerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerView addSubview:headerLabel];
    
    UIView *headerDivider = [[UIView alloc] init];
    headerDivider.backgroundColor = [UIColor separatorColor];
    headerDivider.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerView addSubview:headerDivider];
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.tableView.separatorColor = [UIColor separatorColor];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.containerView addSubview:self.tableView];
    
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [cancelButton setTitle:LOC(@"CANCEL") forState:UIControlStateNormal];
    [cancelButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    cancelButton.backgroundColor = [UIColor systemPurpleColor];
    cancelButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    cancelButton.layer.cornerRadius = 14.0;
    cancelButton.clipsToBounds = YES;
    cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
    [cancelButton addTarget:self action:@selector(dismissPicker) forControlEvents:UIControlEventTouchUpInside];
    [self.containerView addSubview:cancelButton];
    
    NSLayoutConstraint *widthConstraint = [self.containerView.widthAnchor constraintEqualToAnchor:self.view.widthAnchor multiplier:0.8];
    widthConstraint.priority = UILayoutPriorityDefaultHigh;

    NSLayoutConstraint *heightConstraint = [self.containerView.heightAnchor constraintEqualToAnchor:self.view.heightAnchor multiplier:0.65];
    heightConstraint.priority = UILayoutPriorityDefaultHigh;

    [NSLayoutConstraint activateConstraints:@[
        [self.containerView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.containerView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        
        widthConstraint,
        [self.containerView.widthAnchor constraintLessThanOrEqualToConstant:320.0],
        
        heightConstraint,
        [self.containerView.heightAnchor constraintLessThanOrEqualToConstant:500.0],
        
        [headerLabel.topAnchor constraintEqualToAnchor:self.containerView.topAnchor constant:14],
        [headerLabel.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor constant:20],
        [headerLabel.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor constant:-20],
        
        [headerDivider.topAnchor constraintEqualToAnchor:headerLabel.bottomAnchor constant:12],
        [headerDivider.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor],
        [headerDivider.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor],
        [headerDivider.heightAnchor constraintEqualToConstant:0.5],
        
        [self.tableView.topAnchor constraintEqualToAnchor:headerDivider.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:cancelButton.topAnchor constant:-10],
        
        [cancelButton.leadingAnchor constraintEqualToAnchor:self.containerView.leadingAnchor constant:16],
        [cancelButton.trailingAnchor constraintEqualToAnchor:self.containerView.trailingAnchor constant:-16],
        [cancelButton.bottomAnchor constraintEqualToAnchor:self.containerView.bottomAnchor constant:-14],
        [cancelButton.heightAnchor constraintEqualToConstant:44]
    ]];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    NSUInteger selectedIndex = [self.codes indexOfObject:self.selectedLangCode];
    if (selectedIndex != NSNotFound && selectedIndex < self.titles.count) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:selectedIndex inSection:0];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view isDescendantOfView:self.containerView]) {
        return NO;
    }
    return YES;
}

- (void)dismissPicker {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - TableView Delegate & DataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.titles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"LangCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
        cell.backgroundColor = [UIColor clearColor];
    }
    
    NSString *name = self.titles[indexPath.row];
    NSString *code = self.codes[indexPath.row];
    cell.textLabel.text = name;
    
    if ([code isEqualToString:self.selectedLangCode]) {
        cell.textLabel.textColor = [UIColor systemPurpleColor];
        cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
        
        UIImage *checkImg = [UIImage systemImageNamed:@"checkmark"];
        cell.imageView.image = [checkImg imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        cell.imageView.tintColor = [UIColor systemPurpleColor];
    } else {
        cell.textLabel.textColor = [UIColor labelColor];
        cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
        
        static UIImage *emptyImage = nil;
        if (!emptyImage) {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(20, 20), NO, 0.0);
            emptyImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
        cell.imageView.image = emptyImage;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.onSelectLanguage) {
        self.onSelectLanguage(self.codes[indexPath.row], self.titles[indexPath.row]);
    }
    [self dismissPicker];
}

@end

@implementation YouModTranslationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = LOC(@"TRANSLATION");

    if (self.navigationController) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = [UIColor systemBackgroundColor];
        appearance.titleTextAttributes = @{
            NSForegroundColorAttributeName: [UIColor labelColor],
            NSFontAttributeName: [UIFont boldSystemFontOfSize:17]
        };
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    }
    
    UIBarButtonItem *closeItem = [self createEqualBarButtonWithSymbol:@"xmark" action:@selector(closeTapped)];
    UIBarButtonItem *copyItem = [self createEqualBarButtonWithSymbol:@"doc.on.doc" action:@selector(copyTapped)];
    UIBarButtonItem *shareItem = [self createEqualBarButtonWithSymbol:@"square.and.arrow.up" action:@selector(shareTapped:)];

    self.navigationItem.rightBarButtonItems = @[closeItem, copyItem, shareItem];

    self.languageTitles = getAllSystemLanguageTitles();
    self.languageCodes = getAllSystemLanguageValues();
    
    self.selectedLangCode = @"en";
    self.selectedLangName = @"English";
    
    NSUInteger defaultIndex = [self.languageCodes indexOfObject:self.selectedLangCode];
    if (defaultIndex != NSNotFound && defaultIndex < self.languageTitles.count) {
        self.selectedLangName = self.languageTitles[defaultIndex];
    } else if (self.languageTitles.count > 0 && self.languageCodes.count > 0) {
        self.selectedLangCode = self.languageCodes.firstObject;
        self.selectedLangName = self.languageTitles.firstObject;
    }

    UIView *langRowView = [[UIView alloc] init];
    langRowView.translatesAutoresizingMaskIntoConstraints = NO;
    langRowView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    langRowView.layer.cornerRadius = 12;
    [self.view addSubview:langRowView];

    UILabel *langTitleLabel = [[UILabel alloc] init];
    langTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    langTitleLabel.text = LOC(@"LANGUAGE");
    langTitleLabel.textColor = [UIColor labelColor];
    langTitleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [langRowView addSubview:langTitleLabel];

    self.langValueLabel = [[UILabel alloc] init];
    self.langValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.langValueLabel.userInteractionEnabled = YES;
    
    UITapGestureRecognizer *langTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(selectLanguageTapped:)];
    [self.langValueLabel addGestureRecognizer:langTap];
    [langRowView addSubview:self.langValueLabel];
    [self updateLanguageLabelText];

    self.reloadButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.reloadButton.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageSymbolConfiguration *reloadConfig = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIFontWeightMedium];
    UIImage *reloadImage = [UIImage systemImageNamed:@"arrow.clockwise" withConfiguration:reloadConfig];
    [self.reloadButton setImage:reloadImage forState:UIControlStateNormal];
    self.reloadButton.tintColor = [UIColor systemRedColor];
    self.reloadButton.hidden = YES;
    [self.reloadButton addTarget:self action:@selector(performTranslation) forControlEvents:UIControlEventTouchUpInside];
    [langRowView addSubview:self.reloadButton];

    self.resultTextView = [[UITextView alloc] init];
    self.resultTextView.translatesAutoresizingMaskIntoConstraints = NO;
    self.resultTextView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.resultTextView.layer.cornerRadius = 12;
    self.resultTextView.textColor = [UIColor labelColor];
    self.resultTextView.font = [UIFont systemFontOfSize:16];
    self.resultTextView.editable = NO;
    self.resultTextView.textContainerInset = UIEdgeInsetsMake(12, 12, 12, 12);
    [self.view addSubview:self.resultTextView];

    UILayoutGuide *guide = self.view.safeAreaLayoutGuide;

    [NSLayoutConstraint activateConstraints:@[
        [langRowView.topAnchor constraintEqualToAnchor:guide.topAnchor constant:12],
        [langRowView.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:16],
        [langRowView.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-16],
        [langRowView.heightAnchor constraintEqualToConstant:48],

        [langTitleLabel.leadingAnchor constraintEqualToAnchor:langRowView.leadingAnchor constant:16],
        [langTitleLabel.centerYAnchor constraintEqualToAnchor:langRowView.centerYAnchor],

        [self.langValueLabel.trailingAnchor constraintEqualToAnchor:langRowView.trailingAnchor constant:-16],
        [self.langValueLabel.centerYAnchor constraintEqualToAnchor:langRowView.centerYAnchor],

        [self.reloadButton.trailingAnchor constraintEqualToAnchor:self.langValueLabel.leadingAnchor constant:-8],
        [self.reloadButton.centerYAnchor constraintEqualToAnchor:langRowView.centerYAnchor],
        [self.reloadButton.widthAnchor constraintEqualToConstant:28],
        [self.reloadButton.heightAnchor constraintEqualToConstant:28],

        [self.resultTextView.topAnchor constraintEqualToAnchor:langRowView.bottomAnchor constant:12],
        [self.resultTextView.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:16],
        [self.resultTextView.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-16],
        [self.resultTextView.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor constant:-16]
    ]];

    [self performTranslation];
}

- (UIBarButtonItem *)createEqualBarButtonWithSymbol:(NSString *)symbolName action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIFontWeightMedium];
    UIImage *image = [UIImage systemImageNamed:symbolName withConfiguration:config];
    [button setImage:image forState:UIControlStateNormal];
    button.tintColor = [UIColor labelColor];
    
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:32],
        [button.heightAnchor constraintEqualToConstant:32]
    ]];
    
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return [[UIBarButtonItem alloc] initWithCustomView:button];
}

- (void)updateLanguageLabelText {
    NSString *langName = self.selectedLangName ?: @"";
    UIColor *purpleColor = [UIColor systemPurpleColor];
    UIFont *labelFont = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ ", langName] attributes:@{
        NSFontAttributeName: labelFont,
        NSForegroundColorAttributeName: purpleColor
    }];
    
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithFont:labelFont];
    UIImage *symbol = [UIImage systemImageNamed:@"chevron.up.chevron.down" withConfiguration:config];
    
    if (symbol) {
        NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
        attachment.image = [symbol imageWithTintColor:purpleColor renderingMode:UIImageRenderingModeAlwaysOriginal];
        
        CGFloat fontCapHeight = labelFont.capHeight;
        CGFloat iconHeight = symbol.size.height;
        attachment.bounds = CGRectMake(0, (fontCapHeight - iconHeight) / 2.0, symbol.size.width, iconHeight);
        
        [attrString appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
    }
    
    self.langValueLabel.attributedText = attrString;
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)copyTapped {
    if (self.resultTextView.text.length > 0 && ![self.resultTextView.text isEqualToString:LOC(@"TRANSLATING")] && ![self.resultTextView.text isEqualToString:LOC(@"TRANSLATE_FAILED")]) {
        [UIPasteboard generalPasteboard].string = self.resultTextView.text;
        
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [feedback impactOccurred];

        UIView *parent = sbGetNotificationParent();
        [SBSkipNotificationView showSuccessInView:parent message:LOC(@"COPIED_TO_CLIPBOARD") duration:3.0];
    }
}

- (void)shareTapped:(id)sender {
    if (self.resultTextView.text.length == 0 || [self.resultTextView.text isEqualToString:LOC(@"TRANSLATING")] || [self.resultTextView.text isEqualToString:LOC(@"TRANSLATE_FAILED")]) return;
    
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[self.resultTextView.text] applicationActivities:nil];
    if (activityVC.popoverPresentationController) {
        if ([sender isKindOfClass:[UIBarButtonItem class]]) {
            activityVC.popoverPresentationController.barButtonItem = (UIBarButtonItem *)sender;
        } else if ([sender isKindOfClass:[UIView class]]) {
            activityVC.popoverPresentationController.sourceView = (UIView *)sender;
            activityVC.popoverPresentationController.sourceRect = ((UIView *)sender).bounds;
        }
    }
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)selectLanguageTapped:(UITapGestureRecognizer *)gesture {
    if (!self.languageTitles || self.languageTitles.count == 0) return;
    
    YouModLanguagePickerViewController *pickerVC = [[YouModLanguagePickerViewController alloc] init];
    pickerVC.titles = self.languageTitles;
    pickerVC.codes = self.languageCodes;
    pickerVC.selectedLangCode = self.selectedLangCode;
    
    __weak typeof(self) weakSelf = self;
    pickerVC.onSelectLanguage = ^(NSString *code, NSString *title) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.selectedLangCode = code;
        strongSelf.selectedLangName = title;
        [strongSelf updateLanguageLabelText];
        [strongSelf performTranslation];
    };
    
    pickerVC.modalPresentationStyle = UIModalPresentationOverFullScreen;
    pickerVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:pickerVC animated:YES completion:nil];
}

- (void)performTranslation {
    self.reloadButton.hidden = YES;
    self.resultTextView.text = LOC(@"TRANSLATING");
    self.resultTextView.textColor = [UIColor systemPurpleColor];
    
    __weak typeof(self) weakSelf = self;
    YouModTranslateText(self.originalText, self.selectedLangCode, ^(NSString *translatedText, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (translatedText && translatedText.length > 0) {
            strongSelf.resultTextView.text = translatedText;
            strongSelf.resultTextView.textColor = [UIColor labelColor];
            strongSelf.reloadButton.hidden = YES;
        } else {
            strongSelf.resultTextView.text = LOC(@"TRANSLATE_FAILED");
            strongSelf.resultTextView.textColor = [UIColor systemRedColor];
            strongSelf.reloadButton.hidden = NO;
        }
    });
}

@end
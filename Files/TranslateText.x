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
    self.title = LOC(@"SELECT_LANG");
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"LangCell"];
    self.tableView.tableFooterView = [[UIView alloc] init];
    
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

    UIBarButtonItem *closeItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"xmark"] style:UIBarButtonItemStylePlain target:self action:@selector(closeTapped)];
    closeItem.tintColor = [UIColor labelColor];
    self.navigationItem.rightBarButtonItem = closeItem;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    NSUInteger selectedIndex = [self.codes indexOfObject:self.selectedCode];
    if (selectedIndex != NSNotFound && selectedIndex < self.titles.count) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:selectedIndex inSection:0];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
        });
    }
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - TableView Data Source & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.titles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"LangCell" forIndexPath:indexPath];
    NSString *name = self.titles[indexPath.row];
    NSString *code = self.codes[indexPath.row];
    
    cell.textLabel.text = name;
    cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
    cell.textLabel.textColor = [UIColor labelColor];
    cell.backgroundColor = [UIColor clearColor];
    
    if ([code isEqualToString:self.selectedCode]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        cell.tintColor = [UIColor systemPurpleColor];
        cell.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.onSelect) {
        self.onSelect(self.codes[indexPath.row], self.titles[indexPath.row]);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
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
    
    UIBarButtonItem *closeItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"xmark"] style:UIBarButtonItemStylePlain target:self action:@selector(closeTapped)];
    closeItem.tintColor = [UIColor labelColor];

    UIBarButtonItem *copyItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"doc.on.doc"] style:UIBarButtonItemStylePlain target:self action:@selector(copyTapped)];
    copyItem.tintColor = [UIColor labelColor];

    UIBarButtonItem *shareItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"square.and.arrow.up"] style:UIBarButtonItemStylePlain target:self action:@selector(shareTapped:)];
    shareItem.tintColor = [UIColor labelColor];

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
    if (self.resultTextView.text.length > 0 && ![self.resultTextView.text isEqualToString:LOC(@"TRANSLATING")]) {
        [UIPasteboard generalPasteboard].string = self.resultTextView.text;
        
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        [feedback impactOccurred];
    }
}

- (void)shareTapped:(UIBarButtonItem *)sender {
    if (self.resultTextView.text.length == 0 || [self.resultTextView.text isEqualToString:LOC(@"TRANSLATING")]) return;
    
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[self.resultTextView.text] applicationActivities:nil];
    if (activityVC.popoverPresentationController) {
        activityVC.popoverPresentationController.barButtonItem = sender;
    }
    [self presentViewController:activityVC animated:YES completion:nil];
}

- (void)selectLanguageTapped:(UITapGestureRecognizer *)gesture {
    if (!self.languageTitles || self.languageTitles.count == 0) return;
    
    YouModLanguagePickerViewController *pickerVC = [[YouModLanguagePickerViewController alloc] init];
    pickerVC.titles = self.languageTitles;
    pickerVC.codes = self.languageCodes;
    pickerVC.selectedCode = self.selectedLangCode;
    
    __weak typeof(self) weakSelf = self;
    pickerVC.onSelect = ^(NSString *code, NSString *title) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.selectedLangCode = code;
        strongSelf.selectedLangName = title;
        [strongSelf updateLanguageLabelText];
        [strongSelf performTranslation];
    };
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:pickerVC];
    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *sheet = nav.sheetPresentationController;
        if (sheet) {
            sheet.detents = @[
                [UISheetPresentationControllerDetent mediumDetent],
                [UISheetPresentationControllerDetent largeDetent]
            ];
            sheet.prefersGrabberVisible = YES;
            sheet.preferredCornerRadius = 20.0;
        }
    }
    
    [self presentViewController:nav animated:YES completion:nil];
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
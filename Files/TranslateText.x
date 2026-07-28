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

@implementation YouModTranslationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorWithRed:0.13 green:0.13 blue:0.13 alpha:1.0];
    self.title = LOC(@"TRANSLATION");

    if (self.navigationController) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = [UIColor colorWithRed:0.13 green:0.13 blue:0.13 alpha:1.0];
        appearance.titleTextAttributes = @{
            NSForegroundColorAttributeName: [UIColor whiteColor],
            NSFontAttributeName: [UIFont boldSystemFontOfSize:17]
        };
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    }
    
    UIBarButtonItem *closeItem = [[UIBarButtonItem alloc] initWithTitle:@"✕" style:UIBarButtonItemStylePlain target:self action:@selector(closeTapped)];
    closeItem.tintColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    self.navigationItem.rightBarButtonItem = closeItem;

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
    langRowView.backgroundColor = [UIColor colorWithWhite:0.18 alpha:1.0];
    langRowView.layer.cornerRadius = 12;
    UITapGestureRecognizer *langTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(selectLanguageTapped:)];
    [langRowView addGestureRecognizer:langTap];
    [self.view addSubview:langRowView];

    UILabel *langTitleLabel = [[UILabel alloc] init];
    langTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    langTitleLabel.text = LOC(@"LANGUAGE");
    langTitleLabel.textColor = [UIColor whiteColor];
    langTitleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [langRowView addSubview:langTitleLabel];

    self.langValueLabel = [[UILabel alloc] init];
    self.langValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.langValueLabel.text = [NSString stringWithFormat:@"%@ ↕", self.selectedLangName];
    self.langValueLabel.textColor = [UIColor colorWithRed:0.75 green:0.55 blue:1.0 alpha:1.0];
    self.langValueLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [langRowView addSubview:self.langValueLabel];

    self.resultTextView = [[UITextView alloc] init];
    self.resultTextView.translatesAutoresizingMaskIntoConstraints = NO;
    self.resultTextView.backgroundColor = [UIColor colorWithWhite:0.18 alpha:0.5];
    self.resultTextView.layer.cornerRadius = 12;
    self.resultTextView.textColor = [UIColor whiteColor];
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

        [self.resultTextView.topAnchor constraintEqualToAnchor:langRowView.bottomAnchor constant:12],
        [self.resultTextView.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:16],
        [self.resultTextView.trailingAnchor constraintEqualToAnchor:guide.trailingAnchor constant:-16],
        [self.resultTextView.bottomAnchor constraintEqualToAnchor:guide.bottomAnchor constant:-16]
    ]];

    [self performTranslation];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)selectLanguageTapped:(UITapGestureRecognizer *)gesture {
    if (!self.languageTitles || self.languageTitles.count == 0) return;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:LOC(@"SELECT_LANG") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    __weak typeof(self) weakSelf = self;
    for (NSUInteger i = 0; i < self.languageTitles.count; i++) {
        NSString *name = self.languageTitles[i];
        NSString *code = self.languageCodes[i];
        NSString *itemTitle = [code isEqualToString:self.selectedLangCode] ? [NSString stringWithFormat:@"✓ %@", name] : name;

        [alert addAction:[UIAlertAction actionWithTitle:itemTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.selectedLangCode = code;
            strongSelf.selectedLangName = name;
            strongSelf.langValueLabel.text = [NSString stringWithFormat:@"%@ ↕", name];
            [strongSelf performTranslation];
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:LOC(@"CANCEL") style:UIAlertActionStyleCancel handler:nil]];
    
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = gesture.view;
        alert.popoverPresentationController.sourceRect = gesture.view.bounds;
    }
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performTranslation {
    self.resultTextView.text = LOC(@"TRANSLATING");
    self.resultTextView.textColor = [UIColor colorWithRed:0.75 green:0.55 blue:1.0 alpha:1.0];
    
    __weak typeof(self) weakSelf = self;
    YouModTranslateText(self.originalText, self.selectedLangCode, ^(NSString *translatedText, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        if (translatedText && translatedText.length > 0) {
            strongSelf.resultTextView.text = translatedText;
            strongSelf.resultTextView.textColor = [UIColor whiteColor];
        } else {
            strongSelf.resultTextView.text = LOC(@"TRANSLATE_FAILED");
            strongSelf.resultTextView.textColor = [UIColor systemRedColor];
        }
    });
}

@end
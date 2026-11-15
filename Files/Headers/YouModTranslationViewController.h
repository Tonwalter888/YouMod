typedef NS_ENUM(NSInteger, YouModTranslationState) {
    YouModTranslationStateLoading = 0,
    YouModTranslationStateSuccess = 1,
    YouModTranslationStateFailed = 2
};

@interface YouModTranslationViewController : UIViewController
@property (nonatomic, copy) NSString *originalText;
@property (nonatomic, strong) UILabel *langValueLabel;
@property (nonatomic, strong) UIButton *reloadButton;
@property (nonatomic, strong) UITextView *resultTextView;
@property (nonatomic, copy) NSString *selectedLangCode;
@property (nonatomic, copy) NSString *selectedLangName;
@property (nonatomic, strong) NSArray<NSString *> *languageTitles;
@property (nonatomic, strong) NSArray<NSString *> *languageCodes;
@property (nonatomic, assign) YouModTranslationState translationState;
- (void)performTranslation;
@end

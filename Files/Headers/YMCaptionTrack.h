@interface YMCaptionTrack : NSObject
@property (nonatomic, copy) NSString *name;          // "English (US)"
@property (nonatomic, copy) NSString *languageCode;  // "en"
@property (nonatomic, copy) NSString *vttURL;        // fetched just before muxing
@property (nonatomic, strong) NSURL *localURL;       // set once fetched
@end

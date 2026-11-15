// YMDownloadSheet internal class extension — the sheet's private model/UI state,
// moved out of YMDownloadSheet.x (implementation stays there).
#import <UIKit/UIKit.h>

#import "YMDownloadSheet.h"

@class YMFormat;
@class YMCaptionTrack;

@interface YMDownloadSheet () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, assign) YMDownloadDestination destination;
@property (nonatomic, assign) BOOL isShorts;
@property (nonatomic, copy) NSString *videoTitle;
@property (nonatomic, copy) NSString *videoID;
@property (nonatomic, strong) NSURL *thumbnailURL;
@property (nonatomic, copy) NSString *channelTitle;
@property (nonatomic, strong) NSArray<YMFormat *> *allFormats;
@property (nonatomic, strong) NSArray<YMCaptionTrack *> *captions;
@property (nonatomic, strong) NSArray<NSString *> *tabs;
@property (nonatomic, strong) NSArray<NSString *> *videoTabs;
@property (nonatomic, copy) NSString *selectedTab;
@property (nonatomic, strong) NSArray<NSString *> *audioCodecs;
@property (nonatomic, copy) NSString *selectedAudioCodec;
@property (nonatomic, strong) NSArray<YMFormat *> *audioRows;
@property (nonatomic, strong) NSMutableArray<YMFormat *> *selectedAudios;
@property (nonatomic, strong) NSArray<YMFormat *> *videoRows;
@property (nonatomic, strong) YMFormat *selectedVideo;
@property (nonatomic, strong) NSMutableArray<YMCaptionTrack *> *selectedCaptions;
@property (nonatomic, strong) NSArray<NSNumber *> *sections;
@property (nonatomic, strong) UISegmentedControl *videoCodecControl;
@property (nonatomic, strong) UISegmentedControl *audioCodecControl;
@property (nonatomic, strong) UILabel *codecHint;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIButton *downloadButton;
@end

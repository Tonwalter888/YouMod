#import "MLFormat.h"
#import "MLHAMPlayerItem.h"
#import "MLPlayerReloadContext.h"
#import "MLPlayerStickySettings.h"
#import "MLQueuePlayerDelegate.h"
#import "YTSingleVideo.h"
#import "YTSingleVideoControllerDelegate.h"
#import "MLInnerTubeCaptionTrack.h"
#import "MLQuickMenuVideoQualitySettingFormatConstraint.h"

@interface YTSingleVideoController : NSObject <MLQueuePlayerDelegate>
@property (nonatomic, weak, readwrite) NSObject <YTSingleVideoControllerDelegate> *delegate;
@property (nonatomic, strong, readwrite) MLPlayerStickySettings *mediaStickySettings;
@property (nonatomic, strong, readwrite) MLHAMPlayerItem *playerItem;
- (YTSingleVideo *)singleVideo;
- (YTSingleVideo *)videoData;
- (NSArray <MLFormat *> *)selectableVideoFormats;
- (BOOL)isMuted;
- (void)setMuted:(BOOL)muted;
- (void)reloadPlayerWithContext:(MLPlayerReloadContext *)context;
@end

@interface YTSingleVideoController (YouMod)
- (CGFloat)totalMediaTime;
- (void)setVideoFormatConstraint:(MLQuickMenuVideoQualitySettingFormatConstraint *)arg;
- (void)YouModAutoQuality;
- (NSArray *)availableCaptionTracks;
- (MLInnerTubeCaptionTrack *)activeCaptionTrack;
- (float)volume;
- (void)setVolume:(float)volume;
@end

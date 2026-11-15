// YMSABRMediaHeader — decoded MEDIA_HEADER (UMP part 20): maps a headerId to a
// format + segment.

@interface YMSABRMediaHeader : NSObject
@property (nonatomic, assign) uint64_t headerId;
@property (nonatomic, assign) uint64_t itag;
@property (nonatomic, assign) uint64_t sequence;
@property (nonatomic, assign) uint64_t startMs;
@property (nonatomic, assign) uint64_t durationMs;
@property (nonatomic, assign) uint64_t contentLength;
@property (nonatomic, assign) BOOL isInit;
@end

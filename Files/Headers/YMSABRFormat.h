// YMSABRFormat — a resolved SABR download target: the {itag, lastModified,
// xtags} triple copied verbatim from the request's available-format list.

@interface YMSABRFormat : NSObject
@property (nonatomic, assign) uint64_t itag;
@property (nonatomic, assign) uint64_t lastModified;
@property (nonatomic, strong) NSData *xtags;   // may be empty; always emitted (matches the real client)
@property (nonatomic, assign) BOOL found;
@end

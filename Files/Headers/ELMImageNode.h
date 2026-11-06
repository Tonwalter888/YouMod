#import "ASDisplayNode.h"

// Reverse-engineered ELM image node (YouTube's Elements framework).
@interface ELMImageNode : ASDisplayNode
- (void)setImage:(UIImage *)image;
- (id)downloadImageWithURL:(NSURL *)URL shouldRetry:(BOOL)retry callbackQueue:(id)queue downloadProgress:(id)progress completion:(id)completion;
- (void)cachedImageWithURL:(NSURL *)URL callbackQueue:(id)queue completion:(id)completion;
@end

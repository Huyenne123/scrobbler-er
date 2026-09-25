#import <Foundation/Foundation.h>
#import "LFMTrack.h"

NS_ASSUME_NONNULL_BEGIN

@interface MetadataNormalizer : NSObject

- (LFMTrack *)normalizeTrack:(LFMTrack *)track;

@end

NS_ASSUME_NONNULL_END
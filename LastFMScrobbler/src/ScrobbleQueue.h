#import <Foundation/Foundation.h>
#import "LFMTrack.h"

NS_ASSUME_NONNULL_BEGIN

@interface ScrobbleQueue : NSObject

+ (instancetype)sharedQueue;

- (void)queueScrobble:(LFMTrack *)track;
- (void)attemptToSendQueuedScrobbles;
- (void)addRecentScrobble:(LFMTrack *)track;
- (BOOL)isRecentlyScrobbled:(LFMTrack *)track;

// Internal methods for managing the queue
- (NSArray *)getAndClearQueuedScrobbles;
- (void)queueScrobbles:(NSArray *)tracks;

@end

NS_ASSUME_NONNULL_END
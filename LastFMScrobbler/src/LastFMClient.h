#import <Foundation/Foundation.h>

@class LFMTrack;

typedef void (^LastFMClientCompletion)(BOOL success, NSError *error);

@interface LastFMClient : NSObject

- (void)setSessionKey:(NSString *)sessionKey;
- (void)invalidate;

- (void)updateNowPlayingWithTrack:(LFMTrack *)track;
- (void)scrobbleTrack:(LFMTrack *)track withCompletion:(LastFMClientCompletion)completion;

@end
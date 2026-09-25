#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

@class MediaRemoteManager;
@class LastFMClient;
@class CredentialStore;
@class ScrobbleQueue;
@class MetadataNormalizer;
@class LFMTrack;

@interface LFMScrobbler : NSObject

+ (instancetype)sharedScrobbler;

- (void)start;
- (void)stop;

@end
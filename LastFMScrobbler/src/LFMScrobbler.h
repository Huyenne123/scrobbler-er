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

// Public accessors for internal components (used by ScrobbleQueue, etc.)
@property (nonatomic, strong, readonly) MediaRemoteManager *mediaRemoteManager;
@property (nonatomic, strong, readonly) LastFMClient *lastFMClient;
@property (nonatomic, strong, readonly) CredentialStore *credentialStore;
@property (nonatomic, strong, readonly) ScrobbleQueue *scrobbleQueue;
@property (nonatomic, strong, readonly) MetadataNormalizer *metadataNormalizer;

@end
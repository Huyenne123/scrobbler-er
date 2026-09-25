#import "LFMScrobbler.h"
#import "MediaRemoteManager.h"
#import "LastFMClient.h"
#import "CredentialStore.h"
#import "ScrobbleQueue.h"
#import "MetadataNormalizer.h"
#import "LFMTrack.h"

@interface LFMScrobbler ()

@property (nonatomic, strong) MediaRemoteManager *mediaRemoteManager;
@property (nonatomic, strong) LastFMClient *lastFMClient;
@property (nonatomic, strong) CredentialStore *credentialStore;
@property (nonatomic, strong) ScrobbleQueue *scrobbleQueue;
@property (nonatomic, strong) MetadataNormalizer *metadataNormalizer;

@property (nonatomic, assign) BOOL isRunning;

@end

@implementation LFMScrobbler

+ (instancetype)sharedScrobbler {
    static LFMScrobbler *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mediaRemoteManager = [[MediaRemoteManager alloc] init];
        _lastFMClient = [[LastFMClient alloc] init];
        _credentialStore = [[CredentialStore alloc] init];
        _scrobbleQueue = [[ScrobbleQueue alloc] init];
        _metadataNormalizer = [[MetadataNormalizer alloc] init];
        _isRunning = NO;
    }
    return self;
}

- (void)start {
    if (_isRunning) return;
    _isRunning = YES;

    // Load credentials and session
    [_credentialStore loadCredentials];

    // If we have a session, set it in the LastFMClient
    NSString *sessionKey = [_credentialStore sessionKey];
    if (sessionKey) {
        [_lastFMClient setSessionKey:sessionKey];
    }

    // Start the media remote manager to listen for now playing changes
    [_mediaRemoteManager startMonitoringWithCallback:^(LFMTrack *track, BOOL isPlaying) {
        [self handleNowPlayingChange:track isPlaying:isPlaying];
    }];

    // Optionally, scrobble the currently playing track on startup
    // This would be controlled by a preference
    BOOL scrobbleCurrentOnStartup = [[NSUserDefaults standardUserDefaults] boolForKey:@"scrobbleCurrentOnStartup"];
    if (scrobbleCurrentOnStartup) {
        [_mediaRemoteManager fetchCurrentNowPlayingWithCallback:^(LFMTrack *track, BOOL isPlaying) {
            if (isPlaying && track) {
                [self handleNowPlayingChange:track isPlaying:isPlaying];
            }
        }];
    }
}

- (void)stop {
    if (!_isRunning) return;
    _isRunning = NO;

    [_mediaRemoteManager stopMonitoring];
    [_lastFMClient invalidate];
}

- (void)handleNowPlayingChange:(LFMTrack *)track isPlaying:(BOOL)isPlaying {
    if (!isPlaying || !track) {
        // Not playing or no track, do nothing
        return;
    }

    // Normalize metadata if enabled
    BOOL cleanMetadataEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"cleanMetadata"];
    if (cleanMetadataEnabled) {
        track = [_metadataNormalizer normalizeTrack:track];
    }

    // Update Last.fm now playing
    [_lastFMClient updateNowPlayingWithTrack:track];

    // Check if we should scrobble this track
    double scrobblePercentage = [[NSUserDefaults standardUserDefaults] doubleForKey:@"scrobblePercentage"];
    if (scrobblePercentage == 0) scrobblePercentage = 70.0; // default

    NSTimeInterval duration = [track.duration doubleValue];
    if (duration < 30.0) {
        // Track too short to scrobble
        return;
    }

    NSTimeInterval thresholdTime = duration * (scrobblePercentage / 100.0);
    // We don't know the elapsed time, so we assume we just started?
    // In a real implementation, we would need to get the current playback position from MediaRemote.
    // For now, we'll schedule the scrobble for the threshold time from now.
    // This is a simplification; we should actually get the elapsed time from MediaRemote if possible.

    // For the sake of this example, we'll just schedule after thresholdTime seconds.
    // However, note that we must re-check the track and playback state at scrobble time.

    // We'll use a timer to schedule the scrobble
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(scrobbleTrack:) object:track];
    [self performSelector:@selector(scrobbleTrack:) withObject:track afterDelay:thresholdTime];
}

- (void)scrobbleTrack:(LFMTrack *)track {
    // At scrobble time, we need to re-check the current track and playback state
    [_mediaRemoteManager fetchCurrentNowPlayingWithCallback:^(LFMTrack *currentTrack, BOOL isPlaying) {
        if (!isPlaying || !currentTrack) {
            // Not playing anymore, do not scrobble
            return;
        }

        // Verify that the track is the same
        if ([track.title isEqualToString:currentTrack.title] &&
            [track.artist isEqualToString:currentTrack.artist] &&
            ([track.album isEqualToString:currentTrack.album] ||
             (track.album == nil && currentTrack.album == nil) ||
             [track.album isEqualToString:currentTrack.album])) {
            // Tracks match, scrobble
            [_lastFMClient scrobbleTrack:track withCompletion:^(BOOL success, NSError *error) {
                if (success) {
                    // Add to recent scrobbles to prevent duplicates
                    [[ScrobbleQueue sharedQueue] addRecentScrobble:track];
                    // Also, if there are any queued scrobbles, try to send them
                    [[ScrobbleQueue sharedQueue] attemptToSendQueuedScrobbles];
                } else {
                    // Scrobble failed, maybe queue it for later
                    [[ScrobbleQueue sharedQueue] queueScrobble:track];
                }
            }];
        } else {
            // Track changed, do not scrobble the old one
        }
    }];
}

@end
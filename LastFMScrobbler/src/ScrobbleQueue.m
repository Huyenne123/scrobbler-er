#import "ScrobbleQueue.h"
#import "LFMTrack.h"
#import "LFMScrobbler.h"
#import <sys/stat.h>

static NSString *const kRecentScrobblesKey = @"RecentScrobbles";
static NSUInteger const kMaxRecentScrobbles = 50;

@interface ScrobbleQueue ()

@property (nonatomic, strong) NSMutableArray *queue; // Array of LFMTrack objects waiting to be scrobbled
@property (nonatomic, strong) NSMutableArray *recentScrobbles; // Array of LFMTrack objects that have been recently scrobbled (to avoid duplicates)
@property (nonatomic, strong) dispatch_queue_t queueSerialQueue; // Serial queue to synchronize access to the queue and recent scrobbles

@end

@implementation ScrobbleQueue

+ (instancetype)sharedQueue {
    static ScrobbleQueue *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = [NSMutableArray array];
        _recentScrobbles = [NSMutableArray array];
        _queueSerialQueue = dispatch_queue_create("com.neyuh.lastfmscrobbler.scrobblequeue", DISPATCH_QUEUE_SERIAL);

        // Load the persisted queue and recent scrobbles from disk
        [self loadQueue];
        [self loadRecentScrobbles];
    }
    return self;
}

#pragma mark - Queue Persistence

- (NSString *)scrobbleQueueFilePath {
    static NSString *path = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Use the caches directory for the queue file
        NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        path = [cachesDir stringByAppendingPathComponent:@"scrobblequeue.plist"];
    });
    return path;
}

- (NSString *)recentScrobblesFilePath {
    static NSString *path = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        path = [cachesDir stringByAppendingPathComponent:@"recentscrobbles.plist"];
    });
    return path;
}

- (void)loadQueue {
    NSData *data = [NSData dataWithContentsOfFile:[self scrobbleQueueFilePath]];
    if (data) {
        NSArray *array = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        if (array) {
            dispatch_sync(_queueSerialQueue, ^{
                _queue = [array mutableCopy];
            });
        }
    }
}

- (void)saveQueue {
    dispatch_sync(_queueSerialQueue, ^{
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:_queue];
        [data writeToFile:[self scrobbleQueueFilePath] atomically:YES];
    });
}

- (void)loadRecentScrobbles {
    NSData *data = [NSData dataWithContentsOfFile:[self recentScrobblesFilePath]];
    if (data) {
        NSArray *array = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        if (array) {
            dispatch_sync(_queueSerialQueue, ^{
                _recentScrobbles = [array mutableCopy];
            });
        }
    }
}

- (void)saveRecentScrobbles {
    dispatch_sync(_queueSerialQueue, ^{
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:_recentScrobbles];
        [data writeToFile:[self recentScrobblesFilePath] atomically:YES];
    });
}

#pragma mark - Public Methods

- (void)queueScrobble:(LFMTrack *)track {
    if (!track) return;

    dispatch_sync(_queueSerialQueue, ^{
        // Check if we have already scrobbled this track recently (to avoid duplicates in the queue)
        if ([self isRecentlyScrobbled:track]) {
            return;
        }

        [_queue addObject:track];
        [self saveQueue];
    });
}

- (NSArray *)getAndClearQueuedScrobbles {
    dispatch_sync(_queueSerialQueue, ^{
        NSArray *copy = [_queue copy];
        [_queue removeAllObjects];
        [self saveQueue];
        return copy;
    });
}

- (void)queueScrobbles:(NSArray *)tracks {
    if (!tracks || tracks.count == 0) return;
    dispatch_sync(_queueSerialQueue, ^{
        [_queue addObjectsFromArray:tracks];
        [self saveQueue];
    });
}

- (void)attemptToSendQueuedScrobbles {
    NSArray *tracksToSend = [self getAndClearQueuedScrobbles];
    if (tracksToSend.count == 0) {
        return;
    }

    // We'll send the tracks one by one, waiting for each to complete before sending the next.
    // We do this on a background queue to avoid blocking the caller.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        LFMScrobbler *scrobbler = [LFMScrobbler sharedScrobbler];
        LastFMClient *client = scrobbler.lastFMClient;

        NSMutableArray *failedTracks = [NSMutableArray array];
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(1);

        for (LFMTrack *track in tracksToSend) {
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            [client scrobbleTrack:track withCompletion:^(BOOL success, NSError *error) {
                if (success) {
                    [self addRecentScrobble:track];
                } else {
                    [failedTracks addObject:track];
                }
                dispatch_semaphore_signal(semaphore);
            }];
            // Wait for the completion to signal the semaphore
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            // Now we can go to the next track
        }

        // If there are failed tracks, re-queue them
        if (failedTracks.count > 0) {
            [self queueScrobbles:failedTracks];
        }

        dispatch_semaphore_release(semaphore);
    });
}

- (void)addRecentScrobble:(LFMTrack *)track {
    if (!track) return;

    dispatch_sync(_queueSerialQueue, ^{
        // Remove if already exists (to avoid duplicates in the recent list)
        [_recentScrobbles removeObjectIdenticalTo:track];
        // Add to the front
        [_recentScrobbles insertObject:track atIndex:0];
        // Trim to max size
        if (_recentScrobbles.count > kMaxRecentScrobbles) {
            [_recentScrobbles removeLastObject];
        }
        [self saveRecentScrobbles];
    });
}

- (BOOL)isRecentlyScrobbled:(LFMTrack *)track {
    if (!track) return NO;
    BOOL result = NO;
    dispatch_sync(_queueSerialQueue, ^{
        for (LFMTrack *recentTrack in _recentScrobbles) {
            // Compare the essential parts: artist, title, album, and startDate (or timestamp?)
            // We'll compare artist, title, and album. We don't have a timestamp in the track for when it was scrobbled.
            // We'll use the track's startDate? But two different tracks can have the same startDate? Unlikely.
            // We'll also include the duration? Not necessary.
            // We'll do a simple comparison of artist, title, and album.
            if ([track.artist isEqualToString:recentTrack.artist] &&
                [track.title isEqualToString:recentTrack.title] &&
                ([track.album isEqualToString:recentTrack.album] ||
                 (track.album == nil && recentTrack.album == nil))) {
                result = YES;
                break;
            }
        }
    });
    return result;
}

@end
#import "MediaRemoteManager.h"
#import <dlfcn.h>
#import <CoreFoundation/CoreFoundation.h>

// Function pointers for MediaRemote functions
static CFDictionaryRef (*MRMediaRemoteGetNowPlayingInfoPtr)() = NULL;
static Boolean (*MRMediaRemoteGetNowPlayingApplicationIsPlayingPtr)() = NULL;

// Keys for the now playing info dictionary - we'll try to get them from the framework, fallback to known strings
static CFStringRef kMRMediaRemoteNowPlayingInfoArtist = NULL;
static CFStringRef kMRMediaRemoteNowPlayingInfoAlbum = NULL;
static CFStringRef kMRMediaRemoteNowPlayingInfoTitle = NULL;
static CFStringRef kMRMediaRemoteNowPlayingInfoAlbumArtist = NULL;
static CFStringRef kMRMediaRemoteNowPlayingInfoTrackIdentifier = NULL;
static CFStringRef kMRMediaRemoteNowPlayingInfoArtworkURL = NULL; // Not MBID, but we don't have MBID key
static CFStringRef kMRMediaRemoteNowPlayingInfoPlaybackDuration = NULL;
static CFStringRef kMRMediaRemoteNowPlayingInfoPlaybackStartDate = NULL;

@interface MediaRemoteManager ()

@property (nonatomic, strong) MediaRemoteManagerCallback callback;
@property (nonatomic, assign) BOOL isMonitoring;
@property (nonatomic, strong) dispatch_queue_t callbackQueue;

@end

@implementation MediaRemoteManager

+ (instancetype)sharedManager {
    static MediaRemoteManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _callbackQueue = dispatch_queue_create("com.neyuh.lastfmscrobbler.mediaremote", DISPATCH_QUEUE_SERIAL);
        _isMonitoring = NO;

        // Initialize the keys if not already done
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [self initializeNowPlayingInfoKeys];
        });
    }
    return self;
}

- (void)initializeNowPlayingInfoKeys {
    void *handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
    if (handle) {
        // Try to get the keys as symbols
        kMRMediaRemoteNowPlayingInfoArtist = dlsym(handle, "kMRMediaRemoteNowPlayingInfoArtist");
        kMRMediaRemoteNowPlayingInfoAlbum = dlsym(handle, "kMRMediaRemoteNowPlayingInfoAlbum");
        kMRMediaRemoteNowPlayingInfoTitle = dlsym(handle, "kMRMediaRemoteNowPlayingInfoTitle");
        kMRMediaRemoteNowPlayingInfoAlbumArtist = dlsym(handle, "kMRMediaRemoteNowPlayingInfoAlbumArtist");
        kMRMediaRemoteNowPlayingInfoTrackIdentifier = dlsym(handle, "kMRMediaRemoteNowPlayingInfoTrackIdentifier");
        kMRMediaRemoteNowPlayingInfoArtworkURL = dlsym(handle, "kMRMediaRemoteNowPlayingInfoArtworkURL");
        kMRMediaRemoteNowPlayingInfoPlaybackDuration = dlsym(handle, "kMRMediaRemoteNowPlayingInfoPlaybackDuration");
        kMRMediaRemoteNowPlayingInfoPlaybackStartDate = dlsym(handle, "kMRMediaRemoteNowPlayingInfoPlaybackStartDate");

        dlclose(handle);
    }

    // If any key is NULL, create it from the known string
    if (!kMRMediaRemoteNowPlayingInfoArtist) {
        kMRMediaRemoteNowPlayingInfoArtist = CFStringCreateWithCString(NULL, "Artist", kCFStringEncodingUTF8);
    }
    if (!kMRMediaRemoteNowPlayingInfoAlbum) {
        kMRMediaRemoteNowPlayingInfoAlbum = CFStringCreateWithCString(NULL, "Album", kCFStringEncodingUTF8);
    }
    if (!kMRMediaRemoteNowPlayingInfoTitle) {
        kMRMediaRemoteNowPlayingInfoTitle = CFStringCreateWithCString(NULL, "Title", kCFStringEncodingUTF8);
    }
    if (!kMRMediaRemoteNowPlayingInfoAlbumArtist) {
        kMRMediaRemoteNowPlayingInfoAlbumArtist = CFStringCreateWithCString(NULL, "AlbumArtist", kCFStringEncodingUTF8);
    }
    if (!kMRMediaRemoteNowPlayingInfoTrackIdentifier) {
        kMRMediaRemoteNowPlayingInfoTrackIdentifier = CFStringCreateWithCString(NULL, "TrackIdentifier", kCFStringEncodingUTF8);
    }
    if (!kMRMediaRemoteNowPlayingInfoArtworkURL) {
        kMRMediaRemoteNowPlayingInfoArtworkURL = CFStringCreateWithCString(NULL, "ArtworkURL", kCFStringEncodingUTF8);
    }
    if (!kMRMediaRemoteNowPlayingInfoPlaybackDuration) {
        kMRMediaRemoteNowPlayingInfoPlaybackDuration = CFStringCreateWithCString(NULL, "PlaybackDuration", kCFStringEncodingUTF8);
    }
    if (!kMRMediaRemoteNowPlayingInfoPlaybackStartDate) {
        kMRMediaRemoteNowPlayingInfoPlaybackStartDate = CFStringCreateWithCString(NULL, "PlaybackStartDate", kCFStringEncodingUTF8);
    }
}

- (void)startMonitoringWithCallback:(MediaRemoteManagerCallback)callback {
    if (_isMonitoring) return;
    _isMonitoring = YES;
    _callback = callback;

    // Load MediaRemote framework and get function pointers
    if (![self loadMediaRemoteFunctions]) {
        NSLog(@"[LastFMScrobbler] Failed to load MediaRemote functions");
        return;
    }

    // Register for the notification
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    (CFNotificationCallback)nowPlayingInfoDidChange,
                                    CFSTR("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}

- (void)stopMonitoring {
    if (!_isMonitoring) return;
    _isMonitoring = FALSE;
    _callback = NULL;

    // Remove the observer
    CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL);
}

// This is the callback for the notification
static void nowPlayingInfoDidChange(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    // We want to delay a bit to let the metadata settle
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Get the shared instance and fetch the current now playing
        MediaRemoteManager *manager = [MediaRemoteManager sharedManager];
        [manager fetchCurrentNowPlayingWithCallback:manager.callback];
    });
}

- (void)fetchCurrentNowPlayingWithCallback:(MediaRemoteManagerCallback)callback {
    dispatch_async(_callbackQueue, ^{
        if (![self loadMediaRemoteFunctions]) {
            if (callback) {
                callback(NULL, NO);
            }
            return;
        }

        // Get the now playing info
        CFDictionaryRef info = MRMediaRemoteGetNowPlayingInfoPtr();
        if (!info) {
            if (callback) {
                callback(NULL, NO);
            }
            return;
        }

        // Check if the application is currently playing
        Boolean isPlaying = MRMediaRemoteGetNowPlayingApplicationIsPlayingPtr();
        if (!isPlaying) {
            if (callback) {
                callback(NULL, NO);
            }
            return;
        }

        // Extract the relevant information using our keys
        NSString *title = info ? (__bridge NSString *)CFDictionaryGetValue(info, kMRMediaRemoteNowPlayingInfoTitle) : nil;
        NSString *artist = info ? (__bridge NSString *)CFDictionaryGetValue(info, kMRMediaRemoteNowPlayingInfoArtist) : nil;
        NSString *album = info ? (__bridge NSString *)CFDictionaryGetValue(info, kMRMediaRemoteNowPlayingInfoAlbum) : nil;
        NSString *albumArtist = info ? (__bridge NSString *)CFDictionaryGetValue(info, kMRMediaRemoteNowPlayingInfoAlbumArtist) : nil;
        NSString *trackID = info ? (__bridge NSString *)CFDictionaryGetValue(info, kMRMediaRemoteNowPlayingInfoTrackIdentifier) : nil;
        // Note: ArtworkURL is not MBID, we leave MBID as nil
        NSString *mbid = nil;
        NSNumber *duration = info ? (__bridge NSNumber *)CFDictionaryGetValue(info, kMRMediaRemoteNowPlayingInfoPlaybackDuration) : nil;
        NSDate *startDate = info ? (__bridge NSDate *)CFDictionaryGetValue(info, kMRMediaRemoteNowPlayingInfoPlaybackStartDate) : nil;
        // Get the bundle identifier if possible - we don't have a key for that in the standard info
        NSString *bundleIdentifier = nil;

        LFMTrack *track = [[LFMTrack alloc] initWithTitle:title
                                                   artist:artist
                                                    album:album
                                               albumArtist:albumArtist
                                                   trackID:trackID
                                                      mbid:mbid
                                                 duration:duration
                                              startDate:startDate
                                       bundleIdentifier:bundleIdentifier];

        if (callback) {
            callback(track, YES);
        }
    });
}

- (BOOL)loadMediaRemoteFunctions {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Attempt to load the MediaRemote framework
        void *handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
        if (!handle) {
            NSLog(@"[LastFMScrobbler] Unable to load MediaRemote framework: %s", dlerror());
            return;
        }

        // Get the function pointers
        MRMediaRemoteGetNowPlayingInfoPtr = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo");
        MRMediaRemoteGetNowPlayingApplicationIsPlayingPtr = dlsym(handle, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");

        // Check if we got the required functions
        if (!MRMediaRemoteGetNowPlayingInfoPtr || !MRMediaRemoteGetNowPlayingApplicationIsPlayingPtr) {
            NSLog(@"[LastFMScrobbler] Failed to get required MediaRemote functions");
            dlclose(handle);
            handle = NULL;
        }
    });

    return MRMediaRemoteGetNowPlayingInfoPtr && MRMediaRemoteGetNowPlayingApplicationIsPlayingPtr;
}

@end
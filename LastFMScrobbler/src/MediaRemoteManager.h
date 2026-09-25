#import <Foundation/Foundation.h>
#import "LFMTrack.h"

@class MediaRemoteManager;

typedef void (^MediaRemoteManagerCallback)(LFMTrack *track, BOOL isPlaying);

@interface MediaRemoteManager : NSObject

+ (instancetype)sharedManager;

- (void)startMonitoringWithCallback:(MediaRemoteManagerCallback)callback;
- (void)stopMonitoring;
- (void)fetchCurrentNowPlayingWithCallback:(MediaRemoteManagerCallback)callback;

@end
#import "LFMTrack.h"

@implementation LFMTrack

- (instancetype)initWithTitle:(NSString *)title
                         artist:(NSString *)artist
                          album:(NSString *)album
                     albumArtist:(NSString *)albumArtist
                         trackID:(NSString *)trackID
                            mbid:(NSString *)mbid
                        duration:(NSNumber *)duration
                         startDate:(NSDate *)startDate
                  bundleIdentifier:(NSString *)bundleIdentifier {
    self = [super init];
    if (self) {
        _title = title ? [title copy] : nil;
        _artist = artist ? [artist copy] : nil;
        _album = album ? [album copy] : nil;
        _albumArtist = albumArtist ? [albumArtist copy] : nil;
        _trackID = trackID ? [trackID copy] : nil;
        _mbid = mbid ? [mbid copy] : nil;
        _duration = duration;
        _startDate = startDate ? [startDate copy] : nil;
        _bundleIdentifier = bundleIdentifier ? [bundleIdentifier copy] : nil;
    }
    return self;
}

@end
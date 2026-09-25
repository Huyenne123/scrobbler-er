#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LFMTrack : NSObject

@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) NSString *artist;
@property (nonatomic, copy, readonly) NSString *album;
@property (nonatomic, copy, readonly) NSString *albumArtist;
@property (nonatomic, copy, readonly) NSString *trackID;
@property (nonatomic, copy, readonly) NSString *mbid;
@property (nonatomic, strong, readonly) NSNumber *duration;
@property (nonatomic, strong, readonly) NSDate *startDate;
@property (nonatomic, copy, readonly) NSString *bundleIdentifier;

- (instancetype)initWithTitle:(NSString *)title
                         artist:(NSString *)artist
                          album:(NSString *)album
                     albumArtist:(NSString *)albumArtist
                         trackID:(NSString *)trackID
                            mbid:(NSString *)mbid
                        duration:(NSNumber *)duration
                         startDate:(NSDate *)startDate
                  bundleIdentifier:(NSString *)bundleIdentifier;

@end

NS_ASSUME_NONNULL_END
#import "MetadataNormalizer.h"

@implementation MetadataNormalizer

- (LFMTrack *)normalizeTrack:(LFMTrack *)track {
    if (!track) return track;

    // Create mutable copies of the strings to modify
    NSMutableString *title = [track.title mutableCopy];
    NSMutableString *artist = [track.artist mutableCopy];
    NSMutableString *album = [track.album mutableCopy];
    NSMutableString *albumArtist = [track.albumArtist mutableCopy];

    // Normalize title
    if (title) {
        [self normalizeString:title];
    }

    // Normalize artist
    if (artist) {
        [self normalizeString:artist];
    }

    // Normalize album
    if (album) {
        [self normalizeString:album];
    }

    // Normalize album artist
    if (albumArtist) {
        [self normalizeString:albumArtist];
    }

    // Create and return a new track with the normalized metadata
    LFMTrack *normalizedTrack = [[LFMTrack alloc] initWithTitle:title
                                                   artist:artist
                                                    album:album
                                               albumArtist:albumArtist
                                                   trackID:track.trackID
                                                      mbid:track.mbid
                                                 duration:track.duration
                                              startDate:track.startDate
                                       bundleIdentifier:track.bundleIdentifier];

    return normalizedTrack;
}

- (void)normalizeString:(NSMutableString *)string {
    // Remove common suffixes and prefixes
    [self removeCommonSuffixes:string];
    [self removeCommonPrefixes:string];
    [self normalizeFeaturing:string];
    [self normalizePunctuation:string];
}

- (void)removeCommonSuffixes:(NSMutableString *)string {
    // List of common suffixes to remove
    NSArray *suffixes = @[
        @"(Remastered)",
        @"[Remastered]",
        @"(Live)",
        @"[Live]",
        @"(Album Version)",
        @"[Album Version]",
        @"(Single Version)",
        @"[Single Version]",
        @"(Deluxe Edition)",
        @"[Deluxe Edition]",
        @"(Explicit)",
        @"[Explicit]",
        @"(Clean)",
        @"[Clean]",
    ];

    for (NSString *suffix in suffixes) {
        if ([string hasSuffix:suffix]) {
            NSRange range = [string rangeOfString:suffix options:NSBackwardsSearch];
            [string deleteCharactersInRange:range];
            break; // Only remove one suffix
        }
    }
}

- (void)removeCommonPrefixes:(NSMutableString *)string {
    // List of common prefixes to remove
    NSArray *prefixes = @[
        @"(Remastered)",
        @"[Remastered]",
        @"(Live)",
        @"[Live]",
        @"(Album Version)",
        @"[Album Version]",
        @"(Single Version)",
        @"[Single Version]",
        @"(Deluxe Edition)",
        @"[Deluxe Edition]",
        @"(Explicit)",
        @"[Explicit]",
        @"(Clean)",
        @"[Clean]",
    ];

    for (NSString *prefix in prefixes) {
        if ([string hasPrefix:prefix]) {
            NSRange range = [string rangeOfString:prefix options:NSAnchoredSearch];
            [string deleteCharactersInRange:range];
            break; // Only remove one prefix
        }
    }
}

- (void)normalizeFeaturing:(NSMutableString *)string {
    // Normalize "feat." to "feat"
    NSRange range = [string rangeOfString:@"feat." options:NSCaseInsensitiveSearch];
    if (range.location != NSNotFound) {
        [string replaceCharactersInRange:range withString:@"feat"];
    }
}

- (void)normalizePunctuation:(NSMutableString *)string {
    // Trim whitespace and punctuation from the ends
    NSCharacterSet *whitespaceAndPunctuation = [NSCharacterSet characterSetWithCharactersInString:@"
"];
    NSRange range = [string rangeOfCharacterFromSet:whitespaceAndPunctuation options:NSBackwardsSearch];
    if (range.location != NSNotFound) {
        [string deleteCharactersInRange:NSMakeRange(range.location, string.length - range.location)];
    }

    range = [string rangeOfCharacterFromSet:whitespaceAndPunctuation options:NSAnchoredSearch];
    if (range.location != NSNotFound) {
        [string deleteCharactersInRange:NSMakeRange(0, range.location + range.length)];
    }
}

@end
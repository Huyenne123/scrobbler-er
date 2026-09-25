#import "LastFMClient.h"
#import <CommonCrypto/CommonDigest.h>
#import <Foundation/Foundation.h>

static NSString *const kLastFM_APIEndpoint = @"https://ws.audioscrobbler.com/2.0/";

@interface LastFMClient ()

@property (nonatomic, copy) NSString *sessionKey;
@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, copy) NSString *apiSecret;

// Helper methods
- (NSString *)apiSignatureForParameters:(NSDictionary *)parameters;
- (void)sendRequestWithParameters:(NSDictionary *)parameters completion:(void (^)(NSDictionary *response, NSError *error))completion;

@end

@implementation LastFMClient

- (instancetype)init {
    self = [super init];
    if (self) {
        // We'll load the API key and secret from the credential store or user defaults?
        // Actually, we should get them from the CredentialStore, but for now we leave them nil and expect them to be set via a method.
        // Alternatively, we can load them in the LFMScrobbler and set them here.
        // We'll add a method to set API credentials.
    }
    return self;
}

// We'll add a method to set API credentials (called by LFMScrobbler after reading from credential store)
- (void)setAPIKey:(NSString *)apiKey secret:(NSString *)apiSecret {
    _apiKey = apiKey;
    _apiSecret = apiSecret;
}

- (void)setSessionKey:(NSString *)sessionKey {
    _sessionKey = sessionKey;
}

- (void)invalidate {
    _sessionKey = nil;
}

- (void)updateNowPlayingWithTrack:(LFMTrack *)track {
    if (!_sessionKey || !_apiKey || !_apiSecret) {
        NSLog(@"[LastFMScrobbler] Missing credentials for updateNowPlaying");
        return;
    }

    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"method"] = @"track.updateNowPlaying";
    params[@"artist"] = track.artist;
    params[@"track"] = track.title;
    if (track.album) {
        params[@"album"] = track.album;
    }
    if (track.albumArtist) {
        params[@"albumArtist"] = track.albumArtist;
    }
    if (track.duration) {
        params[@"duration"] = track.duration;
    }
    // Note: We don't send mbid in updateNowPlaying? The API allows it but we don't have it.

    [self sendAuthenticatedRequestWithParameters:params completion:^(NSDictionary *response, NSError *error) {
        if (error) {
            NSLog(@"[LastFMScrobbler] updateNowPlaying failed: %@", error);
        } else {
            NSLog(@"[LastFMScrobbler] updateNowPlaying successful");
        }
    }];
}

- (void)scrobbleTrack:(LFMTrack *)track withCompletion:(void (^)(BOOL success, NSError *error))completion {
    if (!_sessionKey || !_apiKey || !_apiSecret) {
        NSLog(@"[LastFMScrobbler] Missing credentials for scrobble");
        if (completion) {
            completion(NO, [NSError errorWithDomain:@"LastFMScrobbler" code:-1 userInfo:@{NSLocalizedDescriptionKey:@"Missing credentials"}]);
        }
        return;
    }

    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"method"] = @"track.scrobble";
    params[@"artist"] = track.artist;
    params[@"track"] = track.title;
    if (track.album) {
        params[@"album"] = track.album;
    }
    if (track.timestamp) {
        // We don't have a timestamp in LFMTrack, but we can use the current time or the startDate?
        // The scrobble requires a timestamp (Unix timestamp of when the track started).
        // We have startDate in LFMTrack, so we can use that.
        // If we don't have startDate, we can use the current time? But that's not accurate.
        // We'll use the startDate if available, otherwise we'll omit and let Last.fm use the current time?
        // According to the API, timestamp is optional but recommended.
        // We'll convert startDate to Unix timestamp.
        if (track.startDate) {
            params[@"timestamp"] = @(track.startDate.timeIntervalSince1970);
        }
    }
    // Note: We don't send albumArtist, mbid, etc. in scrobble? The API allows them but we don't have them.

    [self sendAuthenticatedRequestWithParameters:params completion:^(NSDictionary *response, NSError *error) {
        BOOL success = !error && [response[@"scrobbles"][@"scrobble"][@"[@"accepted"][@"#text"] intValue] > 0];
        if (completion) {
            completion(success, error);
        }
        if (!success && error) {
            NSLog(@"[LastFMScrobbler] Scrobble failed: %@", error);
        } else if (success) {
            NSLog(@"[LastFMScrobbler] Scrobbled successfully: %@ - %@", track.artist, track.title);
        }
    }];
}

#pragma mark - Private

- (void)sendAuthenticatedRequestWithParameters:(NSMutableDictionary *)parameters completion:(void (^)(NSDictionary *response, NSError *error))completion {
    // Add the required parameters
    parameters[@"api_key"] = self.apiKey;
    parameters[@"sk"] = self.sessionKey;
    parameters[@"format"] = @"json";

    // Generate the api_sig
    NSString *apiSig = [self apiSignatureForParameters:parameters];
    parameters[@"api_sig"] = apiSig;

    [self sendRequestWithParameters:parameters completion:completion];
}

- (NSString *)apiSignatureForParameters:(NSDictionary *)parameters {
    // Create an array of the keys and sort them
    NSArray *sortedKeys = [parameters.keys sortedArrayUsingSelector:@selector(compare:)];
    NSMutableString *stringToSign = [NSMutableString string];
    for (NSString *key in sortedKeys) {
        [stringToSign appendFormat:@"%@%@", key, parameters[key]];
    }
    // Append the secret
    [stringToSign appendString:self.apiSecret];

    // Compute MD5 hash
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(stringToSign.UTF8String, (CC_LONG)stringToSign.length, digest);

    // Convert to hex string
    NSMutableString *hash = [NSMutableString string];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [hash appendFormat:@"%02x", digest[i]];
    }
    return [hash copy];
}

- (void)sendRequestWithParameters:(NSDictionary *)parameters completion:(void (^)(NSDictionary *response, NSError *error))completion {
    // Build the URL
    NSURL *url = [NSURL URLWithString:kLastFM_APIEndpoint];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";

    // Build the HTTP body
    NSMutableString *bodyString = [NSMutableString string];
    NSArray *sortedKeys = [parameters.keys sortedArrayUsingSelector:@selector(compare:)];
    for (NSString *key in sortedKeys) {
        if ([bodyString length] > 0) {
            [bodyString appendString:@"&"];
        }
        [bodyString appendFormat:@"%@=%@", key, [parameters[key] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    }
    request.HTTPBody = [bodyString dataUsingEncoding:NSUTF8StringEncoding];

    // Create the session and task
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }

        // Parse the JSON response
        NSError *jsonError;
        NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError) {
            if (completion) {
                completion(nil, jsonError);
            }
            return;
        }

        // Check for Last.fm error
        if (jsonResponse[@"error"]) {
            NSError *apiError = [NSError errorWithDomain:@"LastFMScrobbler" code:[jsonResponse[@"error"] integerValue] userInfo:@{NSLocalizedDescriptionKey:jsonResponse[@"message"]}];
            if (completion) {
                completion(nil, apiError);
            }
            return;
        }

        if (completion) {
            completion(jsonResponse, nil);
        }
    }];
    [task resume];
}

@end
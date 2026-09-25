#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CredentialStore : NSObject

+ (instancetype)sharedStore;

- (void)loadCredentials;

// API Key (non-secret, stored in user defaults)
@property (nonatomic, copy, readonly) NSString *apiKey;
// Username (non-secret, stored in user defaults)
@property (nonatomic, copy, readonly) NSString *username;
// Password (secret, stored in keychain)
@property (nonatomic, copy, readonly) NSString *password;
// API Secret (secret, stored in keychain)
@property (nonatomic, copy, readonly) NSString *apiSecret;
// Session Key (secret, stored in keychain)
@property (nonatomic, copy, readonly) NSString *sessionKey;

// Methods to save credentials (called from preference bundle)
- (void)setAPIKey:(NSString *)apiKey;
- (void)setUsername:(NSString *)username;
- (void)setPassword:(NSString *)password;
- (void)setAPISecret:(NSString *)apiSecret;
- (void)setSessionKey:(NSString *)sessionKey;

// Clear all credentials
- (void)clearCredentials;

@end

NS_ASSUME_NONNULL_END
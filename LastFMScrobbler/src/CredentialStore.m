#import "CredentialStore.h"
#import <Security/Security.h>

static NSString *const kServiceIdentifier = @"com.neyuh.lastfmscrobbler";

@interface CredentialStore ()

@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, copy) NSString *apiSecret;
@property (nonatomic, copy) NSString *sessionKey;

@end

@implementation CredentialStore

@synthesize apiKey = _apiKey;
@synthesize username = _username;
@synthesize password = _password;
@synthesize apiSecret = _apiSecret;
@synthesize sessionKey = _sessionKey;

+ (instancetype)sharedStore {
    static CredentialStore *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Load from defaults and keychain
        [self loadCredentials];
    }
    return self;
}

- (void)loadCredentials {
    // Load non-sensitive data from NSUserDefaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _apiKey = [defaults stringForKey:@"apiKey"];
    _username = [defaults stringForKey:@"username"];

    // Load sensitive data from Keychain
    _password = [self loadStringFromKeychainForKey:@"password"];
    _apiSecret = [self loadStringFromKeychainForKey:@"apiSecret"];
    _sessionKey = [self loadStringFromKeychainForKey:@"sessionKey"];
}

#pragma mark - Keychain Helpers

- (NSString *)loadStringFromKeychainForKey:(NSString *)key {
    NSData *data = [self loadDataFromKeychainForKey:key];
    if (data) {
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return nil;
}

- (NSData *)loadDataFromKeychainForKey:(NSString *)key {
    NSMutableDictionary *searchDictionary = [self keychainSearchDictionaryWithKey:key];
    [searchDictionary setObject:(__bridge id)kCFBooleanTrue forKey:(__bridge id)kSecReturnData];
    [searchDictionary setObject:(__bridge id)kSecMatchLimitOne forKey:(__bridge id)kSecMatchLimit];

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)searchDictionary, &result);
    if (status == noErr) {
        return (__bridge_transfer NSData *)result;
    }
    return nil;
}

- (BOOL)saveString:(NSString *)string forKey:(NSString *)key {
    if (!string) {
        return [self deleteItemForKey:key];
    }
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    return [self saveData:data forKey:key];
}

- (BOOL)saveData:(NSData *)data forKey:(NSString *)key {
    NSMutableDictionary *searchDictionary = [self keychainSearchDictionaryWithKey:key];
    [searchDictionary setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [searchDictionary setObject:data forKey:(__bridge id)kSecValueData];
    [searchDictionary setObject:[self accessible] forKey:(__bridge id)kSecAttrAccessible];

    // Delete any existing item first
    SecItemDelete((__bridge CFDictionaryRef)searchDictionary);

    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)searchDictionary, NULL);
    return status == noErr;
}

- (BOOL)deleteItemForKey:(NSString *)key {
    NSMutableDictionary *searchDictionary = [self keychainSearchDictionaryWithKey:key];
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)searchDictionary);
    return status == noErr || status == errSecItemNotFound;
}

- (NSMutableDictionary *)keychainSearchDictionaryWithKey:(NSString *)key {
    NSMutableDictionary *searchDictionary = [NSMutableDictionary dictionary];
    [searchDictionary setObject:(__bridge id)kSecClassGenericPassword forKey:(__bridge id)kSecClass];
    [searchDictionary setObject:kServiceIdentifier forKey:(__bridge id)kSecAttrService];
    [searchDictionary setObject:key forKey:(__bridge id)kSecAttrAccount];
    return searchDictionary;
}

- (NSString *)accessible {
    // kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly means the data is accessible after the device is unlocked once until the next reboot.
    // This is suitable for our daemon that runs as mobile user.
    return (NSString *)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
}

#pragma mark - Public Setters (called from preference bundle)

- (void)setAPIKey:(NSString *)apiKey {
    if (_apiKey != apiKey) {
        _apiKey = apiKey;
        [[NSUserDefaults standardUserDefaults] setObject:apiKey forKey:@"apiKey"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)setUsername:(NSString *)username {
    if (_username != username) {
        _username = username;
        [[NSUserDefaults standardUserDefaults] setObject:username forKey:@"username"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)setPassword:(NSString *)password {
    if (![self saveString:password forKey:@"password"]) {
        NSLog(@"[LastFMScrobbler] Failed to save password to keychain");
    }
    _password = password;
}

- (void)setAPISecret:(NSString *)apiSecret {
    if (![self saveString:apiSecret forKey:@"apiSecret"]) {
        NSLog(@"[LastFMScrobbler] Failed to save API secret to keychain");
    }
    _apiSecret = apiSecret;
}

- (void)setSessionKey:(NSString *)sessionKey {
    if (![self saveString:sessionKey forKey:@"sessionKey"]) {
        NSLog(@"[LastFMScrobbler] Failed to save session key to keychain");
    }
    _sessionKey = sessionKey;
}

- (void)clearCredentials {
    // Clear user defaults
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"apiKey"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"username"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    // Clear keychain
    [self deleteItemForKey:@"password"];
    [self deleteItemForKey:@"apiSecret"];
    [self deleteItemForKey:@"sessionKey"];

    // Clear local copies
    _apiKey = nil;
    _username = nil;
    _password = nil;
    _apiSecret = nil;
    _sessionKey = nil;
}

#pragma mark - Getters (readonly)

- (NSString *)apiKey {
    return _apiKey;
}

- (NSString *)username {
    return _username;
}

- (NSString *)password {
    return _password;
}

- (NSString *)apiSecret {
    return _apiSecret;
}

- (NSString *)sessionKey {
    return _sessionKey;
}

@end
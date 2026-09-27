#import <Preferences/Preferences.h>

@interface LastFMScrobblerPrefsController : PSListController
@end

@implementation LastFMScrobblerPrefsController

- (id)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"LastFMScrobblerPrefs" target:self];
    }
    return _specifiers;
}

@end
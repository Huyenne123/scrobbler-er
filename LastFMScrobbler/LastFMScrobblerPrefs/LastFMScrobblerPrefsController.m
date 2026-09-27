#import <Preferences/Preferences.h>

@interface LastFMScrobblerPrefsController : PSListController
@end

@implementation LastFMScrobblerPrefsController

- (NSMutableArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"LastFMScrobblerPrefs" target:self];
    }
    return _specifiers;
}

@end
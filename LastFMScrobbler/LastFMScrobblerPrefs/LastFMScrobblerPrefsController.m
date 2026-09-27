#import <Preferences/Preferences.h>

@interface LastFMScrobblerPrefsController : PSListController
@property (nonatomic, strong) NSArray *specifiers;
@end

@implementation LastFMScrobblerPrefsController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"LastFMScrobblerPrefs" target:self];
    }
    return _specifiers;
}

@end
#import <Preferences/Preferences.h>

@interface LastFMScrobblerPrefsController : PSListController
@property (nonatomic, retain) NSMutableArray *specifiers;
@end

@implementation LastFMScrobblerPrefsController

@dynamic specifiers;

- (NSMutableArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"LastFMScrobblerPrefs" target:self];
    }
    return _specifiers;
}

@end
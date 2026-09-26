#import <Foundation/Foundation.h>
#import "LFMScrobbler.h"

int main(int argc, char *argv[]) {
    @autoreleasepool {
        // Initialize the scrobbler
        [[LFMScrobbler sharedScrobbler] start];

        // Run the run loop to keep the daemon alive
        [[NSRunLoop currentRunLoop] run];
    }
    return 0;
}
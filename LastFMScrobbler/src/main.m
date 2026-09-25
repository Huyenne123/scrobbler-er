#import <Foundation/Foundation.h>
#import <unistd.h>
#import <sys/types.h>
#import <sys/sysctl.h>
#import "LFMScrobbler.h"

int main(int argc, char *argv[]) {
    @autoreleasepool {
        // Daemonize: detach from terminal, run in background
        if (daemon(1, 0) == -1) {
            perror("daemon");
            exit(EXIT_FAILURE);
        }

        // Initialize the scrobbler
        [[LFMScrobbler sharedScrobbler] start];

        // Run the run loop to keep the daemon alive
        [[NSRunLoop currentRunLoop] run];
    }
    return 0;
}
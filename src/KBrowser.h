#import <ChromiumTabs/ChromiumTabs.h>

// We provide our own CTBrowser subclass so we can create our own, custom tabs.
// See the implementation file for details.

@interface KBrowser : CTBrowser {
}

+ (KBrowser*)mainBrowser;

// received from the browsers window controller in order to keep track of which
// browser instance is the "main" one
- (void)windowDidBecomeMain:(NSNotification*)notification;
- (void)windowDidResignMain:(NSNotification*)notification;

@end

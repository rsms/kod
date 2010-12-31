#import <ChromiumTabs/ChromiumTabs.h>

// We provide our own CTBrowser subclass so we can create our own, custom tabs.
// See the implementation file for details.

@interface KBrowser : CTBrowser {
  BOOL shouldCloseTab;
}

@end

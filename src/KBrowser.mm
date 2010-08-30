#import "KBrowser.h"
#import "KTabContents.h"
#import "KBrowserWindowController.h"
#import <ChromiumTabs/common.h>

@implementation KBrowser

// This method is called when a new tab is being created. We need to return a
// new CTTabContents object which will represent the contents of the new tab.
-(CTTabContents*)createBlankTabBasedOn:(CTTabContents*)baseContents {
  // Create a new instance of our tab type
  return [[KTabContents alloc] initWithBaseTabContents:baseContents];
}

// Create a new window controller. The default implementation will create a
// controller loaded with a nib called "BrowserWindow". If the nib can't be
// found in the main bundle, a fallback nib will be loaded from the framework.
// This is usually enough since all UI which normally is customized is comprised
// within each tab (CTTabContents view).
-(CTBrowserWindowController *)createWindowController {
  NSString *windowNibPath = [CTUtil pathForResource:@"BrowserWindow"
                                             ofType:@"nib"];
  return [[KBrowserWindowController alloc] initWithWindowNibPath:windowNibPath
                                                         browser:self];
}


-(CTTabContents*)addTabContents:(CTTabContents*)tab
                        atIndex:(int)index
                   inForeground:(BOOL)foreground {
  if (index == -1) {
    // -1 means "append" -- we add it after the currently selected tab
    index = [self selectedTabIndex] + 1;
  }
  return [super addTabContents:tab atIndex:index inForeground:foreground];
}


/*-(void)newWindow {
  [isa openEmptyWindow];
}

-(void)closeWindow {
  [self.window orderOut:self];
  [self.window performClose:self];  // Autoreleases the controller.
}

    case CTBrowserCommandNewWindow:            [self newWindow]; break;
    //case CTBrowserCommandNewIncognitoWindow: break;
    case CTBrowserCommandCloseWindow:          [self closeWindow]; break;
    //case CTBrowserCommandAlwaysOnTop: break;
    case CTBrowserCommandNewTab:               [self addBlankTab]; break;
    case CTBrowserCommandCloseTab:             [self closeTab]; break;*/

@end

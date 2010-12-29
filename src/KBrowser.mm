#import "KBrowser.h"
#import "KDocument.h"
#import "kconf.h"
#import "KBrowserWindowController.h"
#import "KToolbarController.h"
#import "common.h"

@implementation KBrowser

- (void) dealloc {
  // fix for a bug where tabs keep lingering after their browser has died
  for (KDocument *tab in self) {
    tab.browser = nil;
  }
  [super dealloc];
}



// This method is called when a new tab is being created. We need to return a
// new CTTabContents object which will represent the contents of the new tab.
- (CTTabContents*)createBlankTabBasedOn:(CTTabContents*)baseContents {
  // Create a new instance of our tab type
  return [[[KDocument alloc]
      initWithBaseTabContents:baseContents] autorelease];
}


- (CTToolbarController*)createToolbarController {
  // subclasses could override this -- returning nil means no toolbar
  return [[[KToolbarController alloc] initWithNibName:@"Toolbar"
                                               bundle:kconf_bundle()
                                              browser:self] autorelease];
}


- (CTTabContents*)addTabContents:(CTTabContents*)tab
                        atIndex:(int)index
                   inForeground:(BOOL)foreground {
  if (index == -1) {
    // -1 means "append" -- we add it after the currently selected tab
    index = [self selectedTabIndex] + 1;
  }
  return [super addTabContents:tab atIndex:index inForeground:foreground];
}


/*-(void)updateTabStateForContent:(CTTabContents*)contents {
  DLOG("updateTabStateForContent:%@", contents);
  int index = tabStripModel_->GetIndexOfTabContents(contents);
  DLOG_EXPR(index);
  if (index != -1) {
    tabStripModel_->UpdateTabContentsStateAt(index, CTTabChangeTypeAll);
  }
}*/


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

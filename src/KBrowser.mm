// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

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


// Overriding CTBrowser's -closeTab in order to check if the document is
// dirty or not before closing.
- (void)closeTab {
  shouldCloseTab = NO;
}


// canCloseDocumentWithDelegate callback
- (void)document:(NSDocument *)tab
     shouldClose:(BOOL)shouldClose
     contextInfo:(void*)contextInfo {
  shouldCloseTab = shouldClose;

  if ( shouldClose ) {
    [super closeTab];
  }
}


// Overriding CTBrowser's implementation, which always returns YES
- (BOOL)canCloseTab {
  return shouldCloseTab;
}

- (BOOL)canCloseContentsAt:(int)index {
  if ( shouldCloseTab == YES ) {
    return shouldCloseTab;
  }

  KDocument *doc = (KDocument *)[self tabContentsAtIndex:index];

  if ([doc isDirty]) {
    [doc canCloseDocumentWithDelegate:self shouldCloseSelector:@selector(document:shouldClose:contextInfo:) contextInfo:nil];
  } else {
    shouldCloseTab = YES;
  }

  return shouldCloseTab;
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

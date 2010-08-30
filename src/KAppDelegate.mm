#import "KAppDelegate.h"
#import "KBrowser.h"
#import "KBrowserWindowController.h"
#import "KTabContents.h"
#import "KDocumentController.h"
#import <ChromiumTabs/common.h>

@implementation KAppDelegate

@synthesize documentController = documentController_;

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
  // Create our document controller. We need to be the first who creates a
  // NSDocumentController type, since it's somewhat singleton.
  documentController_ = [[KDocumentController alloc] init];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  // NOTE: KDocumentController will create a new window & tab upon start
}

// When there are no windows in our application, this class (AppDelegate) will
// become the first responder. We forward the command to the browser class.
- (void)commandDispatch:(id)sender {
  [KBrowser executeCommand:[sender tag]];
}

/*- (NSApplicationTerminateReply)applicationShouldTerminate:
    (NSApplication*)sender {
  DLOG_TRACE();
  return NSTerminateNow;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
  DLOG_TRACE();
}*/

/*- (NSApplicationTerminateReply)applicationShouldTerminate:
    (NSApplication*)sender {
  DLOG_TRACE();
  if (documentController_ && [documentController_ hasEditedDocuments]) {
    SEL selector = @selector(documentController:didCloseAll:contextInfo:);
    [documentController_ closeAllDocumentsWithDelegate:self
                                   didCloseAllSelector:selector
                                           contextInfo:nil];
    return NSTerminateLater;
  } else {
    return NSTerminateNow;
  }
}

- (void)documentController:(NSDocumentController *)docController
               didCloseAll:(BOOL)didCloseAll
               contextInfo:(void *)contextInfo {
  // The document controller have given all documents a chance to close and
  // possibly save themselves, or abort the termination cycle. If all documents
  // have been closed, we know we can continue with out termination.
  [NSApp replyToApplicationShouldTerminate:didCloseAll];
}*/

/*-(void)openDocumentInWindow:(KBrowserWindowController *)windowController
                     sender:(id)sender {
  // Create and display a standard open panel
  NSOpenPanel* openPanel = [[NSOpenPanel openPanel] retain];
  [openPanel setCanChooseFiles:YES];
  [openPanel setCanChooseDirectories:YES];
  [openPanel setResolvesAliases:YES];
  [openPanel setAllowsMultipleSelection:YES];
  [openPanel setCanCreateDirectories:YES];
  [openPanel beginWithCompletionHandler:^void (NSInteger result) {
    if (result == NSFileHandlingPanelOKButton) {
      CTBrowser *browser = nil;
      if (windowController) {
        // Use the browser assigned to the calling window
        browser = windowController.browser;
      }
      KTabContents *tab;
      for (NSURL *url in [openPanel URLs]) {
        if (!browser) {
          // Lazily create a new browser instance if we got called from the app
          // delegate
          browser = [KBrowser browser];
        }
        // Open the file
        NSError* error = nil;
        KTabContents* tab =
            [documentController_ openDocumentWithContentsOfURL:url
                                                       display:YES
                                                         error:&error];
        // Check results
        if (!tab || error) {
          // Error? Note that we do not need to free |tab| here -- cocoa takes
          // care of that for us, since we got an error (is that a good thing?).
          [NSApp presentError:error];
        } else {
          // Add the tab
          [browser addTabContents:tab];
          DLOG("added %@", url);
        }
      }
      if ([[openPanel URLs] count] > 0) {
        assert(browser);
        [browser.windowController showWindow:self];
      }
    }
    [openPanel release];
  }];
}*/

@end

#import "KAppDelegate.h"
#import "KBrowser.h"
#import "KBrowserWindowController.h"
#import "KTabContents.h"
#import "KDocumentController.h"
#import "kconf.h"
#import "KStyle.h"
#import "KNodeProcess.h"
#import "common.h"

#if K_WITH_F_SCRIPT
#import <FScript/FScript.h>
#endif

@implementation KAppDelegate

- (IBAction)newWindow:(id)sender {
  KBrowserWindowController* windowController = (KBrowserWindowController*)
      [[KBrowserWindowController browserWindowController] retain];
  [windowController newDocument:sender];
  [windowController showWindow:self];
}

- (IBAction)newDocument:(id)sender {
  [self newWindow:sender];
}

- (IBAction)insertTab:(id)sender {
  // When we receive "new tab" it means "gimme a new tab in a new window"
  [self newDocument:sender];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
  // Create our document controller. We need to be the first who creates a
  // NSDocumentController type, since it's somewhat singleton.
  [[KDocumentController alloc] init];
  
  // Register ourselves as service provider
  [NSApp setServicesProvider:self];
  
  // Start loading default style
  NSURL *builtinURL = kconf_res_url(@"style/default.css");
  NSURL *url = kconf_url(@"styleURL", builtinURL);
  [[KStyle sharedStyle] loadFromURL:url withCallback:^(NSError *error) {
    if (error) [NSApp presentError:error];
  }];
  
  // XXX load another style after 5 seconds
  /*h_dispatch_delayed_main(5000, ^{
    NSURL *url2 = kconf_res_url(@"style/bright.css");
    [[KStyle sharedStyle] loadFromURL:url2 withCallback:^(NSError *error) {
      if (error) [NSApp presentError:error];
    }];
  });*/
  
  // Register URL handler
  NSAppleEventManager *aem = [NSAppleEventManager sharedAppleEventManager];
	[aem setEventHandler:self
           andSelector:@selector(openUrl:withReplyEvent:)
         forEventClass:kInternetEventClass
            andEventID:kAEGetURL];

  // Add F-Script menu item if feasible
  #if K_WITH_F_SCRIPT
  [[NSApp mainMenu] addItem:[[FScriptMenuItem alloc] init]];
  #endif
  
  // Start node.js
  [KNodeProcess sharedProcess];
}

- (void)openUrl:(NSAppleEventDescriptor*)event
 withReplyEvent:(NSAppleEventDescriptor*)replyEvent {
	NSString *urlstr = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
	NSURL* url = [NSURL URLWithString:urlstr];
  if (url) {
    [self openURL:url];
  }
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  // NOTE: KDocumentController will create a new window & tab upon start
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


#pragma mark -
#pragma mark NSServices


- (void)openLink:(NSPasteboard*)pboard
        userData:(NSString*)userData
           error:(NSString**)error {
  DLOG("openLink:%@ userData:%@", pboard, userData);
  
  // Read all URLs in |pboard|
  NSArray *classes = [NSArray arrayWithObject:[NSURL class]];
  NSArray *urls = [pboard readObjectsForClasses:classes options:nil];
  if (!urls.count) {
    classes = [NSArray arrayWithObject:[NSString class]];
    NSArray *strings = [pboard readObjectsForClasses:classes options:nil];
    urls = [NSMutableArray array];
    for (NSString *str in strings) {
      NSURL *url = [NSURL URLWithString:str];
      if (!url) {
        // This happens for malformed URL
        // For example (ironically enough) Apple's developer docs URLs:
        //   "http://developer.apple.com/library/mac/#documentation/Miscellaneou
        //   s/Reference/UTIRef/Articles/System-DeclaredUniformTypeIdentifiers.h
        //   tml#//apple_ref/doc/uid/TP40009259-SW1"
        *error = @"Failed to parse link(s)";
      } else {
        [(NSMutableArray*)urls addObject:url];
      }
    }
  }
  
  // open all urls in the normal priority background dispatch queue
  //DLOG("urls => %@", urls);
  if (urls.count) {
    for (NSURL *url in urls) {
      [self openURL:url];
    }
  }
  
  //[pboard clearContents];
}


- (void)openURL:(NSURL*)url {
  KDocumentController *docCtrl =
      (KDocumentController*)[NSDocumentController sharedDocumentController];
  if ([url isFileURL]) {
    // file URLs use blocking I/O
    K_DISPATCH_BG_ASYNC({
      [docCtrl openDocumentWithContentsOfURL:url display:YES error:nil];
    });
  } else {
    // non-file URLs use async I/O and should be run on the main thread
    // (the underlying mechansim will take care of scheduling on the main
    // thread, so we don't need to check for it here).
    [docCtrl openDocumentWithContentsOfURL:url display:YES error:nil];
  }
}

@end

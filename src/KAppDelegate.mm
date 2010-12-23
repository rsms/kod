#import "common.h"
#import "KAppDelegate.h"
#import "KBrowser.h"
#import "KBrowserWindowController.h"
#import "KTerminalUsageWindowController.h"
#import "KTabContents.h"
#import "KDocumentController.h"
#import "kconf.h"
#import "KStyle.h"
#import "KNodeProcess.h"
#import "KMachService.h"
#import "KSudo.h"

#import <Sparkle/SUUpdater.h>

#if K_WITH_F_SCRIPT
#import <FScript/FScript.h>
#endif


#if KOD_WITH_BREAKPAD
BreakpadRef gBreakpad = NULL;

void k_breakpad_init() {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  gBreakpad = NULL;
  NSDictionary *plist = [[NSBundle mainBundle] infoDictionary];
  if (plist) {
    // Note: version 1.0.0.4 of the framework changed the type of the argument 
    // from CFDictionaryRef to NSDictionary * on the next line:
    gBreakpad = BreakpadCreate(plist);
  }
  [pool release];
}
#else
void k_breakpad_init() {}
#endif


@implementation KAppDelegate


- (void)awakeFromNib {
  k_breakpad_init();
  
  // Sparkle configuration
  [sparkleUpdater_ setAutomaticallyChecksForUpdates:YES];
  [sparkleUpdater_ setUpdateCheckInterval:3600.0];
  [sparkleUpdater_ setFeedURL:[NSURL URLWithString:
      @"http://kodapp.com/appcast.xml"]];
  [sparkleUpdater_ setAutomaticallyDownloadsUpdates:YES];
}


#pragma mark -
#pragma mark Actions

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


- (IBAction)displayTerminalUsage:(id)sender {
  if (!terminalUsageWindowController_) {
    terminalUsageWindowController_ =
        [[KTerminalUsageWindowController alloc] initWithWindowNibName:
        @"terminal-usage"];
  }
  [terminalUsageWindowController_ showWindow:sender];
}


#pragma mark -
#pragma mark Notifications


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
  
  // Start Mach service
  [KMachService sharedService];
}


- (void)openUrl:(NSAppleEventDescriptor*)event
 withReplyEvent:(NSAppleEventDescriptor*)replyEvent {
	NSString *urlstr = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
	NSURL* url = [NSURL URLWithString:urlstr];
  if (url) {
    NSArray *urls = [NSArray arrayWithObject:url];
    KDocumentController *documentController =
      (KDocumentController*)[NSDocumentController sharedDocumentController];
    [documentController openDocumentsWithContentsOfURLs:urls callback:nil];
  }
}


- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  // NOTE: KDocumentController will create a new window & tab upon start
  [sparkleUpdater_ setAutomaticallyDownloadsUpdates:YES];
  
  // Stuff we do upon first launch (keep this to a minimum)
  if (!kconf_bool(@"firstLaunchMarker", NO)) {
    kconf_set_bool(@"firstLaunchMarker", YES);
    // Offer to enable the kod helper
    [self displayTerminalUsage:self];
  }
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
  #if KOD_WITH_BREAKPAD
  BreakpadRelease(gBreakpad);
  #endif
  [[KNodeProcess sharedProcess] terminate];
}


- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames {
  //DLOG("application:openFiles:%@", filenames);
  NSMutableArray *fileURLs = [NSMutableArray array];
  NSMutableArray *dirPaths = [NSMutableArray array];
  NSFileManager *fm = [NSFileManager defaultManager];

  // check URL refers to a local directory
  for (NSString *path in filenames) {
    BOOL isDir;
    BOOL exists = [fm fileExistsAtPath:path isDirectory:&isDir];
    if (exists) {
      if (isDir) {
        [dirPaths addObject:path];
      } else {
        [fileURLs addObject:[NSURL fileURLWithPath:path]];
      }
    }
  }

  // open first directory
  if (dirPaths.count != 0) {
    KBrowserWindowController *windowController = (KBrowserWindowController *)
        [KBrowserWindowController mainBrowserWindowController];
    NSURL *dirURL = [NSURL fileURLWithPath:[dirPaths objectAtIndex:0]
                               isDirectory:YES];
    NSError *error = nil;
    if (![windowController openFileDirectoryAtURL:dirURL error:&error]) {
      WLOG("failed to read directory %@ -- %@", dirURL, error);
    }
  }

  // dispatch opening of files
  if (fileURLs.count != 0) {
    KDocumentController *documentController =
      (KDocumentController*)[NSDocumentController sharedDocumentController];
    [documentController openDocumentsWithContentsOfURLs:fileURLs
                                               callback:nil];
  }
}


/*- (NSApplicationTerminateReply)applicationShouldTerminate:
    (NSApplication*)sender {
  DLOG_TRACE();
  return NSTerminateNow;
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
  
  //DLOG("urls => %@", urls);
  if (urls.count == 0) return;
  
  // separate files from remote's since we apply special handling of files
  // in application:openFiles: to deal with directories.
  NSMutableArray *filenames = [NSMutableArray array];
  NSMutableArray *urls2 = [NSMutableArray array];
  for (NSURL *url in urls) {
    if ([url isFileURL]) {
      [filenames addObject:[url path]];
    } else {
      [urls2 addObject:url];
    }
  }
  
  if (filenames.count != 0)
    [self application:NSApp openFiles:filenames];
  
  if (urls2.count != 0) {
    KDocumentController *documentController =
      (KDocumentController*)[NSDocumentController sharedDocumentController];
    [documentController openDocumentsWithContentsOfURLs:urls2
                                               callback:nil];
  }
  
  //[pboard clearContents];
}


@end

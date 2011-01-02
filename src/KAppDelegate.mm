#import "common.h"
#import "KAppDelegate.h"
#import "KBrowser.h"
#import "KBrowserWindowController.h"
#import "KTerminalUsageWindowController.h"
#import "KDocument.h"
#import "KDocumentController.h"
#import "KCrashReportCollector.h"
#import "kconf.h"
#import "KStyle.h"
#import "KMachService.h"
#import "KSudo.h"
#import "KNodeThread.h"

#import <Sparkle/SUUpdater.h>

#if K_WITH_F_SCRIPT
#import <FScript/FScript.h>
#endif


@implementation KAppDelegate


- (void)awakeFromNib {
  // Sparkle configuration
  [sparkleUpdater_ setAutomaticallyChecksForUpdates:YES];
  [sparkleUpdater_ setAutomaticallyDownloadsUpdates:YES];
  [sparkleUpdater_ setUpdateCheckInterval:3600.0];
  [sparkleUpdater_ setFeedURL:[NSURL URLWithString:
      @"http://kodapp.com/appcast.xml"]];
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


- (IBAction)displayAbout:(id)sender {
  NSURL *url = [NSURL URLWithString:@"kod:about"];
  [[KDocumentController kodController] openDocumentsWithContentsOfURL:url
                                                             callback:nil];
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
  NSURL *url = kconf_url(@"style/current/url", builtinURL);
  if (url) {
    [[KStyle sharedStyle] loadFromURL:url withCallback:^(NSError *error) {
      if (error) [NSApp presentError:error];
    }];
  }

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
  KNodeThread *nodeThread = [[KNodeThread alloc] init];
  [nodeThread start];

  // Start Mach service
  [KMachService sharedService];
}


- (void)openUrl:(NSAppleEventDescriptor*)event
 withReplyEvent:(NSAppleEventDescriptor*)replyEvent {
  NSString *urlstr = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
  NSURL* url = [NSURL URLWithString:urlstr];
  if (url) {
    [[KDocumentController kodController] openDocumentsWithContentsOfURL:url
                                                               callback:nil];
  }
}


- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  // NOTE: KDocumentController will create a new window & tab upon start

  // Stuff we do upon first launch (keep this to a minimum)
  BOOL launchedBefore = kconf_bool(@"firstLaunchMarker", NO);
  if (!launchedBefore) {
    kconf_set_bool(@"firstLaunchMarker", YES);
    // Offer to enable the kod helper
    [self displayTerminalUsage:self];
  }

  // Did we just launch a new version? (happens after upgrade)
  NSString *lastLaunchedVersion = kconf_string(@"lastLaunchedVersion", nil);
  NSString *currentVersion =
      [[kconf_bundle() infoDictionary] objectForKey:@"CFBundleVersion"];
  if (!lastLaunchedVersion ||
      ![currentVersion isEqualToString:lastLaunchedVersion]) {
    // write current version
    kconf_set_object(@"lastLaunchedVersion", currentVersion);
    if (![currentVersion isEqualToString:lastLaunchedVersion] ||
        // happens when upgrading from 0.0.1:
        (launchedBefore && !lastLaunchedVersion)) {
      // we did upgrade -- display the changelog
      NSURL *changelogURL = [NSURL URLWithString:@"kod:changelog"];
      [[KDocumentController kodController]
       openDocumentsWithContentsOfURL:changelogURL callback:nil];
    }
  }

  #if K_WITH_CRASH_REPORT_COLLECTOR
  // Find & process any crash reports and offer the user to submit any newfound
  // reports. Note: This will block (switch runloop mode into modal) if there
  // was a new crash reports since a modal dialog is used to ask the user to
  // send the report. However, submission is done in the backround which means
  // this method returns before any report has been submitted.
  [[KCrashReportCollector crashReportCollector]
      askUserToSubmitAnyUnprocessedCrashReport];
  #endif
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
  // TODO: terminate node thread
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
    [[KDocumentController kodController]
     openDocumentsWithContentsOfURLs:fileURLs callback:nil];
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

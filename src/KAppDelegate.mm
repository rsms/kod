// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

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
#import "KWindowBackgroundCoverView.h"

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

  // Background cover configuration
  BOOL isCoverWindowActive = kconf_bool(@"window/backgroundCover/enabled", NO);
  if (isCoverWindowActive) {
    [coverBackgroundMenuItem_ setState:NSOnState];
    [self _createBackgroundCoverWindow];
    [backgroundCoverWindow_ orderFront:nil];
  } else {
    [coverBackgroundMenuItem_ setState:NSOffState];
  }

  // activate 80 chars limit configuration
  BOOL usingColumnGuide = kconf_double(@"window/columnGuide/enabled", NO);
  [show80charsMenuItem_ setState:usingColumnGuide ? NSOnState : NSOffState];
}


#pragma mark -
#pragma mark Internal


- (void)_checkIntegrityOfCLIHelperForSymlink:(NSString*)symlinkPath {
  DLOG("verifying integrity of CLI symlink");

  NSFileManager *fm = [NSFileManager defaultManager];

  // resolve the symlink target
  NSString *actualPath = [fm destinationOfSymbolicLinkAtPath:symlinkPath
                                                       error:nil];
  NSString *askToFixWithMessage = nil;
  // TODO(rsms): Move these text snippets into a string table and use
  // descriptive but short keys instead.
  if (!actualPath) {
    // case: symlinkPath is not a symlink or missing
    askToFixWithMessage = NSLocalizedString(
        @"The \"kod\" terminal helper seems to be missing."
        " Would you like to create or repair the symlink?", nil);
  } else {
    // case: symlinkPath is a symlink...
    // confirm that the target points to our cli program
    NSString *expectedPath = [kconf_support_url(@"kod") path];
    if (![actualPath isEqualToString:expectedPath]) {
      // case: the symlink points to something else
      askToFixWithMessage = [NSString stringWithFormat:NSLocalizedString(
          @"It seems as if you moved Kod and thus broken the terminal"
          " helper program. Would you like to repair the symlink at"
          " \"%@\"?", nil), symlinkPath];
    }
  }

  // ask to fix the symlink?
  if (askToFixWithMessage) {
    K_DISPATCH_MAIN_ASYNC({
      NSString *title = NSLocalizedString(@"Terminal helper missing", nil);
      NSString *repairLabel = NSLocalizedString(@"Repair...", nil);
      NSString *cancelLabel = NSLocalizedString(@"Do nothing", nil);
      NSAlert *alert = [NSAlert alertWithMessageText:title
                                       defaultButton:repairLabel
                                     alternateButton:cancelLabel
                                         otherButton:nil
                           informativeTextWithFormat:askToFixWithMessage];
      [alert setAlertStyle:NSWarningAlertStyle];
      if ([alert runModal] == NSAlertDefaultReturn) {
        [self displayTerminalUsage:self];
      } else {
        // clear the conf key so that Kod will not ask the same question
        // over and over (each time it's launched)
        kconf_remove(@"cli/symlink/url");
      }
    });
  }
}


- (void)_createBackgroundCoverWindow {
  if (backgroundCoverWindow_)
    return;
  NSRect windowRect = [[NSScreen mainScreen] frame];
  backgroundCoverWindow_ = [[NSWindow alloc] initWithContentRect:windowRect
                                                       styleMask:NSBorderlessWindowMask
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO];
  NSView *view = [[KWindowBackgroundCoverView alloc] initWithFrame:windowRect];
  [[backgroundCoverWindow_ contentView] addSubview:view];
  [backgroundCoverWindow_ setCollectionBehavior:NSWindowCollectionBehaviorIgnoresCycle];
  [backgroundCoverWindow_ setBackgroundColor:[NSColor blackColor]];
  // [backDrop setHidesOnDeactivate:YES]; // Activate?
  [backgroundCoverWindow_ setHasShadow:NO];
}


#pragma mark -
#pragma mark Actions

- (IBAction)newWindow:(id)sender {
  // Note: This method is called when there are no active windows. There might
  // still exist windows which are minimized to the Dock.
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


- (IBAction)checkIntegrityOfCLIHelper:(id)sender {
  NSString *symlinkPath = [kconf_url(@"cli/symlink/url", nil) path];
  // only verify integrity if we are expecting a CLI symlink to exists
  if (symlinkPath) {
    K_DISPATCH_BG_ASYNC({
      [self _checkIntegrityOfCLIHelperForSymlink:symlinkPath];
    });
  }
}


- (IBAction)displayAbout:(id)sender {
  NSURL *url = [NSURL URLWithString:@"kod:about"];
  [[KDocumentController kodController] openDocumentsWithContentsOfURL:url
                                                             callback:nil];
}


- (IBAction)showColumnGuide:(id)sender {
  if ([sender state] == NSOnState) {
    [sender setState:NSOffState];
    kconf_set_bool(@"window/columnGuide/enabled", NO);
  } else {
    [sender setState:NSOnState];
    kconf_set_bool(@"window/columnGuide/enabled", YES);
  }
}


- (IBAction)coverBackground:(id)sender {
  NSArray *orderedWindows = [[NSApplication sharedApplication] orderedWindows];
  NSIndexSet *indexes = [orderedWindows indexesOfObjectsPassingTest:
                         ^ BOOL (id obj, NSUInteger idx, BOOL *stop) {
                           NSWindow *win = (NSWindow*)obj;
                           return [win isVisible];
                         }];

  if (backgroundCoverWindow_) {
    if ([sender state] == NSOnState) {
      [sender setState:NSOffState];
      [backgroundCoverWindow_ orderOut:nil];
      kconf_set_bool(@"window/backgroundCover/enabled", NO);
    } else {
      [self _createBackgroundCoverWindow];
      if (indexes.count > 0) {
        NSWindow *backWin = [orderedWindows objectAtIndex:[indexes lastIndex]];
        [backgroundCoverWindow_ orderWindow:NSWindowBelow relativeTo:[backWin windowNumber]];
      } else {
        [backgroundCoverWindow_ orderFront:nil];
      }
      [sender setState:NSOnState];
      kconf_set_bool(@"window/backgroundCover/enabled", YES);
    }
  } else {
    [self _createBackgroundCoverWindow];
    if (indexes.count > 0) {
      NSWindow *backWin = [orderedWindows objectAtIndex:[indexes lastIndex]];
      [backgroundCoverWindow_ orderWindow:NSWindowBelow relativeTo:[backWin windowNumber]];
    } else {
      [backgroundCoverWindow_ orderFront:nil];
    }
    [sender setState:NSOnState];
    kconf_set_bool(@"window/backgroundCover/enabled", YES);
  }
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
  // Note: This setting is deprecated and should be removed in a future version:
  builtinURL = kconf_url(@"style/current/url", builtinURL);
  NSURL *url = kconf_url(@"style/url", builtinURL);
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
  } else {
    // Confirm integrity of the kod helper
    [self checkIntegrityOfCLIHelper:self];
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
      // we did upgrade -- display the changelog (at next tick)
      K_DISPATCH_MAIN_ASYNC({
        NSURL *changelogURL = [NSURL URLWithString:@"kod:changelog"];
        [[KDocumentController kodController]
         openDocumentsWithContentsOfURL:changelogURL callback:nil];
      });
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

- (void)applicationWillResignActive:(NSNotification *)notification {
  DLOG("Not Active Anymore");
  if(kconf_bool(@"editor/save/onlosefocus", NO)) {
    DLOG("Saving Documents");
    KDocumentController* controller = [KDocumentController kodController];
    NSArray* documents = controller.documents;
    for(KDocument* document in documents) {
      if ([document isDirty] && [document canQuietlySaveDocument]) {
        [document saveDocument:nil];
      }
    }
  }
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

    // if windowController is nil, open a new window
    if (!windowController) {
      windowController = (KBrowserWindowController *)
          [KBrowserWindowController browserWindowController];
    }

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

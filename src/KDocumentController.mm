#import "KDocumentController.h"
#import "KTabContents.h"
#import "KBrowserWindowController.h"
#import "KBrowser.h"

#import <ChromiumTabs/common.h>
#import <objc/objc-runtime.h>


// used for the asynchronous but sequential closing of documents cycle.
@interface KCloseCycleContext : NSObject {
 @public
  id delegate;               // cycle invoker's finalize target
  SEL didCloseAllSelector;   // cycle invoker's finalize selector
  void *contextInfo;         // cycle invoker's context, passed to finalizer
  NSUInteger stillOpenCount; // initially documents.count & decr for each close.
  NSMutableArray* documents; // documents to close
  BOOL waitingForSheet;
}
@end
@implementation KCloseCycleContext
- (void)dealloc {
  [delegate release];
  [documents release];
  [super dealloc];
}
@end



@implementation KDocumentController



- (NSSet*)windows {
  NSArray* documents = [self documents];
  NSMutableSet* windows = [NSMutableSet set];
  for (KTabContents* tab in documents) {
    if (tab && tab.browser && tab.browser.windowController) // FIXME! Should'nt happen
      [windows addObject:[tab.browser.windowController window]];
  }
  return windows;
}


- (id)makeUntitledDocumentOfType:(NSString *)typeName error:(NSError **)error {
  KTabContents* tab = [[KTabContents alloc] initWithBaseTabContents:nil];
  //tab.isUntitled = YES;
  return tab;
}

- (id)openUntitledDocumentWithWindowController:(NSWindowController*)windowController
                                       display:(BOOL)display
                                         error:(NSError **)error {
  KTabContents* tab = [self makeUntitledDocumentOfType:[self defaultType]
                                                 error:error];
  if (tab) {
    assert([NSThread isMainThread]);
    if (!windowController) {
      windowController = [KBrowserWindowController mainBrowserWindowController];
    }
    [self finalizeOpenDocument:tab
          withWindowController:(KBrowserWindowController*)windowController
                       display:display];
  }
  return tab;
}

- (id)openUntitledDocumentAndDisplay:(BOOL)display error:(NSError **)error {
  return [self openUntitledDocumentWithWindowController:nil
                                                display:display
                                                  error:error];
}


- (void)addTabContents:(KTabContents*)tab
  withWindowController:(KBrowserWindowController*)windowController {
  // NOTE: if we want to add a tab in the background, we should not use this
  // helper function (addTabContents:inBrowser:)

  // If there is one single, unmodified and empty document (i.e. a new window
  // with a default empty document): remove the document first. This is a common
  // use-case where you open a new window which comes with a new empty document,
  // and then Open... one or more files.
  KBrowser* browser = (KBrowser*)windowController.browser;
  if ([browser tabCount] == 1) {
    KTabContents* tab0 = (KTabContents*)[browser tabContentsAtIndex:0];
    assert(tab0);
    BOOL existingTabIsVirgin = ![tab0 isDocumentEdited] && ![tab0 fileURL];
    BOOL newTabIsVirgin = ![tab isDocumentEdited] && ![tab fileURL];
    if (existingTabIsVirgin && !newTabIsVirgin) {
      [browser replaceTabContentsAtIndex:0 withTabContents:tab];
      return;
    }
  }
  // Append a new tab after the currently selected tab
  [browser addTabContents:tab];
}


- (void)finalizeOpenDocument:(KTabContents*)tab
        withWindowController:(KBrowserWindowController*)windowController
                     display:(BOOL)display {
  assert([NSThread isMainThread]);
  if (!windowController) {
    // Try to get main controller again, as it might have occured since we first
    // got dispatched.
    windowController = (KBrowserWindowController*)
        [KBrowserWindowController mainBrowserWindowController];
    if (!windowController) {
      // defering creation of a new browser (in the case it does not exist when
      // starting a read) makes the calls sequential, thus avoid race-conditions
      // which could create multiple new browser instances.
      windowController = (KBrowserWindowController*)
          [[KBrowserWindowController browserWindowController] retain];
    }
  }

  [self addTabContents:tab withWindowController:windowController];

  if (display && ![[windowController window] isVisible]) {
    [windowController showWindow:self];
  }

  // Make sure the new tab gets focus
  if (display && tab.isVisible)
    [[tab.view window] makeFirstResponder:tab.view];
}


- (void)finalizeOpenDocument:(NSArray*)args {
  // proxy to finalizeOpenDocument: for background threads
  assert([NSThread isMainThread]);
  [self finalizeOpenDocument:[args objectAtIndex:0]
        withWindowController:[args count] > 2 ? [args objectAtIndex:2] : nil
                     display:[(NSNumber*)[args objectAtIndex:1] boolValue]];
}


- (id)openDocumentWithContentsOfURL:(NSURL *)absoluteURL
                            display:(BOOL)display
                              error:(NSError **)error {
  KBrowserWindowController *windowController = (KBrowserWindowController *)
      [KBrowserWindowController mainBrowserWindowController];
  return [self openDocumentWithContentsOfURL:absoluteURL
                        withWindowController:windowController
                                     display:display
                                       error:error];
}


- (id)makeDocumentWithContentsOfURL:(NSURL *)url
                             ofType:(NSString *)typeName
                              error:(NSError **)error {
  // This may be called by a background thread
  KTabContents* tab = [[KTabContents alloc] initWithContentsOfURL:url
                                                           ofType:typeName
                                                            error:error];
  if (tab && !(*error)) {
    // set tab title, url, icon (implied by setting url), etc.
    [tab setFileURL:url];
  } else {
    [tab release];
    tab = nil;
  }
  return tab;
}


- (id)openDocumentWithContentsOfURL:(NSURL *)url
               withWindowController:(KBrowserWindowController*)windowController
                            display:(BOOL)display
                              error:(NSError **)error {
  KTabContents* tab = [self makeDocumentWithContentsOfURL:url
                                                   ofType:@"txt"
                                                    error:error];
  if (tab) {
    // add the tab to |browser|
    if (![NSThread isMainThread]) {
      // if we worked in a background thread
      NSArray* args = [NSArray arrayWithObjects:
          tab, [NSNumber numberWithBool:display], windowController, nil];
      [self performSelectorOnMainThread:@selector(finalizeOpenDocument:)
                             withObject:args
                          waitUntilDone:YES];
      // NODE: if we don't wait for the above to complete, we'll need to
      // manage the references of |args|. Now we just let it autorelease.
    } else {
      [self finalizeOpenDocument:tab
            withWindowController:windowController
                         display:display];
    }
  }
  return tab;
}


/*- (void)addDocument:(NSDocument *)document {
  [super addDocument:document];
  DLOG("addDocument:%@", document);
}


- (void)removeDocument:(NSDocument *)document {
  [super removeDocument:document];
  DLOG("removeDocument:%@", document);
}*/


- (NSString *)defaultType {
  return @"txt";
}

/*- (NSArray*)documentClassNames {
  DLOG_TRACE();
  return [NSArray arrayWithObject:@"KTabContents"];
}

- (Class)documentClassForType:(NSString *)documentTypeName {
  DLOG_TRACE();
  return [KTabContents class];
}

- (NSString *)displayNameForType:(NSString *)documentTypeName {
  DLOG_TRACE();
  return documentTypeName;
}

- (NSString *)typeForContentsOfURL:(NSURL *)url error:(NSError **)error {
  DLOG_TRACE();
  return [self defaultType];
}*/


#pragma mark -
#pragma mark Document close cycle


// Private method for initiating closing of the next document, or finalizing a
// close cycle if no more documents are left in the close cycle.
- (void)closeNextDocumentInCloseCycle {
  assert(closeCycleContext_ != nil);
  NSUInteger count = [closeCycleContext_->documents count];
  if (count > 0) {
    // Query next tab in the list
    KTabContents* tab = [closeCycleContext_->documents objectAtIndex:count-1];
    [closeCycleContext_->documents removeObjectAtIndex:count-1];
    
    // Select the tab
    if (tab.browser) {
      [tab.browser selectTabAtIndex:[tab.browser indexOfTabContents:tab]];
    }
    
    //NSWindow* window = [tab.browser.windowController window];
    //[window makeKeyAndOrderFront:self];
    [tab canCloseDocumentWithDelegate:self
                  shouldCloseSelector:@selector(document:shouldClose:contextInfo:)
                          contextInfo:nil];
  } else {
    DLOG("close cycle finalizing");
    // Stop observing sheet notifications for windows which are still alive
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    for (NSWindow* window in [self windows]) {
      [nc removeObserver:self
                    name:NSWindowWillBeginSheetNotification
                  object:window];
      [nc removeObserver:self
                    name:NSWindowDidEndSheetNotification
                  object:window];
    }
    // Invoke |closeCycleContext_->didCloseAllSelector| on
    // |closeCycleContext_->delegate| which has the following signature:
    //documentController:(NSDocumentController *)docController
    //       didCloseAll:(BOOL)didCloseAll
    //      contextInfo:(void *)contextInfo
    id r = objc_msgSend(closeCycleContext_->delegate,
                        closeCycleContext_->didCloseAllSelector,
                        self,
                        closeCycleContext_->stillOpenCount > 0 ? NO : YES,
                        closeCycleContext_->contextInfo);
    // Free our cycle context
    [closeCycleContext_ release];
    closeCycleContext_ = nil;
  }
}


#if _DEBUG
static int _closeCycleSheetDebugRefCount = 0;
#endif

- (void)windowInCloseCycleWillBeginSheet:(NSNotification*)notification {
  if (!closeCycleContext_) return;
  #if _DEBUG
  // refcount open sheets in debug builds -- this is a common death trap!
  if (_closeCycleSheetDebugRefCount > 0) {
    WLOG("WARNING! Sheet already active (sheets: %d)",
         _closeCycleSheetDebugRefCount);
  }
  _closeCycleSheetDebugRefCount++;
  #endif // _DEBUG
  assert(closeCycleContext_->waitingForSheet == NO);
  closeCycleContext_->waitingForSheet = YES;
}

- (void)windowInCloseCycleDidEndSheet:(NSNotification*)notification {
  if (!closeCycleContext_) return;
  #if _DEBUG
  _closeCycleSheetDebugRefCount--;
  #endif // _DEBUG
  assert(closeCycleContext_->waitingForSheet == YES);
  closeCycleContext_->waitingForSheet = NO;
  if (closeCycleContext_) {
    // closeCycleContext_ is null here when we just finalized the cycle
    // schedule next call in the runloop to avoid blowing the stack
    [self performSelectorOnMainThread:@selector(closeNextDocumentInCloseCycle)
                           withObject:nil
                        waitUntilDone:YES];
  }
}

- (void)closeAllDocumentsWithDelegate:(id)delegate
                  didCloseAllSelector:(SEL)didCloseAllSelector
                          contextInfo:(void*)contextInfo {
  // Observe sheet notifications for relevant windows
  NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
  for (NSWindow* window in [self windows]) {
    [nc addObserver:self
           selector:@selector(windowInCloseCycleWillBeginSheet:)
               name:NSWindowWillBeginSheetNotification
             object:window];
    [nc addObserver:self
           selector:@selector(windowInCloseCycleDidEndSheet:)
               name:NSWindowDidEndSheetNotification
             object:window];
  }

  // Create a cycle context with the initial delegate, selector and context. We
  // pass around this until we have processed all documents, which happen
  // asynchronously.
  assert(closeCycleContext_ == nil);
  closeCycleContext_ = [[KCloseCycleContext alloc] init];
  closeCycleContext_->delegate = [delegate retain];
  closeCycleContext_->didCloseAllSelector = didCloseAllSelector;
  closeCycleContext_->contextInfo = contextInfo;
  closeCycleContext_->documents =
      [[NSMutableArray alloc] initWithArray:[self documents]];
  closeCycleContext_->stillOpenCount = [closeCycleContext_->documents count];
  [self closeNextDocumentInCloseCycle];
}


- (void)document:(NSDocument *)tab
     shouldClose:(BOOL)shouldClose
     contextInfo:(void*)contextInfo {
  BOOL wasCleanClose = NO;
  if (shouldClose) {
    if (closeCycleContext_) {
      assert(closeCycleContext_->stillOpenCount > 0);
      closeCycleContext_->stillOpenCount--;
      // We need to make this calculation here, since after calling [tab close]
      // closeCycleContext_ might be invalid.
      wasCleanClose = !closeCycleContext_->waitingForSheet;
    }
    // NOTE: we need to call close _after_ we have accessed closeCycleContext_
    // since it might lead to closeCycleContext_ being dealloced and assigned
    // nil.
    [tab close];
  }
  if (wasCleanClose) {
    // This happens when the closed document was 
    // schedule next call in the runloop to avoid blowing the stack
    [self performSelectorOnMainThread:@selector(closeNextDocumentInCloseCycle)
                           withObject:nil
                        waitUntilDone:YES];
  }
  // else, we wait for the sheet to complete and then continue in
  // windowInCloseCycleDidEndSheet
}


@end

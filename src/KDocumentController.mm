#import "KDocumentController.h"
#import "KTabContents.h"
#import "KBrowserWindowController.h"
#import "KBrowser.h"

#import <ChromiumTabs/common.h>
#import <objc/objc-runtime.h>

@implementation KDocumentController

- (id)makeUntitledDocumentOfType:(NSString *)typeName error:(NSError **)error {
  DLOG_TRACE();
  KTabContents* tab = [[KTabContents alloc] initWithBaseTabContents:nil];
  //tab.isUntitled = YES;
  return tab;
}

- (id)openUntitledDocumentAndDisplay:(BOOL)display error:(NSError **)error {
  DLOG_TRACE();
  KTabContents* tab = [self makeUntitledDocumentOfType:[self defaultType]
                                                 error:error];
  if (tab) {
    assert([NSThread isMainThread]);
    [self finalizeOpenDocument:tab
                     inBrowser:(KBrowser*)[KBrowser mainBrowser]
                       display:display];
  }
  return tab;
}


- (void)addTabContents:(KTabContents*)tab inBrowser:(KBrowser*)browser {
  // NOTE: if we want to add a tab in the background, we should not use this
  // helper function (addTabContents:inBrowser:)

  // If there is one single, unmodified and empty document (i.e. a new window
  // with a default empty document): remove the document first. This is a common
  // use-case where you open a new window which comes with a new empty document,
  // and then Open... one or more files.
  if ([browser tabCount] == 1) {
    KTabContents* tab0 = (KTabContents*)[browser tabContentsAtIndex:0];
    assert(tab0);
    if (![tab0 isDocumentEdited] && ![tab0 fileURL]) {
      [browser replaceTabContentsAtIndex:0 withTabContents:tab];
      return;
    }
  }
  // Append a new tab after the currently selected tab
  [browser addTabContents:tab];
}


- (void)finalizeOpenDocument:(KTabContents*)tab
                   inBrowser:(KBrowser*)browser
                     display:(BOOL)display {
  assert([NSThread isMainThread]);
  if (!browser) {
    // Try to get mainBrowser again, as it might have occured since we first got 
    // dispatched.
    if (!(browser = (KBrowser*)[KBrowser mainBrowser])) {
      // defering creation of a new browser (in the case it does not exist when
      // starting a read) makes the calls sequential, thus avoid race-conditions
      // which could create multiple new browser instances.
      browser = [[[KBrowser alloc] init] autorelease];
    }
  }
  if (!browser.windowController) {
    [browser createWindowControllerInstance];
  }

  [self addTabContents:tab inBrowser:browser];

  if (display && ![[browser.windowController window] isVisible])
    [browser.windowController showWindow:self];

  // Make sure the new tab gets focus
  if (display && tab.isVisible)
    [[tab.view window] makeFirstResponder:tab.view];
}


- (void)finalizeOpenDocument:(NSArray*)args {
  // proxy to finalizeOpenDocument: for background threads
  assert([NSThread isMainThread]);
  [self finalizeOpenDocument:[args objectAtIndex:0]
                   inBrowser:[args count] > 2 ? [args objectAtIndex:2] : nil
                     display:[(NSNumber*)[args objectAtIndex:1] boolValue]];
}


- (id)openDocumentWithContentsOfURL:(NSURL *)absoluteURL
                            display:(BOOL)display
                              error:(NSError **)error {
  DLOG_TRACE();
  return [self openDocumentWithContentsOfURL:absoluteURL
                                   inBrowser:(KBrowser*)[KBrowser mainBrowser]
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
    tab.title = [url lastPathComponent];
    [tab setFileURL:url];
  } else {
    [tab release];
    tab = nil;
  }
  return tab;
}


- (id)openDocumentWithContentsOfURL:(NSURL *)url
                          inBrowser:(KBrowser*)browser
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
          tab, [NSNumber numberWithBool:display], browser, nil];
      [self performSelectorOnMainThread:@selector(finalizeOpenDocument:)
                             withObject:args
                          waitUntilDone:YES];
      // NODE: if we don't wait for the above to complete, we'll need to
      // manage the references of |args|. Now we just let it autorelease.
    } else {
      [self finalizeOpenDocument:tab inBrowser:browser display:display];
    }
  }
  return tab;
}


- (void)addDocument:(NSDocument *)document {
  [super addDocument:document];
  DLOG("addDocument:%@", document);
}


- (void)removeDocument:(NSDocument *)document {
  [super removeDocument:document];
  DLOG("removeDocument:%@", document);
}


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


// Private struct used for the asynchronous but sequential closing of documents
// cycle.
typedef struct {
  id delegate;               // cycle invoker's finalize target
  SEL didCloseAllSelector;   // cycle invoker's finalize selector
  void *contextInfo;         // cycle invoker's context, passed to finalizer
  NSUInteger stillOpenCount; // initially documents.count & decr for each close.
  NSMutableArray* documents; // documents to close
  BOOL waitingForSheet;
} KCloseCycleContext;


// Private method for initiating closing of the next document, or finalizing a
// close cycle if no more documents are left in the close cycle.
- (void)closeNextDocumentWithCycleContext:(KCloseCycleContext*)cContext {
  NSUInteger count = [cContext->documents count];
  if (count > 0) {
    // Query next tab in the list
    KTabContents* tab = [cContext->documents objectAtIndex:count-1];
    [cContext->documents removeObjectAtIndex:count-1];
    // make sure we receive notifications
    NSWindow* window = [tab.browser.windowController window];
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self
                  name:NSWindowWillBeginSheetNotification
                object:window];
    [nc addObserver:self
           selector:@selector(windowInCloseCycleWillBeginSheet:)
               name:NSWindowWillBeginSheetNotification
             object:window];
    [nc removeObserver:self
                  name:NSWindowDidEndSheetNotification
                object:window];
    [nc addObserver:self
           selector:@selector(windowInCloseCycleDidEndSheet:)
               name:NSWindowDidEndSheetNotification
             object:window];
    [window makeKeyAndOrderFront:self];
    [tab canCloseDocumentWithDelegate:self
                  shouldCloseSelector:@selector(document:shouldClose:contextInfo:)
                          contextInfo:(void*)cContext];
  } else {
    // Invoke |cContext->didCloseAllSelector| on |cContext->delegate| which has
    // the following signature:
    //documentController:(NSDocumentController *)docController
    //       didCloseAll:(BOOL)didCloseAll
    //      contextInfo:(void *)contextInfo
    id r = objc_msgSend(cContext->delegate,
                        cContext->didCloseAllSelector,
                        self,
                        cContext->stillOpenCount ? NO : YES,
                        cContext->contextInfo);
    // Free our cycle context
    assert(closeCycleContext_ == cContext);
    closeCycleContext_ = NULL;
    [cContext->delegate release];
    [cContext->documents release];
    NSZoneFree(NSDefaultMallocZone(), cContext);
  }
}

static int _closeCycleSheetDebugRefCount = 0;
- (void)windowInCloseCycleWillBeginSheet:(NSNotification*)notification {
  DLOG_TRACE();
  #if _DEBUG
  // refcount open sheets in debug builds -- this is a common death trap!
  if (_closeCycleSheetDebugRefCount > 0) {
    WLOG("WARNING! Sheet already active (sheets: %d)",
         _closeCycleSheetDebugRefCount);
  }
  _closeCycleSheetDebugRefCount++;
  #endif // _DEBUG
  assert(((KCloseCycleContext*)closeCycleContext_)->waitingForSheet == NO);
  ((KCloseCycleContext*)closeCycleContext_)->waitingForSheet = YES;
}

- (void)windowInCloseCycleDidEndSheet:(NSNotification*)notification {
  DLOG_TRACE();
  #if _DEBUG
  _closeCycleSheetDebugRefCount--;
  #endif // _DEBUG
  assert(((KCloseCycleContext*)closeCycleContext_)->waitingForSheet == YES);
  ((KCloseCycleContext*)closeCycleContext_)->waitingForSheet = NO;
  NSWindow* window = [notification object];
  NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
  [nc removeObserver:self
                name:NSWindowWillBeginSheetNotification
              object:window];
  [nc removeObserver:self
                name:NSWindowDidEndSheetNotification
              object:window];
  [self closeNextDocumentWithCycleContext:(KCloseCycleContext*)closeCycleContext_];
}

- (void)closeAllDocumentsWithDelegate:(id)delegate
                  didCloseAllSelector:(SEL)didCloseAllSelector
                          contextInfo:(void*)contextInfo {
  // Create a cycle context with the initial delegate, selector and context. We
  // pass around this until we have processed all documents, which happen
  // asynchronously.
  KCloseCycleContext* cycleContext =
      (KCloseCycleContext*)NSZoneCalloc(NSDefaultMallocZone(), 1,
                                        sizeof(KCloseCycleContext));
  cycleContext->delegate = [[delegate retain] retain];
  cycleContext->didCloseAllSelector = didCloseAllSelector;
  cycleContext->contextInfo = contextInfo;
  cycleContext->documents =
      [[NSMutableArray alloc] initWithArray:[self documents]];
  cycleContext->stillOpenCount = [cycleContext->documents count];
  assert(closeCycleContext_ == NULL);
  closeCycleContext_ = cycleContext;
  [self closeNextDocumentWithCycleContext:cycleContext];
}


- (void)document:(NSDocument *)doc
     shouldClose:(BOOL)shouldClose
     contextInfo:(void*)contextInfo {
  DLOG_TRACE();
  DLOG_EXPR(shouldClose);
  KCloseCycleContext* cycleContext = (KCloseCycleContext*)contextInfo;
  if (shouldClose) {
    [doc close];
    assert(cycleContext->stillOpenCount > 0);
    cycleContext->stillOpenCount--;
  }
  if (!cycleContext->waitingForSheet)
    [self closeNextDocumentWithCycleContext:cycleContext];
  // instead, we wait for the sheet to complete and then continue
}


@end

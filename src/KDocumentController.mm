#import "common.h"
#import "KDocumentController.h"
#import "KDocument.h"
#import "KBrowserWindowController.h"
#import "KBrowser.h"
#import "KFileURLHandler.h"
#import "KHTTPURLHandler.h"
#import "KKodURLHandler.h"
#import "HEventEmitter.h"
#import "kconf.h"
#import "kod_node_interface.h"

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


+ (KDocumentController*)kodController {
  return (KDocumentController*)[NSDocumentController sharedDocumentController];
}


- (id)init {
  if ((self = [super init])) {
    urlHandlers_ = [NSMutableDictionary new];

    // register built-in URL handlers
    [urlHandlers_ setObject:[KFileURLHandler handler] forKey:@"file"];
    [urlHandlers_ setObject:[KHTTPURLHandler handler] forKey:@"http"];
    [urlHandlers_ setObject:[KHTTPURLHandler handler] forKey:@"https"];
    [urlHandlers_ setObject:[KKodURLHandler handler] forKey:@"kod"];
  }
  return self;
}


- (NSSet*)windows {
  NSArray* documents = [self documents];
  NSMutableSet* windows = [NSMutableSet set];
  for (KDocument* tab in documents) {
    if (tab && tab.browser && tab.browser.windowController) // FIXME! Should'nt happen
      [windows addObject:[tab.browser.windowController window]];
  }
  return windows;
}


- (KURLHandler*)urlHandlerForURL:(NSURL*)url {
  NSString *urlScheme = [url.scheme lowercaseString];
  return [urlHandlers_ objectForKey:urlScheme];
}


#pragma mark -
#pragma mark Creating and opening documents


- (KDocument*)_documentForURL:(NSURL*)absoluteURL
                  makeKeyIfFound:(BOOL)makeKeyIfFound {
  // check if |url| is already open
  KDocument *tab = (KDocument *)[self documentForURL:absoluteURL];
  if (makeKeyIfFound) {
    // make sure the tab is presented to the user (need to run on main)
    if (![NSThread isMainThread]) {
      K_DISPATCH_MAIN_ASYNC([tab makeKeyAndOrderFront:self];);
    } else {
      [tab makeKeyAndOrderFront:self];
    }
  }
  return tab;
}


- (void)openDocumentsWithContentsOfURLs:(NSArray*)urls
                withWindowController:(KBrowserWindowController*)windowController
                               priority:(long)priority
         nonExistingFilesAsNewDocuments:(BOOL)newDocForNewURLs
                               callback:(void(^)(NSError*))callback {
  DLOG("openDocumentsWithContentsOfURLs:%@", urls);
  // countdown
  NSUInteger i = urls ? urls.count : 0;

  // check for empty array
  if (i == 0) {
    if (callback) {
      NSError *error = [NSError kodErrorWithFormat:@"Empty list of URLs"];
      callback(error);
    }
    return;
  }

  // dispatch queue to open the documents in
  dispatch_queue_t dispatchQueue = dispatch_get_global_queue(priority, 0);
  NSFileManager *fm = [NSFileManager defaultManager];

  // callback countdown
  kassert(i < INT32_MAX);
  __block int32_t callbackCountdown = i;
  __block void(^countdown)(NSError*) = nil;
  if (callback) {
    callback = [callback copy];
    countdown = [^(NSError *err){
      //NSLog(@"countdown %@", (id)countdown);
      if (h_atomic_dec(&callbackCountdown) == 0) {
        callback(err);
        [callback release];
        [countdown release];
      } else if (err && h_atomic_cas(&callbackCountdown, callbackCountdown, 0)){
        callback(err);
        [callback release];
        [countdown release];
      }
      // Note: the callback block will be implicitly retained or copied by
      // this block, which is released once we are done.
    } copy];
  }

  // Dispatch opening of each document
  for (NSURL *url in urls) {
    int index = --i; // so it gets properly copied into the dispatched block
    BOOL directory = NO;

    KDocument *alreadyOpenTab = [self _documentForURL:url
                                       makeKeyIfFound:index==0];
    if (alreadyOpenTab) {
      if (countdown) countdown(nil);
    } else if ([url isFileURL] &&
               [fm fileExistsAtPath:[url path] isDirectory:&directory] &&
               directory) {
      // Special case: open a directory
      NSError *error = nil;
      BOOL ok = [windowController openFileDirectoryAtURL:url error:&error];
      if (countdown) countdown(error);
      if (!ok) [windowController presentError:error];
    } else if (newDocForNewURLs && [url isFileURL] &&
               ![fm fileExistsAtPath:[url path]]) {
      // Special case: open a new (non-existing) document
      NSError *error = nil;

      // create new document
      KDocument *doc = [self openNewDocumentWithBlock:
        ^(KDocument *doc, KDocumentOpenClosure closure) {
          // set URL
          doc.url = url;
          // continue opening the document
          closure(nil, doc);
        } withWindowController:windowController display:index==0 error:&error];

      if (doc) doc.url = url;
      if (countdown) countdown(error);
      if (!doc) [windowController presentError:error];
    } else {
      dispatch_async(dispatchQueue, ^{
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
        NSError *error = nil;
        KDocument *doc = [self openDocumentWithContentsOfURL:url
                                           withWindowController:windowController
                                              groupWithSiblings:YES
                                                // display last document opened:
                                                        display:index==0
                                                          error:&error];
        if (doc && doc.isLoading) {
          if (countdown) {
            [doc on:@"load" call:^(KDocument *doc2){
              countdown(error);
              return YES; // remove ourselves from listeners
            }];
          }
        } else if (countdown) {
          countdown(error);
        }
        if (!doc) [windowController presentError:error];
        [pool drain];
      });
    }
  }
}


- (void)openDocumentsWithContentsOfURLs:(NSArray*)urls
         nonExistingFilesAsNewDocuments:(BOOL)newDocForNewURLs
                               callback:(void(^)(NSError*))callback {
  // open the documents in the frontmost window controller
  KBrowserWindowController *windowController = (KBrowserWindowController *)
    [KBrowserWindowController mainBrowserWindowController];
  [self openDocumentsWithContentsOfURLs:urls
                   withWindowController:windowController
                               priority:DISPATCH_QUEUE_PRIORITY_HIGH
         nonExistingFilesAsNewDocuments:(BOOL)newDocForNewURLs
                               callback:callback];
}


- (void)openDocumentsWithContentsOfURLs:(NSArray*)urls
                               callback:(void(^)(NSError*))callback {
  [self openDocumentsWithContentsOfURLs:urls
         nonExistingFilesAsNewDocuments:NO
                               callback:callback];
}


- (void)openDocumentsWithContentsOfURL:(NSURL*)url
                              callback:(void(^)(NSError*))callback {
  [self openDocumentsWithContentsOfURLs:[NSArray arrayWithObject:url]
                               callback:callback];
}


- (IBAction)openDocument:(id)sender {
  // Run open panel in modal state and continue with a list of URLs
  NSArray *urls = [self URLsFromRunningOpenPanel];

  // Open urls in frontmost window with high priority
  [self openDocumentsWithContentsOfURLs:urls callback:nil];
}


- (id)makeUntitledDocumentOfType:(NSString *)typeName error:(NSError **)error {
  KDocument *doc = [[KDocument alloc] initWithBaseTabContents:nil];
  assert(doc); // since we don't set error

  // IMPORTANT(rsms): This is a fix which is not completely investigated or
  // understood. Documents created through the makeUntitledDocumentOfType branch
  // of calls are retained more time than documents created from the
  // makeDocumentWithContentsOfURL branch of calls.
  // The NSDocument system is rather complex.
  [doc autorelease];

  // Give the new tab a "Untitled #" name
  doc.title = [NSString stringWithFormat:NSLocalizedString(@"Untitled %@", nil),
               [NSNumber numberWithUnsignedLongLong:doc.identifier]];

  // set type
  doc.type = typeName;

  return doc;
}


- (KDocument*)openNewDocumentWithBlock:(void(^)(KDocument*,KDocumentOpenClosure))block
                  withWindowController:(NSWindowController*)windowController
                               display:(BOOL)display
                                 error:(NSError**)error {
  BOOL groupWithSiblings = NO;

  // Create a new buffer document
  KDocument* doc = [self makeUntitledDocumentOfType:[self defaultType]
                                              error:error];

  if (doc) {
    // Unless we got an explicit window controller, get the current main one
    if (!windowController) {
      windowController = [KBrowserWindowController mainBrowserWindowController];
    } else {
      kassert(
          [windowController isKindOfClass:[KBrowserWindowController class]]);
    }

    // Use custom initializer block?
    if (block) {
      KDocumentOpenClosure closure = ^(NSError *err, KDocument *doc) {
        if (err) {
          if (doc) [doc release];
          K_DISPATCH_MAIN_ASYNC({ [windowController presentError:err]; });
        } else if (doc) {
          [self safeFinalizeOpenDocument:doc
                withWindowController:(KBrowserWindowController*)windowController
                       groupWithSiblings:groupWithSiblings
                                 display:display];
        } // else do nothing. i.e. opening was aborted
      };
      block(doc, closure);
    } else {
      // Finalize opening of the document, causing it to be inserted and presented
      [self safeFinalizeOpenDocument:doc
                withWindowController:(KBrowserWindowController*)windowController
                   groupWithSiblings:NO
                             display:display];
    }
  } else {
    assert(!error || *error);
  }
  return doc;
}


// overload of NSDocumentController impl
- (id)openUntitledDocumentWithWindowController:(NSWindowController*)windowController
                                       display:(BOOL)display
                                         error:(NSError**)error {
  return [self openNewDocumentWithBlock:nil
                   withWindowController:windowController
                                display:display
                                  error:error];
}


// overload of NSDocumentController impl
- (id)openUntitledDocumentAndDisplay:(BOOL)display error:(NSError**)error {
  // Note: When starting the application, AppKit will invoke this method in
  // order to have a new window and document be opened.

  return [self openUntitledDocumentWithWindowController:nil
                                                display:display
                                                  error:error];
}


// levenstein edit distance threshold which must be passed (go below this value)
// in order for a tab to be repositioned
static double kSiblingAutoGroupEditDistanceThreshold = 0.4;


- (void)addDocument:(KDocument*)doc
withWindowController:(KBrowserWindowController*)windowController
       inForeground:(BOOL)foreground
  groupWithSiblings:(BOOL)groupWithSiblings {
  // NOTE: if we want to add a tab in the background, we should not use this
  // helper function (addTabContents:inBrowser:)

  // If there is one single, unmodified and empty document (i.e. a new window
  // with a default empty document): remove the document first. This is a common
  // use-case where you open a new window which comes with a new empty document,
  // and then Open... one or more files.
  KBrowser* browser = (KBrowser*)windowController.browser;
  if ([browser tabCount] == 1) {
    KDocument *firstDocument = (KDocument*)[browser tabContentsAtIndex:0];
    kassert(firstDocument != nil);
    if (firstDocument.isVirgin && !doc.isVirgin) {
      [browser replaceTabContentsAtIndex:0 withTabContents:doc];
      return;
    }
  }

  // Move to a position beside the most natural sibling
  kassert([NSThread isMainThread]);

  // index to insert the new tab. -1 means "after the current tab"
  int insertIndex = -1;

  if (groupWithSiblings && kconf_bool(@"groupNewDocuments/enabled", YES)) {
    BOOL useEditDistance = kconf_bool(@"groupNewDocuments/byEditDistance", YES);
    KDocument *otherTab;
    double bestSiblingDistance = 1.0;
    int i = 0, tabCount = [browser tabCount];
    NSString *tabExt = [doc.title pathExtension];

    for (; i<tabCount; ++i) {
      otherTab = (KDocument*)[browser tabContentsAtIndex:i];
      if (otherTab) {
        NSString *tabName = [doc.title stringByDeletingPathExtension];
        NSString *otherName = [otherTab.title stringByDeletingPathExtension];
        // test simple case-insensitive compare as this is a common use-case
        // (this is an optimization for i.e. "foo.c", "Foo.h")
        if ([tabName caseInsensitiveCompare:otherName] == NSOrderedSame) {
          // same basename means zero editing distance
          // did we already find a perfect match? Compare file extensions.
          if (bestSiblingDistance == 0.0) {
            kassert(insertIndex != -1);
            otherTab = (KDocument*)[browser tabContentsAtIndex:insertIndex];
            NSString *otherExt = [otherTab.title pathExtension];
            if ([tabExt caseInsensitiveCompare:otherExt] == NSOrderedDescending) {
              // tabExt = z, otherExt = a -- use this doc instead of previously
              // found doc
              insertIndex = i;
            }
          } else {
            bestSiblingDistance = 0.0;
            insertIndex = i;
          }
        } else if (bestSiblingDistance != 0.0 && useEditDistance) {
          // test levenstein distance
          double editDistance = [doc.title editDistanceToString:otherTab.title];
          //DLOG("editDistance('%@' > '%@') -> %f", doc.title, otherTab.title,
          //     editDistance);
          if (editDistance <= kSiblingAutoGroupEditDistanceThreshold &&
              editDistance < bestSiblingDistance) {
            bestSiblingDistance = editDistance;
            insertIndex = i;
          }
        }
      }
    }

    if (insertIndex != -1) {
      otherTab = (KDocument*)[browser tabContentsAtIndex:insertIndex];
      NSString *otherExt = [otherTab.title pathExtension];
      if ([tabExt caseInsensitiveCompare:otherExt] == NSOrderedDescending) {
        // insert after
        insertIndex++;
      }
      //DLOG("insert '%@' at %d (sibling: '%@')", doc.title, insertIndex,
      //     otherTab);
    }

  }

  // Append a new tab after the currently selected tab
  [browser addTabContents:doc atIndex:insertIndex inForeground:foreground];
}


- (void)finalizeOpenDocument:(KDocument*)doc
        withWindowController:(KBrowserWindowController*)windowController
           groupWithSiblings:(BOOL)groupWithSiblings
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

  KNodeEmitEvent("openDocument", doc, nil);

  [self addDocument:doc withWindowController:windowController
       inForeground:display
  groupWithSiblings:groupWithSiblings];

  if (display && !windowController.window.isVisible) {
    [windowController showWindow:self];
  }

  // Make sure the new document gets focus
  if (display && doc.isVisible)
    [doc becomeFirstResponder];
}


- (void)safeFinalizeOpenDocument:(KDocument*)doc
            withWindowController:(KBrowserWindowController*)windowController
               groupWithSiblings:(BOOL)groupWithSiblings
                         display:(BOOL)display {
  if (![NSThread isMainThread]) {
    K_DISPATCH_MAIN_ASYNC(
      [self finalizeOpenDocument:doc
            withWindowController:windowController
               groupWithSiblings:groupWithSiblings
                         display:display];
    );
  } else {
    [self finalizeOpenDocument:doc
          withWindowController:windowController
             groupWithSiblings:groupWithSiblings
                       display:display];
  }
}


- (id)openDocumentWithContentsOfURL:(NSURL *)absoluteURL
                            display:(BOOL)display
                              error:(NSError **)error {
  KBrowserWindowController *windowController = (KBrowserWindowController *)
      [KBrowserWindowController mainBrowserWindowController];
  return [self openDocumentWithContentsOfURL:absoluteURL
                        withWindowController:windowController
                           groupWithSiblings:YES
                                     display:display
                                       error:error];
}


- (id)makeDocumentWithContentsOfURL:(NSURL *)url
                             ofType:(NSString *)typeName
                              error:(NSError **)error {
  // Note: This may be called by a background thread

  // Dive down into the opening mechanism...
  KDocument* tab = [[KDocument alloc] initWithContentsOfURL:url
                                                     ofType:typeName
                                                      error:error];
  if (!tab && error) {
    // if tab failed to create and we received a pointer to store the error,
    // make sure an error is present
    assert(*error);
  }
  return tab;
}


- (KDocument*)openNewDocumentWithData:(NSData*)data
                               ofType:(NSString *)typeName
                 withWindowController:(KBrowserWindowController*)windowController
                    groupWithSiblings:(BOOL)groupWithSiblings
                              display:(BOOL)display
                                error:(NSError**)outError {
  if (!typeName)
    typeName = [self defaultType];
  KDocument *doc = [self makeUntitledDocumentOfType:typeName error:outError];
  if (doc) {
    if (![doc readFromData:data ofType:typeName error:outError]) {
      doc = nil;
    } else {
      // default to current "main" window (current key window)
      if (!windowController) {
        windowController = (KBrowserWindowController*)
            [KBrowserWindowController mainBrowserWindowController];
      }
      [self safeFinalizeOpenDocument:doc
                withWindowController:windowController
                   groupWithSiblings:groupWithSiblings
                             display:display];
    }
  }
  return doc;
}


- (id)openDocumentWithContentsOfURL:(NSURL *)absoluteURL
               withWindowController:(KBrowserWindowController*)windowController
                  groupWithSiblings:(BOOL)groupWithSiblings
                            display:(BOOL)display
                              error:(NSError **)error {
  // check if |url| is already open. Although we check this earlier, we need
  // to check again since we are running on a background thread and things might
  // have changed.
  KDocument *tab = [self _documentForURL:absoluteURL makeKeyIfFound:display];
  if (tab) return tab;

  // make a document from |absoluteURL|
  NSString *typeName = [self typeForContentsOfURL:absoluteURL error:nil];
  tab = [self makeDocumentWithContentsOfURL:absoluteURL
                                     ofType:typeName
                                      error:error];
  if (tab) {
    [self safeFinalizeOpenDocument:tab
              withWindowController:windowController
                 groupWithSiblings:groupWithSiblings
                           display:display];
  }
  return tab;
}


#pragma mark -
#pragma mark Document types


- (NSString*)defaultType {
  return @"public.text";  // FIXME but how? UX
}

/*- (NSArray*)documentClassNames {
  DLOG_TRACE();
  return [NSArray arrayWithObject:@"KDocument"];
}

- (Class)documentClassForType:(NSString *)documentTypeName {
  DLOG_TRACE();
  return [KDocument class];
}

- (NSString *)displayNameForType:(NSString *)documentTypeName {
  DLOG_TRACE();
  return documentTypeName;
}
*/

- (NSString *)typeForContentsOfURL:(NSURL*)url error:(NSError**)error {
  NSString *uti = nil;
  [url getResourceValue:&uti forKey:NSURLTypeIdentifierKey error:error];
  //DLOG("typeForContentsOfURL:%@ -> %@", url, uti);
  //DLOG("%@", [NSThread callStackSymbols]);
  return uti;
}


- (Class)documentClassForType:(NSString *)typeName {
  // we only have one document type at the moment
  return [KDocument class];
}


#pragma mark -
#pragma mark Tracking recent documents


// Returns the maximum number of items that may be presented in the standard
// "Open Recent" menu
- (NSUInteger)maximumRecentDocumentCount {
  NSUInteger count = kconf_uint(@"recentDocuments/count", 50);
  // Sanity check -- e.g. if someone stored "-1"
  return MIN(count, 10000);
}


// This method is called by NSDocument objects at "appropriate times"(?) for
// managing the recent-documents list.
//
// Note: The NSDocument system only supports file URLs.
// TODO(rsms): Implement a "Recent documents" system which supports any URI.
- (void)noteNewRecentDocument:(NSDocument*)doc {
  NSURL *url = ((KDocument*)doc).url;
  if (!url) {
    // ignore documents w/o a URL
    return;
  } else if ([url isFileURL]) {
    DLOG("recording recent document %@", doc);
    // let the super implementation handle this
    [super noteNewRecentDocument:doc];
  }
}


/*- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)item {
  DLOG("validateUserInterfaceItem:%@", item);
  return [super validateUserInterfaceItem:item];
}*/


//hasEditedDocuments


#pragma mark -
#pragma mark Document close cycle


// Private method for initiating closing of the next document, or finalizing a
// close cycle if no more documents are left in the close cycle.
- (void)closeNextDocumentInCloseCycle {
  assert(closeCycleContext_ != nil);
  NSUInteger count = [closeCycleContext_->documents count];
  if (count > 0) {
    // Query next tab in the list
    KDocument* tab = [closeCycleContext_->documents objectAtIndex:count-1];
    [closeCycleContext_->documents removeObjectAtIndex:count-1];

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

#import <Cocoa/Cocoa.h>

@class KDocument, KCloseCycleContext, KBrowserWindowController, KURLHandler;

// Block type used to finalize a deferred document "open" action.
//
// - To abort, pass nil for both arguments (you are responsible for releasing
//   the document in this case).
//
// - To abort with error, pass an error as the first argument and optionally
//   nil for the second argument. If you instead pass a document as the second
//   argument, the document will be released.
//
// - To proceed, pass a nil error and a valid document as the second argument.
//
typedef void (^KDocumentOpenClosure)(NSError*,KDocument*);


@interface KDocumentController : NSDocumentController {
  KCloseCycleContext *closeCycleContext_;
  NSMutableDictionary *urlHandlers_;
}

// Typed sharedDocumentController
+ (KDocumentController*)kodController;

// Returns a set (unique) of all windows used by |documents|
- (NSSet*)windows;

- (void)addDocument:(KDocument*)document
withWindowController:(KBrowserWindowController*)windowController
       inForeground:(BOOL)foreground
  groupWithSiblings:(BOOL)groupWithSiblings;

- (KURLHandler*)urlHandlerForURL:(NSURL*)url;

// --------------------------------------------------------------------
// high-level operners which will dispatch opening to the background

// Open |urls| concurrently in the background, inserting tabs by closest sibling
// edit distance (groupWithSiblings:YES). Only the last tab opened will be
// brought to foreground and become first responder.
- (void)openDocumentsWithContentsOfURLs:(NSArray*)urls
                   withWindowController:(KBrowserWindowController*)windowController
                               priority:(long)priority
         nonExistingFilesAsNewDocuments:(BOOL)newDocForNewURLs
                               callback:(void(^)(NSError*))callback;

// Open |urls| in frontmost window with high priority
- (void)openDocumentsWithContentsOfURLs:(NSArray*)urls
         nonExistingFilesAsNewDocuments:(BOOL)newDocForNewURLs
                               callback:(void(^)(NSError*))callback;

// Open |urls| in frontmost window with high priority
- (void)openDocumentsWithContentsOfURLs:(NSArray*)urls
                               callback:(void(^)(NSError*))callback;

// Open |url| in frontmost window with high priority
- (void)openDocumentsWithContentsOfURL:(NSURL*)url
                              callback:(void(^)(NSError*))callback;

// --------------------------------------------------------------------
// lower level openers which run in the current thread

- (id)openDocumentWithContentsOfURL:(NSURL *)absoluteURL
               withWindowController:(KBrowserWindowController*)windowController
                  groupWithSiblings:(BOOL)groupWithSiblings
                            display:(BOOL)displayDocument
                              error:(NSError **)outError;

- (KDocument*)openNewDocumentWithBlock:(void(^)(KDocument*,KDocumentOpenClosure))block
                  withWindowController:(NSWindowController*)windowController
                               display:(BOOL)display
                                 error:(NSError**)error;

- (KDocument*)openNewDocumentWithData:(NSData*)data
                               ofType:(NSString *)typeName
                 withWindowController:(KBrowserWindowController*)windowController
                    groupWithSiblings:(BOOL)groupWithSiblings
                              display:(BOOL)display
                                error:(NSError**)outError;

- (void)finalizeOpenDocument:(KDocument*)tab
        withWindowController:(KBrowserWindowController*)windowController
           groupWithSiblings:(BOOL)groupWithSiblings
                     display:(BOOL)display;

// A "safe" version which guarantees finalizeOpenDocument: is called on main
- (void)safeFinalizeOpenDocument:(KDocument*)doc
            withWindowController:(KBrowserWindowController*)windowController
               groupWithSiblings:(BOOL)groupWithSiblings
                         display:(BOOL)display;

@end

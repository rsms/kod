#import <Cocoa/Cocoa.h>

@class KTabContents;
@class KCloseCycleContext;
@class KBrowserWindowController;

@interface KDocumentController : NSDocumentController {
  KCloseCycleContext *closeCycleContext_;
}

// Returns a set (unique) of all windows used by |documents|
- (NSSet*)windows;

- (id)openDocumentWithContentsOfURL:(NSURL *)absoluteURL
               withWindowController:(KBrowserWindowController*)windowController
                            display:(BOOL)displayDocument
                              error:(NSError **)outError;

- (void)finalizeOpenDocument:(KTabContents*)tab
        withWindowController:(KBrowserWindowController*)windowController
                     display:(BOOL)display;
- (void)finalizeOpenDocument:(NSArray*)args;

@end

#import <Cocoa/Cocoa.h>

@class KTabContents;
@class KCloseCycleContext;
@class KBrowserWindowController;

@interface KDocumentController : NSDocumentController {
  KCloseCycleContext *closeCycleContext_;

  // atomically monotonically incrementing counter
  int32_t untitledNumberCounter_;
}

@property(readonly) int32_t nextUntitledNumber;

// Returns a set (unique) of all windows used by |documents|
- (NSSet*)windows;

- (void)addTabContents:(KTabContents*)tab
  withWindowController:(KBrowserWindowController*)windowController
          inForeground:(BOOL)foreground
     groupWithSiblings:(BOOL)groupWithSiblings;

- (id)openDocumentWithContentsOfURL:(NSURL *)absoluteURL
               withWindowController:(KBrowserWindowController*)windowController
                  groupWithSiblings:(BOOL)groupWithSiblings
                            display:(BOOL)displayDocument
                              error:(NSError **)outError;

- (void)finalizeOpenDocument:(KTabContents*)tab
        withWindowController:(KBrowserWindowController*)windowController
           groupWithSiblings:(BOOL)groupWithSiblings
                     display:(BOOL)display;

@end

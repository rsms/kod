#import <Cocoa/Cocoa.h>

@class KBrowser;
@class KTabContents;
@class KCloseCycleContext;


@interface KDocumentController : NSDocumentController {
  KCloseCycleContext *closeCycleContext_;
}

// Returns a set (unique) of all windows used by |documents|
- (NSSet*)windows;

- (id)openDocumentWithContentsOfURL:(NSURL *)absoluteURL
                          inBrowser:(KBrowser*)browser
                            display:(BOOL)displayDocument
                              error:(NSError **)outError;

- (void)finalizeOpenDocument:(KTabContents*)tab
                   inBrowser:(KBrowser*)browser
                     display:(BOOL)display;
- (void)finalizeOpenDocument:(NSArray*)args;

@end

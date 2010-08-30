#import <Cocoa/Cocoa.h>

@class KBrowser;
@class KTabContents;
@class KCloseCycleContext;


@interface KDocumentController : NSDocumentController {
  KCloseCycleContext *closeCycleContext_;
}

- (id)openDocumentWithContentsOfURL:(NSURL *)absoluteURL
                          inBrowser:(KBrowser*)browser
                            display:(BOOL)displayDocument
                              error:(NSError **)outError;

- (void)finalizeOpenDocument:(KTabContents*)tab
                   inBrowser:(KBrowser*)browser
                     display:(BOOL)display;
- (void)finalizeOpenDocument:(NSArray*)args;

@end

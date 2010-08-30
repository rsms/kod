#import <Cocoa/Cocoa.h>

@class KBrowser;
@class KTabContents;

@interface KDocumentController : NSDocumentController {
  void *closeCycleContext_;
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

#import <Cocoa/Cocoa.h>

@class KBrowser;
@class KTabContents;

@interface KDocumentController : NSDocumentController {
}

- (id)openDocumentWithContentsOfURL:(NSURL *)absoluteURL
                          inBrowser:(KBrowser*)browser
                            display:(BOOL)displayDocument
                              error:(NSError **)outError;

- (void)finalizeOpenDocument:(KTabContents*)tab inBrowser:(KBrowser*)browser;
- (void)finalizeOpenDocument:(NSArray*)args;

@end

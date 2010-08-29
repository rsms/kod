#import <Cocoa/Cocoa.h>

@class KBrowserWindowController;
@class KDocumentController;

@interface KAppDelegate : NSObject <NSApplicationDelegate> {
  KDocumentController* documentController_;
}

@property(readonly, nonatomic) KDocumentController* documentController;

- (void)commandDispatch:(id)sender;

/*-(void)openDocumentInWindow:(KBrowserWindowController*)windowController
                     sender:(id)sender;*/

@end

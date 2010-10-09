#import <Cocoa/Cocoa.h>

@interface KAppDelegate : NSObject <NSApplicationDelegate> {
}

- (IBAction)newWindow:(id)sender;
- (IBAction)newDocument:(id)sender;  // "New tab"

/*-(void)openDocumentInWindow:(KBrowserWindowController*)windowController
                     sender:(id)sender;*/

@end

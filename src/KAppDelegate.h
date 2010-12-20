#import <Cocoa/Cocoa.h>

@class SUUpdater;

@interface KAppDelegate : NSObject <NSApplicationDelegate> {
  IBOutlet SUUpdater *sparkleUpdater_;
}

- (IBAction)newWindow:(id)sender;
- (IBAction)newDocument:(id)sender;  // "New tab"

- (void)openURL:(NSURL*)url;

/*-(void)openDocumentInWindow:(KBrowserWindowController*)windowController
                     sender:(id)sender;*/

@end

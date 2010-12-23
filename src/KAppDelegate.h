#import <Cocoa/Cocoa.h>
#import <Breakpad/Breakpad.h>

@class SUUpdater, KTerminalUsageWindowController;

void k_breakpad_init();

@interface KAppDelegate : NSObject <NSApplicationDelegate> {
  IBOutlet SUUpdater *sparkleUpdater_;
  KTerminalUsageWindowController *terminalUsageWindowController_;
}

- (IBAction)newWindow:(id)sender;
- (IBAction)newDocument:(id)sender;  // "New tab"
- (IBAction)displayTerminalUsage:(id)sender;

/*-(void)openDocumentInWindow:(KBrowserWindowController*)windowController
                     sender:(id)sender;*/

@end

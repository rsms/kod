#import <Cocoa/Cocoa.h>

@class SUUpdater, KTerminalUsageWindowController;

@interface KAppDelegate : NSObject <NSApplicationDelegate> {
  IBOutlet SUUpdater *sparkleUpdater_;
  IBOutlet NSMenu *syntaxModeMenu_;
  KTerminalUsageWindowController *terminalUsageWindowController_;
}

- (IBAction)newWindow:(id)sender;
- (IBAction)newDocument:(id)sender;  // "New tab"
- (IBAction)displayTerminalUsage:(id)sender;
- (IBAction)displayAbout:(id)sender;

@end

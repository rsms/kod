
@interface KTerminalUsageWindowController : NSWindowController {
  IBOutlet NSTextField *binPathTextField_;
  IBOutlet NSButton *cancelButton_;
  IBOutlet NSButton *commitButton_;
}

- (IBAction)createLink:(id)sender;

@end

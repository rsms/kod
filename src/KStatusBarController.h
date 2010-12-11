#import "KStatusBarView.h"
@class KSplitView, KTabContents;

@interface KStatusBarController : NSViewController {
  IBOutlet KSplitView *splitView_;
  IBOutlet NSButton *toggleSplitViewButton_;
  __weak KTabContents *currentContents_;
}

@property(readonly) KStatusBarView *statusBarView;

- (void)updateWithContents:(KTabContents*)contents;

- (IBAction)toggleSplitView:(id)sender;
- (IBAction)toggleStatusBarVisibility:(id)sender;

@end

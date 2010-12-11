#import "KStatusBarView.h"
@class KSplitView, KTabContents;

@interface KStatusBarController : NSViewController {
  IBOutlet KSplitView *splitView_;
  IBOutlet NSButton *toggleSplitViewButton_;
  __weak KTabContents *currentContents_;
}

- (KStatusBarView*)statusBarView;
- (IBAction)toggleSplitView:(id)sender;

- (void)updateWithContents:(KTabContents*)contents;

@end

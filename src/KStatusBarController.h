#import "KStatusBarView.h"
@class KSplitView, KTabContents;

extern NSString * const KStatusBarDidChangeHiddenStateNotification;

@interface KStatusBarController : NSViewController {
  IBOutlet KSplitView *splitView_;
  IBOutlet NSButton *toggleSplitViewButton_;
  __weak KTabContents *currentContents_;
}

@property(readonly) KStatusBarView *statusBarView;
@property(nonatomic) BOOL isHidden;

- (void)updateWithContents:(KTabContents*)contents;

- (IBAction)toggleSplitView:(id)sender;
- (IBAction)toggleStatusBarVisibility:(id)sender;

@end

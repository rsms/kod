#import <ChromiumTabs/ChromiumTabs.h>

@class KFileOutlineView, KFileTreeController, KStatusBarView,
       KStatusBarController, KSplitView, KPopUp;

@interface KBrowserWindowController : CTBrowserWindowController {
  IBOutlet KFileOutlineView *fileOutlineView_;
  IBOutlet KStatusBarController *statusBarController_;
  IBOutlet KSplitView *splitView_;
  KFileTreeController *fileTreeController_;

  NSInteger goToLineLastValue_;
  KPopUp *goToLinePopUp_; // non-nil while active
}

@property(readonly) NSSplitView *verticalSplitView;
@property(readonly) CGFloat statusBarHeight;

// TODO: fullscreen
// implement lockBarVisibilityForOwner... and friends (see chromium source)

- (IBAction)focusLocationBar:(id)sender;
- (IBAction)toggleStatusBarVisibility:(id)sender;
- (IBAction)toggleSplitView:(id)sender;
- (IBAction)reloadStyle:(id)sender;
- (IBAction)goToLine:(id)sender;

- (BOOL)openFileDirectoryAtURL:(NSURL *)absoluteURL error:(NSError **)outError;

@end

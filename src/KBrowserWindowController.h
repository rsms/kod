#import <ChromiumTabs/ChromiumTabs.h>

@class KFileOutlineView;
@class KFileTreeController;
@class KStatusBarView;
@class KStatusBarController;

@interface KBrowserWindowController : CTBrowserWindowController {
  IBOutlet NSSplitView *verticalSplitView_;
  IBOutlet NSView *leftmostSubviewOfVerticalSplitView_;
  IBOutlet KFileOutlineView *fileOutlineView_;
  IBOutlet KStatusBarController *statusBarController_;
  KFileTreeController *fileTreeController_;
}

@property(readonly) NSSplitView *verticalSplitView;
@property(readonly) NSView *leftmostSubviewOfVerticalSplitView;
@property(readonly) CGFloat statusBarHeight;

// TODO: fullscreen
// implement lockBarVisibilityForOwner... and friends (see chromium source)

- (IBAction)focusLocationBar:(id)sender;

@end

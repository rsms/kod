#import <ChromiumTabs/ChromiumTabs.h>

@class KFileOutlineView;
@class KFileTreeController;

@interface KBrowserWindowController : CTBrowserWindowController {
  IBOutlet NSSplitView *verticalSplitView_;
  IBOutlet NSView *leftmostSubviewOfVerticalSplitView_;
  IBOutlet KFileOutlineView *fileOutlineView_;
  KFileTreeController *fileTreeController_;
}

@property(readonly) NSSplitView *verticalSplitView;
@property(readonly) NSView *leftmostSubviewOfVerticalSplitView;

// TODO: fullscreen
// implement lockBarVisibilityForOwner... and friends (see chromium source)

- (IBAction)focusLocationBar:(id)sender;

@end

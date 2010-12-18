#import <ChromiumTabs/ChromiumTabs.h>

@class KAutocompleteTextField,
       KAutocompleteTextFieldEditor,
       KLocationBarController,
       KSplitView;

// A controller for the toolbar in the browser window.
//
// This class is meant to be subclassed -- the default implementation will load
// a placeholder/dummy nib. You need to do two things:
//
// 1. Create a new subclass of CTToolbarController.
//
// 2. Copy the Toolbar.xib into your project (or create a new) and modify it as
//    needed (add buttons etc). Make sure the "files owner" type matches your
//    CTToolbarController subclass.
//
// 3. Implement createToolbarController in your CTBrowser subclass to initialize
//    and return a CTToolbarController based on your nib.
//
@interface KToolbarController : CTToolbarController {
  IBOutlet KAutocompleteTextField* locationBarTextField_;
  IBOutlet NSView *leftViewGroup_;
  IBOutlet NSView *rightViewGroup_;
  KSplitView *splitView_;
  KAutocompleteTextFieldEditor *autocompleteTextFieldEditor_;
  KLocationBarController *locationBarController_;
  __weak CTTabContents *currentContents_;
}

@property(readonly, nonatomic) KAutocompleteTextField* locationBarTextField;
@property(assign, nonatomic) __weak KSplitView *splitView;

- (void)updateLayoutForSplitView;

@end

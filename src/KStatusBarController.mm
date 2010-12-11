#import "KStatusBarController.h"
#import "KSplitView.h"
#import "KTabContents.h"
#import "common.h"

@implementation KStatusBarController


- (void)_updateCursorPosition {
  NSString *label;
  if (!currentContents_) {
    label = @"(0, 0)";
  } else {
    NSRange selection = [currentContents_.textView selectedRange];
    NSString *line = @"0";
    NSString *column;
    if (selection.length == 0) {
      column = [NSString stringWithFormat:@"%lu", selection.location];
    } else {
      column = [NSString stringWithFormat:@"%lu:%lu", selection.location,
                selection.length];
    }
    label = [NSString stringWithFormat:@"(%@, %@)", line, column];
  }
  [self statusBarView].cursorPositionTextField.stringValue = label;
}


- (void)updateWithContents:(KTabContents*)contents {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  if (currentContents_) {
    [nc removeObserver:self
                  name:NSTextViewDidChangeSelectionNotification
                object:currentContents_.textView];
  }
  currentContents_ = contents;
  if (currentContents_) {
    [nc addObserver:self
           selector:@selector(contentsTextViewDidChangeSelection:)
               name:NSTextViewDidChangeSelectionNotification
             object:currentContents_.textView];
  }
  [self _updateCursorPosition];
}


- (void)contentsTextViewDidChangeSelection:(NSNotification*)notification {
  [self _updateCursorPosition];
}


- (void)_updateToggleSplitViewButton {
  //toggleSplitViewButton_
}


- (void)awakeFromNib {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self
         selector:@selector(splitViewDidResize:)
             name:NSSplitViewDidResizeSubviewsNotification
           object:splitView_];
  [self statusBarView].splitView = splitView_;
  [self _updateToggleSplitViewButton];
}


- (KStatusBarView*)statusBarView {
  return (KStatusBarView*)super.view;
}


- (void)splitViewDidResize:(NSNotification*)notification {
  [self.statusBarView splitViewDidResize];
  [self _updateToggleSplitViewButton];
}


- (IBAction)toggleSplitView:(id)sender {
  [splitView_ toggleCollapse:sender];
}


@end

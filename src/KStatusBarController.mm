#import "KStatusBarController.h"
#import "KSplitView.h"
#import "KTabContents.h"
#import "common.h"

@implementation KStatusBarController


- (void)_updateCursorPosition {
  NSString *label;
  if (!currentContents_) {
    label = @"0, 0";
  } else {
    NSRange selection = [currentContents_.textView selectedRange];
    
    // line
    NSString *line;
    NSUInteger lineno =
        [currentContents_ lineNumberForLocation:selection.location];
    NSRange lineRange = [currentContents_ rangeOfLineAtLineNumber:lineno];
    if (selection.length > 0 &&
        (lineRange.location + lineRange.length)
        < (selection.location + selection.length) ) {
      // find end lineno
      NSUInteger endLineno = [currentContents_ lineNumberForLocation:
          (selection.location + selection.length - 1)];
      if (endLineno != lineno) {
        line = [NSString stringWithFormat:@"%lu:%lu", lineno, endLineno];
      } else {
        line = [NSString stringWithFormat:@"%lu", lineno];
      }
    } else {
      line = [NSString stringWithFormat:@"%lu", lineno];
    }
    
    // column
    NSString *column;
    NSUInteger colno = selection.location - lineRange.location;
    if (selection.length == 0) {
      column = [NSString stringWithFormat:@"%lu", colno];
    } else {
      column = [NSString stringWithFormat:@"%lu:%lu", colno, selection.length];
    }
    
  #if 0  // include character offset
    // offset
    NSString *offset;
    if (selection.length == 0) {
      offset = [NSString stringWithFormat:@"%lu", selection.location];
    } else {
      offset = [NSString stringWithFormat:@"%lu-%lu", selection.location,
                selection.location + selection.length];
    }
    label = [NSString stringWithFormat:@"%@, %@, %@", line, column, offset];
  #else
    label = [NSString stringWithFormat:@"%@, %@", line, column];
  #endif
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


- (IBAction)toggleStatusBarVisibility:(id)sender {
  [self.statusBarView setHidden:![self.statusBarView isHidden]];
  /*NSRect frame = self.statusBarView.frame;
  frame.size.height = 0.0;
  self.statusBarView.frame = frame;*/
}


@end

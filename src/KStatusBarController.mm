#import "KStatusBarController.h"
#import "KSplitView.h"
#import "KDocument.h"
#import "HEventEmitter.h"
#import "common.h"

NSString * const KStatusBarDidChangeHiddenStateNotification =
               @"KStatusBarDidChangeHiddenStateNotification";

@implementation KStatusBarController


- (void)dealloc {
  [currentContents_ release];
  [super dealloc];
}



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


- (void)updateWithContents:(KDocument*)contents {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  
  id oldContents = currentContents_;
  if (!h_atomic_cas(&currentContents_, oldContents, contents))
    return;

  if (oldContents) {
    [self stopObservingObject:currentContents_.textView];
    [oldContents release];
  }

  if (currentContents_) {
    [currentContents_ retain];
    [self observe:NSTextViewDidChangeSelectionNotification
           source:currentContents_.textView
          handler:@selector(contentsTextViewDidChangeSelection:)];
  }

  [self _updateCursorPosition];
}


- (void)contentsTextViewDidChangeSelection:(NSNotification*)notification {
  if (!self.isHidden)
    [self _updateCursorPosition];
}


- (void)_updateToggleSplitViewButton {
  [toggleSplitViewButton_ setState:splitView_.isCollapsed];
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
  if (!self.isHidden) {
    [self.statusBarView splitViewDidResize];
    [self _updateToggleSplitViewButton];
  }
}


- (IBAction)toggleSplitView:(id)sender {
  [splitView_ toggleCollapse:sender];
}


- (BOOL)isHidden {
  return self.statusBarView.isHidden;
}

- (void)setIsHidden:(BOOL)hidden {
  if (self.isHidden != hidden) {
    [self.statusBarView setHidden:hidden];
    [self post:KStatusBarDidChangeHiddenStateNotification];

    // trigger an update since updates are suspended while hidden
    if (!hidden) {
      [self _updateCursorPosition];
      [self _updateToggleSplitViewButton];
    }
    [self.statusBarView splitViewDidResize];
  }
}


- (IBAction)toggleStatusBarVisibility:(id)sender {
  self.isHidden = !self.isHidden;
}


@end

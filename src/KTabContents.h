#import <ChromiumTabs/ChromiumTabs.h>

@class KBrowser;

// This class represents a tab. In this example application a tab contains a
// simple scrollable text area.
@interface KTabContents : CTTabContents <NSTextViewDelegate> {
  __weak NSTextView* textView_; // Owned by NSScrollView which is our view_
  __weak NSUndoManager *undoManager_; // Owned by textView_
  BOOL isDirty_;
  NSStringEncoding textEncoding_;
}

@property(assign, nonatomic) BOOL isDirty;
@property(assign, nonatomic) NSStringEncoding textEncoding;

- (void)textStorageDidProcessEditing:(NSNotification*)notification;
- (void)documentDidChangeDirtyState; // when isDirty_ changed

@end

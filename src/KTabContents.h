#import <ChromiumTabs/ChromiumTabs.h>

@class KBrowser;

// This class represents a tab. In this example application a tab contains a
// simple scrollable text area.
@interface KTabContents : CTTabContents <NSTextViewDelegate> {
  __weak NSTextView* textView_; // Owned by NSScrollView which is our view_
  __weak NSUndoManager *undoManager_; // Owned by textView_
  KBrowser *browser_;
}

@property(retain, nonatomic) KBrowser *browser;

- (void)textStorageDidProcessEditing:(NSNotification*)notification;

@end

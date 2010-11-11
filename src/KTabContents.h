#import <ChromiumTabs/ChromiumTabs.h>

@class KBrowser;
@class KSyntaxHighlighter;
@class KBrowserWindowController;

// This class represents a tab. In this example application a tab contains a
// simple scrollable text area.
@interface KTabContents : CTTabContents <NSTextViewDelegate> {
  __weak NSTextView* textView_; // Owned by NSScrollView which is our view_
  __weak NSUndoManager *undoManager_; // Owned by textView_
  BOOL isDirty_;
  NSStringEncoding textEncoding_;
  KSyntaxHighlighter *syntaxHighlighter_;
  
  // Internal state
  BOOL hasPendingInitialHighlighting_;
}

@property(assign, nonatomic) BOOL isDirty;
@property(assign, nonatomic) NSStringEncoding textEncoding;
@property(readonly) KBrowserWindowController* windowController;
@property(readonly) KSyntaxHighlighter* syntaxHighlighter;
@property(readonly) NSMutableParagraphStyle *paragraphStyle;

+ (NSFont*)defaultFont;

// actions
- (IBAction)debugDumpAttributesAtCursor:(id)sender;
- (IBAction)selectNextElement:(id)sender;
- (IBAction)selectPreviousElement:(id)sender;

- (void)highlightCompleteDocument:(id)sender;
- (void)queueCompleteHighlighting:(id)sender;

- (void)textStorageDidProcessEditing:(NSNotification*)notification;
- (void)documentDidChangeDirtyState; // when isDirty_ changed

@end

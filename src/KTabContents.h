#import <ChromiumTabs/ChromiumTabs.h>

#import "common.h"
#import "KSourceHighlighter.h"
#import "HSemaphore.h"

@class KBrowser;
@class KStyle;
@class KBrowserWindowController;

typedef std::pair<std::pair<NSRange,NSRange>, HObjCPtr> KHighlightQueueEntry;
typedef std::deque<KHighlightQueueEntry> KHighlightQueue;

// This class represents a tab. In this example application a tab contains a
// simple scrollable text area.
@interface KTabContents : CTTabContents <NSTextViewDelegate,
                                         NSTextStorageDelegate> {
  __weak NSTextView* textView_; // Owned by NSScrollView which is our view_
  __weak NSUndoManager *undoManager_; // Owned by textView_
  BOOL isDirty_;
  NSStringEncoding textEncoding_;
  
  KSourceHighlighterPtr sourceHighlighter_;
  BOOL highlightingEnabled_;
  HSemaphore highlightSem_;
  
  // Current language
  NSString const *langId_;
  
  // Internal state
  hatomic_flags_t stateFlags_;
  NSRange lastEditedHighlightStateRange_;
  __weak KSourceHighlightState *lastEditedHighlightState_;
  int64_t highlightWaitBackOffNSec_; // nanoseconds
}

@property(assign, nonatomic) BOOL isDirty;
@property(assign, nonatomic) BOOL highlightingEnabled;
@property(readonly) BOOL canSaveDocument;
@property(readonly) BOOL hasRemoteSource;
@property(assign, nonatomic) NSStringEncoding textEncoding;
@property(readonly) KBrowserWindowController* windowController;
@property(readonly) NSMutableParagraphStyle *paragraphStyle; // compound
@property(retain, nonatomic) NSString *langId;


+ (NSFont*)defaultFont;
- (void)setIconBasedOnContents;

- (void)guessLanguageBasedOnUTI:(NSString*)uti textContent:(NSString*)text;

// actions
- (IBAction)debugDumpAttributesAtCursor:(id)sender;
- (IBAction)selectNextElement:(id)sender;
- (IBAction)selectPreviousElement:(id)sender;

- (BOOL)setNeedsHighlightingOfCompleteDocument;
- (BOOL)highlightCompleteDocumentInBackgroundIfQueued;
- (BOOL)highlightCompleteDocumentInBackground;

- (BOOL)deferHighlightTextStorage:(NSTextStorage*)textStorage
                          inRange:(NSRange)range;

- (void)clearHighlighting;
- (void)refreshStyle;

- (void)textStorageDidProcessEditing:(NSNotification*)notification;
- (void)documentDidChangeDirtyState; // when isDirty_ changed


// These two are called by readFromURL:ofType:error:

- (BOOL)readFromFileURL:(NSURL *)absoluteURL
                 ofType:(NSString *)typeName
                  error:(NSError **)outError;

- (void)startReadingFromRemoteURL:(NSURL*)absoluteURL
                           ofType:(NSString *)typeName;

@end

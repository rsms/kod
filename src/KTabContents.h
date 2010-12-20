#import <ChromiumTabs/ChromiumTabs.h>

#import "common.h"
#import "KSourceHighlighter.h"
#import "HSemaphore.h"

@class KBrowser, KStyle, KBrowserWindowController, KScrollView, KMetaRulerView;
@class KTextView, KClipView;

typedef std::pair<std::pair<NSRange,NSRange>, HObjCPtr> KHighlightQueueEntry;
typedef std::deque<KHighlightQueueEntry> KHighlightQueue;

// This class represents a tab. In this example application a tab contains a
// simple scrollable text area.
@interface KTabContents : CTTabContents <NSTextViewDelegate,
                                         NSTextStorageDelegate> {
  KTextView* textView_; // Owned by NSScrollView which is our view_
  __weak NSUndoManager *undoManager_; // Owned by textView_
  BOOL isDirty_;
  NSStringEncoding textEncoding_;
  
  KSourceHighlighterPtr sourceHighlighter_;
  BOOL highlightingEnabled_;
  HSemaphore highlightSem_;
  
  // Current language
  NSString const *langId_;
  
  // Mapped line breaks. Provides number of lines and a mapping from line number
  // to actual character offset. The location of each range denotes the start
  // of a linebreak and the length denotes how many characters are included in
  // that linebreak (normally 1 or 2: LF, CR or CRLF).
  std::vector<NSRange> lineToRangeVec_;
  
  // Meta ruler (nil if not shown)
  __weak KMetaRulerView *metaRulerView_;
  
  // Internal state
  hatomic_flags_t stateFlags_;
  NSRange lastEditedHighlightStateRange_;
  __weak KSourceHighlightState *lastEditedHighlightState_;
  int64_t highlightWaitBackOffNSec_; // nanoseconds
}

@property(assign, nonatomic) BOOL isDirty;
@property(assign, nonatomic) BOOL highlightingEnabled;
@property BOOL hasMetaRuler;
@property(readonly) BOOL canSaveDocument;
@property(readonly) BOOL hasRemoteSource;
@property(assign, nonatomic) NSStringEncoding textEncoding;
@property(readonly) KBrowserWindowController* windowController;
@property(readonly) NSMutableParagraphStyle *paragraphStyle; // compound
@property(retain, nonatomic) NSString *langId;
@property(readonly, nonatomic) KTextView* textView;
@property(readonly, nonatomic) KScrollView* scrollView;
@property(readonly, nonatomic) KClipView* clipView;

@property(readonly, nonatomic) NSUInteger lineCount;
@property(readonly, nonatomic) NSUInteger charCountOfLastLine;


+ (NSFont*)defaultFont;
- (void)setIconBasedOnContents;

- (void)guessLanguageBasedOnUTI:(NSString*)uti textContent:(NSString*)text;

// actions
- (IBAction)debugDumpAttributesAtCursor:(id)sender;
- (IBAction)selectNextElement:(id)sender;
- (IBAction)selectPreviousElement:(id)sender;
- (IBAction)toggleMetaRuler:(id)sender;

- (BOOL)setNeedsHighlightingOfCompleteDocument;
- (BOOL)highlightCompleteDocumentInBackgroundIfQueued;
- (BOOL)highlightCompleteDocumentInBackground;

- (BOOL)deferHighlightTextStorage:(NSTextStorage*)textStorage
                          inRange:(NSRange)range;

- (void)clearHighlighting;
- (void)refreshStyle;

- (void)styleDidChange:(NSNotification*)notification;
- (void)textStorageDidProcessEditing:(NSNotification*)notification;
- (void)documentDidChangeDirtyState; // when isDirty_ changed

// Retrieve line number (first line is 1) for character |location|
- (NSUInteger)lineNumberForLocation:(NSUInteger)location;

// Range of line terminator for |lineNumber|
- (NSRange)rangeOfLineTerminatorAtLineNumber:(NSUInteger)lineNumber;

// Range of line at |lineNumber| including line terminator (first line is 1)
- (NSRange)rangeOfLineAtLineNumber:(NSUInteger)lineNumber;


// These two are called by readFromURL:ofType:error:

- (BOOL)readFromFileURL:(NSURL *)absoluteURL
                 ofType:(NSString *)typeName
                  error:(NSError **)outError;

- (void)startReadingFromRemoteURL:(NSURL*)absoluteURL
                           ofType:(NSString *)typeName;

- (BOOL)readFromData:(NSData *)data
              ofType:(NSString *)typeName
               error:(NSError **)outError
               callback:(void(^)(void))callback;

@end

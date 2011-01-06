#import <ChromiumTabs/ChromiumTabs.h>

#import "common.h"
#import "HSpinLock.h"

@class KBrowser, KStyle, KBrowserWindowController, KScrollView, KMetaRulerView;
@class KTextView, KClipView, KURLHandler;

// notifications
extern NSString *const KDocumentDidLoadDataNotification;

// This class represents a tab. In this example application a tab contains a
// simple scrollable text area.
@interface KDocument : CTTabContents <NSTextViewDelegate,
                                      NSTextStorageDelegate> {
  KTextView* textView_; // Owned by NSScrollView which is our view_
  __weak NSUndoManager *undoManager_; // Owned by textView_
  BOOL isDirty_;
  NSStringEncoding textEncoding_;

  // Current language
  NSString const *langId_;

  // Mapped line breaks. Provides number of lines and a mapping from line number
  // to actual character offset. The location of each range denotes the start
  // of a linebreak and the length denotes how many characters are included in
  // that linebreak (normally 1 or 2: LF, CR or CRLF).
  std::vector<NSRange> lineToRangeVec_;
  HSpinLock lineToRangeSpinLock_;

  // Meta ruler (nil if not shown)
  __weak KMetaRulerView *metaRulerView_;

  // Timestamp of last edit (in microseconds). 0 if never edited.
  uint64_t lastEditTimestamp_;

  // Internal state
  hatomic_flags_t stateFlags_;
  NSRange lastEditedHighlightStateRange_;
  NSNumber *activeNodeTextEditedInvocationRTag_;
}

@property(assign, nonatomic) BOOL isDirty;
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

// Tab identifier
@property(readonly, nonatomic) NSUInteger identifier;

// Text contents
@property(copy) NSString *text;

// alias of fileURL
@property(retain) NSURL *url;

// Makes the document editable (default) or read-only
@property(assign) BOOL isEditable;

// True if the document is a new, untouched buffer without a url
@property(readonly) BOOL isVirgin;


+ (NSFont*)defaultFont;
- (void)setIconBasedOnContents;

// actions
- (IBAction)debugDumpAttributesAtCursor:(id)sender;
- (IBAction)selectNextElement:(id)sender;
- (IBAction)selectPreviousElement:(id)sender;
- (IBAction)toggleMetaRuler:(id)sender;

- (void)refreshStyle;

- (void)styleDidChange:(NSNotification*)notification;
- (void)textStorageDidProcessEditing:(NSNotification*)notification;

// Retrieve line number (first line is 1) for character |location|
- (NSUInteger)lineNumberForLocation:(NSUInteger)location;

// Range of line terminator for |lineNumber|
- (NSRange)rangeOfLineTerminatorAtLineNumber:(NSUInteger)lineNumber;

// Range of line indentation for |lineNumber|
- (NSRange)rangeOfLineIndentationAtLineNumber:(NSUInteger)lineNumber;

// Range of line at |lineNumber| including line terminator (first line is 1)
- (NSRange)rangeOfLineAtLineNumber:(NSUInteger)lineNumber;

/*!
 * Returns the range of characters representing the line or lines containing the
 * current selection.
 */
- (NSRange)lineRangeForCurrentSelection;

// These are called by readFromURL:ofType:error:

// KURLHandlers need to invoke this lengthy method after they have read a url
- (void)urlHandler:(KURLHandler*)urlHandler
finishedReadingURL:(NSURL*)url
              data:(NSData*)data
            ofType:(NSString*)typeName
             error:(NSError*)error
          callback:(void(^)(NSError*))callback;

- (BOOL)readFromData:(NSData *)data
              ofType:(NSString *)typeName
               error:(NSError **)outError
            callback:(void(^)(void))callback;

@end

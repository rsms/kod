// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import <ChromiumTabs/ChromiumTabs.h>

#import "common.h"
#import "HSpinLock.h"
#import "AST.h"

@class KBrowser, KStyle, KBrowserWindowController, KScrollView, KMetaRulerView;
@class KTextView, KClipView, KURLHandler;

class KNodeParseEntry;

// notifications
extern NSString *const KDocumentDidLoadDataNotification;
extern NSString *const KDocumentWillCloseNotification;

// This class represents a tab. In this example application a tab contains a
// simple scrollable text area.
@interface KDocument : CTTabContents <NSTextViewDelegate,
                                      NSTextStorageDelegate> {
  uint64_t identifier_;
  volatile uint64_t version_;

  KTextView* textView_; // Owned by NSScrollView which is our view_
  __weak NSUndoManager *undoManager_; // Owned by textView_
  BOOL isDirty_;
  NSStringEncoding textEncoding_;

  // Abstract Syntax Tree
  kod::ASTPtr ast_;

  // Mapped line breaks. Provides number of lines and a mapping from line number
  // to actual character offset. The location of each range denotes the start
  // of a linebreak and the length denotes how many characters are included in
  // that linebreak (normally 1 or 2: LF, CR or CRLF).
  std::vector<NSRange> lineToRangeVec_;
  HSpinLock lineToRangeSpinLock_;

  // Meta ruler (nil if not shown)
  __weak KMetaRulerView *metaRulerView_;
}

@property(assign, nonatomic) BOOL isDirty;
@property BOOL hasMetaRuler;
@property(readonly) BOOL canSaveDocument;
@property(readonly) BOOL hasRemoteSource;
@property(assign) NSStringEncoding textEncoding;
@property(readonly) KBrowserWindowController* windowController;
@property(readonly) NSMutableParagraphStyle *paragraphStyle; // compound

@property(readonly) KTextView* textView;
@property(readonly) KScrollView* scrollView;
@property(readonly) KClipView* clipView;

@property(readonly) NSUInteger lineCount;
@property(readonly) NSUInteger charCountOfLastLine;


// An opaque value which identifies this document. It's guaranteed to be unique
// during a session (between starting and terminating Kod.app).
@property(readonly) uint64_t identifier;

/*!
 * Monotonically incrementing version number which changes for each edit.
 * This number is only unique within this document and during its opened
 * life-cycle (that is, when closing and again opening a document, it is reset).
 *
 * -- Internal usage --
 *
 * Incrementing the version and reading the new value:
 *    uint64_t version = h_atomic_inc(&version_);
 *
 * Incrementing the version and reading the previous value:
 *    uint64_t oldVersion = h_atomic_inc_and_return_prev(&version_);
 *
 * Reading the current version can be done by simply reading the value of
 * version_ since each h_atomic_inc-call issues a full memory barrier, thus any
 * concurrent reads will synchronize to either complete or hold.
 */
@property(readonly) uint64_t version;


@property(readonly) kod::ASTPtr &ast;
@property(readonly) kod::ASTNodePtr &astRootNode;


// A Uniform Type Identifier for the current contents
@property(retain) NSString *type;
- (void)setTypeFromPathExtension:(NSString*)pathExtension;
- (void)setTypeFromMIMEType:(NSString*)mimeType;


// Text contents (returns a reference when read, and makes a copy when written)
@property(copy) NSString *text;

// alias of fileURL
@property(retain) NSURL *url;

// Makes the document editable (default) or read-only
@property(assign) BOOL isEditable;

// True if the document is a new, untouched buffer without a url
@property(readonly) BOOL isVirgin;


- (void)setIconBasedOnContents;

// actions
- (IBAction)debugDumpAttributesAtCursor:(id)sender;
- (IBAction)debugUpdateASTViewer:(id)sender;
- (IBAction)selectNextElement:(id)sender;
- (IBAction)selectPreviousElement:(id)sender;
- (IBAction)toggleMetaRuler:(id)sender;

- (void)refreshStyle;
- (void)styleDidChange:(NSNotification*)notification;

- (void)ASTWasUpdated;

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

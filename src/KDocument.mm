// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#include <sys/xattr.h>

#import "common.h"

#import "kconf.h"
#import "KDocument.h"
#import "KBrowser.h"
#import "KBrowserWindowController.h"
#import "KDocumentController.h"
#import "KURLHandler.h"
#import "KStyle.h"
#import "KScroller.h"
#import "KScrollView.h"
#import "KClipView.h"
#import "KTextView.h"
#import "KStatusBarView.h"
#import "KMetaRulerView.h"
#import "HEventEmitter.h"
#import "kod_node_interface.h"
#import "knode_ns_additions.h"
#import "ExternalUTF16String.h"
#import "node-module/ASTNodeWrapper.h"
#import "KASTViewerWindowController.h"
#import "KASTViewerController.h"
#import "KMachService-NSInvocation.h"

#import "NSImage-kod.h"
#import "CIImage-kod.h"

// set to 1 to enable resource usage sampling and logging
#define KOD_WITH_K_RUSAGE 1
#import "KRUsage.hh"


// Hate to use this, but we need to travel around the world if we don't
@interface NSDocument (Private)
- (void)_updateForDocumentEdited:(BOOL)arg1;
@end

// used by lastEditChangedTextStatus_
static const uint8_t kEditChangeStatusUnknown = 0;
static const uint8_t kEditChangeStatusUserUnalteredText = 1;
static const uint8_t kEditChangeStatusUserAlteredText = 2;

// notifications
NSString *const KDocumentDidLoadDataNotification =
              @"KDocumentDidLoadDataNotification";
NSString *const KDocumentWillCloseNotification =
              @"KDocumentWillCloseNotification";

static NSString *_NSStringFromRangeArray(std::vector<NSRange> &lineToRangeVec,
                                         NSString *string) {
  NSMutableString *str = [NSMutableString string];
  size_t i = 0, count = lineToRangeVec.size();
  for (; i < count; ++i) {
    NSRange &r = lineToRangeVec[i];
    NSString *sstr;
    @try { sstr = string ? [string substringWithRange:r] : @""; }
    @catch (NSException *e) { sstr = @"<out of range>"; }
    [str appendFormat:@"\n%3zu => %@ '%@',", i, NSStringFromRange(r), sstr];
  }
  return str;
}


// Document identifier
static volatile uint64_t _identifierNext = 0;
static uint64_t KDocumentNextIdentifier() {
  return h_atomic_inc(&_identifierNext);
}


@interface KDocument (Private)
- (void)undoManagerCheckpoint:(NSNotification*)notification;
@end

@implementation KDocument

@synthesize textEncoding = textEncoding_,
            textView = textView_;

static NSImage* _kDefaultIcon = nil;
static NSString* _kDefaultTitle = @"Untitled";

+ (void)load {
  NSAutoreleasePool* pool = [NSAutoreleasePool new];
  _kDefaultIcon =
      [[[NSWorkspace sharedWorkspace] iconForFile:@"/dev/null"] retain];
  [pool drain];
}


// This is the main initialization method
- (id)initWithBaseTabContents:(CTTabContents*)baseContents {
  // Note: This might be called from a background thread and must thus be
  // thread-safe.
  if (!(self = [super init])) return nil;

  // Assign a new identifier
  identifier_ = KDocumentNextIdentifier();

  // Initialize ast_
  ast_.reset(new kod::AST(self));

  // Default title and icon
  self.title = _kDefaultTitle;
  self.icon = _kDefaultIcon;

  // Default text encoding for new "Untitled" documents
  textEncoding_ = NSUTF8StringEncoding;

  // Save a weak reference to the undo manager (performance reasons)
  undoManager_ = [self undoManager]; assert(undoManager_);

  // Create a KTextView
  textView_ = [[KTextView alloc] initWithFrame:NSZeroRect];
  [textView_ setDelegate:self];
  [textView_ setFont:[[KStyle sharedStyle] baseFont]];

  // configure layout manager
  //NSLayoutManager *layoutManager = []

  // default paragraph style
  NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
  [paragraphStyle setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
  [paragraphStyle setLineBreakMode:NSLineBreakByCharWrapping];
  [textView_ setDefaultParagraphStyle:paragraphStyle];
  [paragraphStyle release];

  // TODO: this defines the attributes to apply to "marked" text, input which is
  // pending, like "¨" waiting for "u" to build the character "ü". Should match
  // the current style.
  //[textView_ setMarkedTextAttributes:[NSDictionary dictionaryWithObject:[NSColor redColor] forKey:NSBackgroundColorAttributeName]];

  // Create a NSScrollView to which we add the NSTextView
  KScrollView *sv = [[KScrollView alloc] initWithFrame:NSZeroRect];
  [sv setDocumentView:textView_];
  ((KScroller*)[sv horizontalScroller]).tab = self; // weak
  ((KScroller*)[sv verticalScroller]).tab = self; // weak

  // Set the NSScrollView as our view
  self.view = [sv autorelease];

  // Configure meta ruler (line numbers)
  self.hasMetaRuler = !kconf_bool(@"editor/metaRuler/hidden", NO);

  // Start with the empty style and load the default style
  kassert([KStyle sharedStyle] != nil);
  [self observe:KStyleDidChangeNotification
         source:[KStyle sharedStyle]
        handler:@selector(styleDidChange:)];
  [self styleDidChange:nil]; // trigger initial

  // Let the global document controller know we came to life
  [[NSDocumentController sharedDocumentController] addDocument:self];

  // Observe when the document is modified so we can update the UI accordingly
  /*NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self
         selector:@selector(undoManagerCheckpoint:)
             name:NSUndoManagerCheckpointNotification
           object:undoManager_];*/

  // register as text storage delegate
  textView_.textStorage.delegate = self;

  return self;
}


/*
 This method is invoked by the NSDocumentController method
 makeDocumentWithContentsOfURL:ofType:error:
 */
- (id)initWithContentsOfURL:(NSURL *)absoluteURL
                     ofType:(NSString *)typeName
                      error:(NSError **)outError {
  // This may be called on a background thread
  self = [self initWithBaseTabContents:nil];
  kassert(self);

  // call upon the mighty read-from-URL machinery
  if (![self readFromURL:absoluteURL ofType:typeName error:outError]) {
    [self release];
    if (outError) kassert(*outError != nil);
    return nil;
  }

  return self;
}


- (void)dealloc {
  //DLOG("--- DEALLOC %@ ---", self);
  [self stopObserving];
  if (metaRulerView_) {
    // Okay, so this is the deal: We own the ruler, so the ruler shouldn't
    // retain us. But, the ruler might be retained by our owning KScrollView,
    // which could case access to us after we are dead. This little thing clear
    // our weak ref in the ruler:
    metaRulerView_.tabContents = nil;
  }
  //if (sourceHighlighter_.get())
  //  sourceHighlighter_->cancel();
  [super dealloc];
}

/*- (id)retain {
  DLOG("\n%@ retain (%lu) %@\n", self, [self retainCount],
       @""//[NSThread callStackSymbols]
       );
   fflush(stderr); fsync(STDERR_FILENO);
  usleep(5000);
  return [super retain];
}
- (void)release {
  //DLOG("%@ release %@", self, [NSThread callStackSymbols]);
  DLOG("\n%@ release (%lu) %@\n", self, [self retainCount],
       @""//[NSThread callStackSymbols]
       );
  fflush(stderr); fsync(STDERR_FILENO);
  usleep(5000);
  [super release];
}
- (id)autorelease {
  DLOG("\n%@ autorelease %@\n", self,
       @""//[NSThread callStackSymbols]
       );
  fflush(stderr); fsync(STDERR_FILENO);
  return [super autorelease];
}
- (void)destroy:(CTTabStripModel*)sender {
  sender->TabContentsWasDestroyed(self);
}*/


#pragma mark -
#pragma mark Properties


- (void)setIsLoading:(BOOL)loading {
  if (isLoading_ != loading) {
    BOOL isLoadingPrev = isLoading_;
    isLoading_= loading;
    // this need to execute in main since animation is triggered from this
    dispatch_block_t block = ^{
      if (browser_) [browser_ updateTabStateForContent:self];
      // update icon if we went from "loading" to "not loading"
      if (isLoadingPrev && !isLoading_) {
        [self setIconBasedOnContents];
      }
    };
    if ([NSThread isMainThread]) {
      block();
    } else {
      h_dispatch_async_main(block);
    }
  }
}


- (BOOL)hasRemoteSource {
  NSURL *url = self.fileURL;
  return url && ![url isFileURL];
}


- (NSString*)type {
  return [self fileType];
}

- (void)setType:(NSString*)typeName {
  [self setFileType:typeName];
}

- (void)setTypeFromPathExtension:(NSString*)typeTag {
  self.type = (NSString*)
      UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
                                            (CFStringRef)typeTag,
                                            NULL /* no conform restraints */ );
}

- (void)setTypeFromMIMEType:(NSString*)typeTag {
  self.type = (NSString*)
      UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType,
                                            (CFStringRef)typeTag,
                                            NULL /* no conform restraints */ );
}


- (NSMutableParagraphStyle*)paragraphStyle {
  return (NSMutableParagraphStyle*)textView_.defaultParagraphStyle;
}


- (void)setIconBasedOnContents {
  DLOG_TRACE();
  NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
  NSURL *url = [self fileURL];
  if (url) {
    if ([url isFileURL]) {
      self.icon = [workspace iconForFile:[url path]];
    } else if (self.fileType) {
      //DLOG("remote url -- self.fileType => %@", self.fileType);
      NSString *guessedExt =
          [workspace preferredFilenameExtensionForType:self.fileType];
      self.icon = [workspace iconForFileType:guessedExt];
    }
  } else {
    self.icon = _kDefaultIcon;
  }
}


- (void)setFileURL:(NSURL *)url {
  DLOG("setFileURL:%@", url);
  if (url != [self fileURL]) {
    [super setFileURL:url];
    if (url) {
      // set title
      if ([url isFileURL]) {
        self.title = url.lastPathComponent;
      } else {
        self.title = [url absoluteString];
      }
    } else {
      self.title = _kDefaultTitle;
    }
  }
}


- (NSURL*)url {
  return [self fileURL];
}

- (void)setUrl:(NSURL *)url {
  [self setFileURL:url];
}


/*- (NSDate*)fileModificationDate {
  NSDate *mtime = [super fileModificationDate];

  NSDate *mtime2 = [[[NSFileManager defaultManager] attributesOfItemAtPath:[self.fileURL path] error:nil] objectForKey:NSFileModificationDate];

  DLOG("%@ fileModificationDate -> %@ (actual: %@)", self, mtime, mtime2);
  return mtime;
}


- (void)setFileModificationDate:(NSDate*)mtime {
  DLOG("%@ setFileModificationDate:%@", self, mtime);
  [super setFileModificationDate:mtime];
}*/


- (NSString*)displayName {
  return self.title;
}


- (KBrowserWindowController*)windowController {
  NSArray *v = self.windowControllers;
  if (v && [v count] == 1)
    return (KBrowserWindowController*)[v objectAtIndex:0];
  return nil;
}


- (NSWindow *)windowForSheet {
  KBrowser* browser = (KBrowser*)self.browser;
  if (browser) {
    CTBrowserWindowController* windowController = browser.windowController;
    if (windowController) {
      return [windowController window];
    }
  }
  return nil;
}


// NSDocument override
- (void)setWindow:(NSWindow*)window {
  // Called when this tab receives either |tabDidBecomeSelected| (with a window
  // object) or |tabDidBecomeSelected| (with nil).

  [super setWindow:window];

  if (window) {
    // case: we just became the key content of |window|

    // update window title
    NSURL *url = [self fileURL];
    // We need to set repr. filename to the empty string if we do not
    // represent a local file since it's stateful in the context of window.
    NSString *absolutePath = (url && [url isFileURL]) ? [url path] : @"";
    [window setRepresentedFilename:absolutePath];
    [window setTitle:self.title];
  }
}


- (KScrollView*)scrollView {
  return (KScrollView*)view_;
}


- (KClipView*)clipView {
  return (KClipView*)[self.scrollView contentView];
}


- (BOOL)hasMetaRuler {
  return [self.scrollView hasVerticalRuler];
}


- (void)setHasMetaRuler:(BOOL)displayRuler {
  BOOL hasRuler = self.hasMetaRuler;
  if (hasRuler == displayRuler) return; // noop
  KScrollView *scrollView = self.scrollView;
  if (displayRuler) {
    NSRulerView *prevRulerView = [scrollView verticalRulerView];
    if (!prevRulerView ||
        ![prevRulerView isKindOfClass:[KMetaRulerView class]]) {
      metaRulerView_ = [[KMetaRulerView alloc] initWithScrollView:scrollView
                                                      tabContents:self];
      [scrollView setVerticalRulerView:metaRulerView_];
      [metaRulerView_ release];
    } else {
      metaRulerView_ = (KMetaRulerView*)prevRulerView;
    }
    [scrollView setHasVerticalRuler:YES];
    [scrollView setRulersVisible:YES];
  } else {
    [scrollView setHasVerticalRuler:NO];
    [scrollView setRulersVisible:NO];
    metaRulerView_ = nil;
  }

  // Update config
  kconf_set_bool(@"editor/metaRuler/hidden", !displayRuler);
}


- (BOOL)isDirty { return isDirty_; }
- (void)setIsDirty:(BOOL)isDirty {
  if (!isDirty == !isDirty_) return; //noop
  isDirty_ = isDirty;
  if (browser_) [browser_ updateTabStateForContent:self];
}


- (NSImage*)icon {
  NSImage *icon = [super icon];
  if (isDirty_) {
    NSDictionary *filterParameters =
      [NSDictionary dictionaryWithObject:[NSNumber numberWithDouble:-1.5]
                                  forKey:@"inputEV"];
    icon = [icon imageByApplyingCIFilterNamed:@"CIExposureAdjust"
                             filterParameters:filterParameters];
    //icon = [icon imageByApplyingCIFilterNamed:@"CIColorInvert"];
  }
  return icon;
}


- (uint64_t)identifier {
  return identifier_;
}

- (uint64_t)version {
  return version_;
}


- (NSString*)text {
  return textView_.textStorage.string;
}


- (void)setText:(NSString*)text {
  NSTextStorage *textStorage = textView_.textStorage;
  [textStorage replaceCharactersInRange:NSMakeRange(0, textStorage.length)
                             withString:text];
}


- (BOOL)isEditable {
  return [textView_ isEditable];
}

- (void)setIsEditable:(BOOL)editable {
  [textView_ setEditable:editable];
}


- (BOOL)isVirgin {
  return ![self isDocumentEdited] && ![self fileURL];
}


- (kod::ASTPtr&)ast { return ast_; }


- (kod::ASTNodePtr&)astRootNode {
  kassert(ast_.get() != NULL);
  DLOG("ast_->status() -> %d", ast_->status());
  DLOG("ast_->isOpenEnded() -> %d", ast_->isOpenEnded());
  return ast_->rootNode();
}


#pragma mark -
#pragma mark Notifications


- (void)styleDidChange:(NSNotification*)notification {
  [self refreshStyle];
}


- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item {
  BOOL y = NO;
  SEL action = [item action];
  if (action == @selector(saveDocument:)) {
    y = [self isDocumentEdited] || ![self fileURL];
  } else if (action == @selector(toggleMetaRuler:)) {
    NSMenuItem *menuItem = (NSMenuItem*)item;
    [menuItem setState:self.hasMetaRuler];
    y = YES;
  } else if (action == @selector(setSyntaxMode:)) {
    // TODO
  } else {
    y = [super validateUserInterfaceItem:item];
  }
  return y;
}


- (void)tabWillCloseInBrowser:(CTBrowser*)browser atIndex:(NSInteger)index {
  NSNumber *ident = [NSNumber numberWithUnsignedInteger:self.identifier];

  KNodeEmitEvent("closeDocument", self, ident, nil);
  // TODO(rsms): emit "close" event in nodejs on our v8 wrapper object instead
  // of the kod module.

  [self post:KDocumentWillCloseNotification];
  [self emitEvent:@"close" argument:self];

  [super tabWillCloseInBrowser:browser atIndex:index];

  NSWindowController *wc = browser.windowController;
  if (wc) {
    [self removeWindowController:wc];
    [self setWindow:nil];
  }
  [[NSDocumentController sharedDocumentController] removeDocument:self];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)tabDidBecomeSelected {
  [super tabDidBecomeSelected];
  if (browser_) {
    NSWindowController *wc = browser_.windowController;
    if (wc) {
      [self addWindowController:wc];
      [self setWindow:[wc window]];
    }
  }
  K_DISPATCH_MAIN_ASYNC({
    self.clipView.allowsScrolling = YES;
  });

  // XXX FIXME TEMP DEBUG ...
  [self debugUpdateASTViewer:self];

  KNodeEmitEvent("activateDocument", self, nil);
}


- (void)tabDidResignSelected {
  [super tabDidResignSelected];

  // disable scrolling while not selected (workaround for an AppKit bug)
  self.clipView.allowsScrolling = NO;

  if (browser_) {
    NSWindowController *wc = browser_.windowController;
    if (wc) {
      [self removeWindowController:wc];
      [self setWindow:nil];
    }
  }
}


// Invoked when ranges of lines changed. |lineCountDelta| denotes how many lines
// where added or removed, if any.
- (void)linesDidChangeWithLineCountDelta:(NSInteger)lineCountDelta {
  //DLOG("linesDidChangeWithLineCountDelta:%ld %@", lineCountDelta,
  //     _NSStringFromRangeArray(lineToRangeVec_, textView_.textStorage.string));
  if (metaRulerView_) {
    [metaRulerView_ linesDidChangeWithLineCountDelta:lineCountDelta];
  }
}


- (NSString*)_inspectASTTree:(kod::ASTNodePtr&)astNode {
  if (!astNode.get())
    return @"<null>";
  NSRange sourceRange = astNode->sourceRange();
  NSMutableString *str = [NSMutableString stringWithFormat:
      @"{ kind:\"%s\", sourceRange:[%lu, %lu]",
      //astNode->kind()->weakNSString(),
      astNode->ruleName(),
      sourceRange.location, sourceRange.length];

  if (!astNode->childNodes().empty()) {
    [str appendFormat:@", childNodes: ["];
    std::vector<kod::ASTNodePtr>::iterator it = astNode->childNodes().begin();
    std::vector<kod::ASTNodePtr>::iterator endit = astNode->childNodes().end();
    for ( ; it < endit; ++it ) {
      [str appendString:[self _inspectASTTree:*it]];
    }
    [str appendFormat:@"]"];
  }

  [str appendString:@"},"];
  return str;
}


- (void)ASTWasUpdated {
  DLOG("%@ ASTWasUpdated", self);
  K_DISPATCH_MAIN_ASYNC({ [self debugUpdateASTViewer:self]; });
}


#pragma mark -
#pragma mark Node.js


// wrappers for KDocuments should be persistent
- (BOOL)nodeWrapperIsPersistent {
  return YES;
}

//- (v8::Local<v8::Value>)v8Value { return *v8::Undefined(); }


#pragma mark -
#pragma mark Line info


- (NSUInteger)charCountOfLastLine {
  HSpinLock::Scope slscope(lineToRangeSpinLock_);
  NSUInteger remainingCharCount = textView_.textStorage.length;
  if (!lineToRangeVec_.empty()) {
    NSRange &r = lineToRangeVec_.back();
    remainingCharCount -= r.location + r.length;
  }
  return remainingCharCount;
}


- (NSUInteger)lineCount {
  HSpinLock::Scope slscope(lineToRangeSpinLock_);
  return lineToRangeVec_.size() + 1;
}


- (NSRange)rangeOfLineTerminatorAtLineNumber:(NSUInteger)lineNumber {
  HSpinLock::Scope slscope(lineToRangeSpinLock_);

  if (lineNumber > 0) // 1-based
    --lineNumber;
  if (lineNumber < lineToRangeVec_.size()) {
    return lineToRangeVec_[lineNumber];
  } else if (!lineToRangeVec_.empty()) {
    if (lineNumber == lineToRangeVec_.size()) {
      NSRange range = lineToRangeVec_.back();
      NSUInteger lastLineLength = textView_.textStorage.length -
          (range.location + range.length);
      range.location += range.length;
      range.length = lastLineLength;
      return range;
    } else {
      // |lineNumber| goes beyond number of total lines
      return NSMakeRange(NSNotFound, 0);
    }
  } else {
    if (lineNumber < 2) {
      // there are no line breaks (just the "last line")
      return NSMakeRange(0, textView_.textStorage.length);
    } else {
      return NSMakeRange(NSNotFound, 0);
    }
  }
}

- (NSRange)rangeOfLineIndentationAtLineNumber:(NSUInteger)lineNumber {
  NSRange line = [self rangeOfLineAtLineNumber:lineNumber];
  NSString *lineString = [textView_.textStorage.string substringWithRange:line];

  int indentLen = 0;
  int length = [lineString length];
  while ([lineString characterAtIndex:indentLen] == ' ' && indentLen < length) {
    indentLen++;
  }
  return NSMakeRange(line.location, indentLen);
}


- (NSRange)rangeOfLineAtLineNumber:(NSUInteger)lineNumber {
  NSRange lineRange = [self rangeOfLineTerminatorAtLineNumber:lineNumber];
  if (lineRange.location == NSNotFound)
    return lineRange;

  // find previous line end
  NSUInteger startLocation = 0;
  if (lineNumber == 1) {
    lineRange.length += lineRange.location;
    lineRange.location = 0;
  } else {  // lineNumber > 1
    NSRange prevLineRange = [self rangeOfLineTerminatorAtLineNumber:lineNumber-1];
    NSUInteger lineEnd = lineRange.location + lineRange.length;
    NSUInteger prevLineEnd = prevLineRange.location + prevLineRange.length;
    lineRange.length = lineEnd - prevLineEnd;
    lineRange.location = prevLineEnd;
  }

  return lineRange;
}


- (NSRange)lineRangeForCurrentSelection {
  NSRange selectedRange = [textView_ selectedRange];
  NSTextStorage *textStorage = textView_.textStorage;
  NSRange lineRange = [textStorage.string lineRangeForRange:selectedRange];
  return lineRange;
}


- (NSUInteger)lineNumberForLocation:(NSUInteger)location {
  HSpinLock::Scope slscope(lineToRangeSpinLock_);

  // TODO(rsms): we could be "smart" here and guess a position to start looking
  // by comparing location to current number of total characters, which would
  // give us an approximate position in lineToRangeVec_ at which to start
  // looking.

  NSUInteger lineno = 0;
  for (; lineno < lineToRangeVec_.size(); ++lineno) {
    NSRange &r = lineToRangeVec_[lineno];
    if (location < r.location + r.length)
      break;
  }

  return lineno + 1;
}

#pragma mark -
#pragma mark NSTextViewDelegate implementation

// For some reason, this is called for _each edit_ to the text view so it needs
// to be fast.
- (NSUndoManager *)undoManagerForTextView:(NSTextView *)aTextView {
  return undoManager_;
}


#pragma mark -
#pragma mark NSDocument implementation

+ (BOOL)canConcurrentlyReadDocumentsOfType:(NSString *)typeName {
  return YES;
}


// close (without asking the user)
- (void)close {
  if (browser_) {
    int index = [browser_ indexOfTabContents:self];
    // if we are associated with a browser, the browser should "have" us
    if (index != -1)
      [browser_ closeTabAtIndex:index makeHistory:YES];
  }
}

- (void)canCloseDocumentWithDelegate:(id)delegate
                 shouldCloseSelector:(SEL)shouldCloseSelector
                         contextInfo:(void *)contextInfo {
  if (self.isDirty && self.browser) {
    [self.browser selectTabAtIndex:[self.browser indexOfTabContents:self]];
  }
  [super canCloseDocumentWithDelegate:delegate
                  shouldCloseSelector:shouldCloseSelector
                          contextInfo:contextInfo];
}


- (NSString*)_changeTypeToString:(NSDocumentChangeType)changeType {
  switch (changeType) {
    case NSChangeDone: return @"NSChangeDone";
    case NSChangeUndone: return @"NSChangeUndone";
    case NSChangeCleared: return @"NSChangeCleared";
    case NSChangeRedone: return @"NSChangeRedone";
    case NSChangeReadOtherContents: return @"NSChangeReadOtherContents";
    case NSChangeAutosaved: return @"NSChangeAutosaved";
  }
  return @"?";
}


/*- (void)updateChangeCount:(NSDocumentChangeType)changeType {
  DLOG("%@ updateChangeCount:%@", self, [self _changeTypeToString:changeType]);
  [super updateChangeCount:changeType];
}*/

// private method of NSDocument which is triggered when "dirty state" changes
- (void)_updateForDocumentEdited:(BOOL)isDirty {
  self.isDirty = isDirty;
  [super _updateForDocumentEdited:isDirty];
}


#pragma mark -
#pragma mark UI actions


- (IBAction)debugDumpAttributesAtCursor:(id)sender {
  NSTextStorage *textStorage = textView_.textStorage;
  NSRange selectedRange = [textView_ selectedRange];
  NSUInteger index = selectedRange.location;
  if (index >= textStorage.length) index = textStorage.length-1;
  NSDictionary *attrs = [textStorage attributesAtIndex:index
                                        effectiveRange:&selectedRange];
  [textView_ setSelectedRange:selectedRange];
  fprintf(stderr, "ATTRS%s => %s\n",
          [NSStringFromRange(selectedRange) UTF8String],
          [[attrs description] UTF8String]);
}


- (IBAction)debugUpdateASTViewer:(id)sender {
  KASTViewerWindowController *astViewerWindowController =
      [KASTViewerWindowController sharedInstance];
  kassert(astViewerWindowController);
  KASTViewerController *astViewerController =
    astViewerWindowController.outlineViewController;
  kassert(astViewerController);
  astViewerController.representedDocument = self;
}


- (IBAction)selectNextElement:(id)sender {
/*  NSMutableAttributedString *mastr = textView_.textStorage;
  NSString *text = mastr.string;
  NSCharacterSet *cs = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  NSRange selectedRange = [textView_ selectedRange];
  NSRange range = selectedRange;
  NSUInteger index = range.location + range.length;

  while (YES) {
    NSUInteger maxLength = mastr.length;
    [mastr attribute:KStyleElementAttributeName
             atIndex:index
longestEffectiveRange:&range
             inRange:NSMakeRange(0, maxLength)];

    // trim left
    NSRange r = [text rangeOfCharactersFromSet:cs
                                       options:NSAnchoredSearch
                                         range:range];
    if (r.location == range.location) {
      if (r.length == range.length) {
        // all characters where SP|TAB|CR|LF
        index = range.location + range.length;
        continue;
      }
      range.location += r.length;
      range.length -= r.length;
    }

    // trim right
    r = [text rangeOfCharactersFromSet:cs
                               options:NSAnchoredSearch|NSBackwardsSearch
                                 range:range];
    if (r.location != NSNotFound) {
      NSUInteger end = r.location + r.length;
      if (end == range.location + range.length) {
        if (range.location == selectedRange.location &&
            (range.length - r.length) == selectedRange.length) {
          index = range.location + range.length;
          continue;
        } else {
          range.length -= r.length;
        }
      }
    }
    [textView_ setSelectedRange:range];
    //[textView_ showFindIndicatorForRange:range];
    return;
  }*/
}


- (IBAction)selectPreviousElement:(id)sender {
/*  NSMutableAttributedString *mastr = textView_.textStorage;
  NSString *text = mastr.string;
  NSCharacterSet *cs = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  NSRange selectedRange = [textView_ selectedRange];
  NSRange range = selectedRange;
  NSUInteger index = range.location == 0 ? 0 : range.location-1;

  while (YES) {
    NSUInteger maxLength = mastr.length;
    [mastr attribute:KStyleElementAttributeName
             atIndex:index
longestEffectiveRange:&range
             inRange:NSMakeRange(0, maxLength)];

    // beginning of document?
    if (selectedRange.location == 0 && range.location == 0 &&
        selectedRange.length == range.length) {
      // wrap around
      index = text.length-1;
      continue;
    }

    // trim left
    NSRange L = [text rangeOfCharactersFromSet:cs
                                       options:NSAnchoredSearch
                                         range:range];
    if (L.location == range.location) {
      if (L.length == range.length) {
        // all characters where SP|TAB|CR|LF
        index = range.location - 1;
        continue;
      }
      range.location += L.length;
      range.length -= L.length;
      if (range.location == selectedRange.location &&
          range.length == selectedRange.length) {
        index = range.location - (1 + L.length);
        continue;
      }
    }

    // trim right
    NSRange R = [text rangeOfCharactersFromSet:cs
                                       options:NSAnchoredSearch
                                              |NSBackwardsSearch
                                         range:range];
    if (R.location != NSNotFound) {
      NSUInteger end = R.location + R.length;
      if (end == range.location + range.length) {
        if (range.location == selectedRange.location &&
            (range.length - R.length) == selectedRange.length) {
          // this will never happen, right?
          index = range.location - (1 + L.length);
          continue;
        } else {
          range.length -= R.length;
        }
      }
    }

    [textView_ setSelectedRange:range];
    //[textView_ showFindIndicatorForRange:range];
    return;
  }*/
}


- (IBAction)toggleMetaRuler:(id)sender {
  self.hasMetaRuler = !self.hasMetaRuler;
}


- (IBAction)setSyntaxMode:(id)sender {
  DLOG("TODO: setSyntaxMode:%@", [sender representedObject]);
}


#pragma mark -
#pragma mark Style
// TODO(rsms): Most of these things should probably move to the KTextView and
// its components.


- (NSDictionary*)defaultTextAttributes {
  NSDictionary *attrs;
  KStyle *style = [KStyle sharedStyle];
  kassert(style);
  KStyleElement *styleElement = [style defaultStyleElement];
  kassert(styleElement);
  attrs = styleElement->textAttributes();
  return attrs;
}


- (void)refreshStyle {
  //DLOG("refreshStyle");
  KStyle *style = [KStyle sharedStyle];
  kassert(style);

  // text attributes
  NSTextStorage *textStorage = textView_.textStorage;
  [textStorage beginEditing];
  [textStorage setAttributesFromKStyle:style
                                 range:NSMakeRange(0, textStorage.length)];
  [textStorage endEditing];

  // find parent scroll view and mark it for redraw
  /*NSScrollView *scrollView =
      (NSScrollView*)[textView_ findFirstParentViewOfKind:[NSScrollView class]];
  if (scrollView)
    [scrollView setNeedsDisplay:YES];*/

  // mark everything in this window as needing redisplay (style is window-wide)
  NSWindow *window = textView_.window;
  if (window) {
    [window setViewsNeedDisplay:YES];
  }
}


#pragma mark -
#pragma mark Tracking line count


// Edits arrive in singles. This method is only called for used edits, not
// programmatical changes.
/*- (BOOL)textView:(NSTextView *)textView
shouldChangeTextInRange:(NSRange)range
replacementString:(NSString *)replacementString {
  #if 0
  DLOG("replace text '%@' at %@ with '%@'",
       [textView_.textStorage.string substringWithRange:range],
       NSStringFromRange(range), replacementString);
  #endif

  BOOL didEditCharacters = YES;

  // find range of highlighting state at edit location
  NSTextStorage *textStorage = textView_.textStorage;
  if (textStorage.length != 0) {
    NSUInteger index;
    if (replacementString.length == 0) {
      didEditCharacters = YES;
      // deletion
      if (textStorage.length == 1) {
        index = NSNotFound;
      } else {
        index = MIN(range.location+1, textStorage.length-1);
      }
    } else {
      didEditCharacters = ![replacementString isEqualToString:
                            [textStorage.string substringWithRange:range]];
      // insertion/replacement
      index = MIN(range.location, textStorage.length-1);
    }
  } else { // if (textStorage.length == 0)
    didEditCharacters = (replacementString.length != 0);
  }

  return YES;
}*/


/*!
 * startIndex: first line range within |editedRange|
 * endIndex: first line range after startIndex which is NOT within |editedRange|
 *
 * Last line range within |editedRange| is (endIndex -1)
 */
static BOOL _lb_lines_in_editedRange(std::vector<NSRange> &lineToRangeVec,
                                     NSRange &editedRange,
                                     size_t &startIndex, size_t &endIndex) {
  NSUInteger editedRangeEndLocation = editedRange.location + editedRange.length;
  size_t i = 0, count = lineToRangeVec.size();
  startIndex = count;
  endIndex = 0;
  for (; i < count; ++i) {
    NSRange &lineRange = lineToRangeVec[i];
    NSUInteger lineRangeEnd = lineRange.location + lineRange.length;

    if (startIndex == count) {
      // looking for start
      if (lineRangeEnd > editedRange.location) {
        // this line is the first one within the edited scope
        startIndex = i;
      }
    } else {
      // looking for end
      if (lineRangeEnd > editedRangeEndLocation) {
        // we have passed the end (previous line was the last affected one)
        break;
      }
      endIndex = i;
    }
  }

  if (startIndex != count) {
    if (startIndex > endIndex) {
      // we did not find an end, which means the edit extends to the end of the
      // document
      endIndex = count;
    } else {
      ++endIndex;
    }
    return YES;
  } else {
    return NO;
  }
}


static void _lb_offset_ranges(std::vector<NSRange> &lineToRangeVec,
                              size_t startIndex, NSUInteger offset) {
  // add range offset to lines which goes after the affected line
  size_t count = lineToRangeVec.size();
  for (; startIndex < count; ++startIndex) {
    NSRange &r = lineToRangeVec[startIndex];
    r.location += offset;
  }
}


- (void)_updateLinesToRangesInfoForTextStorage:(NSTextStorage*)textStorage
                                       inRange:(NSRange)editedRange
                                   changeDelta:(NSInteger)changeInLength
                                      recursed:(BOOL)recursed {

  // Note: We can't use a HSpinLock::Scope here since we need to release the
  // lock before we call linesDidChangeWithLineCountDelta: at the end
  lineToRangeSpinLock_.lock();


  // update linebreaks mapping
  NSString *string = textStorage.string;

  NSCharacterSet *newlines = [NSCharacterSet newlineCharacterSet];
  BOOL editSpansToEndOfDocument =
      (editedRange.location + editedRange.length == string.length);
  size_t lbStartIndex = 0, lbEndIndex = 0, offsetRangesStart = 0;
  BOOL didAffectLines = NO;
  __block NSInteger lineCountDelta = 0;
  if (changeInLength != 0) {
    // any edit causes line offsets after the edit to be offset
    // first, find affected lines (last part performed by _lb_offset_ranges)
    //if (!editSpansToEndOfDocument || changeInLength < 0) {
    didAffectLines = _lb_lines_in_editedRange(lineToRangeVec_, editedRange,
                                              lbStartIndex, lbEndIndex);
    offsetRangesStart = lbStartIndex;
    #if 0
    DLOG("didAffectLines: %@, lbStartIndex: %zu, lbEndIndex: %zu, "
         "editSpansToEndOfDocument: %@",
         didAffectLines?@"YES":@"NO", lbStartIndex, lbEndIndex,
         editSpansToEndOfDocument?@"YES":@"NO");
    #endif
  }

  if (changeInLength == 1 && editedRange.length == 1) {
    // simple use-case: inserted a single character at the end of a line
    unichar ch = [string characterAtIndex:editedRange.location];
    if ([newlines characterIsMember:ch]) {
      //DLOG("linebreak: inserted one explicitly");
      NSUInteger lineStart, lineEnd, contentsEnd;
      [string getLineStart:&lineStart
                       end:&lineEnd
               contentsEnd:&contentsEnd
                  forRange:editedRange];
      NSRange lineRange = NSMakeRange(contentsEnd, lineEnd - contentsEnd);
      //DLOG_RANGE(lineRange, string);

      if (editSpansToEndOfDocument || !didAffectLines) {
        // simply appended a new line to the end of the document
        lineToRangeVec_.push_back(lineRange);
      } else {
        // inserted a new line in the middle of the document
        // insert causes all lines after |lbStartIndex| to be shifted right
        lineToRangeVec_.insert(lineToRangeVec_.begin() + lbStartIndex,
                               lineRange);
      }
      // don't offset the range of the line we just registered
      ++offsetRangesStart;
      ++lineCountDelta;
    } else if (editSpansToEndOfDocument) {
      // inserted a non-linebreak char at end of document -- noop
      lineToRangeSpinLock_.unlock();
      return;
    }

  } else if (changeInLength > 0) {
    // reset |i|
    __block size_t i = lbStartIndex;

    // consider each line which was affected by the edit
    [string enumerateSubstringsInRange:editedRange
                               options:NSStringEnumerationByLines
                                      |NSStringEnumerationSubstringNotRequired
                            usingBlock:^(NSString *substring,  // nil, unused
                                         NSRange substringRange,
                                         NSRange enclosingRange,
                                         BOOL *stop) {
      // number of characters constituting the linebreak (0 means no line end,
      // 1 might mean LF or CR while 2 probably means CRLF). However, valid
      // newline chars are: U+000A–U+000D, U+0085
      NSUInteger nlCharCount = enclosingRange.length - substringRange.length;
      //DLOG("nlCharCount -> %lu", nlCharCount);
      //DLOG_RANGE(substringRange, string);
      //DLOG_RANGE(enclosingRange, string);

      if (!nlCharCount) {
        // most likely the last line (no newline anyhow, so "continue")
        return;
      }

      // register range
      if (i < lbEndIndex) {
        NSRange &r = lineToRangeVec_[i];
        r.location = substringRange.location + substringRange.length;
        r.length = nlCharCount;
      } else {
        NSRange r = NSMakeRange(substringRange.location + substringRange.length,
                                nlCharCount);
        lineToRangeVec_.insert(lineToRangeVec_.begin() + i, r);
        ++lineCountDelta;
      }
      ++i;
    }];

    offsetRangesStart = i;

  } else if (changeInLength < 0) {
    // edit action was "deletion"

    if (didAffectLines) {
      NSRange deletedRange = editedRange;
      deletedRange.length = -changeInLength;
      //DLOG("deletedRange -> %@", NSStringFromRange(deletedRange));

      // figure out if any lines where deleted
      size_t i = lbStartIndex;
      BOOL didFoundOneInside = NO;
      for (; i < lbEndIndex && i < lineToRangeVec_.size(); ) {
        NSRange &lineRange = lineToRangeVec_[i];

        if ( NSLocationInRange(lineRange.location, deletedRange) ||
             (lineRange.length > 1 &&
              NSLocationInRange(lineRange.location+lineRange.length-1,
                                deletedRange)) ) {
          //DLOG("[%lu] %@ was inside delete", i, NSStringFromRange(lineRange));
          lineToRangeVec_.erase(lineToRangeVec_.begin() + i);
          --lineCountDelta;
          didFoundOneInside = YES;
        } else if (didFoundOneInside) {
          // in this case we have passed all removed lines
          break;
        } else {
          ++i;
        }
      }
    }
  }

  // offset affected ranges
  if (didAffectLines) {
    //DLOG("_lb_offset_ranges(%lu, %ld)", offsetRangesStart, changeInLength);
    _lb_offset_ranges(lineToRangeVec_, offsetRangesStart, changeInLength);
  }

  // release the spin lock before calling linesDidChangeWithLineCountDelta:
  // which in turn might call a function using lineToRangeVec_ which would
  // otherwise cause a deadlock.
  lineToRangeSpinLock_.unlock();

  if (changeInLength != 0 &&
      (lineToRangeVec_.size() != 0 || lineCountDelta != 0)) {
    [self linesDidChangeWithLineCountDelta:lineCountDelta];
  }

  // TODO(swizec): this section might be a hack, perhaps there is a more
  // efficient way of solving this problem.

  // performing recursion like this solves problems with line numbering
  if (changeInLength < 1 && recursed == NO) {
    // this happens when we're replacing text with less text
    // the idea is that the first time 'round we took care of vanishing text
    // and on the second go we take care of the newly added text
    [self _updateLinesToRangesInfoForTextStorage:textStorage
                                         inRange:editedRange
                                     changeDelta:editedRange.length
                                        recursed:YES];
  } else if (editedRange.length > 1 && recursed == NO) {
    // this happens when we insert text into the document
    // the idea is that the first time 'round we took care of the inserted text
    // now we have to treat all text from here to the end of the document as new
    // text otherwise the last x lines don't get numbered
    NSRange newEditedRange =
        NSMakeRange(editedRange.location + editedRange.length,
                    textStorage.string.length -
                    (editedRange.location + editedRange.length));
    [self _updateLinesToRangesInfoForTextStorage:textStorage
                                         inRange:newEditedRange
                                     changeDelta:newEditedRange.length
                                        recursed:YES];
  }
}


#pragma mark -
#pragma mark Responding to text edits



// invoked after an editing occured, but before it's been committed
// Has the nasty side effect of losing the selection if applying attributes
- (void)textStorageWillProcessEditing:(NSNotification *)notification {
  NSTextStorage *textStorage = [notification object];

  if (!(textStorage.editedMask & NSTextStorageEditedCharacters))
    return;

  // Record change properties
  krusage_begin(rusage, "Retrieve changes from text storage");
  NSRange editedRange = [textStorage editedRange];
  NSInteger changeDelta = [textStorage changeInLength];

  ast_->parseEdit(editedRange.location, changeDelta);
  //ast_->parse();

  // enqeue edit to be handled by the text parser system
  //KNodeEnqueueParseEntry(new KNodeParseEntry(editedRange.location,
  //                                           changeDelta, self));
}


// invoked after an editing occured which has just been committed
- (void)textStorageDidProcessEditing:(NSNotification *)notification {
  // Note: this might be called on different threads

  NSTextStorage *textStorage = [notification object];

  // no-op unless characters where edited
  if (!(textStorage.editedMask & NSTextStorageEditedCharacters)) {
    return;
  }

  // Increment our version
  [self willChangeValueForKey:@"version"];
  uint64_t version = h_atomic_inc(&version_);
  [self didChangeValueForKey:@"version"];

  // range that was affected by the edit
  NSRange editedRange = [textStorage editedRange];

  // length delta of the edit (i.e. negative for deletions)
  int changeInLength = [textStorage changeInLength];

  // update lineToRangeVec_ (need to run in main)
  if ([NSThread isMainThread]) {
    [self _updateLinesToRangesInfoForTextStorage:textStorage
                                         inRange:editedRange
                                     changeDelta:changeInLength
                                        recursed:NO];
  } else {
    K_DISPATCH_MAIN_ASYNC({
      [self _updateLinesToRangesInfoForTextStorage:textStorage
                                           inRange:editedRange
                                       changeDelta:changeInLength
                                          recursed:NO];
    });
  }

  // emit event in node-land
  KNodePerformInNode(^(KNodeReturnBlock returnCallback){
    v8::HandleScope scope;
    v8::Local<v8::Object> doc = [self v8Value]->ToObject();
    // TODO: refactor this to be reusable for emitting events on any object
    v8::Local<v8::Value> emitV = doc->Get(v8::String::New("emit"));
    if (!emitV.IsEmpty() && emitV->IsFunction()) {
      v8::Local<v8::Value> argv[] = {
        v8::String::New("edit"),
        v8::Number::New((double)version),
        v8::Number::New((double)editedRange.location),
        v8::Integer::New(changeInLength)
      };
      static const int argc = sizeof(argv) / sizeof(argv[0]);
      v8::TryCatch tryCatch;
      v8::Local<v8::Value> returnValue =
          v8::Local<v8::Function>::Cast(emitV)->Call(doc, argc, argv);
      NSError *error = nil;
      if (tryCatch.HasCaught()) {
        v8::String::Utf8Value trace(tryCatch.StackTrace());
        NSAutoreleasePool *pool1 = [NSAutoreleasePool new];
        WLOG("Error while emitting event '%s' on %@: %s", "edit", self,
             *trace ? *trace : "(no trace)");
        [pool1 drain];
      }
    }
    // must be called since this takes care of releasing some resources
    returnCallback(nil, nil, nil);
  });

  // we do not process edits when we are loading
  if (isLoading_) return;

  BOOL wasInUndoRedo = [[self undoManager] isUndoing] ||
                       [[self undoManager] isRedoing];
  #if 0 && K_DEBUG_BUILD
  DLOG_RANGE(editedRange, textStorage.string);
  #endif

  DLOG("editedRange: %@, changeInLength: %d, wasInUndoRedo: %@, editedMask: %d",
       NSStringFromRange(editedRange), changeInLength,
       wasInUndoRedo ? @"YES":@"NO", textStorage.editedMask);

  #if 0
  NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
  NSArray *args = [NSArray arrayWithObject:textStorage.string];
  KNodeInvokeExposedJSFunction("silentPing", args, ^(NSError *err, NSArray *args){
    NSTimeInterval endTime = [NSDate timeIntervalSinceReferenceDate];
    /*DLOG("[node] call returned to kod (error: %@, args: %@) "
         "real time spent: %.2f ms",
         err, args, (endTime - startTime)*1000.0);*/
    fprintf(stderr, "real: %.4f ms\n", (endTime - startTime)*1000.0);
  });
  #endif

  // this makes the edit an undoable entry
  // TODO(rsms): Make this configurable through kconf "editor/undo/granularity"
  //[textView_ breakUndoCoalescing];
}


#pragma mark -
#pragma mark Loading contents


// High-level load method which is used both for reloading, replacing and
// creating documents.
- (BOOL)readFromURL:(NSURL *)absoluteURL
             ofType:(NSString *)typeName
              error:(NSError **)outError {
  // May be called on a background thread
  DLOG("readFromURL:%@ ofType:%@", absoluteURL, typeName);

  // we are in a loading state
  self.isLoading = YES;

  // reset encoding (so it can be set by the loading machinery)
  textEncoding_ = 0;

  // set url
  self.fileURL = absoluteURL;

  // locate handler
  KURLHandler *urlHandler =
      [[KDocumentController kodController] urlHandlerForURL:absoluteURL];
  if (!urlHandler) {
    if (outError) {
      *outError = [NSError kodErrorWithFormat:@"Unsupported URI scheme '%@'",
                   absoluteURL.scheme];
    }
    return NO;
  }

  // check if the handler can read URLs
  if (![urlHandler canReadURL:absoluteURL]) {
    if (outError) {
      *outError = [NSError kodErrorWithFormat:@"Unknown URI '%@'", absoluteURL];
    }
    return NO;
  }

  // trigger reading
  [urlHandler readURL:absoluteURL ofType:typeName inTab:self];
  return YES;

  // different branches depending on local file or remote
  /*if (![absoluteURL isFileURL]) {
    [self startReadingFromRemoteURL:absoluteURL ofType:typeName];
    return YES;
  }*/
}


- (void)urlHandler:(KURLHandler*)urlHandler
finishedReadingURL:(NSURL*)url
              data:(NSData*)data
            ofType:(NSString*)typeName
             error:(NSError*)error
          callback:(void(^)(NSError*))callback {
  // check data
  if (!data) {
    error = [NSError kodErrorWithFormat:@"%@ failed to read '%@': %@",
             urlHandler, url, [error localizedDescription]];
  }

  // handle error
  if (error) {
    [self presentError:error];
    return;
  }

  // intermediate success callback
  dispatch_block_t successCallback = nil;
  if (callback) {
    successCallback = ^{
      callback(nil);
    };
  }

  // invoke internal data loader
  NSError *outError = nil;
  if (![self readFromData:data
                   ofType:typeName
                    error:&outError
                 callback:successCallback]) {
    if (!outError) {
      outError = [NSError kodErrorWithFormat:
                  @"Unknown error while loading data provided by %@",
                  urlHandler];
    }
    [self presentError:outError];
    if (callback)
      callback(outError);
  }
}





// Sets the contents of this document by reading from a file wrapper of a
// specified type (e.g. a directory).
- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper
                     ofType:(NSString *)typeName
                      error:(NSError **)outError {
  /*if (![fileWrapper isDirectory]) {
    return [super readFromFileWrapper:fileWrapper
                               ofType:typeName
                                error:outError];
  }
  DLOG("TODO: readFromFileWrapper:%@ ofType:%@ error:*", fileWrapper, typeName);*/
  if (outError) {
    *outError = [NSError kodErrorWithDescription:
                 @"Unable to handle reading of NSFIleWrapper"];
  }
  return NO;
}


// Generate text from data
- (BOOL)readFromData:(NSData *)data
              ofType:(NSString *)typeName
               error:(NSError **)outError
            callback:(void(^)(void))callback {
  DLOG("readFromData:%p ofType:%@", data, typeName);

  NSString *text = nil;

  // If we have an explicit encoding, try decoding using that encoding
  if (textEncoding_ != 0)
    text = [data weakStringWithEncoding:textEncoding_];

  // Guess encoding if no explicit encoding, or explicit decode failed
  if (!text)
    text = [data weakStringByGuessingEncoding:&textEncoding_];

  if (!text) {
    // We're out of hope
    textEncoding_ = 0;
    WLOG("Failed to parse data. text => nil (data length: %u)", [data length]);
    if (outError)
      *outError = [NSError kodErrorWithDescription:@"Failed to parse file"];
    return NO;
  } else {
    // Yay, we decoded the damn text
    // Now, we want to join on main since we're hitting weird NSRunLoop-related
    // bugs when doing this in the background. E.g:
    //
    // "In '__CFRunLoopSourceLock', file
    //  /SourceCache/CF/CF-550.42/RunLoop.subproj/CFRunLoop.c, line 614, during
    //  lock, spin lock 0x117619df4 has value 0x1763abf0, which is neither
    //  locked nor unlocked.  The memory has been smashed."
    //
    // That's scary.

    // log encoding used
    DLOG("Decoded text data using %@",
         [NSString localizedNameOfStringEncoding:textEncoding_]);

    // we need to retain |data| and |text| since |text| contains a weak
    // reference to bytes in |data|.
    [data retain];
    [text retain];

    K_DISPATCH_MAIN_ASYNC2(
      //NSTextStorage *textStorage = textView_.textStorage;
      [textView_ setString:text];
      [textView_ setSelectedRange:NSMakeRange(0, 0)];
      [self updateChangeCount:NSChangeCleared];
      isDirty_ = NO;
      self.isLoading = NO;
      self.isWaitingForResponse = NO;
      self.fileType = typeName;
      [self post:KDocumentDidLoadDataNotification];
      [self emitEvent:@"load" argument:nil];
      // TODO(rsms): emit event in nodejs on our v8 wrapper object
      // TODO(rsms): guess language if no language has been set

      if (callback) callback();

      [text release];
      [data release];
    );
  }
  return YES;
}


- (BOOL)readFromData:(NSData *)data
              ofType:(NSString *)typeName
               error:(NSError **)outError {
  return [self readFromData:data
                     ofType:typeName
                      error:outError
                   callback:nil];
}


#pragma mark -
#pragma mark Saving contents


// Returns true to indicate a saveDocument: message is allowed, saving the
// document to it's current URL
- (BOOL)canSaveDocument {
  NSURL *url = self.fileURL;
  KURLHandler *urlHandler =
      [[KDocumentController kodController] urlHandlerForURL:url];
  return ( (urlHandler && [urlHandler canWriteURL:url]) || !url );
}


// Generate data from text
- (NSData*)dataOfType:(NSString*)typeName error:(NSError **)outError {
  [textView_ breakUndoCoalescing]; // preserves undo state
  NSData *data = [[textView_ string] dataUsingEncoding:textEncoding_
                                  allowLossyConversion:NO];
  if (!data) {
    *outError = [NSError kodErrorWithFormat:
        @"Unable to encode text using encoding '%@'",
        [NSString localizedNameOfStringEncoding:textEncoding_]];
  }
  return data;
}


- (BOOL)saveToURL:(NSURL*)absoluteURL
           ofType:(NSString*)typeName
 forSaveOperation:(NSSaveOperationType)saveOperation
            error:(NSError**)outError {

  // Find a handler
  // Note: When this method gets called, canSaveDocument should have been called
  // already, thus we should always find a usable url handler.
  KURLHandler *urlHandler =
      [[KDocumentController kodController] urlHandlerForURL:absoluteURL];
  if (!urlHandler || ![urlHandler canWriteURL:absoluteURL]) {
    if (outError) {
      *outError = [NSError kodErrorWithFormat:
                   @"Unable to save file to '%@' (%@ does not support writing)",
                   absoluteURL, urlHandler];
    }
    return NO;
  }

  // make data
  NSData *data = [self dataOfType:typeName
                            error:outError];
  if (!data)
    return NO;

  // freeze tab during writing
  BOOL tabWasEditable = self.isEditable;
  if (tabWasEditable)
    self.isEditable = NO;
  self.isLoading = YES;

  // delegate writing to the handler
  NSURL *originalURL = self.fileURL;
  [urlHandler writeData:data
                 ofType:typeName
                  toURL:absoluteURL
                  inTab:self
       forSaveOperation:saveOperation
            originalURL:originalURL
               callback:^(NSError *err, NSDate *mtime){
    // Error?
    if (err) {
      [self presentError:err];
    } else if (saveOperation != NSSaveToOperation) {
      // "Save to" means "saving a copy to another location without changing the
      // location of the current document", so we do not update our properties in
      // that case.

      // set fileURL (needed for the internal resource tracking logic of
      // NSDocument)
      [self setFileURL:absoluteURL];

      // Clear change count
      [self updateChangeCount:NSChangeCleared];

      // update modification date -- needed for NSDocument's interal "did someone
      // else change our document?" logic.
      self.fileModificationDate = mtime ? mtime : [NSDate date];

      // If we wrote the stylesheet, trigger a reload or load
      if (originalURL && [originalURL isEqual:[KStyle sharedStyle].url]) {
        [[KStyle sharedStyle] loadFromURL:absoluteURL withCallback:nil];
      }

      // Turn typeName back into UTI (e.g. php -> public.php-script)
      NSString *uti = nil;
      [absoluteURL getResourceValue:&uti
                             forKey:NSURLTypeIdentifierKey
                              error:nil];
      self.type = uti;

      // TODO(rsms): guess syntax/language
    }

    // unfreeze tab
    if (tabWasEditable)
      self.isEditable = YES;
    self.isLoading = NO;

    K_DISPATCH_MAIN_ASYNC({
      // restart cursor blink timer. This fails to restart when writing a file
      // asynchronously (my guess is the setEditable call fail to trigger the
      // animation restart)
      [self.textView updateInsertionPointStateAndRestartTimer:YES];
    });
  }];

  return YES;
}


#pragma mark -
#pragma mark CTTabContents implementation


-(void)viewFrameDidChange:(NSRect)newFrame {
  // We need to recalculate the frame of the NSTextView when the frame changes.
  // This happens when a tab is created and when it's moved between windows.
  //NSLog(@"viewFrameDidChange:%@", NSStringFromRect(newFrame));
  [super viewFrameDidChange:newFrame];
  NSClipView* clipView = [[view_ subviews] objectAtIndex:0];
  NSTextView* tv = [[clipView subviews] objectAtIndex:0];
  NSRect frame = NSZeroRect;
  frame.size = [(NSScrollView*)(view_) contentSize];
  [tv setFrame:frame];
  DLOG("textView frame -> %@", NSStringFromRect(frame));
}


#pragma mark -
#pragma mark NSObject etc


- (NSString*)description {
  return [NSString stringWithFormat:@"<%@@%p '%@'>",
      NSStringFromClass([self class]), self, self.title];
}


@end

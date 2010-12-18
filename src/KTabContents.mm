#include <sys/xattr.h>

#import "common.h"

#import "kconf.h"
#import "KTabContents.h"
#import "KBrowser.h"
#import "KBrowserWindowController.h"
#import "KSourceHighlighter.h"
#import "KStyle.h"
#import "KScroller.h"
#import "KScrollView.h"
#import "KLangMap.h"
#import "KTextView.h"
#import "KStatusBarView.h"
#import "KMetaRulerView.h"
#import "HEventEmitter.h"


// used in stateFlags_
enum {
  kCompleteHighlightingIsQueued = HATOMIC_FLAG_MIN,
  kCompleteHighlightingIsProcessing,
  kHighlightingIsProcessing,
  kTestStorageEditingIsProcessing,
};

// used by lastEditChangedTextStatus_
static const uint8_t kEditChangeStatusUnknown = 0;
static const uint8_t kEditChangeStatusUserUnalteredText = 1;
static const uint8_t kEditChangeStatusUserAlteredText = 2;


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


@interface KTabContents (Private)
- (void)undoManagerCheckpoint:(NSNotification*)notification;
@end

@implementation KTabContents

@synthesize isDirty = isDirty_,
            textEncoding = textEncoding_,
            textView = textView_;

static NSImage* _kDefaultIcon = nil;
static NSString* _kDefaultTitle = @"Untitled";

+ (void)load {
  NSAutoreleasePool* pool = [NSAutoreleasePool new];
  _kDefaultIcon =
      [[[NSWorkspace sharedWorkspace] iconForFile:@"/dev/null"] retain];
  [pool drain];
}

static NSFont* _kDefaultFont = nil;

+ (NSFont*)defaultFont {
  if (!_kDefaultFont) {
    _kDefaultFont = [[NSFont fontWithName:@"M+ 1m light" size:11.0] retain];
    if (!_kDefaultFont) {
      WLOG("unable to find default font \"M+\" -- using system default");
      _kDefaultFont = [[NSFont userFixedPitchFontOfSize:11.0] retain];
    }
  }
  return _kDefaultFont;
}

// DEBUG: intercepts and dumps selector queries
/*- (BOOL)respondsToSelector:(SEL)selector {
	BOOL y = [super respondsToSelector:selector];
  DLOG("respondsToSelector %@ -> %@", NSStringFromSelector(selector), y?@"YES":@"NO");
  return y;
}*/


// XXX DEBUG
static int debugSimulateTextAppendingIteration = 0;
- (void)debugSimulateTextAppending:(id)x {
  #if 0
  [textView_ insertText:@"void foo(int arg) {\n  return 5;\n}\n"
                        @"/* multi\nline\ncomment */ bool bar;\n"
                        @"string s = \"this is a \\\"string\\\" yes\";\n"];
  return;
  #endif
  switch (debugSimulateTextAppendingIteration) {
    case 0:
      [textView_ insertText:@"void foo(int arg) {\n  return 5;\n}\n"];
      break;
    case 1:
      [textView_ insertText:@"/* multi\nline"];
      break;
    case 2:
      [textView_ insertText:@"\ncomment */ bool bar;\n"];
      break;
    case 3:
      [textView_ insertText:@"string s = \"this is a \\\"string\\\" yes\";\n"];
      break;
  }
  if (++debugSimulateTextAppendingIteration < 4) {
    [self performSelector:@selector(debugSimulateTextAppending:)
               withObject:self
               afterDelay:0.1];
  } else {
    [self performSelector:@selector(debugSimulateSwitchStyle:)
               withObject:self
               afterDelay:2.0];
  }
}


// This is the main initialization method
- (id)initWithBaseTabContents:(CTTabContents*)baseContents {
  // Note: This might be called from a background thread and must thus be
  // thread-safe.
  if (!(self = [super init])) return nil;
  NSZone *zone = [self zone];

  // Default title and icon
  self.title = _kDefaultTitle;
  self.icon = _kDefaultIcon;
  
  // Default text encoding for new "Untitled" documents
  textEncoding_ = NSUTF8StringEncoding;
  
  // Default highlighter
  sourceHighlighter_.reset(new KSourceHighlighter);
  highlightingEnabled_ = YES;

  // Save a weak reference to the undo manager (performance reasons)
  undoManager_ = [self undoManager]; assert(undoManager_);

  // Create a KTextView
  textView_ = [[KTextView allocWithZone:zone] initWithFrame:NSZeroRect];
  [textView_ setDelegate:self];
  [textView_ setFont:[isa defaultFont]];
  
  // configure layout manager
  //NSLayoutManager *layoutManager = []
  
  // default paragraph style
  NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
  [paragraphStyle setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
  [paragraphStyle setLineBreakMode:NSLineBreakByCharWrapping];
  [paragraphStyle setDefaultTabInterval:2];
  [textView_ setDefaultParagraphStyle:paragraphStyle];
  //NSParagraphStyleAttributeName
  
  // TODO: this defines the attributes to apply to "marked" text, input which is
  // pending, like "¨" waiting for "u" to build the character "ü". Should match
  // the current style.
  //[textView_ setMarkedTextAttributes:[NSDictionary dictionaryWithObject:[NSColor redColor] forKey:NSBackgroundColorAttributeName]];

  // Create a NSScrollView to which we add the NSTextView
  KScrollView *sv = [[KScrollView alloc] initWithFrame:NSZeroRect];
  [sv setDocumentView:textView_];

  // Set the NSScrollView as our view
  view_ = sv;
  
  // Configure meta ruler (line numbers)
  self.hasMetaRuler = !kconf_bool(@"editor/metaRuler/hidden", NO);
  
  // Start with the empty style and load the default style
  kassert([KStyle sharedStyle] != nil);
  [self observe:KStyleDidChangeNotification
         source:[KStyle sharedStyle]
        handler:@selector(styleDidChange:)];
  [self styleDidChange:nil]; // trigger initial
  
  // debug xxx
  /*[self retain];
  h_dispatch_delayed_main(10000, ^{
    DLOG("loading new style after 10s");
    NSURL* url = kconf_res_url(@"style/bright.css");
    [KStyle styleAtURL:url withCallback:^(NSError *err, KStyle *style) {
      if (err) [NSApp presentError:err];
      else self.style = style;
    }];
    [self release];
  });*/

  // Let the global document controller know we came to life
  [[NSDocumentController sharedDocumentController] addDocument:self];
  
  // Observe when the document is modified so we can update the UI accordingly
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self
         selector:@selector(undoManagerCheckpoint:)
             name:NSUndoManagerCheckpointNotification
					 object:undoManager_];

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
  KStyle *style = [KStyle sharedStyle];
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc removeObserver:self
                name:KStyleDidChangeNotification
              object:style];
  //delete highlightSem_; highlightSem_ = NULL;
  //delete highlightQueueSem_; highlightQueueSem_ = NULL;
  [super dealloc];
}


#pragma mark -
#pragma mark Properties


- (BOOL)highlightingEnabled {
  return highlightingEnabled_;
}

- (void)setHighlightingEnabled:(BOOL)enabled {
  if (highlightingEnabled_ != enabled) {
    highlightingEnabled_ = enabled;
    // IDEA: here we could optimize the case where the user has highlighting
    // turned on, thus contents are highlighted, then turns highlighting off,
    // does not make any edits and the turns it back on again. We only need to
    // re-apply the style in this case, not re-parse everything.
    if (highlightingEnabled_) {
      [self setNeedsHighlightingOfCompleteDocument];
    } else {
      [self clearHighlighting];
    }
  }
}


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


- (NSString*)langId {
  return langId_;
}

- (void)setLangId:(NSString*)langId {
  if (langId_ != langId) {
    langId_ = [langId retain];
    DLOG("%@ changed langId to '%@'", self, langId_);
    // TODO: langId should be a UTI in the future
    self.fileType = langId;
    sourceHighlighter_->setLanguage(langId_);
    [self setNeedsHighlightingOfCompleteDocument];
  }
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
  } else {
    y = [super validateUserInterfaceItem:item];
  }
  return y;
}


- (void)tabWillCloseInBrowser:(CTBrowser*)browser atIndex:(NSInteger)index {
  [super tabWillCloseInBrowser:browser atIndex:index];
  
  // cancel and disable highlighting
  highlightingEnabled_ = NO;
  sourceHighlighter_->cancel();
  
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
}


- (void)tabDidResignSelected {
  [super tabDidResignSelected];
  if (browser_) {
    NSWindowController *wc = browser_.windowController;
    if (wc) {
      [self removeWindowController:wc];
      [self setWindow:nil];
    }
  }
}


-(void)tabDidBecomeVisible {
  [super tabDidBecomeVisible];
  [self highlightCompleteDocumentInBackgroundIfQueued];
}


//- (void)undoManagerChangeDone:(NSNotification *)notification;
//- (void)undoManagerChangeUndone:(NSNotification *)notification;


- (void)undoManagerCheckpoint:(NSNotification*)notification {
  //DLOG_EXPR([self isDocumentEdited]);
  BOOL isDirty = [self isDocumentEdited];
  if (isDirty_ != isDirty) {
    isDirty_ = isDirty;
    [self documentDidChangeDirtyState];
  }
}


- (void)documentDidChangeDirtyState {
  DLOG("documentDidChangeDirtyState");
  // windowController - (void)setDocumentEdited:(BOOL)dirtyFlag;
  //self.title = @"*";
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


#pragma mark -
#pragma mark Line info


- (NSUInteger)charCountOfLastLine {
  NSUInteger remainingCharCount = textView_.textStorage.length;
  if (!lineToRangeVec_.empty()) {
    NSRange &r = lineToRangeVec_.back();
    remainingCharCount -= r.location + r.length;
  }
  return remainingCharCount;
}


- (NSUInteger)lineCount {
  return lineToRangeVec_.size() + 1;
}


- (NSRange)rangeOfLineTerminatorAtLineNumber:(NSUInteger)lineNumber {
  kassert(lineNumber > 0); // 1-based
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
    // there are no line breaks (just the "last line")
    return NSMakeRange(0, textView_.textStorage.length);
  }
}


- (NSRange)rangeOfLineAtLineNumber:(NSUInteger)lineNumber {
  NSRange lineRange = [self rangeOfLineTerminatorAtLineNumber:lineNumber];
  
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


- (NSUInteger)lineNumberForLocation:(NSUInteger)location {
  kassert([NSThread isMainThread]); // since lineToRangeVec_ is not thread safe

  // TODO: we could be "smart" here and guess a position to start looking by
  // comparing location to current number of total characters, which would give
  // us an approximate position in lineToRangeVec_ at which to start looking.

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


#if _DEBUG
/*- (void)canCloseDocumentWithDelegate:(id)delegate shouldCloseSelector:(SEL)shouldCloseSelector contextInfo:(void *)contextInfo {
  DLOG_TRACE();
  Debugger();
  [super canCloseDocumentWithDelegate:delegate shouldCloseSelector:shouldCloseSelector contextInfo:contextInfo];
}*/
#endif // _DEBUG


// close (without asking the user)
- (void)close {
  if (browser_) {
    int index = [browser_ indexOfTabContents:self];
    // if we are associated with a browser, the browser should "have" us
    if (index != -1)
      [browser_ closeTabAtIndex:index makeHistory:YES];
  }
}


//- (void)setFileType:(NSString*)typeName { [super setFileType:typeName]; }

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


- (IBAction)selectNextElement:(id)sender {
  NSMutableAttributedString *mastr = textView_.textStorage;
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
    return;
  }
}


- (IBAction)selectPreviousElement:(id)sender {
  NSMutableAttributedString *mastr = textView_.textStorage;
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
    return;
  }
}


- (IBAction)toggleMetaRuler:(id)sender {
  self.hasMetaRuler = !self.hasMetaRuler;
}


#pragma mark -
#pragma mark Highlighting


- (NSDictionary*)defaultTextAttributes {
  NSDictionary *attrs;
  KStyle *style = [KStyle sharedStyle];
  kassert(style);
  KStyleElement *styleElement = [style defaultStyleElement];
  kassert(styleElement);
  attrs = styleElement->textAttributes();
  return attrs;
}


// clear all highlighting attributes. Normally called after highlighting has
// been turned off.
- (void)clearHighlighting {
  NSTextStorage *textStorage = textView_.textStorage;
  [textStorage beginEditing];
  [textStorage setAttributes:[self defaultTextAttributes]
                       range:NSMakeRange(0, textStorage.length)];
  [textStorage endEditing];
}


- (void)refreshStyle {
  DLOG("refreshStyle");
  KStyle *style = [KStyle sharedStyle];
  kassert(style);
  KStyleElement *defaultElem = [style defaultStyleElement];
  
  // textview bgcolor
  NSColor *color = defaultElem->backgroundColor();
  kassert(color);
  [textView_ setBackgroundColor:color];
  
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


// aka "enqueue complete highlighting"
// returns true if processing was queued, otherwise false indicates processing
// was already queued.
- (BOOL)setNeedsHighlightingOfCompleteDocument {
  if (hatomic_flags_set(&stateFlags_, kCompleteHighlightingIsQueued)) {
    // we did set the flag ("enqueued")
    if (isVisible_) {
      // trigger highlighting directly if visible
      [self highlightCompleteDocumentInBackgroundIfQueued];
    }
    return YES;
  }
  return NO;
}


// aka "dequeue and trigger complete highlighting"
// returns true if processing was scheduled
- (BOOL)highlightCompleteDocumentInBackgroundIfQueued {
  if (hatomic_flags_clear(&stateFlags_, kCompleteHighlightingIsQueued)) {
    // we cleared the flag ("dequeued")
    return [self highlightCompleteDocumentInBackground];
  }
  return NO;
}


// returns true if processing was scheduled
- (BOOL)highlightCompleteDocumentInBackground {
  return [self deferHighlightTextStorage:textView_.textStorage
                                 inRange:NSMakeRange(NSNotFound, 0)];
}


// returns true if processing was scheduled
- (BOOL)deferHighlightTextStorage:(NSTextStorage*)textStorage
                          inRange:(NSRange)editedRange {
  //#define DLOG_HL DLOG
  #define DLOG_HL(...) ((void)0)
  
  // WARNING: this must not be called on the same thread as the
  // dispatch_get_global_queue(0,0) run in -- it will cause a deadlock.
  
  if (!highlightingEnabled_)
    return NO;
  
  // Make copies of these as they may change before we start processing
  KSourceHighlightState* state = lastEditedHighlightState_;
  NSRange stateRange = lastEditedHighlightStateRange_;
  int changeInLength = [textStorage changeInLength];
  
  // Aquire semaphore
  if (!highlightSem_.tryGet()) {
    // currently processing
    DLOG_HL("highlight --CANCEL & WAIT--");
    
    // Combine range of previous hl with current edit
    NSRange prevHighlightRange = sourceHighlighter_->currentRange();
    editedRange = NSUnionRange(prevHighlightRange, editedRange);
    
    // We can no longer rely on state
    //state = nil;
    //stateRange = (NSRange){NSNotFound,0};
    
    // TODO: some kind of funky logic here to deduce range changes
    //int prevChangeInLength = sourceHighlighter_->currentChangeInLength();
    
    // signal "cancel" and wait for lock
    sourceHighlighter_->cancel();
    
    // Since we put back the lock on main we need to reschedule for next tick.
    // We will reschedule on to next tick until we get the semaphore.
    if ([NSThread isMainThread]) {
      // block to execute
      dispatch_block_t block = ^{
        NSAutoreleasePool *pool = [NSAutoreleasePool new];
        // We can't rely on state in this case since we merged two edits
        lastEditedHighlightState_ = nil;
        lastEditedHighlightStateRange_ = NSMakeRange(NSNotFound,0);
        [self deferHighlightTextStorage:textStorage inRange:editedRange];
        [pool drain];
      };
      
      // execute with back-off delay
      if (highlightWaitBackOffNSec_ == 0) {
        // ASAP on next tick
        dispatch_async(dispatch_get_main_queue(), block);
        // start back-off delay at 50ms (1 000 000 000 = 1 sec)
        highlightWaitBackOffNSec_ = 50000000LL;
      } else {
        // backing off and executing after highlightWaitBackOffNSec_ nanosecs
        dispatch_time_t delay = dispatch_time(0, highlightWaitBackOffNSec_);
        dispatch_after(delay, dispatch_get_main_queue(), block);
        // increase back-off delay (100, 200, 400, 800, 1600, 3200 ms and so on)
        highlightWaitBackOffNSec_ *= 2;
      }
      
      return YES;
    } else {
      highlightSem_.get();
    }
  }
  
  // reset cancel-and-wait back-off timeout
  highlightWaitBackOffNSec_ = 0;
  
  // Dispatch
  DLOG_HL("highlight --LOCKED--");
  dispatch_async(dispatch_get_global_queue(0,0),^{
    if (textStorage.length == 0) {
      highlightSem_.put();
      return;
    }
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    
    // Begin processing, buffering all attributes created
    sourceHighlighter_->beginBufferingOfAttributes();

    // highlight
    #if !NDEBUG
    DLOG_HL("highlight --PROCESS-- %@ %@ %@", NSStringFromRange(editedRange),
            state, NSStringFromRange(stateRange));
    #endif
    NSRange affectedRange = {NSNotFound,0};
    @try {
      KStyle *style = [KStyle sharedStyle];
      affectedRange =
          sourceHighlighter_->highlight(textStorage, style, editedRange, state,
                                        stateRange, changeInLength);
    } @catch (NSException *e) {
      WLOG("Caught exception while processing highlighting for range %@: %@",
           NSStringFromRange(editedRange), e);
      sourceHighlighter_->cancel();
    }
    
    if (sourceHighlighter_->isCancelled()) {
      // highlighting was cancelled
      // Note: No need to call clearBufferedAttributes() here since we know that
      // we are soon called again which implies clearing the buffer.
      highlightSem_.put();
    } else {
      // we are done processing -- time to flush our edits
      //
      // Notes:
      //
      // - this buffering and later flushing of attributes is needed to minimize
      //   the time the UI is locked.
      //
      // - We perform this on the main thread to avoid scary _NSLayoutTree bugs
      //
      K_DISPATCH_MAIN_ASYNC(
        if (!sourceHighlighter_->isCancelled()) {
          DLOG_HL("highlight --FLUSH-START-- %@",
                  NSStringFromRange(affectedRange));
          [textStorage beginEditing];
          @try {
            sourceHighlighter_->endFlushBufferedAttributes(textStorage);
          } @catch (NSException *e) {
            WLOG("Caught exception while trying to flush highlighting "
                 "attributes contained within %@: %@",
                 NSStringFromRange(affectedRange), e);
          }
          //[textStorage invalidateAttributesInRange:affectedRange];
          [textStorage endEditing];
          DLOG_HL("highlight --FLUSH-END--");
        }
        highlightSem_.put();
        DLOG_HL("highlight --FREED-- (cancelled: %@)",
                sourceHighlighter_->isCancelled() ? @"YES":@"NO");
      );
    }
    
    [pool drain];
  });
  
  return YES;
  #undef DLOG_HL
}


// Edits arrive in singles. This method is only called for used edits, not
// programmatical changes.
- (BOOL)textView:(NSTextView *)textView
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
    
    if (index != NSNotFound) {
      lastEditedHighlightState_ =
        [textStorage attribute:KSourceHighlightStateAttribute
                       atIndex:index
                effectiveRange:&lastEditedHighlightStateRange_];
    } else {
      lastEditedHighlightState_ = nil;
    }
  } else { // if (textStorage.length == 0)
    lastEditedHighlightState_ = nil;
    didEditCharacters = (replacementString.length != 0);
  }
  
  // Cancel any in-flight highlighting
  if (didEditCharacters && highlightingEnabled_) {
    #if 0
    DLOG("text edited -- '%@' -> '%@' at %@",
     [textView_.textStorage.string substringWithRange:range],
     replacementString, NSStringFromRange(range));
    #endif
    sourceHighlighter_->cancel();
  }

  return YES;
}


/*- (BOOL)textView:(NSTextView *)textView
shouldChangeTextInRanges:(NSArray *)affectedRanges
      replacementStrings:(NSArray *)replacementStrings {
  NSUInteger i, count = [affectedRanges count];
  for (i = 0; i < count; i++) {
    NSValue *val = [affectedRanges objectAtIndex:i];
    NSString *str = [replacementStrings objectAtIndex:i];
    NSRange range = [val rangeValue];
    DLOG("replace text '%@' at %@ with '%@'",
         [textView_.textStorage.string substringWithRange:range],
         NSStringFromRange(range), str);
    
    // find full range of state at edit location
    
    NSRange highlightStateRange;
    NSTextStorage *textStorage = textView_.textStorage;
    KSourceHighlightState *hlstate =
      [textStorage attribute:KSourceHighlightStateAttribute
                     atIndex:range.location
       longestEffectiveRange:&highlightStateRange
                     inRange:NSMakeRange(0, textStorage.length)];
    DLOG("state at %u -> %@ '%@'", range.location, hlstate,
         [textStorage.string substringWithRange:highlightStateRange]);
    
  }
  return YES;
}*/



// used for temporary storage ONLY ON MAIN THREAD
//#define ucharbuf1_size 4096  // 1 memory page
//static unichar ucharbuf1[ucharbuf1_size];


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
                                       changeDelta:(NSInteger)changeInLength {
  // update linebreaks mapping
  NSString *string = textStorage.string;

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
    unichar ch = [string characterAtIndex:editedRange.location];
    if (ch == '\n' || ch == '\r') {
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
  
  if (changeInLength != 0 &&
      (lineToRangeVec_.size() != 0 || lineCountDelta != 0)) {
    [self linesDidChangeWithLineCountDelta:lineCountDelta];
  }
}


// invoked after an editing occured, but before it's been committed
// Has the nasty side effect of losing the selection when applying attributes
//- (void)textStorageWillProcessEditing:(NSNotification *)notification {}

// invoked after an editing occured which has just been committed
//- (void)textStorageDidProcessEditing:(NSNotification *)notification {}

- (void)textStorageDidProcessEditing:(NSNotification *)notification {
  NSTextStorage	*textStorage = [notification object];
  
  // no-op unless characters where edited
  if (!(textStorage.editedMask & NSTextStorageEditedCharacters)) {
    return;
  }
  kassert([NSThread isMainThread]);
  
  // range that was affected by the edit
	NSRange	editedRange = [textStorage editedRange];
  
  // length delta of the edit (i.e. negative for deletions)
	int	changeInLength = [textStorage changeInLength];

  // update lineToRangeVec_
  [self _updateLinesToRangesInfoForTextStorage:textStorage
                                       inRange:editedRange
                                   changeDelta:changeInLength];

  // we do not process edits when we are loading
  if (isLoading_) return;
  
  BOOL wasInUndoRedo = [[self undoManager] isUndoing] ||
                       [[self undoManager] isRedoing];
  DLOG_RANGE(editedRange, textStorage.string);
  DLOG("editedRange: %@, changeInLength: %d, wasInUndoRedo: %@, editedMask: %d",
       NSStringFromRange(editedRange), changeInLength,
       wasInUndoRedo ? @"YES":@"NO", textStorage.editedMask);

  // This should never happen, right?!
  if (changeInLength == 0 && !lastEditedHighlightState_) {
    DLOG("textStorageDidProcessEditing: bailing because "
         "(changeInLength == 0 && !lastEditedHighlightState_)");
    assert(!(changeInLength == 0 && !lastEditedHighlightState_));
    return;
  }
  

  // mark as dirty if not already dirty
  if (!isDirty_) {
    [self updateChangeCount:NSChangeReadOtherContents];
  }
  
  // Syntax highlight
  if (highlightingEnabled_) {
    [self deferHighlightTextStorage:textStorage inRange:editedRange];
  }
  
  // this makes the edit an undoable entry (otherwise each "group" of edits will
  // be undoable, which is not fine-grained enough for us)
  [textView_ breakUndoCoalescing];
}


- (void)guessLanguageBasedOnUTI:(NSString*)uti textContent:(NSString*)text {
  KLangMap *langMap = [KLangMap sharedLangMap];
  NSString *firstLine = nil;
  
  // find first line
  if (text) {
    NSRange firstNewlineRange =
        [text rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]];
    // limit to 1k (the file might lack newlines) since we make a copy and
    // because the underlying mechanism uses somewhat slow regexp.
    if (firstNewlineRange.location != NSNotFound) {
      NSUInteger stopIndex = MIN(1024, firstNewlineRange.location);
      firstLine = [text substringToIndex:stopIndex];
    } else if (text.length <= 1024) {
      firstLine = text;
    } else {
      firstLine = [text substringToIndex:1024];
    }
  }
  
  self.langId = [langMap langIdForSourceURL:self.fileURL
                                    withUTI:uti
                       consideringFirstLine:firstLine];
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
  
  // different branches depending on local file or remote
  if ([absoluteURL isFileURL]) {
    if ([NSThread isMainThread]) {
      // this happens when "reverting to saved"
      K_DISPATCH_BG_ASYNC({
        NSError *error = nil;
        if (![self readFromFileURL:absoluteURL ofType:typeName error:&error])
          [self presentError:error];
      });
      return YES;
    } else {
      // already called in the background
      return [self readFromFileURL:absoluteURL ofType:typeName error:outError];
    }
  } else {
    [self startReadingFromRemoteURL:absoluteURL ofType:typeName];
    return YES;
  }
}


- (BOOL)readFromFileURL:(NSURL *)absoluteURL
                 ofType:(NSString *)typeName
                  error:(NSError **)outError {
  // utilize mmap to load a file
  NSString *path = [absoluteURL path];
  NSData *data = [NSData dataWithContentsOfMappedFile:path];
  
  // if we failed to read the file, set outError with info
  if (!data) {
    if ([absoluteURL checkResourceIsReachableAndReturnError:outError]) {
      // reachable, but might be something else than a regular file
      NSFileManager *fm = [NSFileManager defaultManager];
      BOOL isDir;
      BOOL exists = [fm fileExistsAtPath:path isDirectory:&isDir];
      assert(exists == true); // since checkResourceIsReachableAndReturnError
      if (isDir) {
        *outError = [NSError kodErrorWithFormat:
            @"Opening a directory is not yet supported"];
      } else {
        *outError = [NSError kodErrorWithFormat:@"Unknown I/O read error"];
      }
    }
    return NO;
  }
  
  // read xattrs
  NSRange selectedRange = {0};
  int fd = open([path UTF8String], O_RDONLY);
  if (fd < 0) {
    WLOG("failed to open(\"%@\", O_RDONLY)", path);
  } else {
    const char *key;
    ssize_t readsz;
    static size_t bufsize = 512;
    char *buf = new char[bufsize];
    
    key = "com.apple.TextEncoding";
    // The value is a string "utf-8;134217984" where the last part (if
    // present) is a CFStringEncoding encoded in base-10.
    if ((readsz = fgetxattr(fd, key, (void*)buf, bufsize, 0, 0)) < 0) {
      DLOG("failed to read xattr '%s' from '%@'", key, path);
    } else if (readsz > 2) { // <2 chars doesnt make sense
      NSString *s = [[NSString alloc] initWithBytesNoCopy:(void*)buf
                                                   length:readsz
                                                 encoding:NSUTF8StringEncoding
                                             freeWhenDone:NO];
      NSRange r = [s rangeOfString:@";"];
      CFStringEncoding enc1 = 0;
      if (r.location != NSNotFound) {
        // try parsing a suffix integer value
        enc1 = [[s substringFromIndex:r.location+1] integerValue];
        NSStringEncoding enc2 =
            CFStringConvertEncodingToNSStringEncoding(enc1);
        if (enc2 < NSASCIIStringEncoding || enc2 > NSUTF32LittleEndianStringEncoding) {
          // that didn't work, lets set s to the first part and continue
          enc1 = -1;
          s = [s substringToIndex:r.location];
        }
      }
      if (enc1 == 0) {
        // try to parse s as an IANA charset (e.g. "utf-8")
        enc1 = CFStringConvertIANACharSetNameToEncoding((CFStringRef)s);
      }
      if (enc1 > 0) {
        textEncoding_ = CFStringConvertEncodingToNSStringEncoding(enc1);
      }
      //DLOG("xattr read encoding '%@' %d -> %@ ([%d] %@)", s, (int)enc1,
      //     CFStringConvertEncodingToIANACharSetName(enc1),
      //     (int)textEncoding_,
      //     [NSString localizedNameOfStringEncoding:textEncoding_]);
    }
    
    key = "se.hunch.kod.selection";
    if ((readsz = fgetxattr(fd, key, (void*)buf, bufsize, 0, 0)) < 0) {
      DLOG("failed to read xattr '%s' from '%@'", key, path);
    } else if (readsz > 2) { // <2 chars doesnt make sense
      NSString *s = [[NSString alloc] initWithBytesNoCopy:(void*)buf
                                                   length:readsz
                                                 encoding:NSUTF8StringEncoding
                                             freeWhenDone:NO];
      selectedRange = NSRangeFromString(s);
      DLOG("loaded selection from xattr: %@", s);
    }
    
    delete buf; buf = NULL;
    close(fd);
  }
  
  // read mtime
  NSDate *mtime = nil;
  if (![absoluteURL getResourceValue:&mtime
                              forKey:NSURLContentModificationDateKey
                               error:outError]) {
    return NO;
  }
  self.fileModificationDate = mtime;
  
  // read data
  if (![self readFromData:data ofType:typeName error:outError callback:^{
    // restore (or set) selection
    if (selectedRange.location < textView_.textStorage.length) {
      DLOG("restoring selection to: %@", NSStringFromRange(selectedRange));
      [textView_ setSelectedRange:selectedRange];
    }
  }]) {
    return NO;
  }
  
  return YES;
}


- (void)startReadingFromRemoteURL:(NSURL*)absoluteURL
                           ofType:(NSString *)typeName {
  // set state to "waiting"
  self.isLoading = YES;
  self.isWaitingForResponse = YES;
  
  // set text view to be read-only
  [textView_ setEditable:NO];
  
  // set type (might change when we receive a response)
  self.fileType = typeName;
  
  __block NSString *textEncodingNameFromResponse = nil;
  
  HURLConnection *conn = [absoluteURL
    fetchWithOnResponseBlock:^(NSURLResponse *response) {
      NSError *error = nil;
      NSDate *fileModificationDate = nil;
      
      // change state from waiting to loading
      self.isWaitingForResponse = NO;
      
      // handle HTTP response
      if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        // check status
        NSInteger status = [(NSHTTPURLResponse*)response statusCode];
        if (status < 200 || status > 299) {
          error = [NSError HTTPErrorWithStatusCode:status];
        }
        // TODO: get fileModificationDate from response headers
      }
      
      // try to derive UTI and read filename, unless error
      if (!error) {
        // get UTI based on MIME type
        CFStringRef mimeType = (CFStringRef)[response MIMEType];
        if (mimeType) {
          NSString *uti = (NSString*)
              UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType,
                                                    mimeType, NULL);
          if (uti)
            self.fileType = uti;
        }
        
        // get text encoding
        textEncodingNameFromResponse = [response textEncodingName];
      }
      
      // update URL, if needed (might have been redirected)
      self.fileURL = response.URL;
      
      // set suggested title
      self.title = response.suggestedFilename;
      
      // set modification date
      self.fileModificationDate = fileModificationDate ? fileModificationDate
                                                       : [NSDate date];
      
      return error;
    }
    onCompleteBlock:^(NSError *err, NSData *data) {
      // Read data unless an error occured while reading URL
      if (!err) {
        // if we got a charset, try to convert it into a NSStringEncoding symbol
        if (textEncodingNameFromResponse) {
          textEncoding_ = CFStringConvertEncodingToNSStringEncoding(
              CFStringConvertIANACharSetNameToEncoding(
                  (CFStringRef)textEncodingNameFromResponse));
        }
        // parse data
        [self readFromData:data ofType:self.fileType error:&err callback:^{
          // we are done -- allow editing
          [textView_ setEditable:YES];
        }];
      } else {
        // handle error
        self.isLoading = NO;
        self.isCrashed = YES; // FIXME
        [NSApp presentError:err];
      }
    }
    startImmediately:NO];
  
  kassert(conn);
  
  // we want the blocks to be invoked on the main thread, thank you
  [conn scheduleInRunLoop:[NSRunLoop mainRunLoop]
                  forMode:NSDefaultRunLoopMode];
  [conn start];
  
  // TODO: keep a reference to the connection so we can cancel it if the tab is
  // prematurely closed.
}


// Sets the contents of this document by reading from a file wrapper of a
// specified type (e.g. a directory).
- (BOOL)readFromFileWrapper:(NSFileWrapper *)fileWrapper
                     ofType:(NSString *)typeName
                      error:(NSError **)outError {
  if (![fileWrapper isDirectory]) {
    return [super readFromFileWrapper:fileWrapper
                               ofType:typeName
                                error:outError];
  }
  DLOG("TODO: readFromFileWrapper:%@ ofType:%@ error:*", fileWrapper, typeName);
  *outError = [NSError kodErrorWithDescription:@"Unable to read directories"];
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
      
      // guess language if no language has been set
      if (!langId_) {
        // implies queueing of complete highlighting
        [self guessLanguageBasedOnUTI:typeName textContent:text];
      } else {
        if (isVisible_)
          [self setNeedsHighlightingOfCompleteDocument];
      }

      if (callback)
        callback();

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
  return !url || [url isFileURL];
}


// Generate data from text
- (NSData*)dataOfType:(NSString*)typeName error:(NSError **)outError {
  DLOG_EXPR(typeName);
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
  BOOL ok;
  NSURL *originalURL = self.fileURL;
  if (kconf_bool(@"saving/atomic", NO)) {
    ok = [self writeSafelyToURL:absoluteURL
                         ofType:typeName
               forSaveOperation:saveOperation
                          error:outError];
  } else {
    ok = [self writeToURL:absoluteURL
                   ofType:typeName
         forSaveOperation:saveOperation
      originalContentsURL:self.fileURL
                    error:outError];
  }
  
  if (ok) {
    // update modification date -- needed for NSDocument's interal "did someone
    // else change our document?" logic.
    NSDate *mtime = nil;
    if (![absoluteURL getResourceValue:&mtime
                                forKey:NSURLContentModificationDateKey
                                 error:outError]) {
      return NO;
    }
    self.fileModificationDate = mtime;
    
    // Clear change count
    [self updateChangeCount:NSChangeCleared];

    // If we wrote the stylesheet, trigger a reload or load
    if (originalURL && [originalURL isEqual:[KStyle sharedStyle].url]) {
      [[KStyle sharedStyle] loadFromURL:absoluteURL withCallback:nil];
    }
  }
  
  return ok;
}


- (BOOL)writeToURL:(NSURL *)absoluteURL
            ofType:(NSString *)typeName
  forSaveOperation:(NSSaveOperationType)saveOperation
originalContentsURL:(NSURL *)absoluteOriginalContentsURL
             error:(NSError **)outError {
  // currently only supports writing to files
  if (![absoluteURL isFileURL]) {
    if (outError) {
      *outError = [NSError kodErrorWithFormat:
          @"Kod can't save data to remotely located URL '%@'", absoluteURL];
    }
    return NO;
  }
  
  // make a file wrapper (calls dataOfType:error:)
  NSFileWrapper *fileWrapper = [self fileWrapperOfType:typeName error:outError];
  if (!fileWrapper) return NO;
  
  // write it
  if (![fileWrapper writeToURL:absoluteURL
                       options:0
           originalContentsURL:absoluteOriginalContentsURL
                         error:outError]) {
    return NO;
  }

  // this is needed for the internal resource tracking logic of NSDocument
  [self setFileURL:absoluteURL];
  
  // write xattrs
  NSString *path = [absoluteURL path];
  int fd = open([path UTF8String], O_RDONLY);
  if (fd < 0) {
    WLOG("failed to open(\"%@\", O_RDONLY)", path);
  } else {
    const char *key, *utf8pch;
    
    key = "com.apple.TextEncoding";
    // The value is a string "utf-8;134217984" where the last part (if
    // present) is a CFStringEncoding encoded in base-10.
    CFStringEncoding enc1 =
        CFStringConvertNSStringEncodingToEncoding(textEncoding_);
    NSString *s = [NSString stringWithFormat:@"%@;%d",
                   CFStringConvertEncodingToIANACharSetName(enc1), (int)enc1];
    utf8pch = [s UTF8String];
    if (fsetxattr(fd, key, (void*)utf8pch, strlen(utf8pch), 0, 0) != 0) {
      WLOG("failed to write xattr '%s' to '%@'", key, path);
    }
    
    key = "se.hunch.kod.selection";
    utf8pch = [NSStringFromRange([textView_ selectedRange]) UTF8String];
    if (fsetxattr(fd, key, (void*)utf8pch, strlen(utf8pch), 0, 0) != 0) {
      WLOG("failed to write xattr '%s' to '%@'", key, path);
    }
    
    close(fd);
  }

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

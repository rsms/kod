#include <sys/xattr.h>

#import "KConfig.h"
#import "KTabContents.h"
#import "KBrowser.h"
#import "KBrowserWindowController.h"
#import "KSourceHighlighter.h"
#import "KStyle.h"
#import "KScroller.h"
#import "KScrollView.h"
#import "KLangMap.h"


// used in stateFlags_
enum {
  kHighlightingIsQueued = HATOMIC_FLAG_MIN,
  kHighlightingIsProcessing,
  kTestStorageEditingIsProcessing,
};


@interface KTabContents (Private)
- (void)undoManagerCheckpoint:(NSNotification*)notification;
@end

@implementation KTabContents

@synthesize isDirty = isDirty_,
            textEncoding = textEncoding_,
            style = style_;

static NSImage* _kDefaultIcon = nil;
static NSString* _kDefaultTitle = @"Untitled";
static dispatch_queue_t gHighlightDispatchQueue = NULL;

+ (void)load {
  NSAutoreleasePool* pool = [NSAutoreleasePool new];
  _kDefaultIcon =
      [[[NSWorkspace sharedWorkspace] iconForFile:@"/dev/null"] retain];
  gHighlightDispatchQueue = dispatch_queue_create("kod.highlight", NULL);
  [pool drain];
}

static NSFont* _kDefaultFont = nil;

+ (NSFont*)defaultFont {
  if (!_kDefaultFont) {
    _kDefaultFont = [[NSFont fontWithName:@"M+ 1m light" size:13.0] retain];
    if (!_kDefaultFont) {
      WLOG("unable to find default font \"M+\" -- using system default");
      _kDefaultFont = [[NSFont userFixedPitchFontOfSize:13.0] retain];
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




// things which MUST execute on the main thread.
/*- (void)_initOnMain {
  if (![NSThread isMainThread]) {
    K_DISPATCH_MAIN_ASYNC({ [self _initOnMain]; });
    return;
  }

	// Register for "text changed" notifications of our text storage:
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self
         selector:@selector(textStorageDidProcessEditing:)
             name:NSTextStorageDidProcessEditingNotification
					 object:[textView_ textStorage]];
	[nc addObserver:self
         selector:@selector(textStorageWillProcessEditing:)
             name:NSTextStorageWillProcessEditingNotification
					 object:[textView_ textStorage]];

  // Observe when the document is modified so we can update the UI accordingly
	[nc addObserver:self
         selector:@selector(undoManagerCheckpoint:)
             name:NSUndoManagerCheckpointNotification
					 object:undoManager_];
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
  
  // use default text encoding unless explicitly set
  textEncoding_ = NSUTF8StringEncoding;
      //KConfig.getInt(@"defaultReadTextEncoding", (int)NSUTF8StringEncoding);
  
  // 1=unlocked, 0=locked
  sourceHighlightSem_ = new HSemaphore(1);
  
  // Default highlighter
  sourceHighlighter_.reset(new KSourceHighlighter);

  // Save a weak reference to the undo manager (performance reasons)
  undoManager_ = [self undoManager]; assert(undoManager_);

  // Create a NSTextView
  textView_ = [[NSTextView allocWithZone:zone] initWithFrame:NSZeroRect];
  
  // Create text storage
  //KTextStorage *textStorage = [[KTextStorage alloc] init];
  //textView_.layoutManager.textStorage = textStorage;
  //[textStorage release];
  
  // Setup text view
  [textView_ setDelegate:self];
  [textView_ setAllowsUndo:YES];
  [textView_ setFont:[isa defaultFont]];
  [textView_ setAutomaticLinkDetectionEnabled:NO];
  [textView_ setSmartInsertDeleteEnabled:NO];
  [textView_ setAutomaticQuoteSubstitutionEnabled:NO];
  [textView_ setAllowsImageEditing:NO];
  [textView_ setRichText:NO];
  [textView_ turnOffKerning:self]; // we are monospace (robot voice)
  [textView_ setAutoresizingMask:          NSViewMaxYMargin|
                          NSViewMinXMargin|NSViewWidthSizable|NSViewMaxXMargin|
                                           NSViewHeightSizable|
                                           NSViewMinYMargin];
  [textView_ setUsesFindPanel:YES];
  [textView_ setTextContainerInset:NSMakeSize(2.0, 4.0)];
  
  // configure layout manager
  //NSLayoutManager *layoutManager = []
  
  // default paragraph style
  NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
  [paragraphStyle setParagraphStyle:[NSParagraphStyle defaultParagraphStyle]];
  [paragraphStyle setLineBreakMode:NSLineBreakByCharWrapping];
  [paragraphStyle setDefaultTabInterval:2];
  [textView_ setDefaultParagraphStyle:paragraphStyle];
  //NSParagraphStyleAttributeName
  
  // TODO: the following settings should follow the current style
  [textView_ setBackgroundColor:
      [NSColor colorWithCalibratedWhite:0.1 alpha:1.0]];
  [textView_ setTextColor:[NSColor whiteColor]];
  [textView_ setInsertionPointColor:
      [NSColor colorWithCalibratedRed:1.0 green:0.2 blue:0.1 alpha:1.0]];
  [textView_ setSelectedTextAttributes:[NSDictionary dictionaryWithObject:
      [NSColor colorWithCalibratedRed:0.12 green:0.18 blue:0.27 alpha:1.0]
      forKey:NSBackgroundColorAttributeName]];
  
  // TODO: this defines the attributes to apply to "marked" text, input which is
  // pending, like "¨" waiting for "u" to build the character "ü". Should match
  // the current style.
  //[textView_ setMarkedTextAttributes:[NSDictionary dictionaryWithObject:[NSColor redColor] forKey:NSBackgroundColorAttributeName]];

  // Create a NSScrollView to which we add the NSTextView
  KScrollView *sv = [[KScrollView alloc] initWithFrame:NSZeroRect];
  [sv setDocumentView:textView_];
  [sv setHasVerticalScroller:YES];

  // Set the NSScrollView as our view
  view_ = sv;
  
  // Default style
  style_ = [[KStyle emptyStyle] retain];
  [KStyle defaultStyleWithCallback:^(NSError *err, KStyle *style) {
    if (err) {
      [NSApp presentError:err];
      return;
    }
    DLOG("style %@ loaded", style);
    self.style = style;
  }];

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
  DLOG("initWithContentsOfURL:%@ ofType:%@", absoluteURL, typeName);
  self = [self initWithBaseTabContents:nil];
  assert(self);
  
  // we are in a loading state
  self.isLoading = YES;
  
  // this will take care of loading the contents at |absoluteURL|
  //
  // readFromURL:ofType:error: will call:
  // - setFileURL:
  // - setFileType:
  // - setFileModificationDate:
  // 
  if (![self readFromURL:absoluteURL ofType:typeName error:outError]) {
    [self release];
    if (outError) assert(*outError != nil);
    return nil;
  }
  return self;
}


- (void)dealloc {
  if (style_) {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self
                  name:KStyleDidChangeNotification
                object:style_];
    [style_ release];
  }
  delete sourceHighlightSem_;
  sourceHighlightSem_ = NULL;
  [super dealloc];
}


- (void)setIsLoading:(BOOL)loading {
  BOOL isLoadingPrev = isLoading_;
  [super setIsLoading:loading];
  // update icon if we went from "loading" to "not loading"
  if (isLoadingPrev && !isLoading_) {
    [self setIconBasedOnContents];
  }
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


- (void)styleDidChange:(NSNotification*)notification {
  // TODO: [self reloadStyle];
}


- (void)setStyle:(KStyle*)style {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  KStyle* old = h_objc_swap(&style_, style);
  if (style_) {
    [nc addObserver:self
           selector:@selector(styleDidChange:)
               name:KStyleDidChangeNotification
             object:style_];
    [style_ retain];
  }
  if (old) {
    [nc removeObserver:self
                  name:KStyleDidChangeNotification
                object:old];
    [old release];
  }
  // don't reload style here
}


- (BOOL)validateMenuItem:(NSMenuItem *)item {
  BOOL y;
  if ([item action] == @selector(saveDocument:)) {
    y = [self isDocumentEdited] || ![self fileURL];
  } else {
    y = [super validateMenuItem:item];
  }
  return y;
}


- (void)tabWillCloseInBrowser:(CTBrowser*)browser atIndex:(NSInteger)index {
  [super tabWillCloseInBrowser:browser atIndex:index];
  NSWindowController *wc = browser.windowController;
  if (wc) {
    [self removeWindowController:wc];
    [self setWindow:nil];
  }
  [[NSDocumentController sharedDocumentController] removeDocument:self];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}


/*- (void)tabDidInsertIntoBrowser:(CTBrowser*)browser
                        atIndex:(NSInteger)index
                   inForeground:(bool)foreground {
  [super tabDidInsertIntoBrowser:browser atIndex:index inForeground:foreground];
  DLOG("%@ tabDidInsertIntoBrowser:%@ atIndex:%d", self, browser, index);
  //assert(browser);
  //[self addWindowController:browser.windowController];
}

- (void)tabDidDetachFromBrowser:(CTBrowser*)browser atIndex:(NSInteger)index {
  [super tabDidDetachFromBrowser:browser atIndex:index];
  assert(browser);
  [self removeWindowController:browser.windowController];
}*/


-(void)tabDidBecomeSelected {
  [super tabDidBecomeSelected];
  if (browser_) {
    NSWindowController *wc = browser_.windowController;
    if (wc) {
      [self addWindowController:wc];
      [self setWindow:[wc window]];
    }
    
  }
}


-(void)tabDidResignSelected {
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
  if (hatomic_flags_clear(&stateFlags_, kHighlightingIsQueued)) {
    // we did clear the flag
    [self highlightCompleteDocumentInBackground];
  }
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
  if (url != [self fileURL]) {
    [super setFileURL:url];
    if (url) {
      // set title
      if ([url isFileURL]) {
        self.title = url.lastPathComponent;
      } else {
        NSString *newTitle = [url absoluteString];
        NSCharacterSet *illegalFilenameCharset =
            [NSCharacterSet characterSetWithCharactersInString:@"/:"];
        newTitle = [newTitle stringByTrimmingCharactersInSet:illegalFilenameCharset];
        newTitle = [newTitle stringByReplacingOccurrencesOfString:@"/"
                                                       withString:@"-"];
        self.title = newTitle;
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


// aka "enqueue complete highlighting"
// returns true if processing was queued, otherwise false indicates processing
// was already queued.
- (BOOL)setNeedsHighlightingOfCompleteDocument {
  if (hatomic_flags_set(&stateFlags_, kHighlightingIsQueued)) {
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
  if (hatomic_flags_clear(&stateFlags_, kHighlightingIsQueued)) {
    // we cleared the flag ("dequeued")
    return [self highlightCompleteDocumentInBackground];
  }
  return NO;
}


// returns true if processing was scheduled
- (BOOL)highlightCompleteDocumentInBackground {
  // we utilize the kHighlightingIsProcessing flag
  if (hatomic_flags_set(&stateFlags_, kHighlightingIsProcessing)) {
    K_DISPATCH_BG_ASYNC({
      if (hatomic_flags_clear(&stateFlags_, kHighlightingIsProcessing)) {
        [self highlightCompleteDocument];
      }
    });
    return YES;
  }
  return NO;
}


- (BOOL)highlightCompleteDocument {
  static NSRange range = NSMakeRange(NSNotFound, 0);
  return [self highlightTextStorage:textView_.textStorage
                            inRange:range];
}


- (BOOL)highlightTextStorage:(NSTextStorage*)textStorage
                     inRange:(NSRange)range {
  if (!hatomic_flags_set(&stateFlags_, kHighlightingIsProcessing)) {
    // someone else is already processing
    return NO;
  }
  [textStorage beginEditing];
  sourceHighlighter_->highlight(textStorage, style_, range,
                                lastEditedHighlightState_,
                                lastEditedHighlightStateRange_);
  [textStorage endEditing];
  hatomic_flags_clear(&stateFlags_, kHighlightingIsProcessing);
  return YES;
}


/*
- (void)textStorageWillProcessEditing:(NSNotification *)notification {
  // Edit event preamble (unless loading or already processing)
  if (isLoading_ ||
      hatomic_flags_test(&stateFlags_, kTestStorageEditingIsProcessing)) {
    return;
  }
  
  NSTextStorage	*textStorage = notification.object;
  NSRange	editedRange = [textStorage editedRange];
  
  // Highlight preamble, unless already highlighting
  if (!hatomic_flags_test(&stateFlags_, kHighlightingIsProcessing)) {
    sourceHighlighter_->willHighlight(textStorage, editedRange);
  }
}*/


// Edits arrive in singles
- (BOOL)textView:(NSTextView *)textView
shouldChangeTextInRange:(NSRange)range
replacementString:(NSString *)replacementString {
  #if 0
  DLOG("replace text '%@' at %@ with '%@'",
       [textView_.textStorage.string substringWithRange:range],
       NSStringFromRange(range), replacementString);
  #endif
  
  // find range of highlighting state at edit location
  NSTextStorage *textStorage = textView_.textStorage;
  if (textStorage.length != 0) {
    NSUInteger index;
    if (replacementString.length == 0) {
      // deletion
      if (textStorage.length == 1) {
        index = NSNotFound;
      } else {
        index = MIN(range.location+1, textStorage.length-1);
      }
    } else {
      // insertion/replacement
      index = MIN(range.location, textStorage.length-1);
    }
    if (index != NSNotFound) {
      lastEditedHighlightState_ =
        [textStorage attribute:KSourceHighlightStateAttribute
                       atIndex:index
                effectiveRange:&lastEditedHighlightStateRange_];
    }
    //KSourceHighlightState *hlstate =
    //  [textStorage attribute:KSourceHighlightStateAttribute
    //                 atIndex:range.location
    //   longestEffectiveRange:&highlightStateRange
    //                 inRange:NSMakeRange(0, textStorage.length)];
    //DLOG("state[2] at %u -> %@ '%@'", range.location, hlstate,
    //  [textStorage.string substringWithRange:lastEditedHighlightStateRange_]);
  } else {
    lastEditedHighlightState_ = nil;
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


// invoked after an editing occured, but before it's been committed
// Has the nasty side effect of losing the selection when applying attributes
//- (void)textStorageWillProcessEditing:(NSNotification *)notification {}

// invoked after an editing occured which has just been committed
//- (void)textStorageDidProcessEditing:(NSNotification *)notification {}

- (void)textStorageDidProcessEditing:(NSNotification *)notification {
	// invoked after an editing occured, but before it's been committed

  // Don't process editing if we are in a loading state (i.e. the edit might
  // have been caused by input data arrival)
  if (isLoading_)
    return;

  NSTextStorage	*textStorage = [notification object];
	NSRange	editedRange = [textStorage editedRange];
	int	changeInLen = [textStorage changeInLength];
  if (changeInLen == 0 && !lastEditedHighlightState_) {
    // text attributes changed -- not interested
    return;
  }
  
  // If we don't manage to set kTestStorageEditingIsProcessing, that means a
  // text storage edit is currently being processed, so we bail.
  if (!hatomic_flags_set(&stateFlags_, kTestStorageEditingIsProcessing)) {
    return;
  }
  
  BOOL wasInUndoRedo = [[self undoManager] isUndoing] ||
                       [[self undoManager] isRedoing];
  DLOG_RANGE(editedRange, textStorage.string);
  DLOG("editedRange: %@, changeInLen: %d, wasInUndoRedo: %@",
       NSStringFromRange(editedRange), changeInLen,
       wasInUndoRedo ? @"YES":@"NO");

  // mark as dirty if not already dirty
  if (!isDirty_) {
    [self updateChangeCount:NSChangeReadOtherContents];
  }
  
  // Syntax highlight (it's a no-op if aldready processing a "highlight")
  //selectionsBeforeEdit_ = [textView_ selectedRanges];
  if ([self highlightTextStorage:textStorage inRange:editedRange]) {
    //[textView_ setSelectedRanges:selections];
  }
  
  // this makes the edit an undoable entry (otherwise each "group" of edits will
  // be undoable, which is not fine-grained enough for us)
  [textView_ breakUndoCoalescing];
  
  // No longer processing text storage edit
  hatomic_flags_clear(&stateFlags_, kTestStorageEditingIsProcessing);
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
        [self readFromData:data ofType:self.fileType error:&err];
      }
      
      // make sure isLoading is false
      self.isLoading = NO;
      
      // if an error occured, handle it
      if (err) {
        self.isCrashed = YES; // FIXME
        [NSApp presentError:err];
      }
      
      // we are done -- allow editing
      [textView_ setEditable:YES];
      
      // TODO: syntax highlighting
    }
    startImmediately:NO];
  
  // we want the blocks to be invoked on the main thread, thank you
  [conn scheduleInRunLoop:[NSRunLoop mainRunLoop]
                  forMode:NSDefaultRunLoopMode];
  [conn start];
}



- (BOOL)readFromURL:(NSURL *)absoluteURL
             ofType:(NSString *)typeName
              error:(NSError **)outError {
  DLOG("readFromURL:%@ ofType:%@", absoluteURL, typeName);

  // set url
  self.fileURL = absoluteURL;
  
  if ([absoluteURL isFileURL]) {
    // utilize mmap to load a file
    NSString *path = [absoluteURL path];
    NSData *data = [NSData dataWithContentsOfMappedFile:path];
    if (!data) return NO;
    
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
    if (![self readFromData:data ofType:typeName error:outError]) {
      return NO;
    }
    
    // restore (or set) selection
    if (selectedRange.location < textView_.textStorage.length) {
      [textView_ setSelectedRange:selectedRange];
    }
  } else {
    // load a foreign/remote resource
    [self startReadingFromRemoteURL:absoluteURL ofType:typeName];
  }
  return YES;
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
               error:(NSError **)outError {
  DLOG("readFromData:%p ofType:%@", data, typeName);
  
  // try to decode data as text encoded as textEncoding_
  NSString *text = [[NSString alloc] initWithData:data encoding:textEncoding_];
  
  if (!text) {
    WLOG("Failed to parse data. text => nil (data length: %u)", [data length]);
    *outError = [NSError kodErrorWithDescription:@"Failed to parse file"];
    return NO;
  } else {
    [textView_ setString:text];
    // TODO: restore selection(s), possibly by reading from ext. attrs.
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
    
    [text release];
  }
  return YES;
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
  
  // modify attributes
  NSMutableDictionary* attrs = [fileWrapper.fileAttributes mutableCopy];
  [attrs setObject:@"hello" forKey:@"se.hunch.kod.cursor"];
  [fileWrapper setFileAttributes:attrs];
  
  // write it
  if (![fileWrapper writeToURL:absoluteURL
                       options:0
           originalContentsURL:absoluteOriginalContentsURL
                         error:outError]) {
    return NO;
  }
  
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
}

@end

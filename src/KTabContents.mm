#import "common.h"
#import "KConfig.h"
#import "KTabContents.h"
#import "KBrowser.h"
#import "KBrowserWindowController.h"
#import "KSourceHighlighter.h"
#import "KStyle.h"
#import "KScroller.h"
#import "KScrollView.h"
#import "KLangMap.h"


@interface KTabContents (Private)
- (void)undoManagerCheckpoint:(NSNotification*)notification;
@end

@implementation KTabContents

@synthesize isDirty = isDirty_,
            textEncoding = textEncoding_,
            style = style_;

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
  
  // 1=unlocked, 0=locked
  sourceHighlightSem_ = new HSemaphore(1);

  // Set other default values
  textEncoding_ = NSUTF8StringEncoding;
  
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


- (id)initWithContentsOfURL:(NSURL *)absoluteURL
                     ofType:(NSString *)typeName
                      error:(NSError **)outError {
  // This may be called by a background thread
  DLOG_TRACE();
  self = [self initWithBaseTabContents:nil];
  assert(self);
  DLOG_EXPR(absoluteURL);
  DLOG_EXPR(typeName);
  self = [super initWithContentsOfURL:absoluteURL
                               ofType:typeName
                                error:outError];
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


- (NSString*)langId {
  return langId_;
}

- (void)setLangId:(NSString*)langId {
  if (langId_ != langId) {
    langId_ = [langId retain];
    DLOG("%@ changed langId to '%@'", self, langId_);
    if (sourceHighlighter_->setLanguage(langId_)) {
      [self queueCompleteHighlighting];
    }
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
  assert(browser);
  [self addWindowController:browser.windowController];
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


- (void)undoManagerCheckpoint:(NSNotification*)notification {
  DLOG_EXPR([self isDocumentEdited]);
  BOOL isDirty = [self isDocumentEdited];
  if (isDirty_ != isDirty) {
    isDirty_ = isDirty;
    [self documentDidChangeDirtyState];
  }
}


- (void)documentDidChangeDirtyState {
  DLOG("documentDidChangeDirtyState");
  //self.title = @"*";
}


#pragma mark -
#pragma mark NSTextViewDelegate implementation

// For some reason, this is called for _each edit_ to the text view so it needs
// to be fast.
/*- (NSUndoManager *)undoManagerForTextView:(NSTextView *)aTextView {
  return undoManager_;
}*/


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


- (void)setFileURL:(NSURL *)url {
  [super setFileURL:url];
  if (url && [url path]) {
    self.icon = [[NSWorkspace sharedWorkspace] iconForFile:[url path]];
    self.title = [url lastPathComponent];
  } else {
    self.title = _kDefaultTitle;
    self.icon = _kDefaultIcon;
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
    [mastr attribute:KStyleElement::ClassAttributeName
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
    [mastr attribute:KStyleElement::ClassAttributeName
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


- (void)highlightTextStorage:(NSTextStorage*)textStorage
                     inRange:(NSRange)range
              waitUntilReady:(BOOL)wait {
  //NSLog(@"highlightTextStorage");
  /*if (textStorage.length == 0)
    return;
  if (wait) {
    if (sourceHighlightSem_->get() != 0L) {
      return;
    }
  } else if (sourceHighlightSem_->tryGet() != 0L) {
    return;
  }*/
  
  [textStorage beginEditing];
  sourceHighlighter_->highlight(textStorage, style_, range);
  hasPendingInitialHighlighting_ = NO;
  [textStorage endEditing];
  //sourceHighlightSem_->put();
}


- (void)queueCompleteHighlighting {
  if (!hasPendingInitialHighlighting_) {
    hasPendingInitialHighlighting_ = YES;
    DLOG("queueCompleteHighlighting");
    K_DISPATCH_BG_ASYNC({ [self highlightCompleteDocument]; });
  }
}


- (void)highlightCompleteDocument {
  static NSRange range = NSMakeRange(NSNotFound, 0);
  [self highlightTextStorage:textView_.textStorage
                     inRange:range
              waitUntilReady:YES];
}


- (void)textStorageWillProcessEditing:(NSNotification *)notification {
  NSTextStorage	*textStorage = notification.object;
  NSRange	editedRange = [textStorage editedRange];
  
  // Syntax highlight preamble
  if (!hasPendingInitialHighlighting_) {
    //if (sourceHighlightSem_->tryGet() == 0L) {
      sourceHighlighter_->willHighlight(textStorage, editedRange);
    //  sourceHighlightSem_->put();
    //}
  }
}


- (void)textStorageDidProcessEditing:(NSNotification*)notification {
	// invoked after editing occured

  // We sometimes initialize documents on background threads where the initial
  // "filling" causes this method to be called. We're a noop in that case.
  if (isProcessingTextStorageEdit_ || ![NSThread isMainThread])
    return;

  NSTextStorage	*textStorage = [notification object];
	NSRange	editedRange = [textStorage editedRange];
	int	changeInLen = [textStorage changeInLength];
  if (changeInLen == 0) {
    // text attributes changed -- not interested
    return;
  }
  
  isProcessingTextStorageEdit_ = YES;
  
  BOOL wasInUndoRedo = [[self undoManager] isUndoing] ||
                       [[self undoManager] isRedoing];
  DLOG("editedRange: %@, changeInLen: %d, wasInUndoRedo: %@",
       NSStringFromRange(editedRange), changeInLen,
       wasInUndoRedo ? @"YES":@"NO");

  // mark as dirty if not already dirty
  if (!isDirty_) {
    [self updateChangeCount:NSChangeReadOtherContents];
  }
  
  // Syntax highlight
  if (!hasPendingInitialHighlighting_) {
    [self highlightTextStorage:textStorage
                       inRange:editedRange
                waitUntilReady:NO];
  };
  
  // this makes the edit an undoable entry (otherwise each "group" of edits will
  // be undoable, which is not fine-grained enough for us)
  [textView_ breakUndoCoalescing];
  
  isProcessingTextStorageEdit_ = NO;
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


// Generate data from text
- (NSData*)dataOfType:(NSString*)typeName error:(NSError **)outError {
  DLOG_EXPR(typeName);
  [textView_ breakUndoCoalescing]; // preserves undo state
  NSData *data = [[textView_ string] dataUsingEncoding:textEncoding_
                                  allowLossyConversion:NO];
  if (!data) {
    *outError = [NSError kodErrorWithDescription:@"Failed to parse data"];
  }
  return data;
}


// Generate text from data
- (BOOL)readFromData:(NSData *)data
              ofType:(NSString *)typeName
               error:(NSError **)outError {
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
    
    // guess language if no language has been set
    if (!langId_)
      [self guessLanguageBasedOnUTI:typeName textContent:text];
    
    return YES;
  }
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

// fs extended attributes to write with the document
- (NSDictionary *)fileAttributesToWriteToURL:(NSURL *)url
                                      ofType:(NSString *)typeName
                            forSaveOperation:(NSSaveOperationType)saveOperation
                         originalContentsURL:(NSURL *)originalContentsURL
                                       error:(NSError **)error {
  NSDictionary *sd = [super fileAttributesToWriteToURL:url
                                                ofType:typeName
                                      forSaveOperation:saveOperation
                                   originalContentsURL:originalContentsURL
                                                 error:error];
  DLOG_TRACE();
  NSMutableDictionary* d = [NSMutableDictionary dictionaryWithDictionary:sd];
  [d setObject:@"moset" forKey:@"KTabContentsCursorState"];
  return d;
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

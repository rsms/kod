#include <sys/xattr.h>

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
  
  // Default text encoding for new "Untitled" documents
  textEncoding_ = NSUTF8StringEncoding;
  
  // Default highlighter
  sourceHighlighter_.reset(new KSourceHighlighter);
  highlightingEnabled_ = YES;

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
  [textView_ setAllowsDocumentBackgroundColorChange:NO];
  [textView_ setAllowsImageEditing:NO];
  [textView_ setRichText:NO];
  [textView_ setImportsGraphics:NO];
  [textView_ turnOffKerning:self]; // we are monospace (robot voice)
  [textView_ setAutoresizingMask:NSViewWidthSizable];
  [textView_ setUsesFindPanel:YES];
  [textView_ setTextContainerInset:NSMakeSize(2.0, 4.0)];
  [textView_ setVerticallyResizable:YES];
	[textView_ setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
  
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
  
  // Start with the empty style and load the default style
  style_ = [[KStyle emptyStyle] retain];
  [KStyle defaultStyleWithCallback:^(NSError *err, KStyle *style) {
    if (err) [NSApp presentError:err];
    else self.style = style;
  }];
  
  // debug xxx
  /*[self retain];
  h_dispatch_delayed_main(10000, ^{
    DLOG("loading new style after 10s");
    NSURL* url = KConfig.resourceURL(@"style/bright.css");
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
  if (style_) {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self
                  name:KStyleDidChangeNotification
                object:style_];
    [style_ release];
  }
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
  [self refreshStyle];
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


#pragma mark -
#pragma mark Notifications


- (void)styleDidChange:(NSNotification*)notification {
  DLOG("styleDidChange:%@", notification);
  // TODO: [self reloadStyle];
}


- (BOOL)validateUserInterfaceItem:(id < NSValidatedUserInterfaceItem >)item {
  BOOL y;
  if ([item action] == @selector(saveDocument:)) {
    y = [self isDocumentEdited] || ![self fileURL];
  } else {
    y = [super validateUserInterfaceItem:item];
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

#pragma mark -
#pragma mark Highlighting


- (NSDictionary*)defaultTextAttributes {
  NSDictionary *attrs;
  if (style_) {
    KStyleElement *styleElement = [style_ defaultStyleElement];
    kassert(styleElement);
    attrs = styleElement->textAttributes();
  } else {
    attrs = [NSDictionary dictionaryWithObjectsAndKeys:
      textView_.font, NSFontAttributeName,
      textView_.textColor, NSForegroundColorAttributeName,
      nil];
  }
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
  KStyle *style = style_ ? style_ : [KStyle emptyStyle];
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
    DLOG("highlight --CANCEL & WAIT--");
    
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
  DLOG("highlight --LOCKED--");
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
    DLOG("highlight --PROCESS-- %@ %@ %@", NSStringFromRange(editedRange),
         state, NSStringFromRange(stateRange));
    #endif
    NSRange affectedRange =
        sourceHighlighter_->highlight(textStorage, style_, editedRange, state,
                                      stateRange, changeInLength);
    
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
      K_DISPATCH_MAIN_ASYNC({
        if (!sourceHighlighter_->isCancelled()) {
          DLOG("highlight --FLUSH-START-- %@", NSStringFromRange(affectedRange));
          [textStorage beginEditing];
          sourceHighlighter_->endFlushBufferedAttributes(textStorage);
          //[textStorage invalidateAttributesInRange:affectedRange];
          [textStorage endEditing];
          DLOG("highlight --FLUSH-END--");
        }
        highlightSem_.put();
        DLOG("highlight --FREED-- (cancelled: %@)",
             sourceHighlighter_->isCancelled() ? @"YES":@"NO");
      });
    }
    
    [pool drain];
  });
  
  return YES;
}


- (BOOL)highlightTextStorage:(NSTextStorage*)textStorage
                     inRange:(NSRange)range
           withModifiedState:(KSourceHighlightState*)state
                     inRange:(NSRange)stateRange {
K_DEPRECATED; // use deferHighlightTextStorage:inRange:
/*  if (textStorage.length == 0) {
    return YES;
  }
  
  DLOG("highlightTextStorage --START-- (%s)",
       [NSThread isMainThread] ? "on main thread" : "in background");
  sourceHighlighter_->beginBufferingOfAttributes();
  NSRange affectedRange =
      sourceHighlighter_->highlight(textStorage, style_, range,
                                    lastEditedHighlightState_,
                                    lastEditedHighlightStateRange_);
  // this is needed to minimize the time the UI is locked
  // BUG: when deleting a large piece of text, a "lagging"/"slow rendering"
  // effect occurs which is very weird
  DLOG("highlightTextStorage --FLUSH-- %@", NSStringFromRange(affectedRange));
  [textStorage beginEditing];
  BOOL did_set = hatomic_flags_set(&stateFlags_, kHighlightingIsFlushing);
  assert(did_set == YES);
  sourceHighlighter_->endFlushBufferedAttributes(textStorage);
  [textStorage endEditing];
  DLOG("highlightTextStorage --END--");
  // We need to clear the kHighlightingIsFlushing flag on the main thread
  // because directly after endEditing is called above,
  // |textStorageDidProcessEditing| will be invoked since Cocoa holds a lock and
  // waits during |beginEditing|->|endEditing|.
  // Now, in |textStorageDidProcessEditing| we check if we are currently
  // flushing highlight attributes, thus the flag must still be set, but cleared
  // at the next runloop tick, which is what this block accomplishes.
  // The |kHighlightingIsProcessing| flag needs to be cleared after the
  // |kHighlightingIsFlushing| flag, so we simply clear it in the same block.
  K_DISPATCH_MAIN_ASYNC({
    hatomic_flags_clear(&stateFlags_, kHighlightingIsFlushing);
  });
  return YES;*/
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
    //KSourceHighlightState *hlstate =
    //  [textStorage attribute:KSourceHighlightStateAttribute
    //                 atIndex:range.location
    //   longestEffectiveRange:&highlightStateRange
    //                 inRange:NSMakeRange(0, textStorage.length)];
    //DLOG("state[2] at %u -> %@ '%@'", range.location, hlstate,
    //  [textStorage.string substringWithRange:lastEditedHighlightStateRange_]);
  } else { // if (textStorage.length == 0)
    lastEditedHighlightState_ = nil;
    didEditCharacters = (replacementString.length != 0);
  }
  
  // Cancel any in-flight highlighting
  if (didEditCharacters && highlightingEnabled_) {
    DLOG("text edited -- '%@' -> '%@' at %@",
     [textView_.textStorage.string substringWithRange:range],
     replacementString, NSStringFromRange(range));
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


// invoked after an editing occured, but before it's been committed
// Has the nasty side effect of losing the selection when applying attributes
//- (void)textStorageWillProcessEditing:(NSNotification *)notification {}

// invoked after an editing occured which has just been committed
//- (void)textStorageDidProcessEditing:(NSNotification *)notification {}

- (void)textStorageDidProcessEditing:(NSNotification *)notification {
	// invoked after an editing occured, but before it's been committed

  NSTextStorage	*textStorage = [notification object];
  
  // no-op unless characters where edited
  if (!(textStorage.editedMask & NSTextStorageEditedCharacters)) {
    return;
  }
  
  // we do not process edits when we are loading
  if (isLoading_) return;

	NSRange	editedRange = [textStorage editedRange];
	int	changeInLength = [textStorage changeInLength];
  /*if (changeInLength == 0 && !lastEditedHighlightState_) {
    // text attributes changed -- not interested
    return;
  }*/
  
  BOOL wasInUndoRedo = [[self undoManager] isUndoing] ||
                       [[self undoManager] isRedoing];
  DLOG_RANGE(editedRange, textStorage.string);
  #if !NDEBUG
  //unsigned em = textStorage.editedMask;
  //NSString *editedMaskStr = ;
  #endif
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
        [self readFromData:data ofType:self.fileType error:&err];
      }
      
      // make sure isLoading is false
      self.isLoading = NO;
      
      // if an error occured, handle it
      if (err) {
        self.isCrashed = YES; // FIXME
        [NSApp presentError:err];
      } else {
        // we are done -- allow editing
        [textView_ setEditable:YES];
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
               error:(NSError **)outError {
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
  }
  return YES;
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
}


#pragma mark -
#pragma mark NSObject etc


- (NSString*)description {
  return [NSString stringWithFormat:@"<%@@%p '%@'>",
      NSStringFromClass([self class]), self, self.title];
}

@end

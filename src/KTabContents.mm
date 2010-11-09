#import "KTabContents.h"
#import "KBrowser.h"
#import "KSyntaxHighlighter.h"
#import "KBrowserWindowController.h"
#import "KScroller.h"
#import "KScrollView.h"

#import "NSError+KAdditions.h"
#import <ChromiumTabs/common.h>

@interface KTabContents (Private)
- (void)undoManagerCheckpoint:(NSNotification*)notification;
@end

@implementation KTabContents

@synthesize isDirty = isDirty_;
@synthesize textEncoding = textEncoding_;

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


- (void)_initOnMain:(id)_ {
  if (![NSThread isMainThread]) {
    [self performSelectorOnMainThread:@selector(_initOnMain:)
                           withObject:_
                        waitUntilDone:NO];
    return;
  }

	// Register for "text changed" notifications of our text storage:
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self
         selector:@selector(textStorageDidProcessEditing:)
             name:NSTextStorageDidProcessEditingNotification
					 object:[textView_ textStorage]];

  // Observe when the document is modified so we can update the UI accordingly
	[nc addObserver:self
         selector:@selector(undoManagerCheckpoint:)
             name:NSUndoManagerCheckpointNotification
					 object:undoManager_];
}


// This is the main initialization method
- (id)initWithBaseTabContents:(CTTabContents*)baseContents {
  // Note: This might be called from a background thread and must thus be
  // thread-safe.
  if (!(self = [super init])) return nil;

  // Default title and icon
  self.title = _kDefaultTitle;
  self.icon = _kDefaultIcon;

  // Set other default values
  textEncoding_ = NSUTF8StringEncoding;

  // Save a weak reference to the undo manager (performance reasons)
  undoManager_ = [self undoManager]; assert(undoManager_);

  // Create a NSTextView
  textView_ = [[NSTextView alloc] initWithFrame:NSZeroRect];
  [textView_ setDelegate:self];
  [textView_ setAllowsUndo:YES];
  [textView_ setFont:[isa defaultFont]];
  [textView_ setBackgroundColor:
      [NSColor colorWithCalibratedWhite:0.1 alpha:1.0]];
  [textView_ setTextColor:[NSColor whiteColor]];
  [textView_ setInsertionPointColor:[NSColor cyanColor]];
  [textView_ setAutomaticLinkDetectionEnabled:YES];
  [textView_ setAutoresizingMask:          NSViewMaxYMargin|
                          NSViewMinXMargin|NSViewWidthSizable|NSViewMaxXMargin|
                                           NSViewHeightSizable|
                                           NSViewMinYMargin];
  [textView_ setUsesFindPanel:YES];

  // Create a NSScrollView to which we add the NSTextView
  KScrollView *sv = [[KScrollView alloc] initWithFrame:NSZeroRect];
  [sv setDocumentView:textView_];
  [sv setHasVerticalScroller:YES];

  // Set the NSScrollView as our view
  view_ = sv;

  // Let the global document controller know we came to life
  [[NSDocumentController sharedDocumentController] addDocument:self];
  
  [self _initOnMain:nil];

  return self;
}


- (KSyntaxHighlighter*)syntaxHighlighter {
  if (!syntaxHighlighter_ && [NSThread isMainThread]) {
    syntaxHighlighter_ = [[KSyntaxHighlighter alloc]
        initWithDefinitionsFromFile:@"cpp.lang"
                      styleFromFile:@"sh_bipolar.css"];
  }
  return syntaxHighlighter_;
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

  // Defer highlighting to next tick and also make sure it's run in main
  [self performSelectorOnMainThread:@selector(highlightCompleteDocument:)
                         withObject:self
                      waitUntilDone:NO];

  return self;
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

- (void)highlightCompleteDocument:(id)sender {
  NSTextStorage *textStorage = textView_.textStorage;
  if ([textStorage length]) {
    KSyntaxHighlighter *syntaxHighlighter = self.syntaxHighlighter;
    if (syntaxHighlighter) {
      [syntaxHighlighter highlightTextStorage:textStorage
                                      inRange:NSMakeRange(NSNotFound, 0)];
    }
  }
}

- (void)textStorageDidProcessEditing:(NSNotification*)notification {
	// invoked when editing occured

  // We sometimes initialize documents on background threads where the initial
  // "filling" causes this method to be called. We're a noop in that case.
  if (![NSThread isMainThread]) return;

  NSTextStorage	*textStorage = [notification object];
	NSRange	range = [textStorage editedRange];
	int	changeInLen = [textStorage changeInLength];
  if (changeInLen == 0) {
    // text attributes changed -- not interesting for this code branch
    return;
  }
  BOOL completeDocument = (range.location == 0 &&
                           changeInLen == [textStorage length]);
  BOOL wasInUndoRedo = [[self undoManager] isUndoing] ||
                       [[self undoManager] isRedoing];
  DLOG("range: %@, changeInLen: %d, wasInUndoRedo: %@",
       NSStringFromRange(range), changeInLen, wasInUndoRedo ? @"YES":@"NO");

  // mark as dirty if not already dirty
  if (!isDirty_) {
    [self updateChangeCount:NSChangeReadOtherContents];
  }
  
  // Syntax highlight
  KSyntaxHighlighter *syntaxHighlighter = self.syntaxHighlighter;
  if (syntaxHighlighter && syntaxHighlighter.currentTextStorage == nil) {
    NSRange highlightRange;
    if (completeDocument) {
      NSLog(@"COMPLETE");
      highlightRange = NSMakeRange(NSNotFound, 0); // whole document
    } else {
      NSString *text = [textStorage string];
      highlightRange = [text lineRangeForRange:range];
    }
    if (highlightRange.length != 0) {
      DLOG("highlightRange: %@", highlightRange.location == NSNotFound
                          ? @"{NSNotFound, 0}"
                          : NSStringFromRange(highlightRange));
      [self.syntaxHighlighter highlightTextStorage:textStorage
                                           inRange:highlightRange];
    }
  }

  // this makes the edit an undoable entry (otherwise each "group" of edits will
  // be undoable, which is not fine-grained enough for our application)
  [textView_ breakUndoCoalescing];
}

// Generate data from text
- (NSData*)dataOfType:(NSString*)typeName error:(NSError **)outError {
  DLOG_EXPR(typeName);
  [textView_ breakUndoCoalescing]; // preserves undo state
  return [[textView_ string] dataUsingEncoding:textEncoding_
                          allowLossyConversion:NO];
}

// Generate text from data
- (BOOL)readFromData:(NSData *)data
              ofType:(NSString *)typeName
               error:(NSError **)outError {
  NSString *text = [[NSString alloc] initWithData:data encoding:textEncoding_];
  if (!text) {
    WLOG("Failed to parse data. text => nil (data length: %u)", [data length]);
    *outError = [NSError kodErrorWithDescription:@"Failed to parse data"];
    return NO;
  } else {
    [textView_ setString:text];
    // TODO: restore selection(s), possibly by reading from ext. attrs.
    [textView_ setSelectedRange:NSMakeRange(0, 0)];
    [self updateChangeCount:NSChangeCleared];
    isDirty_ = NO;
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

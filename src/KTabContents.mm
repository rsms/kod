#import "KTabContents.h"
#import "KBrowser.h"
#import "NSError+KAdditions.h"
#import <ChromiumTabs/common.h>

@interface KTabContents (Private)
- (void)undoManagerCheckpoint:(NSNotification*)notification;
@end

@implementation KTabContents

static NSImage* _kDefaultIcon = nil;

+ (void)initialize {
  _kDefaultIcon =
      [[[NSWorkspace sharedWorkspace] iconForFile:@"/no/such/file"] retain];
}

-(id)initWithBaseTabContents:(CTTabContents*)baseContents {
  if (!(self = [super init])) return nil;

  // Default title and icon
  self.title = @"Untitled";
  self.icon = _kDefaultIcon;

  // Save a weak reference to the undo manager (performance reasons)
  undoManager_ = [self undoManager]; assert(undoManager_);

  // Create a simple NSTextView
  textView_ = [[NSTextView alloc] initWithFrame:NSZeroRect];
  [textView_ setDelegate:self];
  [textView_ setAllowsUndo:YES];
  [textView_ setFont:[NSFont userFixedPitchFontOfSize:13.0]];
  [textView_ setBackgroundColor:
      [NSColor colorWithCalibratedWhite:0.1 alpha:1.0]];
  [textView_ setTextColor:[NSColor whiteColor]];
  [textView_ setInsertionPointColor:[NSColor cyanColor]];
  [textView_ setAutomaticLinkDetectionEnabled:YES];
  [textView_ setAutoresizingMask:          NSViewMaxYMargin|
                          NSViewMinXMargin|NSViewWidthSizable|NSViewMaxXMargin|
                                           NSViewHeightSizable|
                                           NSViewMinYMargin];

  // Create a NSScrollView to which we add the NSTextView
  NSScrollView *sv = [[NSScrollView alloc] initWithFrame:NSZeroRect];
  [sv setDocumentView:textView_];
  [sv setHasVerticalScroller:YES];

	// Register for "text changed" notifications of our text storage:
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self
         selector:@selector(textStorageDidProcessEditing:)
             name:NSTextStorageDidProcessEditingNotification
					 object:[textView_ textStorage]];

  // Enable the standard find panel
  [textView_ setUsesFindPanel:YES];

  // Set the NSScrollView as our view
  view_ = sv;

  // Observe when the document is modified so we can update the UI accordingly
	[nc addObserver:self
         selector:@selector(undoManagerCheckpoint:)
             name:NSUndoManagerCheckpointNotification
					 object:undoManager_];

  return self;
}


- (id)initWithContentsOfURL:(NSURL *)absoluteURL
                     ofType:(NSString *)typeName
                      error:(NSError **)outError {
  self = [self initWithBaseTabContents:nil];
  assert(self);
  self = [super initWithContentsOfURL:absoluteURL
                               ofType:typeName
                                error:outError];
  return self;
}

- (void)tabWillCloseInBrowser:(CTBrowser*)browser atIndex:(NSInteger)index {
  [super tabWillCloseInBrowser:browser atIndex:index];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
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
  self.title = @"*";
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

- (void)setFileURL:(NSURL *)absoluteURL {
  [super setFileURL:absoluteURL];
  self.icon = [[NSWorkspace sharedWorkspace] iconForFile:[absoluteURL path]];
}

- (NSString*)displayName {
  return self.title;
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

- (void)textStorageDidProcessEditing:(NSNotification*)notification {
	// invoked when editing occured
  NSTextStorage	*textStorage = [notification object];
	NSRange	range = [textStorage editedRange];
	int	changeInLen = [textStorage changeInLength];
	BOOL wasInUndoRedo = [[self undoManager] isUndoing] ||
                       [[self undoManager] isRedoing];
  DLOG_EXPR(range);
	DLOG_EXPR(changeInLen);
	DLOG_EXPR(wasInUndoRedo);

  // mark as dirty if not already dirty
  if (!isDirty_) {
    [self updateChangeCount:NSChangeReadOtherContents];
  }

  // this makes each edit to the text storage an undoable entry
  [textView_ breakUndoCoalescing];
}

// Generate data from text
- (NSData*)dataOfType:(NSString*)typeName error:(NSError **)outError {
  // TODO: enable text encoding to be set by the user
  DLOG_EXPR(typeName);
  [textView_ breakUndoCoalescing]; // preserves undo state
  return [[textView_ string] dataUsingEncoding:NSUTF8StringEncoding
                          allowLossyConversion:NO];
}

// Generate text from data
- (BOOL)readFromData:(NSData *)data
              ofType:(NSString *)typeName
               error:(NSError **)outError {
  NSString *text = [[NSString alloc] initWithData:data
                                         encoding:NSUTF8StringEncoding];
  if (!text) {
    WLOG("Failed to parse data. text => nil (data length: %u)", [data length]);
    *outError = [NSError kodErrorWithDescription:@"Failed to parse data"];
    return NO;
  } else {
    [textView_ setString:text];
    // TODO: restore selection(s), possibly by reading from ext. attrs.
    [textView_ setSelectedRange:NSMakeRange(0, 0)];
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
  NSMutableDictionary* d = [NSMutableDictionary dictionaryWithDictionary:sd];
  [d setObject:@"moset" forKey:@"KTabContentsCursorState"];
  return d;
}


#pragma mark CTTabContents implementation

-(void)viewFrameDidChange:(NSRect)newFrame {
  // We need to recalculate the frame of the NSTextView when the frame changes.
  // This happens when a tab is created and when it's moved between windows.
  [super viewFrameDidChange:newFrame];
  NSClipView* clipView = [[view_ subviews] objectAtIndex:0];
  NSTextView* tv = [[clipView subviews] objectAtIndex:0];
  NSRect frame = NSZeroRect;
  frame.size = [(NSScrollView*)(view_) contentSize];
  [tv setFrame:frame];
}

@end

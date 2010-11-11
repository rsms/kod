#import "KTabContents.h"
#import "KBrowser.h"
#import "KSyntaxHighlighter.h"
#import "KBrowserWindowController.h"
#import "KScroller.h"
#import "KScrollView.h"
#import "NSString-ranges.h"

#import "NSError+KAdditions.h"
#import <ChromiumTabs/common.h>
#import <dispatch/dispatch.h>

#define K_DISPATCH_MAIN_ASYNC(code)\
  dispatch_async(dispatch_get_main_queue(),^{ \
    NSAutoreleasePool *__arpool = [NSAutoreleasePool new]; \
    code \
    [__arpool drain]; \
  })

#define K_DISPATCH_MAIN_SYNC(code)\
  dispatch_sync(dispatch_get_main_queue(),^{ \
    NSAutoreleasePool *__arpool = [NSAutoreleasePool new]; \
    code \
    [__arpool drain]; \
  })

#define K_DISPATCH_BG_ASYNC(code)\
  dispatch_async(dispatch_get_global_queue(0,0),^{ \
    NSAutoreleasePool *__arpool = [NSAutoreleasePool new]; \
    code \
    [__arpool drain]; \
  })



#define DLOG_RANGE(r, str) do { \
    NSString *s = @"<index out of bounds>"; \
    @try{ s = [str substringWithRange:(r)]; }@catch(id e){} \
    DLOG( #r " %@ \"%@\"", NSStringFromRange(r), s); \
  } while (0)


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





- (void)_initOnMain {
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

  // Observe when the document is modified so we can update the UI accordingly
	[nc addObserver:self
         selector:@selector(undoManagerCheckpoint:)
             name:NSUndoManagerCheckpointNotification
					 object:undoManager_];

  // XXX DEBUG
  #if !NDEBUG
  //[self debugSimulateTextAppending:self];
  #endif
}


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


- (void)debugSimulateSwitchStyle:(id)x {
  #if 0  // load an alternative style
  KSyntaxHighlighter* syntaxHighlighter = self.syntaxHighlighter;  // lazy
  [syntaxHighlighter loadStyleFile:@"bright"];
  [syntaxHighlighter recolorTextStorage:textView_.textStorage];
  #endif
  
  #if 0  // reload style every 2 seconds
  [self performSelector:@selector(debugReloadStyle:)
             withObject:self
             afterDelay:2.0];
  #endif
}


- (void)debugReloadStyle:(id)x {
  [self.syntaxHighlighter reloadStyle];
  [self performSelector:@selector(debugReloadStyle:)
             withObject:self
             afterDelay:2.0];
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
  
  [self _initOnMain];

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
  if (self) {
    // Defer highlighting
    // TODO: only if highlighting is active
    K_DISPATCH_MAIN_ASYNC({
      [self queueCompleteHighlighting:self];
    });
  } else assert(outError && *outError);
  
  return self;
}


- (KSyntaxHighlighter*)syntaxHighlighter {
  if (!syntaxHighlighter_) {
    if (![NSThread isMainThread]) {
      // have the code run in the main thread
      K_DISPATCH_MAIN_SYNC({ [self syntaxHighlighter]; });
      // return the object created on main
      return syntaxHighlighter_;
    }
    NSString *lang = nil;
    NSURL *url = [self fileURL];
    if (url) {
      NSString *filename = [[url path] lastPathComponent];
      lang = [KSyntaxHighlighter languageFileForFilename:filename];
    }
    // default lang file
    if (!lang || lang.length == 0) {
      lang = @"default";
    }
    syntaxHighlighter_ =
        [[KSyntaxHighlighter alloc] initWithLanguageFile:lang
                                               styleFile:@"default"];
  }
  return syntaxHighlighter_;
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

/*- (IBAction)selectNextElement:(id)sender {
  NSMutableAttributedString *mastr = textView_.textStorage;
  NSString *text = [mastr string];
  NSCharacterSet *cs = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  NSRange range = [textView_ selectedRange];
  range.location += range.length;
  range.length = mastr.length - range.location;
  [mastr enumerateAttribute:KTextFormatter::ClassAttributeName
                    inRange:range
                    options:0
                 usingBlock:^(id value, NSRange range, BOOL *stop) {
    
    NSRange r = [text rangeOfCharacterFromSet:cs options:0 range:range];
    if (r.location == range.location) {
      if (r.length == range.length) {
        // all characters where SP|TAB|CR|LF
        DLOG("all blanks");
        return;
      }
      range.location += r.length;
      range.length -= r.length;
    }
    DLOG("find last in range %@ \"%@\"",
         NSStringFromRange(range), [text substringWithRange:range]);
    r = [text rangeOfCharacterFromSet:cs options:NSBackwardsSearch range:range];
    DLOG("r = %@ \"%@\"",
         NSStringFromRange(r), [text substringWithRange:r]);
    if (r.location != NSNotFound) {
      NSUInteger end = r.location + r.length;
      DLOG("A");
      if (end == range.location + range.length) {
        DLOG("B");
        //range.length -= MIN(r.length, range.length);
        range.length -= r.length;
      } else DLOG("C");
    }
    
    DLOG("[2] %@ %@ => \"%@\"", value,
         NSStringFromRange(range), [text substringWithRange:range]);
    
    [textView_ setSelectedRange:range];
    *stop = YES;
  }];
}*/


- (IBAction)selectNextElement:(id)sender {
  NSMutableAttributedString *mastr = textView_.textStorage;
  NSString *text = mastr.string;
  NSCharacterSet *cs = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  NSRange selectedRange = [textView_ selectedRange];
  NSRange range = selectedRange;
  NSUInteger index = range.location + range.length;
  
  while (YES) {
    NSUInteger maxLength = mastr.length;
    NSDictionary *attrs = [mastr attributesAtIndex:index
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
    NSDictionary *attrs = [mastr attributesAtIndex:index
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


- (void)queueCompleteHighlighting:(id)sender {
  assert(hasPendingInitialHighlighting_ == NO);
  hasPendingInitialHighlighting_ = YES;
  DLOG("queueCompleteHighlighting");
  K_DISPATCH_BG_ASYNC({ [self highlightCompleteDocument:sender]; });
}


- (void)highlightCompleteDocument:(id)sender {
  NSTextStorage *textStorage = textView_.textStorage;
  NSMutableAttributedString *mastr = textStorage;
  
  // if we are not on main we need to create a copy of the text storage to avoid
  // pthread mutex deadlocks.
  if (![NSThread isMainThread]) {
    mastr = [[NSMutableAttributedString alloc] initWithAttributedString:mastr];
  }
  
  if ([textStorage length]) {
    KSyntaxHighlighter *syntaxHighlighter = self.syntaxHighlighter;
    assert(syntaxHighlighter != nil);
    NSRange range = NSMakeRange(NSNotFound, 0);
    [syntaxHighlighter highlightMAString:mastr
                                 inRange:range
                              deltaRange:range];
  }
  
  // if we where forced to make a copy of the text, swap it back
  if (mastr != textStorage) {
    K_DISPATCH_MAIN_ASYNC({
      NSArray *selectedRanges = textView_.selectedRanges;
      [textStorage replaceCharactersInRange:NSMakeRange(0, textStorage.length)
                       withAttributedString:mastr];
      //[mastr release]; // this causes double frees... wtf?!
      @try {
        textView_.selectedRanges = selectedRanges;
      } @catch (id e) {
        WLOG("gracefully failed to restore selections after hardcore "
             "background highlighting action");
        // in this case the text changed length which is a used action and not
        // a serious error. Just the selection which is (partially) lost.
      }
      hasPendingInitialHighlighting_ = NO;
    });
  } else if (hasPendingInitialHighlighting_) {
    K_DISPATCH_MAIN_ASYNC({
      hasPendingInitialHighlighting_ = NO; // FIXME run in main
    });
    
    //NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    // NSObject emit, on ...
    
    //[self on:@"highlightComplete", ^{
    //  hasPendingInitialHighlighting_ = NO;
    //}]
  }
}


- (void)textStorageDidProcessEditing:(NSNotification*)notification {
	// invoked after editing occured

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
  NSUInteger textLength = textStorage.length;
  BOOL completeDocument = (range.location == 0 &&
                           range.length == textLength);
  BOOL wasInUndoRedo = [[self undoManager] isUndoing] ||
                       [[self undoManager] isRedoing];
  DLOG("range: %@, changeInLen: %d, wasInUndoRedo: %@",
       NSStringFromRange(range), changeInLen, wasInUndoRedo ? @"YES":@"NO");

  // mark as dirty if not already dirty
  if (!isDirty_) {
    [self updateChangeCount:NSChangeReadOtherContents];
  }
  
  // Syntax highlight
  if (!hasPendingInitialHighlighting_ && textLength != 0) {
    KSyntaxHighlighter *syntaxHighlighter = self.syntaxHighlighter;
    if (syntaxHighlighter && syntaxHighlighter.currentMAString == nil) {
      NSRange highlightRange, deltaRange;
      NSString *text = [textStorage string];
      if (completeDocument) {
        //DLOG(@"COMPLETE");
        highlightRange = NSMakeRange(NSNotFound, 0); // whole document
        deltaRange = highlightRange;
      } else {
        /*if (range.length != 1 || [text characterAtIndex:range.location] != '\n') {
          // unless newline
          highlightRange = [text lineRangeForRange:range];
        } else {
          highlightRange = range;
        }*/
        NSRange maxRange = NSMakeRange(0, text.length);
        NSUInteger index = range.location;
        if (index > 0) index--;
        [textStorage attribute:KTextFormatter::ClassAttributeName
                       atIndex:index
         longestEffectiveRange:&highlightRange
                       inRange:maxRange];
        highlightRange = NSUnionRange(range, highlightRange);
        
        if (range.location > 0 && range.location < maxRange.length-1) {
          index = range.location + 1;
          NSRange highlightRange2;
          [textStorage attribute:KTextFormatter::ClassAttributeName
                         atIndex:index
           longestEffectiveRange:&highlightRange2
                         inRange:maxRange];
          
          //
          // --experimental line extension BEGIN--
          //
          // This is the case when NOT using line extension:
          //   1. initial state:  "void foo(int a) {"
          //   2. we break "foo": "void fo o(int a) {"
          //   3. "fo o" gets re-highlighted and correctly receives the "norma"
          //      format.
          //   4. we remove the space we added to foo, thus the line become:
          //      "void foo(int a) {"
          //   5. "foo" gets re-highlighted, but since the highlighter determine
          //      element type (format) from _context_ "foo" will incorrectly
          //      receive the "normal" format rather than the "function" format.
          //
          // By including the full line we ensure the highlighter will at least
          // have some context to work with. This is far from optimal and should
          // work in one of the following ways:
          //
          //   a. Expanding the range to include one different element (not
          //      counting whitespace/newlines) in each direction, thus the
          //      above use-case would include "void foo(" at step 4.
          //
          //   b. Use a special text attribute (like how state is tracked with
          //      KHighlightState) which replaces the current
          //      KTextFormatter::ClassAttributeName symbol representing the
          //      format. Maybe a struct e.g:
          //
          //        KTextFormat {
          //           NSString *symbol;
          //           int numberOfPreDependants;
          //           int numberOfPostDependants;
          //        }
          //
          //      Where |numberOfPreDependants| indicates how many elements this
          //      format need to consider when being modified, then when
          //      breaking such an element (step 2. in our use-case above) the
          //      highlighter applies the following calculation to the new
          //      format struct ("normal" in our use-case):
          //
          //        newFormat.numberOfPreDependants = 
          //          MAX(newFormat.numberOfPreDependants,
          //              previousFormat.numberOfPreDependants);
          //
          //      Thus, when we later cut out the " " (space) -- as illustrated
          //      by step 4. in the above use-case -- the highlighter will look
          //      at enough context. Maybe.
          //
          // When there is time, I should probably try to implement (a.).
          // However, it's not a guarantee [find previous non-empty element,
          // find next non-empty element, highlight subrange] is a cheaper
          // operation than [find line range, highlight subrange] -- depends on
          // how element scanning is implemented I guess.
          //
          highlightRange = [text lineRangeForRange:highlightRange];
          //
          // --experimental line extension END--
          //
          
          highlightRange = NSUnionRange(highlightRange, highlightRange2);
        }
        
        deltaRange = range;
      }
      DLOG("highlightRange: %@ \"%@\"", highlightRange.location == NSNotFound
                          ? @"{NSNotFound, 0}"
                          : NSStringFromRange(highlightRange),
                          [text substringWithRange:highlightRange]);
      NSRange nextRange = NSMakeRange(0, 0);
      NSUInteger textEnd = [textStorage length];
      while (nextRange.location != textEnd) {
        nextRange = [syntaxHighlighter highlightMAString:textStorage
                                                 inRange:highlightRange
                                              deltaRange:deltaRange];
        //[textStorage ensureAttributesAreFixedInRange:highlightRange];
        if (nextRange.location == textEnd) {
          DLOG("info: code tree is incomplete (open state at end of document)");
          break;
        } else if (nextRange.location == NSNotFound) {
          break;
        }
        deltaRange = nextRange;
        if (deltaRange.length == 0) {
          deltaRange = [text lineRangeForRange:deltaRange];
          //DLOG("adjusted deltaRange to line: %@", NSStringFromRange(deltaRange));
        }
        // adjust one line break backward
        if (deltaRange.location > 1) {
          deltaRange.location -= 1;
          deltaRange.length += 1;
        }
        DLOG_EXPR(deltaRange);
        highlightRange = deltaRange;
      }
    }
  }
  
  
  // this makes the edit an undoable entry (otherwise each "group" of edits will
  // be undoable, which is not fine-grained enough for us)
  [textView_ breakUndoCoalescing];
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

// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "KTextView.h"
#import "KStyleElement.h"
#import "KScroller.h"
#import "KDocument.h"
#import "HEventEmitter.h"
#import "KWordDictionary.h"
#import "KStyle.h"
#import "KInputBindings.h"
#import "virtual_key_codes.h"
#import "kconf.h"
#import "common.h"

// text container rect adjustments
static NSSize kTextContainerInset = (NSSize){6.0, 4.0}; // {(LR),(TB)}
static CGFloat kTextContainerXOffset = -8.0;
static CGFloat kTextContainerYOffset = 0.0;
static NSColor *kColumnGuideColor = nil, *kColumnGuideBackgroundColor = nil;
static CGFloat kColumnGuideWidth = 1.0;


@interface KTextView (Private)
- (void)refreshStyle;
@end


@implementation KTextView

@dynamic automaticallyKeepsIndentation, tabControlsIndentationLevel;
@synthesize wordDictionary = wordDictionary_;


- (id)initWithFrame:(NSRect)frame {
  if (!(self = [super initWithFrame:frame])) return nil;

  [self setAllowsUndo:YES];
  [self setAutomaticLinkDetectionEnabled:NO];
  [self setSmartInsertDeleteEnabled:NO];
  [self setAutomaticQuoteSubstitutionEnabled:NO];
  [self setAllowsDocumentBackgroundColorChange:NO];
  [self setAllowsImageEditing:NO];
  [self setImportsGraphics:NO];
  //[self turnOffKerning:self]; // we are monospace (robot voice)
  [self setAutoresizingMask:NSViewWidthSizable];
  [self setUsesFindPanel:YES];
  [self setTextContainerInset:NSMakeSize(2.0, 4.0)];
  [self setVerticallyResizable:YES];
  [self setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];

  // this bastard causes sporadical crashes when run in other than main
  K_DISPATCH_MAIN_ASYNC( [self setRichText:NO]; );

  // setup inital style
  [self refreshStyle];

  // later adjusted by textContainerOrigin
  [self setTextContainerInset:kTextContainerInset];

  // set values from configuration
  automaticallyKeepsIndentation_ = kconf_bool(@"editor/indent/newline", YES);
  tabControlsIndentationLevel_ = kconf_bool(@"editor/indent/tabkey", YES);
  newlineString_ = [kconf_string(@"editor/text/newline", @"\n") retain];
  indentationString_ =
      [kconf_string(@"editor/text/indentation", @"  ") retain];

  // word dictionary
  wordDictionary_ = [KWordDictionary new];

  // observe configuration changes so we can update cached reps
  [self observe:KConfValueDidChangeNotification
         source:kconf_defaults()
        handler:@selector(configurationValueDidChange:)];

  kassert([KStyle sharedStyle] != nil);
  [self observe:KStyleDidChangeNotification
         source:[KStyle sharedStyle]
        handler:@selector(styleDidChange:)];

  return self;
}


- (void)dealloc {
  [self stopObserving];
  [newlineString_ release];
  [indentationString_ release];
  [wordDictionary_ release];
  [super dealloc];
}


#pragma mark -
#pragma mark Internals


// Note(epatel) This is a very *hacked* way to print a buffer with the help of 'enscript'
// Feel free to fix what ever you think can be improved.
- (void)printWithEnscript_ {
  dispatch_async(dispatch_get_main_queue(), ^ { 
    NSAutoreleasePool *__arpool = [NSAutoreleasePool new]; 
    NSString *tmpPath = [NSString stringWithFormat:@"/tmp/kod-printing-%@", self.document.displayName];
    NSString *tmpPathPS = [NSString stringWithFormat:@"%@.ps", tmpPath];
    NSString *enscriptCommand = [NSString stringWithFormat:@"enscript %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@ %@",
                                 @"--newline=n",
                                 @"--tabsize=4",
                                 @"--encoding=mac",
                                 @"--highlight",
                                 @"--borders",
                                 @"--landscape",
                                 @"--columns=2",
                                 @"--silent",
                                 [NSString stringWithFormat:@"--header='|%@|$D $C'", self.document.displayName],
                                 [NSString stringWithFormat:@"--color=%d", kconf_bool(@"printing/useColors", YES) ? 1 : 0],
                                 [NSString stringWithFormat:@"-o \"%@\"", tmpPathPS], // Out file
                                 [NSString stringWithFormat:@"\"%@\"", tmpPath]]; // In file
    NSString *deleteCommand = [NSString stringWithFormat:@"rm /tmp/kod-printing-*"]; // Clean any previous print files
    NSString *openCommand = [NSString stringWithFormat:@"open \"%@\"", tmpPathPS];
    
    system([deleteCommand cStringUsingEncoding:NSUTF8StringEncoding]);

    // Should pass buffer to stdin of enscript process...but that will need to pass content language to enscript with
    // --highlight=LANG
    NSData *data = [self.string dataUsingEncoding:NSMacOSRomanStringEncoding 
                             allowLossyConversion:YES];
    if ([data writeToFile:tmpPath atomically:NO] == NO) {
      NSLog(@"Failed to write temp file: %@", tmpPath);
    } else {
      system([enscriptCommand cStringUsingEncoding:NSUTF8StringEncoding]);
      system([openCommand cStringUsingEncoding:NSUTF8StringEncoding]);
    }
        
    [__arpool drain]; 
  });
}


#pragma mark -
#pragma mark Printing


- (void)print:(id)sender {
  [self printWithEnscript_];
}


#pragma mark -
#pragma mark Drawing


- (void)drawRect:(NSRect)dirtyRect {
  // Note(rsms): This method is called _several times for each text edit_ and
  // thus need to be cheap (as in "fast" or "high performance")
  [super drawRect:dirtyRect];
  if (columnGuidePosition_ > 0.0 &&
      (kColumnGuideColor || kColumnGuideBackgroundColor)) {
    // read the visibleRect height of the parent clip view (so to avoid
    // drawing our full height)
    NSClipView *clipView = (NSClipView*)self.superview;
    kassert(clipView && [clipView isKindOfClass:[NSClipView class]]);
    NSRect visibleRect = clipView.documentRect;

    // background color?
    if (kColumnGuideBackgroundColor) {
      visibleRect.origin.x = columnGuidePosition_;
      [kColumnGuideBackgroundColor set];
      NSRectFill(visibleRect);
    }

    // border color?
    if (kColumnGuideColor) {
      [kColumnGuideColor set];
      NSPoint srcPoint = NSMakePoint(columnGuidePosition_, 0.0);
      NSPoint dstPoint = NSMakePoint(columnGuidePosition_,
                                     visibleRect.size.height);
      [NSBezierPath setDefaultLineWidth:kColumnGuideWidth];
      [NSBezierPath strokeLineFromPoint:srcPoint toPoint:dstPoint];
    }
  }
}


#pragma mark -
#pragma mark Properties


- (BOOL)automaticallyKeepsIndentation {
  return automaticallyKeepsIndentation_;
}
- (void)setAutomaticallyKeepsIndentation:(BOOL)y {
  automaticallyKeepsIndentation_ = y;
  kconf_set_bool(@"editor/indent/newline", y);
}


- (BOOL)tabControlsIndentationLevel {
  return tabControlsIndentationLevel_;
}
- (void)setTabControlsIndentationLevel:(BOOL)y {
  tabControlsIndentationLevel_ = y;
  kconf_set_bool(@"editor/indent/tabkey", y);
}


- (KDocument*)document {
  KDocument *document = (KDocument*)self.textStorage.delegate;
  kassert([document isKindOfClass:[KDocument class]]);
  return document;
}


- (void)setString:(NSString*)string {
  [super setString:string];
  [self rescanWords];
}


#pragma mark -
#pragma mark Visual aids

- (void)recalculateColumnGuidePosition {
  if (kconf_bool(@"window/columnGuide/enabled", NO)) {
    KStyle *style = [KStyle sharedStyle];
    NSMutableAttributedString *string =
        [[[NSMutableAttributedString alloc] initWithString:@"0"] autorelease];
    NSDictionary *textAttributes =
        [NSDictionary dictionaryWithObject:style.baseFont
                                    forKey:NSFontAttributeName];
    [string setAttributes:textAttributes range:NSMakeRange(0, 1)];
    NSRect rect = [string boundingRectWithSize:NSMakeSize(0, 0)
                                       options:NSStringDrawingOneShot];
    NSUInteger columnPosition = kconf_uint(@"window/columnGuide/position", 80);
    columnGuidePosition_ =
        (rect.size.width * columnPosition) +
        // Note(epatel): Not completly sure about the div with 2(?)
        (kTextContainerInset.width / 2.0) +
        // Note(epatel): This will make the line only one pixel
        // wide due to apple "grid" view
        0.5;
  } else {
    // Special value 0.0 means "don't show a column guide"
    columnGuidePosition_ = 0.;
  }
  [self setNeedsDisplayInRect:[self bounds] avoidAdditionalLayout:YES];
}


#pragma mark -
#pragma mark Notifications


- (void)configurationValueDidChange:(NSNotification*)notification {
  NSString *key = [[notification userInfo] objectForKey:@"key"];
  kassert(key != nil);
  if ([key isEqualToString:@"editor/text/newline"]) {
    h_casid(&newlineString_, kconf_string(@"editor/text/newline", @"  "));
  } else if ([key isEqualToString:@"editor/text/indentation"]) {
    h_casid(&indentationString_,
            kconf_string(@"editor/text/indentation", @"  "));
  } else if ([key isEqualToString:@"editor/indent/newline"]) {
    h_atomic_barrier();
    automaticallyKeepsIndentation_ = kconf_bool(@"editor/indent/newline", YES);
  } else if ([key isEqualToString:@"editor/indent/tabkey"]) {
    h_atomic_barrier();
    tabControlsIndentationLevel_ = kconf_bool(@"editor/indent/tabkey", YES);
  } else if ([key isEqualToString:@"window/columnGuide/enabled"]) {
    [self recalculateColumnGuidePosition];
  }
}


- (void)refreshStyle {
  KStyle *style = [KStyle sharedStyle];

  // font
  if (style.baseFont)
    [self setFont:style.baseFont];

  // recalculate the 80 chars limit (since font might have changed)
  [self recalculateColumnGuidePosition];

  // body/document
  CSSStyle *bodyStyle = [style styleForElementName:@"body"];
  NSColor *color = bodyStyle ? bodyStyle.backgroundColor : nil;
  if (color) {
    [self setBackgroundColor:color];
  } else {
    [self setBackgroundColor:[NSColor colorWithCalibratedWhite:0.1 alpha:1.0]];
  }
  color = bodyStyle.color;
  if (color) {
    [self setTextColor:color];
  } else {
    [self setTextColor:[NSColor colorWithCalibratedWhite:0.9 alpha:1.0]];
  }

  // caret
  CSSStyle *caretStyle = [style styleForElementName:@"caret"];
  color = caretStyle ? caretStyle.color : nil;
  if (color) {
    [self setInsertionPointColor:color];
  } else {
    [self setInsertionPointColor:[NSColor redColor]];
  }

  // selection
  CSSStyle *selectedStyle = [style styleForElementName:@"selection"];
  color = selectedStyle ? selectedStyle.backgroundColor : nil;
  if (!color) {
    color =
        [NSColor colorWithCalibratedRed:0.12 green:0.18 blue:0.27 alpha:1.0];
  }
  [self setSelectedTextAttributes:
      [NSDictionary dictionaryWithObject:color
                                  forKey:NSBackgroundColorAttributeName]];

  // column guide
  // Note: this is shared among all KTextView instances
  CSSStyle *columnGuideStyle = [style styleForElementName:@"column-guide"];
  // color
  color = columnGuideStyle ? columnGuideStyle.color : nil;
  if (!color) {
    // fall back to default color which works for most backgrounds
    color = [NSColor colorWithCalibratedWhite:0.5 alpha:0.3];
  }
  h_casid(&kColumnGuideColor, color);
  // background color
  color = columnGuideStyle ? columnGuideStyle.backgroundColor : nil;
  if (color && [color isEqual:[self backgroundColor]])
    color = nil;
  h_casid(&kColumnGuideBackgroundColor, color);
  // width
  kColumnGuideWidth = columnGuideStyle ? columnGuideStyle.width : 1.0;
  if (k_isnan(kColumnGuideWidth) || kColumnGuideWidth < 1.0)
    kColumnGuideWidth = 1.0;
}


- (void)styleDidChange:(NSNotification*)notification {
  [self refreshStyle];
  NSWindow *window = [self window];
  if (window) {
    [window setViewsNeedDisplay:YES];
  }
}


#pragma mark -
#pragma mark View layout


// overload of NSTextView
- (NSPoint)textContainerOrigin {
  NSPoint origin = [super textContainerOrigin];
  origin.x += kTextContainerXOffset;
  origin.y += kTextContainerYOffset;
  return origin;
}


#pragma mark -
#pragma mark Mouse events


- (void)mouseDown:(NSEvent*)event {
  NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
  NSInteger charIndex = [self characterIndexForInsertionAtPoint:point];

  // Prevent attributesAtIndex:effectiveRange: from throwing its exception
  // by making sure we don't try to get the attributes for the last byte.
  if (charIndex == [[self attributedString] length]) {
    [super mouseDown: event];
    return;
  }

  NSRange effectiveRange;
  NSDictionary *attributes =
      [[self attributedString] attributesAtIndex:charIndex
                                  effectiveRange:&effectiveRange];
  NSString *styleElementKey =
      [attributes objectForKey:KStyleElementAttributeName];

  if (styleElementKey) {
    DLOG("clicked on element of type '%@'", styleElementKey);
    if ([styleElementKey isEqualToString:@"url"]) {
      NSString *effectiveString =
          [[[self textStorage] string] substringWithRange:effectiveRange];
      effectiveString = [effectiveString stringByTrimmingCharactersInSet:
          [NSCharacterSet characterSetWithCharactersInString:@"<>"]];
      NSURL *url = [NSURL URLWithString:effectiveString];
      NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
      if ([workspace openURL:url]) {
        // avoid cursor movement
        return;
      }
    }
  }

  [super mouseDown:event];
}


- (void)mouseMoved:(NSEvent*)event {
  NSPoint loc = [event locationInWindow]; // window coords
  KScroller *scroller =
      (KScroller*)[(NSScrollView*)(self.superview.superview) verticalScroller];
  if (!scroller.isCollapsed) {
    NSRect scrollerFrame = [scroller frame];
    NSPoint loc2 = [scroller convertPointFromBase:loc];
    if (loc2.x <= 0.0) {
      // only delegate mouseMoved to NSTextView if the mouse is outside of the
      // scroller
      [super mouseMoved:event];
    }
  }
}


#pragma mark -
#pragma mark Keyboard events


// return nil for "I handled this"
- (NSEvent*)filterInputEvent:(NSEvent*)event {

  // Bind cmd+] and cmd+[ to indent and de-indent, respectively.
  static BOOL debugDidSet = NO; if (!debugDidSet) { debugDidSet = YES;
    KInputBindings::set(KInputBindings::TextEditorLevel, @"M-]",
        new KSelectorInputAction(@selector(increaseIndentation)));
    KInputBindings::set(KInputBindings::TextEditorLevel, @"M-[",
        new KSelectorInputAction(@selector(decreaseIndentation)));
  }
  KInputAction *action =
      KInputBindings::get(KInputBindings::TextEditorLevel, event);
  //DLOG("input event: %@ -- %@", [event kodInputBindingDescription], event);
  //DLOG("input action -> %p", action);
  if (action && action->perform(self))
    return nil;

  return event;
}


- (void)keyDown:(NSEvent*)event {
  event = [self filterInputEvent:event];
  if (!event) return;

  unsigned short keyCode = event.keyCode;
  if (keyCode == kVK_Tab && tabControlsIndentationLevel_) {
    NSUInteger modifiers = [event modifierFlags];
    if (modifiers & NSAlternateKeyMask) {
      // When pressing TAB+Alt, let a regular tab character be inserted
      [super keyDown:event];
    } else if (modifiers & (NSShiftKeyMask | NSAlphaShiftKeyMask)) {
      [self decreaseIndentation];
    } else {
      [self increaseIndentation];
    }
  } else {
    [super keyDown:event];
  }
}


#pragma mark -
#pragma mark Indentation


- (void)increaseIndentation {
  // make a copy of the selection before we insert text
  NSRange initialSelectedRange = [self selectedRange];
  NSRange finalSelectedRange = initialSelectedRange;

  // reference to the text
  NSString *text = self.textStorage.string;

  if (initialSelectedRange.length == 0) {
    // append |indentationString_| to the start of the current line
    NSUInteger lineStartIndex = [text lineStartForRange:initialSelectedRange];

    // indentation string
    NSString *indentationString = indentationString_;

    // length of indentation
    NSUInteger indentLength = indentationString.length;

    // Find whitespace sequence at the start of the line
    NSRange whitespacePrefixRange =
        [text rangeOfWhitespaceStringAtBeginningOfLineForRange:
         initialSelectedRange substring:NULL];
    if (whitespacePrefixRange.location != NSNotFound) {
      // adjust indent length if there are uneven number of virtual indentations
      NSUInteger reminder = whitespacePrefixRange.length % indentLength;
      if (reminder) {
        indentLength -= reminder;
        indentationString = [indentationString substringToIndex:indentLength];
      }
    }

    // insert indentation string
    [self setSelectedRange:NSMakeRange(lineStartIndex, 0)];
    [self insertText:indentationString];
    finalSelectedRange.location += indentLength;
  } else {
    // expand the effective range to span whole lines
    NSRange effectiveRange = [text lineRangeForRange:initialSelectedRange];

    // local copy of indentLength
    NSUInteger indentLength = indentationString_.length;

    // insert indentation string at the start of each line
    unichar* srcbuf = [text copyOfCharactersInRange:effectiveRange];
    __block NSUInteger dstlen = 0;
    __block NSUInteger dstCapacity = 0;
    __block unichar* dstbuf = NULL;
    __block NSUInteger charactersRemovedFirstLine = NSNotFound;
    __block NSUInteger lineCount = 0;

    // for each line ...
    [NSString kodEnumerateLinesOfCharacters:srcbuf
                                   ofLength:effectiveRange.length
                                  withBlock:^(NSRange lineRange) {
      // assure we have enough space in dstbuf to hold the new string
      NSUInteger requiredCapacity =
            dstlen           // current offset
          + indentLength     // length of first chunk
          + lineRange.length // length of second chunk
          + 1;               // extra char
      if (dstCapacity < requiredCapacity) {
        dstCapacity = requiredCapacity + (lineCount * indentLength);
        dstbuf = (unichar*)realloc(dstbuf, dstCapacity * sizeof(unichar));
      }

      // copy indentation string to dstbuf
      [indentationString_ getCharacters:(dstbuf + dstlen)
                                  range:NSMakeRange(0, indentLength)];
      dstlen += indentLength;

      // copy source characters to dstbuf
      memcpy((void*)(dstbuf+dstlen), (const void*)(srcbuf+lineRange.location),
             sizeof(unichar) * lineRange.length);
      dstlen += lineRange.length;

      // increase line count
      ++lineCount;
    }];

    // Make replacement string
    NSString *replacementString =
        [[[NSString alloc] initWithCharactersNoCopy:dstbuf
                                             length:dstlen
                                       freeWhenDone:YES] autorelease];

    // free temporary char buffer
    dstbuf = NULL;
    free(srcbuf); srcbuf = NULL;

    // replace string
    [self setSelectedRange:effectiveRange];
    [self insertText:replacementString];

    // adjust new selection range
    finalSelectedRange.location += indentLength;
    finalSelectedRange.length += (dstlen - effectiveRange.length) -indentLength;
  }

  // Note(rsms): As we maintain the attributed string, applying text parsing as
  // a result of this change is redundant in many cases. The endEditing call
  // will cause textStorageDidProcessEditing: to be invoked on the parent
  // KDocument, which in turn will tell any active text parser (aka syntax
  // parser) to investigate the changed range. This could be avoided by simply
  // conveying information to textStorageDidProcessEditing: -- BUT! Some text
  // parsers will take different decisions based on the indentation level
  // (e.g. Python), so we keep the current behaviour. What can be done here is
  // simply a performance optimization.

  // Adjust selection
  [self setSelectedRange:finalSelectedRange];
}


- (void)insertNewlineAndMaintainIndentation {
  // string to insert
  NSString *indentationString = newlineString_;

  // reference to the text
  NSString *text = self.textStorage.string;

  // Get current selection
  NSRange selectedRange = [self selectedRange];

  // Find whitespace sequence at the start of the line
  NSString *prefixString;
  NSRange whitespacePrefixRange =
      [text rangeOfWhitespaceStringAtBeginningOfLineForRange:
       selectedRange substring:&prefixString];
  if (whitespacePrefixRange.location != NSNotFound &&
      (selectedRange.location >=
       (whitespacePrefixRange.location + whitespacePrefixRange.length)) ) {
    // append the indentation string
    indentationString =
        [indentationString stringByAppendingString:prefixString];
  }

  // Insert newline and possible indetation string
  [self insertText:indentationString];
}


- (void)insertNewline:(id)sender {
  if (automaticallyKeepsIndentation_) {
    [self insertNewlineAndMaintainIndentation];
  } else {
    [self insertText:newlineString_];
  }
}


- (void)deleteBackward:(id)sender {
  if (automaticallyKeepsIndentation_) {
    // Remove indentationString_.length number of spaces at the beginning of the
    // line if possible

    // if indentation length is less than two, we can delegate to super
    NSUInteger indentLength = indentationString_.length;
    if (indentLength < 2) {
      [super deleteBackward:sender];
      return;
    }

    // make a copy of the selection before we insert text
    NSRange selectedRange = [self selectedRange];
    if (selectedRange.length != 0) {
      // removes selection, not the unit before the caret
      [super deleteBackward:sender];
      return;
    } else if (selectedRange.location == 0) {
      // we are at the beginning of the document
      return;
    }

    // reference to the text
    NSString *text = self.textStorage.string;

    // if previous character is not a space character, delegate to super
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceCharacterSet];
    unichar prevChar = [text characterAtIndex:(selectedRange.location-1)];
    if (prevChar == '\t' || ![whitespace characterIsMember:prevChar]) {
      [super deleteBackward:sender];
      return;
    }

    // find line start
    NSUInteger lineStartIndex = [text lineStartForRange:selectedRange];
    if (selectedRange.location <= lineStartIndex) {
      [super deleteBackward:sender];
      return;
    }

    // find whitespace prefix
    NSRange whitespacePrefixRange =
        [text rangeOfCharactersFromSet:whitespace
                         afterLocation:lineStartIndex
                             substring:nil];
    if (whitespacePrefixRange.location == NSNotFound) {
      [super deleteBackward:sender];
      return;
    }

    // delegate to super if we are positioned beyond the whitespace prefix
    NSUInteger whitespacePrefixEnd = whitespacePrefixRange.location +
                                     whitespacePrefixRange.length;
    if (selectedRange.location > whitespacePrefixEnd) {
      [super deleteBackward:sender];
      return;
    }

    // is there enough whitespace to remove?
    if (whitespacePrefixRange.length < indentLength) {
      // not enough characters
      [super deleteBackward:sender];
      return;
    }

    // adjust indent length if there are uneven number of virtual indentations
    NSUInteger reminder = whitespacePrefixRange.length % indentLength;
    if (reminder)
      indentLength = reminder;

    // remove |indentLength| characters
    whitespacePrefixRange.location += whitespacePrefixRange.length-indentLength;
    whitespacePrefixRange.length = indentLength;
    [self setSelectedRange:whitespacePrefixRange];
    [self insertText:@""];

    return;
  }

  // unless already returned...
  [super deleteBackward:sender];
}


- (void)decreaseIndentation {
  // make a copy of the selection before we insert text
  NSRange initialSelectedRange = [self selectedRange];

  // reference to the text
  NSString *text = self.textStorage.string;

  // find selected line(s) boundary
  NSUInteger lineStart = 0, lineEnd = 0, lineEnd2 = 0;
  [text getLineStart:&lineStart
                 end:&lineEnd
         contentsEnd:NULL
            forRange:initialSelectedRange];
  [text getLineStart:NULL
                 end:&lineEnd2
         contentsEnd:NULL
            forRange:NSMakeRange(initialSelectedRange.location, 0)];
  NSRange lineRange = NSMakeRange(lineStart, lineEnd-lineStart);

  if (lineEnd2 == lineEnd) {
    // this is _not_ a multiline selection, so we take an easier code path

    // Find whitespace sequence at the start of the line
    NSRange whitespacePrefixRange =
        [text rangeOfWhitespaceStringAtBeginningOfLineForRange:
         initialSelectedRange];
    if (whitespacePrefixRange.location != NSNotFound) {
      NSUInteger indentLength = indentationString_.length;

      // adjust indent length if there are uneven number of virtual indentations
      NSUInteger reminder = whitespacePrefixRange.length % indentLength;
      if (reminder) {
        indentLength = reminder;
      }

      // remove a chunk of whitespace
      indentLength = MIN(whitespacePrefixRange.length, indentLength);
      if (indentLength != 0) {
        NSRange prefixRange = NSMakeRange(whitespacePrefixRange.location,
                                          indentLength);
        [self setSelectedRange:prefixRange];
        [self insertText:@""];
        initialSelectedRange.location -= prefixRange.length;
        [self setSelectedRange:initialSelectedRange];
      }
    }
  } else {
    // multiple lines
    NSUInteger indentLength = indentationString_.length;

    // insert indentation string at the start of each line
    unichar* srcbuf = [text copyOfCharactersInRange:lineRange];
    __block unichar* dstbuf =
        (unichar*)malloc(lineRange.length * sizeof(unichar));
    __block NSUInteger dstlen = 0;
    __block NSUInteger charactersRemovedFirstLine = NSNotFound;

    // for each line ...
    [NSString kodEnumerateLinesOfCharacters:srcbuf
                                   ofLength:lineRange.length
                                  withBlock:^(NSRange lineRange) {
      // Advance past whitespace
      NSUInteger i = lineRange.location;
      NSUInteger end = MIN(lineRange.location + lineRange.length,
                           lineRange.location + indentLength);
      for (; i < end; ++i) {
        unichar ch = srcbuf[i];
        if (ch != ' ' && ch != '\t')
          break;
      }

      // record char count
      if (charactersRemovedFirstLine == NSNotFound)
        charactersRemovedFirstLine = (i - lineRange.location);

      // transfer rest of the characters to dstbuf
      NSUInteger remainingCount = lineRange.length - (i - lineRange.location);
      memcpy((void*)(dstbuf+dstlen), (const void*)(srcbuf+i),
             sizeof(unichar) * remainingCount);
      dstlen += remainingCount;
    }];

    NSString *replacementString =
        [[[NSString alloc] initWithCharactersNoCopy:dstbuf
                                             length:dstlen
                                       freeWhenDone:YES] autorelease];
    dstbuf = NULL;
    free(srcbuf); srcbuf = NULL;

    // replace text
    [self setSelectedRange:lineRange];
    [self insertText:replacementString];

    // restore selection
    if (charactersRemovedFirstLine != NSNotFound) {
      NSRange finalSelectedRange = initialSelectedRange;
      NSUInteger charactersRemovedOtherLines =
          (lineRange.length - dstlen) - charactersRemovedFirstLine;
      finalSelectedRange.location -= charactersRemovedFirstLine;
      finalSelectedRange.length -= charactersRemovedOtherLines;
      [self setSelectedRange:finalSelectedRange];
    }
  }
}


/*- (void)resetCursorRects {
  [self addCursorRect:NSMakeRect(0.0, 0.0, 100.0, 100.0)
               cursor:[NSCursor arrowCursor]];
}
- (void)cursorUpdate:(NSEvent*)event {
  DLOG("cursorUpdate:%@", event);
}*/


#pragma mark -
#pragma mark Words


- (void)scanWordsInString:(NSString *)string {
  [wordDictionary_ scanString:string];
}


- (void)rescanWords {
  [wordDictionary_ reset];
  [wordDictionary_ scanString:[self string]];
}


// overload of super
- (BOOL)shouldChangeTextInRange:(NSRange)affectedRange
              replacementString:(NSString *)replacementString {
  if ([super shouldChangeTextInRange:affectedRange
                   replacementString:replacementString]) {
    // update word dictionary
    [wordDictionary_ rescanUpdatedText:[self string]
                              forRange:affectedRange
                 withReplacementString:replacementString];
    return YES;
  }
  return NO;
}


#pragma mark -
#pragma mark Autocomplete


// Override default NSTextView behavior to not autocomplete if not at a word
// boundary
- (void)complete:(id)sender {
  NSRange selectedRange = [self selectedRange];
  NSCharacterSet *irrelevantChars = wordDictionary_.wordSeparatorCharacterSet;
  NSString *text = [self string];
  NSUInteger cursorLocation = selectedRange.location;
  if (selectedRange.length == 0 &&
      cursorLocation > 0 &&
      cursorLocation < [text length]-1 ) {
    NSString *surrounding =
        [text substringWithRange:NSMakeRange(cursorLocation-1, 2)];
    unichar charLeftOfCursor = [text characterAtIndex:cursorLocation-1];
    unichar charAtCursor = [text characterAtIndex:cursorLocation];
    if ([irrelevantChars characterIsMember:charLeftOfCursor] ==
        [irrelevantChars characterIsMember:charAtCursor]) {
      return;
    }
  }
  [super complete:sender];
}


// TODO(irskep): allow plugins to override default autocomplete results
- (NSArray*)completionsForPartialWordRange:(NSRange)charRange
                       indexOfSelectedItem:(NSInteger*)index {
  // ignore completions to the start of the document
  if (charRange.location == 0 && charRange.length == 0)
    return nil;

  NSString *text = [self string];
  NSString *prefix = [text substringWithRange:charRange];
  return [wordDictionary_ completionsForPrefix:prefix
                                    atPosition:charRange.location
                                        inText:text
                                    countLimit:100];
}


@end

#import "KMetaRulerView.h"
#import "KLineNumberMarker.h"
#import "KTextView.h"
#import "KDocument.h"
#import "KStyle.h"
#import "common.h"
#import <tgmath.h>

#define DEFAULT_THICKNESS  22.0
#define RULER_MARGIN_LEFT 10.0
#define RULER_MARGIN_RIGHT 4.0

@implementation KMetaRulerView


@synthesize tabContents = tabContents_;


- (void)_checkAndUpdateThickness {
  // broaden the view if needed
  CGFloat oldThickness = [self ruleThickness];
  CGFloat newThickness = [self requiredThickness];

  if (fabs(oldThickness - newThickness) > 1) {
    //[self setRuleThickness:newThickness];
    // Not a good idea to resize the view during calculations (which can happen
    // during display). Do a delayed perform (using NSInvocation since arg is a
    // float).
    NSInvocation *invocation =
        [NSInvocation invocationWithMethodSignature:
          [self methodSignatureForSelector:@selector(setRuleThickness:)]];
    [invocation setSelector:@selector(setRuleThickness:)];
    [invocation setTarget:self];
    [invocation setArgument:&newThickness atIndex:2];
    [invocation performSelector:@selector(invoke) withObject:nil afterDelay:0.0];
  }
}


- (void)_reloadStyle:(id)sender {
  CSSStyle* style = [[KStyle sharedStyle] styleForElementName:@"metaruler"];

  h_swapid(&backgroundColor_, style.backgroundColor);

  h_swapid(&textAttributes_, [NSDictionary dictionaryWithObjectsAndKeys:
                      style.color, NSForegroundColorAttributeName,
                      style.font, NSFontAttributeName,
                      nil]);

  h_swapid(&dividerColor_, style.borderRightColor);
  dividerWidth_ = style.borderRightWidth;

  [self _checkAndUpdateThickness];
  [self setNeedsDisplay:YES];
}


- (id)initWithScrollView:(NSScrollView *)scrollView
             tabContents:(KDocument*)tabContents {
  if ((self = [super initWithScrollView:scrollView orientation:NSVerticalRuler]) != nil) {
    markers_ = [[NSMutableDictionary alloc] init];
    tabContents_ = tabContents; // weak, owns us
    [self setClientView:tabContents_.textView];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_reloadStyle:)
                                                 name:KStyleDidChangeNotification
                                               object:[KStyle sharedStyle]];
    [self _reloadStyle:self];
  }
  return self;
}


- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [markers_ release];
  [super dealloc];
}


- (CGFloat)requiredThickness {
  NSUInteger lineCount = tabContents_ ? [tabContents_ lineCount] : 1;
  NSUInteger digits = (NSUInteger)log10(lineCount) + 1;
  static NSString * const digitsStr = @"88888888888888888888888888888888";
  NSSize stringSize = [[digitsStr substringToIndex:digits]
      sizeWithAttributes:textAttributes_];

  // Round up the value. There is a bug on 10.4 where the display gets all wonky when scrolling if you don't
  // return an integral value here.
  return ceil(MAX(DEFAULT_THICKNESS,
                  stringSize.width + RULER_MARGIN_LEFT + RULER_MARGIN_RIGHT +
                  dividerWidth_));
}


// Invoked when ranges of lines changed. |lineCountDelta| denotes how many lines
// where added or removed, if any.
- (void)linesDidChangeWithLineCountDelta:(NSInteger)lineCountDelta {
  [self _checkAndUpdateThickness];
  [self setNeedsDisplay:YES];
}


- (void)drawHashMarksAndLabelsInRect:(NSRect)dirtyRect {
  if (!tabContents_)
    return;

  KTextView *textView = tabContents_.textView;
  NSLayoutManager  *layoutManager = textView.layoutManager;
  NSTextContainer *textContainer = textView.textContainer;
  NSRect selfBounds = [self bounds];
  CGFloat width = selfBounds.size.width;
  NSView *contentView = [[self scrollView] contentView];
  NSRect visibleRect = [contentView bounds];

  // Set dirtyRect to cover full width
  dirtyRect.origin.x = 0.0;
  dirtyRect.size.width = width;

  // Set Y-axis of dirtyRect to cover visibleRect
  NSRect visibleRect2 = [self convertRect:visibleRect fromView:contentView];
  dirtyRect.origin.y = visibleRect2.origin.y;
  dirtyRect.size.height = visibleRect2.size.height;

  // Find the characters that are currently visible
  NSRange nilRange = NSMakeRange(NSNotFound, 0);
  NSRange glyphRange = [layoutManager glyphRangeForBoundingRect:visibleRect
                                                inTextContainer:textContainer];
  NSRange charRange = [layoutManager characterRangeForGlyphRange:glyphRange
                                                actualGlyphRange:NULL];

  // Fudge the range a tad in case there is an extra new line at end.
  // It doesn't show up in the glyphs so would not be accounted for.
  charRange.length++;
  NSUInteger charRangeEnd = charRange.location + charRange.length;

  // Y position
  CGFloat ypos, yinset = [textView textContainerInset].height;
  if (yinset > 0.0) yinset -= 1.0; // it's off by 1px for some reason

  // draw background
  if (backgroundColor_) {
    [backgroundColor_ set];
    NSRectFill(dirtyRect);
  }

  // draw divider line
  if (dividerWidth_ > 0.0) {
    [dividerColor_ set];
    NSRect dividerRect = NSMakeRect(NSMaxX(dirtyRect)-dividerWidth_,
                                    0.0, dividerWidth_, dirtyRect.size.height);
    NSRectFill(dividerRect);
  }

  // for each line
  NSUInteger lineNumber =
      [tabContents_ lineNumberForLocation:charRange.location];
  NSUInteger lineCount = [tabContents_ lineCount];
  for (; lineNumber <= lineCount; ++lineNumber) {
    NSRange lineRange = [tabContents_ rangeOfLineAtLineNumber:lineNumber];
    if (lineRange.location >= charRangeEnd)
      break;

    // find pixel rects for characters
    NSUInteger rectsCount = 0;
    NSRectArray  rects = [layoutManager
        rectArrayForCharacterRange:NSMakeRange(lineRange.location, 0)
      withinSelectedCharacterRange:nilRange
                   inTextContainer:textContainer
                         rectCount:&rectsCount];
    if (rectsCount == 0)
      continue;

    // Note that the ruler view is only as tall as the visible
    // portion. Need to compensate for the clipview's coordinates.
    ypos = yinset + NSMinY(rects[0]) - NSMinY(visibleRect);

    // TODO: draw any marker
    // KLineNumberMarker *marker =
    //     [linesToMarkers objectForKey:[NSNumber numberWithUnsignedInt:line]];
    // if (marker) { ...

    // Build a string with the line number (flush right, centered vertically
    // within the line).
    NSString *label = [NSString stringWithFormat:@"%lu", lineNumber];
    NSSize labelSize = [label sizeWithAttributes:textAttributes_];
    NSRect labelRect =
        NSMakeRect(width - labelSize.width - RULER_MARGIN_RIGHT - dividerWidth_,
                   ypos + (NSHeight(rects[0]) - labelSize.height) / 2.0,
                   width -
                      (RULER_MARGIN_LEFT + RULER_MARGIN_RIGHT + dividerWidth_),
                   NSHeight(rects[0]));
    [label drawInRect:labelRect withAttributes:textAttributes_];
  }
}


#pragma mark -
#pragma mark Markers


- (void)setMarkers:(NSArray *)markers {
  NSEnumerator    *enumerator;
  NSRulerMarker    *marker;

  [markers_ removeAllObjects];
  [super setMarkers:nil];

  enumerator = [markers objectEnumerator];
  while ((marker = [enumerator nextObject]) != nil) {
    [self addMarker:marker];
  }
}


- (void)addMarker:(NSRulerMarker *)aMarker {
  if ([aMarker isKindOfClass:[KLineNumberMarker class]]) {
    [markers_ setObject:aMarker
                        forKey:[NSNumber numberWithUnsignedInteger:[(KLineNumberMarker *)aMarker lineNumber] - 1]];
  }
  else {
    [super addMarker:aMarker];
  }
}


- (KLineNumberMarker *)markerAtLine:(NSUInteger)line {
  return [markers_ objectForKey:[NSNumber numberWithUnsignedInteger:line - 1]];
}


- (void)removeMarker:(NSRulerMarker *)aMarker {
  if ([aMarker isKindOfClass:[KLineNumberMarker class]]) {
    [markers_ removeObjectForKey:[NSNumber numberWithUnsignedInteger:[(KLineNumberMarker *)aMarker lineNumber] - 1]];
  }
  else {
    [super removeMarker:aMarker];
  }
}

@end

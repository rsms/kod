#import "KScroller.h"
#import "KFileOutlineView.h"
#import "common.h"

@implementation KScroller

NSColor *KScrollerKnobColorNormal;
NSColor *KScrollerKnobColorHover;

+ (void)load {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  KScrollerKnobColorNormal =
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.4] retain];
  KScrollerKnobColorHover =
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.9] retain];
  [pool drain];
}


+ (CGFloat)scrollerWidth {
	return 16.0;
}

+ (CGFloat)scrollerWidthForControlSize:(NSControlSize)controlSize {
	return 16.0;
}


- (void)_init {
  [self setArrowsPosition:NSScrollerArrowsNone];
  if ([self bounds].size.width / [self bounds].size.height < 1)
    vertical_ = YES;
  else
    vertical_ = NO;
  NSTrackingArea *trackingArea =
      [[NSTrackingArea alloc] initWithRect:[self bounds]
                                   options:NSTrackingMouseEnteredAndExited
                                          |NSTrackingActiveInKeyWindow
                                          |NSTrackingInVisibleRect
                                     owner:self
                                  userInfo:nil];
  [self addTrackingArea:trackingArea];
}


- (id)initWithFrame:(NSRect)frameRect {
	if (self = [super initWithFrame:frameRect]) {
		[self _init];
	}
	return self;
}


- (id)initWithCoder:(NSCoder *)decoder {
	if (self = [super initWithCoder:decoder]) {
		[self _init];
	}
	return self;
}


- (void)viewWillMoveToSuperview:(NSView*)superview {
  if (superview &&
      [superview isKindOfClass:[NSScrollView class]] &&
      (superview = [[superview subviews] lastObject]) &&
      [superview isKindOfClass:[NSClipView class]] &&
      (superview = [[superview subviews] lastObject]) &&
      [superview isKindOfClass:[NSTextView class]]) {
    parentTextView_ = (NSTextView*)superview;
  } else {
    parentTextView_ = nil;
  }
}


- (void)setArrowsPosition:(NSScrollArrowPosition)where {
  //DLOG("%@", NSStringFromSelector(_cmd));
  // We need to intercept this call, as these scrollers are messy business
  [super setArrowsPosition:NSScrollerArrowsNone];
}

- (NSScrollArrowPosition)arrowsPosition {
  return NSScrollerArrowsNone;
}


- (void)mouseEntered:(NSEvent*)ev {
  hover_ = YES;
  [self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent*)ev {
  hover_ = NO;
  [self setNeedsDisplay:YES];
}


- (void)drawKnobSlotInRect:(NSRect)slotRect highlight:(BOOL)highlight {
  /*NSColor *color = nil;
  if (parentTextView_) color = parentTextView_.backgroundColor;
  if (!color) color = KFileOutlineViewBackgroundColor;
  [color set];
  [[NSColor colorWithCalibratedWhite:1.0 alpha:0.2] set];
  //[[NSColor randomColorWithSaturation:0.5 brightness:0.5 alpha:1.0] set];
	NSRectFill([self bounds]);
  return;*/
  
  NSRect knobRect = [self rectForPart:NSScrollerKnob];
  
  if (knobRect.size.width != 0.0) {
    // bubble
    if (vertical_) {
      slotRect.size.width = 9.0;
      slotRect.origin.x = 3.0;
    } else {
      slotRect.size.height = 9.0;
      slotRect.origin.y = 3.0;
    }
    NSBezierPath *bp =
        [NSBezierPath bezierPathWithRoundedRect:slotRect xRadius:4.5 yRadius:4.5];
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.15] set];
    [bp fill];
  }
}

- (BOOL)isOpaque {
  return NO;
}

- (void)drawArrow:(NSScrollerArrow)arrow highlightPart:(int)highlight {
  // we don't roll with arrows
}

- (void)drawKnob {
  NSRect rect = [self rectForPart:NSScrollerKnob];
  rect.size.width = 9.0;
  rect.origin.x = 3.0;
  [(hover_ ? KScrollerKnobColorHover : KScrollerKnobColorNormal) set];
  NSBezierPath *bp = [NSBezierPath bezierPathWithRoundedRect:rect
                                                     xRadius:4.5
                                                     yRadius:4.5];
  [bp fill];
}


@end

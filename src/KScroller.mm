#import "KScroller.h"
#import "KFileOutlineView.h"
#import "KDocument.h"
#import "common.h"

@implementation KScroller

@synthesize tab = tab_;

NSColor *KScrollerKnobColorNormal;
NSColor *KScrollerKnobColorHover;

NSColor *KScrollerKnobSlotColorNormal;
NSColor *KScrollerKnobSlotColorHover;

+ (void)load {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];

  KScrollerKnobColorNormal =
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.4] retain];
  KScrollerKnobColorHover =
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.9] retain];

  KScrollerKnobSlotColorNormal =
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.06] retain];
  KScrollerKnobSlotColorHover =
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.2] retain];

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


- (void)resetCursorRects {
  if (!self.isCollapsed)
    [self addCursorRect:[self bounds] cursor:[NSCursor arrowCursor]];
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
  [[self window] invalidateCursorRectsForView:self];
}


- (void)mouseExited:(NSEvent*)ev {
  hover_ = NO;
  [self setNeedsDisplay:YES];
}


- (BOOL)isCollapsed {
  NSSize size = [self rectForPart:NSScrollerKnob].size;
  return (vertical_ ? size.width : size.height) == 0.0;
}


- (void)drawKnobSlotInRect:(NSRect)slotRect highlight:(BOOL)highlight {
  NSRect knobRect = [self rectForPart:NSScrollerKnob];
  if (knobRect.size.width != 0.0) {
    // enable mouse tracking
    if (!trackingArea_) {
      trackingArea_ =
        [[NSTrackingArea alloc] initWithRect:[self bounds]
                                     options:NSTrackingMouseEnteredAndExited
                                            |NSTrackingActiveInKeyWindow
                                            |NSTrackingInVisibleRect
                                       owner:self
                                    userInfo:nil];
      [self addTrackingArea:trackingArea_];
    }

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
    [(hover_ ? KScrollerKnobSlotColorHover : KScrollerKnobSlotColorNormal) set];
    [bp fill];
  } else {
    // disable mouse tracking
    if (trackingArea_) {
      [self removeTrackingArea:trackingArea_];
      [trackingArea_ release];
      trackingArea_ = nil;
    }
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

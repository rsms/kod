#import "KScroller.h"
#import "KFileOutlineView.h"

@implementation KScroller

NSColor *KScrollerKnobColorNormal;
NSColor *KScrollerKnobColorHover;

+ (void)load {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  KScrollerKnobColorNormal =
    [[NSColor colorWithCalibratedWhite:0.4 alpha:1.0] retain];
  KScrollerKnobColorHover =
    [[NSColor colorWithCalibratedWhite:0.5 alpha:1.0] retain];
  [pool drain];
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


+ (CGFloat)scrollerWidth {
	return 8.0;
}

+ (CGFloat)scrollerWidthForControlSize:(NSControlSize)controlSize {
	return 8.0;
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
  NSColor *color = nil;
  if (parentTextView_) color = parentTextView_.backgroundColor;
  if (!color) color = KFileOutlineViewBackgroundColor;
  [color set];
	NSRectFill([self bounds]);
}

- (BOOL)isOpaque {
  return YES;
}

- (void)drawArrow:(NSScrollerArrow)arrow highlightPart:(int)highlight {
  // we don't roll with arrows
}

- (void)drawKnob {
  NSRect rect = [self rectForPart:NSScrollerKnob];
  rect.size.width -= 11.0;
  rect.origin.x += 9.0;
  [(hover_ ? KScrollerKnobColorHover : KScrollerKnobColorNormal) set];
  NSBezierPath *bp = [NSBezierPath bezierPathWithRoundedRect:rect
                                                     xRadius:2.0
                                                     yRadius:2.0];
  [bp fill];
}

@end

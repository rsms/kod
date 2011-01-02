#import "KModeTextFieldDecoration.h"
#import "common.h"

static const CGFloat kIconWidth = 24.0;
static const CGFloat kIconHeight = 16.0;

static NSImage *kArrowImage = nil;
static const CGFloat kArrowWidth = 7.0;
static const CGFloat kArrowHeight = 6.0;

@implementation KModeTextFieldDecoration


+ (void)initialize {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];

  // draw small "menu arrow"
  kArrowImage = [[NSImage alloc] init];
  [kArrowImage setSize:NSMakeSize(kArrowWidth, kArrowHeight)];
  //[kArrowImage setFlipped:YES];
  [kArrowImage lockFocus];

  NSPoint p1 = NSMakePoint(0,0);
  NSPoint p2 = NSMakePoint(kArrowWidth, 0);
  NSPoint p3 = NSMakePoint(kArrowWidth / 2, kArrowHeight - 1);
  NSBezierPath *triangle = [NSBezierPath bezierPath];
  [triangle moveToPoint:p1];
  [triangle lineToPoint:p2];
  [triangle lineToPoint:p3];
  [triangle lineToPoint:p1];
  [[NSColor blackColor] set];
  [triangle fill];

  [kArrowImage unlockFocus];

  [pool drain];
}


- (id)initWithName:(NSString*)name {
  if ((self = [super init])) {
    visible_ = YES;
    self.name = name;
  }
  return self;
}


- (void)dealloc {
  [icon_ release];
  [super dealloc];
}


- (NSString*)name { return name_; }

- (void)setName:(NSString*)name {
  h_swapid(&name_, name);

  if (name_ == nil) {
    h_swapid(&icon_, [[NSImage imageNamed:@"icon.pdf"] retain]);
    return;
  }

  // create icon
  NSRect iconBounds = NSMakeRect(0.0, 0.0, kIconWidth, kIconHeight);
  NSImage *icon = [[NSImage alloc] init];
  [icon setSize:iconBounds.size];
  [icon lockFocusFlipped:NO];

  NSStringDrawingOptions options = NSStringDrawingOneShot|
                                   NSStringDrawingUsesLineFragmentOrigin;
  NSAttributedString *astr;
  CGFloat size = 12.0;

  while (1) {
    astr =
        [[NSAttributedString alloc] initWithString:name_ attributes:[NSDictionary
          dictionaryWithObjectsAndKeys:
          [NSColor blackColor], NSForegroundColorAttributeName,
          [NSFont fontWithName:@"Helvetica" size:size], NSFontAttributeName,
          nil]];

    NSRect strRect = [astr boundingRectWithSize:iconBounds.size options:options];
    NSLog(@"strRect: %@   dstRect: %@",
          NSStringFromRect(strRect),
          NSStringFromRect(iconBounds));

    if (strRect.size.width <= iconBounds.size.width &&
        strRect.size.height <= iconBounds.size.height)
      break;
    size -= 1.0;
    [astr release];
  }

  [astr drawWithRect:iconBounds options:options];

  [icon unlockFocus];
  h_swapid(&icon_, icon);
}


// Decorations can change their size to fit the available space.
// Returns the width the decoration will use in the space allotted,
// or |kOmittedWidth| if it should be omitted.
- (CGFloat)widthForSpace:(CGFloat)width {
  return kIconWidth + 2.0 + kArrowWidth;
}


// Decorations which do not accept mouse events are treated like the
// field's background for purposes of selecting text.  When such
// decorations are adjacent to the text area, they will show the
// I-beam cursor.  Decorations which do accept mouse events will get
// an arrow cursor when the mouse is over them.
- (BOOL)acceptsMousePress {
  return YES;
}


// Called on mouse down.  Return |false| to indicate that the press
// was not processed and should be handled by the cell.
- (BOOL)mouseDownInRect:(NSRect)frame {
  DLOG("mouseDownInRect:%@", NSStringFromRect(frame));
  return YES;
}


// Draw the decoration in the frame provided.  The frame will be
// generated from an earlier call to |GetWidthForSpace()|.
- (void)drawInteriorWithFrame:(NSRect)frame inView:(NSView*)controlView {
  DLOG("drawInteriorWithFrame:%@", NSStringFromRect(frame));

  NSRect dstRect = frame;
  dstRect.size.width = kIconWidth;
  if (dstRect.size.height > kIconHeight) {
    dstRect.origin.y += ceil((dstRect.size.height - kIconHeight)/2.0);
    dstRect.size.height = kIconHeight;
  }

  //[[NSColor redColor] set]; NSRectFill(dstRect);
  [icon_ drawInRect:dstRect
           fromRect:NSZeroRect
          operation:NSCompositeSourceOver
           fraction:1.0
     respectFlipped:YES
              hints:nil];

  NSPoint arrowOrigin = dstRect.origin;
  arrowOrigin.x += frame.size.width - kArrowWidth;
  arrowOrigin.y += dstRect.size.height - kArrowHeight;

  [kArrowImage drawAtPoint:arrowOrigin
                  fromRect:NSZeroRect
                 operation:NSCompositeSourceOver
                  fraction:0.6];
}


@end

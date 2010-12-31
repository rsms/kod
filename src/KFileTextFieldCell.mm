#import "KFileTextFieldCell.h"
#import "KFileOutlineView.h"

@implementation KFileTextFieldCell

@synthesize image = image_;

- (id)init {
  if ((self = [super init])) {
    [self setLineBreakMode:NSLineBreakByTruncatingTail];
    [self setSelectable:YES];
  }
  return self;
}

- (void)dealloc {
  [image_ release];
  [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone {
  KFileTextFieldCell *cell = (KFileTextFieldCell *)[super copyWithZone:zone];
  // The image ivar will be directly copied; we need to retain or copy it.
  cell->image_ = [image_ retain];
  return cell;
}

- (NSRect)imageRectForBounds:(NSRect)cellFrame {
  NSRect result;
  if (image_ != nil) {
    result.size = [image_ size];
    result.origin = cellFrame.origin;
    result.origin.x += 3;
    result.origin.y += ceil((cellFrame.size.height - result.size.height) / 2);
  } else {
    result = NSZeroRect;
  }
  return result;
}

// We could manually implement expansionFrameWithFrame:inView: and drawWithExpansionFrame:inView: or just properly implement titleRectForBounds to get expansion tooltips to automatically work for us
- (NSRect)titleRectForBounds:(NSRect)cellFrame {
  NSRect result;
  if (image_ != nil) {
    CGFloat imageWidth = [image_ size].width;
    result = cellFrame;
    result.origin.x += (3 + imageWidth);
    result.size.width -= (3 + imageWidth);
  } else {
    result = [super titleRectForBounds:cellFrame];
  }
  return result;
}

- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent {
  NSRect textFrame, imageFrame;
  NSDivideRect (aRect, &imageFrame, &textFrame, 3 + [image_ size].width, NSMinXEdge);
  [super editWithFrame: textFrame inView: controlView editor:textObj delegate:anObject event: theEvent];
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength {
  NSRect textFrame, imageFrame;
  NSDivideRect (aRect, &imageFrame, &textFrame, 3 + [image_ size].width, NSMinXEdge);
  [super selectWithFrame: textFrame inView: controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
  if (image_ != nil) {
    NSRect imageFrame;
    NSSize imageSize = NSMakeSize(cellFrame.size.height, cellFrame.size.height);
    [image_ setSize:imageSize];
    NSDivideRect(cellFrame, &imageFrame, &cellFrame, 3 + imageSize.width, NSMinXEdge);
    if ([self drawsBackground]) {
      [[self backgroundColor] set];
      NSRectFill(imageFrame);
    }
    imageFrame.origin.x += 3;
    imageFrame.size = imageSize;
    if ([controlView isFlipped]) {
      imageFrame.origin.y += ceil((cellFrame.size.height + imageFrame.size.height) / 2);
    } else {
      imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);
    }
    [image_ compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
  }
  [super drawWithFrame:cellFrame inView:controlView];
}

- (NSSize)cellSize {
  NSSize cellSize = [super cellSize];
  if (image_ != nil) {
    cellSize.width += [image_ size].width;
  }
  cellSize.width += 3;
  return cellSize;
}

- (NSUInteger)hitTestForEvent:(NSEvent *)event inRect:(NSRect)cellFrame ofView:(NSView *)controlView {
  NSPoint point = [controlView convertPoint:[event locationInWindow] fromView:nil];
  // If we have an image, we need to see if the user clicked on the image portion.
  if (image_ != nil) {
    // This code closely mimics drawWithFrame:inView:
    NSSize imageSize = [image_ size];
    NSRect imageFrame;
    NSDivideRect(cellFrame, &imageFrame, &cellFrame, 3 + imageSize.width, NSMinXEdge);

    imageFrame.origin.x += 3;
    imageFrame.size = imageSize;
    // If the point is in the image rect, then it is a content hit
    if (NSMouseInRect(point, imageFrame, [controlView isFlipped])) {
      // We consider this just a content area. It is not trackable, nor it it editable text. If it was, we would or in the additional items.
      // By returning the correct parts, we allow NSTableView to correctly begin an edit when the text portion is clicked on.
      return NSCellHitContentArea;
    }
  }
  // At this point, the cellFrame has been modified to exclude the portion for the image. Let the superclass handle the hit testing at this point.
  return [super hitTestForEvent:event inRect:cellFrame ofView:controlView];
}


static NSColor *kTextColorNormal;
static NSColor *kTextColorSelected;
static NSColor *kTextColorFocused;

+ (void)load {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  kTextColorNormal = [[NSColor colorWithCalibratedWhite:0.9 alpha:1.0] retain];
  kTextColorSelected = kTextColorNormal;
  kTextColorFocused =
      [[NSColor colorWithCalibratedWhite:0.00001 alpha:1.0] retain];
  [pool drain];
}


- (NSColor*)textColor {
  if ([self isHighlighted]) {
    KFileOutlineView *outlineView = (KFileOutlineView*)[self controlView];
    return outlineView.firstResponder ? kTextColorFocused : kTextColorSelected;
  } else {
    return kTextColorNormal;
  }
}


- (NSColor *)highlightColorWithFrame:(NSRect)cellFrame
                              inView:(NSView*)controlView {
  return nil;
}

- (void)highlight:(BOOL)flag
        withFrame:(NSRect)cellFrame
           inView:(NSView *)controlView {
  // make sure the cell doesn't draw any highlighting at all
  [super highlight:NO withFrame:cellFrame inView:controlView];
}


@end


#import "KStatusBarView.h"
#import "KSplitView.h"
#import "common.h"
#import <ChromiumTabs/GTMNSColor+Luminance.h>

static NSGradient *_mkGradient(BOOL faded) {
  NSColor* bright = [NSColor colorWithCalibratedWhite:0.75 alpha:1.0];
  NSColor* dark = [NSColor colorWithCalibratedWhite:0.67 alpha:1.0];
  return [[NSGradient alloc] initWithStartingColor:bright endingColor:dark];
}

static NSGradient *kGradientWhenIsKey = nil;
static NSGradient *kGradientWhenNotKey = nil;
static NSColor* kColorStrokeHighlightWhenIsKey = nil;
static NSColor* kColorStrokeHighlightWhenNotKey = nil;
static NSColor* kColorStrokeLowlightWhenIsKey = nil;
static NSColor* kColorStrokeLowlightWhenNotKey = nil;
static NSColor* kColorDivider = nil;

static CGFloat kSplitViewMarkerWidth = 3.0;


@implementation KStatusBarView

@synthesize splitView = splitView_,
            cursorPositionTextField = cursorPositionTextField_;


+ (void)initialize {
  NSAutoreleasePool* pool = [NSAutoreleasePool new];
  kGradientWhenIsKey = _mkGradient(NO);
  kGradientWhenNotKey = _mkGradient(YES);

  kColorStrokeHighlightWhenIsKey =
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.7] retain];
  kColorStrokeHighlightWhenNotKey =
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.3] retain];

  kColorStrokeLowlightWhenIsKey =
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.3] retain];
  kColorStrokeLowlightWhenNotKey =
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.1] retain];

  kColorDivider =
    [[NSColor colorWithCalibratedWhite:0.06 alpha:1.0] retain];

  [pool drain];
}


- (void)_splitViewMarkerFrameDidChange:(NSRect)dirtyRect {
  // reposition rightViewGroup_
  NSRect rightViewGroupFrame = [self bounds];
  rightViewGroupFrame.origin.x += splitViewPositionForLayout_;
  rightViewGroupFrame.size.width -= splitViewPositionForLayout_;
  [rightViewGroup_ setFrame:rightViewGroupFrame];

  //[self setNeedsDisplayInRect:dirtyRect];
  [self setNeedsDisplay:YES];
}


- (void)_updateSplitViewMarkerFrame {
  NSRect frame = NSZeroRect;

  if (splitView_) {
    CGFloat xpos = splitViewPositionForLayout_;
    if (xpos > 0.0) {
      NSRect bounds = [self bounds];
      frame = NSMakeRect(xpos - floor(kSplitViewMarkerWidth/2.0), 0.0,
                         kSplitViewMarkerWidth, bounds.size.height);
    }
  }

  if (!NSEqualRects(frame, splitViewMarkerFrame_)) {
    NSRect dirtyRect;
    if (NSIsEmptyRect(frame)) {
      dirtyRect = splitViewMarkerFrame_;
    } else if (NSIsEmptyRect(splitViewMarkerFrame_)) {
      dirtyRect = frame;
    } else {
      dirtyRect = NSUnionRect(frame, splitViewMarkerFrame_);
    }
    splitViewMarkerFrame_ = frame;
    [self _splitViewMarkerFrameDidChange:dirtyRect];
  }
}


- (void)_recalculateSplitViewPosition {
  // minimum position for layout
  CGFloat actualSplitViewPosition =
      (splitView_ && !splitView_.isCollapsed) ? splitView_.position : 0.0;
  splitViewPositionForLayout_ = MAX([toggleSplitViewButton_ bounds].size.width,
                                    actualSplitViewPosition);
}


- (void)awakeFromNib {
  [super awakeFromNib];
  [self _recalculateSplitViewPosition];
  [self _updateSplitViewMarkerFrame];
}


- (void)splitViewDidResize {
  [self _recalculateSplitViewPosition];
  [self _updateSplitViewMarkerFrame];
}


- (void)_drawVerticalDividerAt:(CGFloat)x isKey:(BOOL)isKey {
  CGFloat width = 1.0;
  x -= width; // since we draw two lines
  NSRect rect = NSMakeRect(x, 0.0, width, splitViewMarkerFrame_.size.height-1);
  [(isKey ? kColorStrokeLowlightWhenIsKey
          : kColorStrokeLowlightWhenNotKey) set];
  NSRectFillUsingOperation(rect, NSCompositeSourceOver);
  rect.origin.x += width;
  [(isKey ? kColorStrokeHighlightWhenIsKey
          : kColorStrokeHighlightWhenNotKey) set];
  NSRectFillUsingOperation(rect, NSCompositeSourceOver);
}


- (void)drawSplitViewMarker {
  BOOL isKey = [[self window] isKeyWindow];
  //[[NSColor redColor] drawSwatchInRect:splitViewMarkerFrame_];

  CGFloat dividerXPos = splitViewMarkerFrame_.origin.x +
                        ceil(splitViewMarkerFrame_.size.width/2.0);
  [self _drawVerticalDividerAt:dividerXPos isKey:isKey];
}


- (void)drawRect:(NSRect)dirtyRect {
  // extend dirtyRect to cover full height
  NSRect bounds = [self bounds];
  dirtyRect.origin.y = bounds.origin.y;
  dirtyRect.size.height = bounds.size.height;

  // draw gradient
  BOOL isKey = [[self window] isKeyWindow];
  NSGradient *gradient = isKey ? kGradientWhenIsKey : kGradientWhenNotKey;
  [gradient drawInRect:dirtyRect angle:270.0];

  // draw strokes
  [kColorDivider set];
  NSRect borderRect = dirtyRect;
  CGFloat thickness = 1.0;
  borderRect.origin.y += borderRect.size.height - thickness;
  borderRect.size.height = thickness;
  NSRectFillUsingOperation(borderRect, NSCompositeSourceOver);

  [(isKey ? kColorStrokeHighlightWhenIsKey : kColorStrokeHighlightWhenNotKey) set];
  thickness = 1.0;
  borderRect.origin.y -= thickness;
  borderRect.size.height = thickness;
  NSRectFillUsingOperation(borderRect, NSCompositeSourceOver);

  // draw splitView position
  if (NSIntersectsRect(splitViewMarkerFrame_, dirtyRect)) {
    [self drawSplitViewMarker];
  }
}

@end

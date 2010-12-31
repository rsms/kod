#import "KScrollView.h"
#import "KScroller.h"
#import "KClipView.h"
#import "common.h"

@implementation KScrollView


+ (Class)_verticalScrollerClass {
  //NSLog(@"KScrollView _verticalScrollerClass");
  return [KScroller class];
}

+ (Class)_horizontalScrollerClass {
  //NSLog(@"KScrollView _horizontalScrollerClass");
  return [KScroller class];
}


- (id)initWithFrame:(NSRect)frame {
  if ((self = [super initWithFrame:frame])) {
    [self setDrawsBackground:NO];

    KClipView *clipView = [[KClipView alloc] initWithFrame:frame];
    [self setContentView:clipView];
    [clipView release];

    [self setHasVerticalScroller:YES];
    [self setHasHorizontalScroller:YES];
    [self setHasHorizontalRuler:NO];
    //[self setAutohidesScrollers:YES]; // don't! Or pain will come when drawing
  }
  return self;
}


- (void)setContentView:(NSClipView *)contentView {
  [super setContentView:contentView];
}


// ovveride to neutralize NSScrollView private method which draws a white square
// behind the "grow box" (window resizing thingy in the bottom right corner)
- (void)_fixGrowBox {
  //DLOG("%@", NSStringFromSelector(_cmd));
}

/*- (BOOL)_updateGrowBoxForWindowFrameChange {
  //BOOL y = [super _updateGrowBoxForWindowFrameChange];
  DLOG("%@", NSStringFromSelector(_cmd));
  return NO;
}*/

/*
- (BOOL)_ownsWindowGrowBox {
  BOOL y = [super _ownsWindowGrowBox];
  DLOG("%@ -> %d", NSStringFromSelector(_cmd), y);
  return y;
}

- (BOOL)_updateGrowBoxForWindowFrameChange {
  BOOL y = [super _updateGrowBoxForWindowFrameChange];
  DLOG("%@ -> %d", NSStringFromSelector(_cmd), y);
  return y;
}

- (BOOL)_fixHeaderAndCornerViews {
  BOOL y = [super _fixHeaderAndCornerViews];
  DLOG("%@ -> %d", NSStringFromSelector(_cmd), y);
  return y;
}*/


- (void)tile {
  [super tile];
  //
  // Make the clip view span underneath the scrollbars
  // [alternative interpretation:]
  // Draw the scrollbars on top of the clip view
  //
  BOOL hasHScroller = [self hasHorizontalScroller];
  BOOL hasVScroller = [self hasVerticalScroller];
  if (hasHScroller || hasVScroller) {
    NSClipView *clipView = [self contentView];
    NSRect clipViewFrame = [clipView frame];
    CGFloat scrollerWidth = [KScroller scrollerWidth];
    if (hasVScroller)
      clipViewFrame.size.width += scrollerWidth;
    if (hasHScroller)
      clipViewFrame.size.height += scrollerWidth;
    [clipView setFrame:clipViewFrame];
  }
}


@end

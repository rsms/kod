#import "KSplitView.h"
#import "common.h"

@interface BWSplitView (Private)
// for silencing warnings
- (void)splitViewDidResizeSubviews:(NSNotification*)notification;
@end


@implementation KSplitView

@synthesize dividerRect = dividerRect_;


- (void)awakeFromNib {
  [super awakeFromNib];
}


- (CGFloat)position {
  return position_;
}


- (void)setPosition:(CGFloat)position {
  [self setPosition:position ofDividerAtIndex:0];
}


- (void)splitViewDidResizeSubviews:(NSNotification*)notification {
  // recalculate position
  position_ = [[[self subviews] objectAtIndex:0] bounds].size.width;
  [super splitViewDidResizeSubviews:notification];
}


- (void)drawDividerInRect:(NSRect)dividerRect {
  dividerRect_ = dividerRect;
  //NSLog(@"dividerRect %@", NSStringFromRect(dividerRect_));
  [[NSColor colorWithCalibratedWhite:0.0 alpha:1.0]
      drawSwatchInRect:dividerRect_];
}


- (float)animationDuration {
  return 0.0;
}


// disable double click on divider to close
- (BOOL)splitView:(NSSplitView *)splitView
    shouldCollapseSubview:(NSView *)subview
    forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex {
  return NO;
}

@end

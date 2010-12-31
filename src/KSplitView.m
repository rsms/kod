#import "KSplitView.h"
#import "common.h"

NSString * const KSplitViewDidChangeCollapseStateNotification =
               @"KSplitViewDidChangeCollapseStateNotification";


@interface BWSplitView (Private)
// for silencing warnings
- (void)splitViewDidResizeSubviews:(NSNotification*)notification;
@end


@implementation KSplitView

@synthesize dividerRect = dividerRect_;


- (void)awakeFromNib {
  [super awakeFromNib];
}


- (CGFloat)collapsePositionThreshold {
  // this need to be synced with the value put into IB
  return 100.0;
}

- (CGFloat)position {
  return position_;
}

- (void)setPosition:(CGFloat)position {
  CGFloat collapsePositionThreshold = self.collapsePositionThreshold;
  position_ = position;
  if (position_ < collapsePositionThreshold)
    position_ = collapsePositionThreshold;
  if (!collapsed_)
    [self setPosition:position ofDividerAtIndex:0];
}


- (BOOL)isCollapsed {
  return collapsed_;
  //return self.position < self.collapsePositionThreshold;
}

- (void)setIsCollapsed:(BOOL)collapsed {
  if (!collapsed_ == !collapsed) return;
  collapsed_ = collapsed;
  NSView *collapsibleSubview = [[self subviews] objectAtIndex:0];

  if (collapsed_) {
    [collapsibleSubview setHidden:YES];
    [collapsibleSubview setAutoresizesSubviews:NO];
    [self setPosition:0.0 ofDividerAtIndex:0];
  } else {
    if (position_ < self.collapsePositionThreshold)
      position_ = self.collapsePositionThreshold;
    [self setPosition:position_ ofDividerAtIndex:0];
    [collapsibleSubview setHidden:NO];
    [collapsibleSubview setAutoresizesSubviews:YES];
  }

  [[NSNotificationCenter defaultCenter]
      postNotificationName:KSplitViewDidChangeCollapseStateNotification
                    object:self];
}


- (IBAction)toggleCollapse:(id)sender {
  self.isCollapsed = !self.isCollapsed;
}


- (void)splitViewDidResizeSubviews:(NSNotification*)notification {
  // recalculate position
  if (!collapsed_)
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

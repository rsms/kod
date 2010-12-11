#import "KSplitView.h"

@implementation KSplitView

@synthesize dividerRect = dividerRect_;

- (void)awakeFromNib {
  [super awakeFromNib];
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

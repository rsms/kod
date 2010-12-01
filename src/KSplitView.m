#import "KSplitView.h"


@implementation KSplitView

-(void)drawRect:(NSRect)dirtyRect {
  [[NSColor colorWithCalibratedWhite:0.0 alpha:1.0] set];
  NSRectFill(dirtyRect);
}

@end

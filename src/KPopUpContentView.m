#import "KPopUpContentView.h"
#import "common.h"

@implementation KPopUpContentView

- (void)drawRect:(NSRect)dirtyRect {
  [[NSColor colorWithCalibratedWhite:0.9 alpha:0.95] set];
  NSRect bounds = [self bounds];
  [[NSBezierPath bezierPathWithRoundedRect:bounds
                                  xRadius:5.0
                                  yRadius:5.0] fill];
}

@end

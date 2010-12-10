#import "KStatusBarView.h"
#import <ChromiumTabs/GTMNSColor+Luminance.h>

static NSGradient *_mkGradient(BOOL faded) {
  NSColor* bright = [NSColor colorWithCalibratedWhite:0.75 alpha:1.0];
  NSColor* dark = [NSColor colorWithCalibratedWhite:0.67 alpha:1.0];
  return [[NSGradient alloc] initWithStartingColor:bright endingColor:dark];
}


@implementation KStatusBarView

static NSGradient *kGradientWhenIsKey = nil;
static NSGradient *kGradientWhenNotKey = nil;
static NSColor* kColorStrokeWhenIsKey = nil;
static NSColor* kColorStrokeWhenNotKey = nil;
static NSColor* kColorDivider = nil;


+ (void)initialize {
  NSAutoreleasePool* pool = [NSAutoreleasePool new];
  kGradientWhenIsKey = _mkGradient(NO);
  kGradientWhenNotKey = _mkGradient(YES);
  kColorStrokeWhenIsKey =
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.7] retain];
  kColorStrokeWhenNotKey =
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.3] retain];
  kColorDivider =
    [[NSColor colorWithCalibratedWhite:0.06 alpha:1.0] retain];
  [pool drain];
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
  
  [(isKey ? kColorStrokeWhenIsKey : kColorStrokeWhenNotKey) set];
  thickness = 1.0;
  borderRect.origin.y -= thickness;
  borderRect.size.height = thickness;
  NSRectFillUsingOperation(borderRect, NSCompositeSourceOver);
}

@end

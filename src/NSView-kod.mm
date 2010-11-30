#import "NSView-kod.h"

@implementation NSView (Kod)

- (NSView*)findFirstParentViewOfKind:(Class)kind {
  NSView *parent = self;
  while ((parent = [parent superview]) && ![parent isKindOfClass:kind]) {}
  return parent;
}

@end

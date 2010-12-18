#import "NSView-kod.h"

@implementation NSView (Kod)

- (NSView*)findFirstParentViewOfKind:(Class)kind {
  NSView *parent = self;
  while ((parent = [parent superview]) && ![parent isKindOfClass:kind]) {}
  return parent;
}


- (NSView*)_findFirstSubviewOfKind:(Class)kind depth:(int)depth {
  if (depth > 0) {
    for (NSView *view in [self subviews]) {
      if ([view isKindOfClass:kind])
        return view;
      if ((view = [view _findFirstSubviewOfKind:kind depth:depth-1]))
        return view;
    }
  }
  return nil;
}

- (NSView*)findFirstSubviewOfKind:(Class)kind {
  return [self _findFirstSubviewOfKind:kind depth:100];
}


@end

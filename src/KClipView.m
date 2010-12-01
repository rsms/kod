#import "KClipView.h"
#import "common.h"

@implementation KClipView

- (id)initWithFrame:(NSRect)frame {
  if ((self = [super initWithFrame:frame])) {
    [self setDrawsBackground:NO];
    [self setCopiesOnScroll:NO];
  }
  return self;
}


@end

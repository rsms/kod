#import "KHighlightState.h"

@implementation KHighlightState

- (id)initWithData:(KHighlightStateData*)d {
  self = [super init];
  data = d;
  return self;
}

- (void) dealloc {
  if (data) {
    delete data;
    data = NULL;
  }
  [super dealloc];
}


- (void)replaceData:(KHighlightStateData*)d {
  if (data) delete data;
  data = d;
}

@end

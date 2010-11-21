#import "KSourceHighlightState.h"
#import "KSourceHighlighter.h"

@implementation KSourceHighlightState

- (id)initWithHighlightState:(srchilite::HighlightStatePtr)hs {
  self = [super init];
  highlightState = hs;
  return self;
}

- (void)dealloc {
  [super dealloc];
}

@end

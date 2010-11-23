#include <srchilite/highlightstate.h>
#import "KSourceHighlighter.h"

@interface KSourceHighlightState : NSObject {
 @public
  srchilite::HighlightStatePtr highlightState;
  KHighlightStateStackPtr stateStack;
}
- (id)initWithHighlightState:(srchilite::HighlightStatePtr)hs
                  stateStack:(KHighlightStateStackPtr)stateStack;
@end

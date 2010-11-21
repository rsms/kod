#include <srchilite/highlightstate.h>

@interface KSourceHighlightState : NSObject {
 @public
  srchilite::HighlightStatePtr highlightState;
}
- (id)initWithHighlightState:(srchilite::HighlightStatePtr)hs;
@end

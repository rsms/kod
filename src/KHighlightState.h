#import "KHighlightStateData.h"

@interface KHighlightState : NSObject {
 @public
  KHighlightStateData *data;
}

- (id)initWithData:(KHighlightStateData*)data;
- (void)replaceData:(KHighlightStateData*)data;

@end

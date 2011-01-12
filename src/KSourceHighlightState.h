// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

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

// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "KSourceHighlightState.h"
#import "KSourceHighlighter.h"

@implementation KSourceHighlightState

- (id)initWithHighlightState:(srchilite::HighlightStatePtr)hs
                  stateStack:(KHighlightStateStackPtr)ss; {
  self = [super init];
  highlightState = hs;
  stateStack = ss;
  return self;
}

- (void)dealloc {
  [super dealloc];
}

- (NSString*)description {
  return [NSString stringWithFormat:@"<%@@%p {state# %d}>",
      NSStringFromClass([self class]), self, highlightState->getId()];
}

@end

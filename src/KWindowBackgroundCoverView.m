// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "KWindowBackgroundCoverView.h"


@implementation KWindowBackgroundCoverView

- (BOOL)shouldDelayWindowOrderingForEvent:(NSEvent *)theEvent {
  return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent {
  return YES; 
}

- (void)mouseDown:(NSEvent *)theEvent {
  [NSApp preventWindowOrdering]; 
}

@end

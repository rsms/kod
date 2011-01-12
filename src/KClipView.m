// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "KClipView.h"
#import "common.h"

@implementation KClipView

@synthesize allowsScrolling = allowsScrolling_;

- (id)initWithFrame:(NSRect)frame {
  if ((self = [super initWithFrame:frame])) {
    [self setDrawsBackground:NO];
    [self setCopiesOnScroll:NO];
    allowsScrolling_ = YES;
  }
  return self;
}


- (void)scrollToPoint:(NSPoint)newOrigin {
  if (allowsScrolling_)
    [super scrollToPoint:newOrigin];
}


- (BOOL)autoscroll:(NSEvent*)event {
  //DLOG("%@ autoscroll:%@", self, event);
  if (allowsScrolling_)
    return [super autoscroll:event];
  return NO;
}


@end

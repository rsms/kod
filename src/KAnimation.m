// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "KAnimation.h"

@implementation KAnimation


@synthesize onEnd = onEnd_,
            onProgress = onProgress_;


+ (KAnimation*)animationWithDuration:(NSTimeInterval)duration
                      animationCurve:(NSAnimationCurve)animationCurve {
  return [[[self alloc] initWithDuration:duration
                          animationCurve:animationCurve] autorelease];
}


- (id)initWithDuration:(NSTimeInterval)duration
        animationCurve:(NSAnimationCurve)animationCurve {
  if (!(self = [super initWithDuration:duration
                        animationCurve:animationCurve]))
    return nil;
  [self setDelegate:self];
  [self setAnimationBlockingMode:NSAnimationNonblocking];
  return self;
}


- (void)dealloc {
  if (onEnd_) [onEnd_ release];
  if (onProgress_) [onProgress_ release];
  [super dealloc];
}


- (void)animationDidEnd:(NSAnimation *)animation {
  if (onEnd_ && animation == self) onEnd_();
}


- (void)setCurrentProgress:(NSAnimationProgress)progress {
  if (onProgress_) onProgress_(progress);
}


@end

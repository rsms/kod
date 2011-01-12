// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

@interface KAnimation : NSAnimation <NSAnimationDelegate> {
  void(^onProgress_)(float);
  void(^onEnd_)(void);
}

@property(copy) void(^onProgress)(float);
@property(copy) void(^onEnd)(void);

+ (KAnimation*)animationWithDuration:(NSTimeInterval)duration
                      animationCurve:(NSAnimationCurve)animationCurve;

- (id)initWithDuration:(NSTimeInterval)duration
        animationCurve:(NSAnimationCurve)animationCurve;

@end

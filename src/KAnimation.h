
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

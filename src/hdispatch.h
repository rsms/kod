#ifndef H_DISPATCH_H_
#define H_DISPATCH_H_

#define K_DISPATCH_MAIN_ASYNC(...)\
  dispatch_async(dispatch_get_main_queue(),^{ \
    NSAutoreleasePool *__arpool = [NSAutoreleasePool new]; \
    __VA_ARGS__ \
    [__arpool drain]; \
  })

#define K_DISPATCH_MAIN_SYNC(...)\
  dispatch_sync(dispatch_get_main_queue(),^{ \
    NSAutoreleasePool *__arpool = [NSAutoreleasePool new]; \
    __VA_ARGS__ \
    [__arpool drain]; \
  })

#define K_DISPATCH_BG_ASYNC(...)\
  dispatch_async(dispatch_get_global_queue(0,0),^{ \
    NSAutoreleasePool *__arpool = [NSAutoreleasePool new]; \
    __VA_ARGS__ \
    [__arpool drain]; \
  })

inline static void h_dispatch_async_main(dispatch_block_t block) {
  block = [block copy];
  dispatch_async(dispatch_get_main_queue(), ^{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    block();
    [block release];
    [pool drain];
  });
}

inline static void h_dispatch_delayed_main(unsigned delaymillis,
                                           dispatch_block_t block) {
  block = [block copy];
  dispatch_time_t delay = dispatch_time(0, delaymillis*1000000LL);
  dispatch_after(delay, dispatch_get_main_queue(), ^{
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    block();
    [block release];
    [pool drain];
  });
}

#endif  // H_DISPATCH_H_

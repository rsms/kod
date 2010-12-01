#ifndef H_DISPATCH_H_
#define H_DISPATCH_H_

#define K_DISPATCH_MAIN_ASYNC(inlineblock)\
  dispatch_async(dispatch_get_main_queue(),^{ \
    NSAutoreleasePool *__arpool = [NSAutoreleasePool new]; \
    inlineblock \
    [__arpool drain]; \
  })

// dispatches to main queue if not on main thread, otherwise runs |inlineblock|
// directly. Note that this writes |inlineblock| twice, but in two different
// branches.
#define K_DISPATCH_MAIN_ASYNC2(inlineblock) do { \
  if ([NSThread isMainThread]) { \
    inlineblock \
  } else { \
    K_DISPATCH_MAIN_ASYNC(inlineblock); \
  } \
  } while(0)

#define K_DISPATCH_MAIN_SYNC(inlineblock)\
  dispatch_sync(dispatch_get_main_queue(),^{ \
    NSAutoreleasePool *__arpool = [NSAutoreleasePool new]; \
    inlineblock \
    [__arpool drain]; \
  })

#define K_DISPATCH_BG_ASYNC(inlineblock)\
  dispatch_async(dispatch_get_global_queue(0,0),^{ \
    NSAutoreleasePool *__arpool = [NSAutoreleasePool new]; \
    inlineblock \
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

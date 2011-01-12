// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#ifndef H_DISPATCH_H_
#define H_DISPATCH_H_

#import <dispatch/dispatch.h>

#ifdef __OBJC__

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


/*!
 * Start a perpetual timer which invokes |block| every |interval| milliseconds
 * on |queue|.
 *
 * Simple example, printing "Timer triggered" to stderr every second:
 *
 *    hd_timer_start(1000.0, nil, ^{
 *      NSLog(@"Timer triggered");
 *    });
 *
 * Example which stops the timer after 10 invocations:
 *
 *    __block int counter = 0;
 *    hd_timer_start(1000.0, nil, ^(dispatch_source_t timer) {
 *      NSLog(@"Timer triggered");
 *      if (counter++ > 10)
 *        hd_timer_stop(timer);
 *    });
 *
 * Alternative version of the above example:
 *
 *    __block int counter = 0;
 *    __block dispatch_source_t timer; //          <--  note use of __block
 *    timer = hd_timer_start(1000.0, nil, ^{
 *      NSLog(@"Timer triggered");
 *      if (counter++ > 10)
 *        hd_timer_stop(timer);
 *    });
 *
 * @param interval milliseconds
 * @param queue Dispatch queue to execute |block| in. NULL means main queue.
 * @param block A block wich takes an optional dispatch_source_t argument
 */
#ifdef __cplusplus
extern "C" {
#endif
dispatch_source_t hd_timer_start(float interval, dispatch_queue_t queue,
                                 id block);
#ifdef __cplusplus
}
#endif

// Stop a timer
static inline void hd_timer_stop(dispatch_source_t timer) {
  dispatch_source_cancel(timer);
}


#endif  // __OBJC__

#endif  // H_DISPATCH_H_

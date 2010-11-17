/*
 *  common macros
 */
#ifndef K_COMMON_H_
#define K_COMMON_H_

#import <ChromiumTabs/common.h>
#import <assert.h>
#import <libkern/OSAtomic.h>

#define K_DISPATCH_MAIN_ASYNC(code)\
  dispatch_async(dispatch_get_main_queue(),^{ \
    NSAutoreleasePool *__arpool = [NSAutoreleasePool new]; \
    code \
    [__arpool drain]; \
  })

#define K_DISPATCH_MAIN_SYNC(code)\
  dispatch_sync(dispatch_get_main_queue(),^{ \
    NSAutoreleasePool *__arpool = [NSAutoreleasePool new]; \
    code \
    [__arpool drain]; \
  })

#define K_DISPATCH_BG_ASYNC(code)\
  dispatch_async(dispatch_get_global_queue(0,0),^{ \
    NSAutoreleasePool *__arpool = [NSAutoreleasePool new]; \
    code \
    [__arpool drain]; \
  })


#define DLOG_RANGE(r, str) do { \
    NSString *s = @"<index out of bounds>"; \
    @try{ s = [str substringWithRange:(r)]; }@catch(id e){} \
    DLOG( #r " %@ \"%@\"", NSStringFromRange(r), s); \
  } while (0)


#define NOTIMPLEMENTED() errx(4, "Not implemented reached in %s (%s:%d)", \
                              __PRETTY_FUNCTION__, __SRC_FILENAME__, __LINE__)

#define K_DEPRECATED \
  WLOG("DEPRECATED %s (%s:%d)", __PRETTY_FUNCTION__, __SRC_FILENAME__, __LINE__)

// Atomically perform (old = (dst = src)).
inline static void *k_swapptr(void * volatile *dst, void *src) {
  void *old;
  while (1) {
    old = *dst;
    if (OSAtomicCompareAndSwapPtrBarrier(old, src, dst)) break;
  }
  return old;
}



#import "NSString-utf8-range-conv.h"
#import "NSString-cpp.h"
#import "NSString-intern.h"
#import "NSString-ranges.h"
#import "NSError+KAdditions.h"
#import "NSColor-web.h"
#import "dsem-scope.hh"
#import "h-objc.h"

#endif  // K_COMMON_H_

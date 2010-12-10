/*
 *  common macros
 */
#ifndef K_COMMON_H_
#define K_COMMON_H_

#import <ChromiumTabs/common.h>
#import <assert.h>
#import <libkern/OSAtomic.h>


#define DLOG_RANGE(r, str) do { \
    NSString *s = @"<index out of bounds>"; \
    @try{ s = [str substringWithRange:(r)]; }@catch(id e){} \
    DLOG( #r " %@ \"%@\"", NSStringFromRange(r), s); \
  } while (0)


#ifdef __OBJC__
  #define K_CALLSTACK_SYMBOLS() [NSThread callStackSymbols]
  #define K_CALLSTACK_SYMBOLS_FORMATTER "%@"
#else
  #define K_CALLSTACK_SYMBOLS() "<callstack not available>"
  #define K_CALLSTACK_SYMBOLS_FORMATTER "%s"
#endif
#define DLOG_TRACE2() \
  _LOG('T', "%s " K_CALLSTACK_SYMBOLS_FORMATTER, __PRETTY_FUNCTION__, \
       K_CALLSTACK_SYMBOLS())


#if !NDEBUG
  #define kassert(expr) do { \
    if (!(expr)) { \
      _LOG('E', "Assertion failed: (" #expr ") in %s " \
           K_CALLSTACK_SYMBOLS_FORMATTER, __PRETTY_FUNCTION__, \
           K_CALLSTACK_SYMBOLS()); \
      Debugger(); \
      kill(getpid(), SIGABRT); \
    } \
  } while(0)
#else
  #define kassert(expr) ((void)0)
#endif


#define K_DEPRECATED \
  WLOG("DEPRECATED %s (%s:%d)", __PRETTY_FUNCTION__, __SRC_FILENAME__, __LINE__)

// Atomically perform (old = (dst = src)).
static inline void *k_swapptr(void * volatile *dst, void *src) {
  void *old;
  while (1) {
    old = *dst;
    if (OSAtomicCompareAndSwapPtrBarrier(old, src, dst)) break;
  }
  return old;
}

// format a string showing which bits are set
#if NDEBUG
#define debug_bits32(a) NULL
#else
static inline const char *debug_bits32(int32_t a) {
  int i;
  static char buf[33] = {0};
  for (i = 31 ; i >= 0 ; --i) {
    buf[31-i] = ((a & (1 << i)) == 0) ? '.' : '1';
  }
  return buf;
}
#endif

#import "kexceptions.h"
#import "hatomic_flags.h"
#import "hobjc.h"
#import "hdispatch.h"
#import "hcommon.h"

#ifdef __cplusplus
#import "basictypes.h"
#import "scoped_nsobject.h"
#import "HSemaphore.h"
#endif

// NS categories
#import "NSString-utf8-range-conv.h"
#import "NSString-cpp.h"
#import "NSString-intern.h"
#import "NSString-ranges.h"
#import "NSString-editdistance.h"
#import "NSString-data.h"
#import "NSError+KAdditions.h"
#import "NSColor-web.h"
#import "NSCharacterSet-kod.h"
#import "NSURL-blocks.h"
#import "NSMutableArray-kod.h"
#import "NSView-kod.h"
#import "NSData-kod.h"

#endif  // K_COMMON_H_

/*
 *  common macros
 */
#ifndef K_COMMON_H_
#define K_COMMON_H_

#import <assert.h>
#import <libkern/OSAtomic.h>
#import <err.h>
#import <unistd.h>
#import <stdlib.h>
#import <stdio.h>
#import <string.h>

// Foundation is nice to have
#ifdef __OBJC__
  #import <Foundation/Foundation.h>
#endif

// Filename macro
#ifndef __FILENAME__
  #define __FILENAME__ ((strrchr(__FILE__, '/') ?: __FILE__ - 1) + 1)
#endif
#define __SRC_FILENAME__ ((k_strrstr(__FILE__, "/src/") ?: __FILE__ - 1) + 1)

// log info, warning and error message
// DLOG(format[, ...]) -- log a debug message
#if defined(__OBJC__)
  #define _LOG(prefixch, fmt, ...) \
      NSLog((NSString*)(CFSTR("%c [%s:%d] " fmt)), prefixch, \
            __SRC_FILENAME__, __LINE__, ##__VA_ARGS__)
#else
  #define _LOG(prefixch, fmt, ...) \
      fprintf(stderr, "%c [%s:%d] " fmt, prefixch, \
              __SRC_FILENAME__, __LINE__, ##__VA_ARGS__)
#endif
#ifdef LOG_SILENT
  #define ILOG(...) do{}while(0)
#else
  #define ILOG(...) _LOG('I', __VA_ARGS__)
#endif
#define WLOG(...) _LOG('W', __VA_ARGS__)
#define ELOG(...) _LOG('E', __VA_ARGS__)

// Debug/development utilities
#if !defined(NDEBUG)
  #ifndef _DEBUG
    #define _DEBUG 1
  #endif
  // shorthand to include and evaluate <x> only for debug builds
  #define IFDEBUG(x) do{ x }while(0)
  #define DLOG(...) _LOG('D', __VA_ARGS__)
  #define DLOG_TRACE() _LOG('T', "%s", __func__)
  // log an expression
  #ifdef __OBJC__
    // trace "<ObjCClass: 0xAddress> selector"
    #define DLOG_TRACE_M() \
      _LOG('T', "%@ %@", self, NSStringFromSelector(_cmd));

    NSString *VTPG_DDToStringFromTypeAndValue(const char *tc, void *v);
    #define DLOG_EXPR(_X_) do{\
      __typeof__(_X_) _Y_ = (_X_);\
      const char * _TYPE_CODE_ = @encode(__typeof__(_X_));\
      NSString *_STR_ = VTPG_DDToStringFromTypeAndValue(_TYPE_CODE_, &_Y_);\
      if(_STR_){\
        NSLog(@"X [%s:%d] %s = %@", __SRC_FILENAME__, __LINE__, #_X_, _STR_);\
      }else{\
        NSLog(@"Unknown _TYPE_CODE_: %s for expression %s in function %s, file %s, line %d",\
              _TYPE_CODE_, #_X_, __func__, __SRC_FILENAME__, __LINE__);\
      }}while(0)
  #else // __OBJC__
    #define DLOG_EXPR(_X_) fprintf(stderr, "%s [%d] X [%s:%d] %s = %s\n",\
                              __FILENAME__, getpid(), __SRC_FILENAME__, __LINE__, \
                              #_X_, "<TODO:common.h>")
    // TODO eval expression ---------------^
  #endif // __OBJC__
#else // !defined(NDEBUG)
  #define IFDEBUG(x)     do{}while(0)
  #define DLOG(...)      do{}while(0)
  #define DLOG_TRACE()   do{}while(0)
  #define DLOG_EXPR(...) do{}while(0)
#endif // !defined(NDEBUG)

// libbase compatible assertion macros
#define DCHECK assert
#define DCHECK_OP(op, val1, val2) assert((val1) op (val2))
#define DCHECK_EQ(val1, val2) DCHECK_OP(==, val1, val2)
#define DCHECK_NE(val1, val2) DCHECK_OP(!=, val1, val2)
#define DCHECK_LE(val1, val2) DCHECK_OP(<=, val1, val2)
#define DCHECK_LT(val1, val2) DCHECK_OP(< , val1, val2)
#define DCHECK_GE(val1, val2) DCHECK_OP(>=, val1, val2)
#define DCHECK_GT(val1, val2) DCHECK_OP(> , val1, val2)

// log an error and exit when reaching unimplemented parts
#define NOTIMPLEMENTED() errx(4, "[not implemented] %s (%s:%d)", \
                              __PRETTY_FUNCTION__, __SRC_FILENAME__, __LINE__)

#define NOTREACHED() assert(false && "Should not have been reached")

// strrstr
#ifdef __cplusplus
extern "C" {
#endif
const char *k_strrstr(const char *string, const char *find);
#ifdef __cplusplus
}
#endif


#define DLOG_RANGE(r, str) do { \
  if ((r).location == NSNotFound && (r).length == NSNotFound) { \
    DLOG( #r " {NSNotFound, NSNotFound} (null)"); \
  } else if ((r).location == NSNotFound) { \
    DLOG( #r " {NSNotFound, %lu} (null)", (r).length); \
  } else if ((r).length == NSNotFound) { \
    DLOG( #r " {%lu, NSNotFound} (null)", (r).location); \
  } else { \
    NSString *s = @"<index out of bounds>"; \
    @try{ s = [str substringWithRange:(r)]; }@catch(id e){} \
    DLOG( #r " %@ \"%@\"", NSStringFromRange(r), s); \
  } \
} while(0)


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

#import "hatomic_flags.h"
#import "hdispatch.h"
#import "hcommon.h"
#import "shared-dispatch-queues.h"
#import "kfs.h"

#ifdef __cplusplus
#import "basictypes.h"
#import "scoped_nsobject.h"
#import "HSemaphore.h"
#endif

#ifdef __OBJC__
#import "hobjc.h"
#import "kexceptions.h"

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
#import "HURLConnection.h"  // provides NSURL category
#import "NSMutableArray-kod.h"
#import "NSView-kod.h"
#import "NSData-kod.h"
#import "NSThread-condensedStackTrace.h"
#endif  // __OBJC__

#endif  // K_COMMON_H_

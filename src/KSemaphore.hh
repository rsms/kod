#ifndef D_SEMAPHORE_SCOPE_H_
#define D_SEMAPHORE_SCOPE_H_

#import <dispatch/dispatch.h>

#ifdef __cplusplus

#define KSemaphoreSection(dsema) for (KSemaphoreScope kSemaphoreScope(dsema); \
  kSemaphoreScope.refs-- != 0;)

class KSemaphoreScope {
 public:
  int refs;  ///< primarily used for the convenience scope macro
  inline KSemaphoreScope(dispatch_semaphore_t dsema) : dsema_(dsema), refs(1) {
    //fprintf(stderr, "dsemscope %p INCREMENT\n", dsema_);
    //NSLog(@"%@", [NSThread callStackSymbols]);
    dispatch_semaphore_wait(dsema_, DISPATCH_TIME_FOREVER);
  }
  inline ~KSemaphoreScope() {
    //fprintf(stderr, "dsemscope %p DECREMENT\n", dsema_);
    dispatch_semaphore_signal(dsema_);
    refs--;
  }
 private:
  dispatch_semaphore_t dsema_;
};

#endif  // __cplusplus
#endif  // D_SEMAPHORE_SCOPE_H_

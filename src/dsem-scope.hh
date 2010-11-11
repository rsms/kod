#ifndef D_SEMAPHORE_SCOPE_H_
#define D_SEMAPHORE_SCOPE_H_

#import <dispatch/dispatch.h>

#ifdef __cplusplus

class KSemaphoreScope {
 public:
  inline KSemaphoreScope(dispatch_semaphore_t dsema) : dsema_(dsema) {
    //fprintf(stderr, "dsemscope %p INCREMENT\n", dsema_);
    //NSLog(@"%@", [NSThread callStackSymbols]);
    dispatch_semaphore_wait(dsema_, DISPATCH_TIME_FOREVER);
  }
  inline ~KSemaphoreScope() {
    //fprintf(stderr, "dsemscope %p DECREMENT\n", dsema_);
    dispatch_semaphore_signal(dsema_);
  }
 private:
  dispatch_semaphore_t dsema_;
};

#endif  // __cplusplus
#endif  // D_SEMAPHORE_SCOPE_H_

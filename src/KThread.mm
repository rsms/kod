#import "KThread.h"
#import "common.h"

static KThread *backgroundThread_ = nil;
static OSSpinLock backgroundThreadSpinLock_ = OS_SPINLOCK_INIT;
static dispatch_semaphore_t backgroundThreadSemaphore_ = NULL;
    // 0 = starting, 1 = started

static inline void _initbg() {
  if (!backgroundThreadSemaphore_) {
    dispatch_semaphore_t old = (dispatch_semaphore_t)
        k_swapptr((void*volatile*)&backgroundThreadSemaphore_,
                  (void*)dispatch_semaphore_create(1));
    if (old) dispatch_release(old);
  }
}

@implementation KThread


+ (void)load {
  _initbg();
}


+ (KThread*)backgroundThread {
  _initbg();
  dispatch_retain(backgroundThreadSemaphore_);
  dispatch_semaphore_wait(backgroundThreadSemaphore_, DISPATCH_TIME_FOREVER);
  if (!backgroundThread_) {
    backgroundThread_ = [[self alloc] init];
    backgroundThread_.keepalive = YES;
    assert(backgroundThread_ != nil);
    [backgroundThread_ start];
    // -main will signal backgroundThreadSemaphore_
  } else {
    dispatch_semaphore_signal(backgroundThreadSemaphore_);
  }
  dispatch_release(backgroundThreadSemaphore_);
  return backgroundThread_;
}


- (id)init {
  self = [super init];
  runSemaphore_ = dispatch_semaphore_create(0);
  keepalive_ = NO;
  return self;
}


- (void)dealloc {
  dispatch_release(runSemaphore_);
  runSemaphore_ = NULL;
  [super dealloc];
}


- (NSRunLoop*)runLoop {
  OSMemoryBarrier();
  return runLoop_;
}


- (BOOL)keepalive {
  OSMemoryBarrier();
  return keepalive_;
}


- (void)setKeepalive:(BOOL)keepalive {
  OSMemoryBarrier();
  keepalive_ = keepalive;
}


- (void)main {
  NSAutoreleasePool *outerPool = [NSAutoreleasePool new];
  [self retain];
  [h_objc_swap(&runLoop_, [[NSRunLoop currentRunLoop] retain]) release];
  NSDate *distantFuture = [NSDate distantFuture];

  if (keepalive_) {
    NSTimer *keepaliveTimer = [NSTimer timerWithTimeInterval:DBL_MAX
                                                  invocation:nil
                                                     repeats:NO];
    [runLoop_ addTimer:keepaliveTimer forMode:NSDefaultRunLoopMode];
  }

  // runSemaphore_ is only used for initial waiting -- allow up to 5 concurrent
  // locks w/o causing contention and thus an expensive call to the kernel.
  for (int i = 5; i--;) dispatch_semaphore_signal(runSemaphore_);

  // for anyone waiting at +backgroundThread
  dispatch_semaphore_signal(backgroundThreadSemaphore_);

  NSAutoreleasePool *pool;
  while (![self isCancelled]) {
    pool = [NSAutoreleasePool new];
    if (![runLoop_ runMode:NSDefaultRunLoopMode beforeDate:distantFuture]) {
      [self cancel];
    }
    [pool drain];
  }

  // unwind
  while (!dispatch_semaphore_wait(runSemaphore_, DISPATCH_TIME_NOW));
  [h_objc_swap(&runLoop_, nil) release];
  [self release];
  [outerPool drain];
}


- (void)cancel {
  CFRunLoopStop([runLoop_ getCFRunLoop]);
  // cmpxch if self == backgroundThread_
  if (OSAtomicCompareAndSwapPtrBarrier(self, nil, (void* volatile*)&backgroundThread_))
    [self release];
  [super cancel];
}


- (BOOL)performBlock:(void(^)(void))block {
  // wait until started if neccessary
  dispatch_semaphore_wait(runSemaphore_, DISPATCH_TIME_FOREVER);
  dispatch_semaphore_signal(runSemaphore_);
  if ([self isCancelled]) return NO;
  CFRunLoopRef rl = [runLoop_ getCFRunLoop];
  assert(rl != NULL);
  CFRunLoopPerformBlock(rl, kCFRunLoopDefaultMode, block);
  CFRunLoopWakeUp(rl);
  return YES;
}


- (BOOL)processURLConnection:(NSURLConnection*)connection {
  if ([self scheduleURLConnection:connection]) {
    [connection start];
    return YES;
  }
  return NO;
}


- (BOOL)scheduleURLConnection:(NSURLConnection*)connection {
  // wait until started if neccessary
  dispatch_semaphore_wait(runSemaphore_, DISPATCH_TIME_FOREVER);
  dispatch_semaphore_signal(runSemaphore_);
  if ([self isCancelled]) return NO;
  [connection scheduleInRunLoop:runLoop_ forMode:NSDefaultRunLoopMode];
  //CFRunLoopWakeUp([runLoop_ getCFRunLoop]);
  return YES;
}


@end

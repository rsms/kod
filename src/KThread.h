
@interface KThread : NSThread {
  NSRunLoop* runLoop_;
  dispatch_semaphore_t runSemaphore_;
  BOOL keepalive_;
}
@property(readonly) NSRunLoop* runLoop;
@property BOOL keepalive;

/// Shared background thread for jobs like low-priority I/O
+ (KThread*)backgroundThread;

/**
 * Schedule |block| to be run on this thread, blocking until the thread has
 * started if neccessary.
 *
 * Returns YES if block was accepted or NO if the thread has been cancelled.
 */
- (BOOL)performBlock:(void(^)(void))block;

@end

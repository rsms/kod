// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.



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

/**
 * Schedule NSURLConnection in this thread's runloop. Returns YES if scheduled
 * or NO if the thread has been cancelled.
 */
- (BOOL)scheduleURLConnection:(NSURLConnection*)connection;

/**
 * Schedule and start processing of connection in this thread. Returns YES if
 * scheduled and processing is pending/has started or NO if the thread has been
 * cancelled.
 */
- (BOOL)processURLConnection:(NSURLConnection*)connection;

@end

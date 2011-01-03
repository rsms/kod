#import "KMachServiceProtocol.h"

@interface KCLIProgram : NSObject {
  NSRunningApplication *kodApp_;
  id<KMachServiceProtocol> kodService_;
  NSURL *kodAppURL_;
  
  // variables allocated as an effect of parsing cli arguments
  NSMutableArray *URLsToOpen_;
  NSMutableDictionary *asyncWaitQueue_;
  BOOL forceReadStdin_; // true if a "-" is passed in argv
  int optNoWaitOpen_; // 1 if -n or --nowait-open
}

@property(readonly) NSRunningApplication *kodApp;
@property(readonly) id<KMachServiceProtocol> kodService;

// Bootstrapping
- (void)printUsageAndExit:(int)exitStatus;
- (void)parseOptionsOfLength:(int)argc argv:(char**)argv;
- (BOOL)findKodAppAndStartIfNeeded:(BOOL)asyncLaunch;
- (BOOL)connectToKod:(NSError**)outError timeout:(NSTimeInterval)timeout;

// Helper to create a new invocation with the receiver as its target
- (NSInvocation*)invocationForHandler:(SEL)handler;

/*!
 * Async action queue
 *
 * A callback has the following prototype:
 *
 *    void(^)([NSError*[, id arg1[, id arg2 ...[, id arg6]...]]])
 *
 * Examples:
 *
 *    [kodService_ performSomeAsyncAction:foo callback:[self registerCallback:
 *    ^(NSError *err, NSString *someArg, id anotherArg){
 *      DLOG("callback executed. err: %@, someArg: %@", err, someArg);
 *    }]];
 *
 */
- (NSInvocation*)registerCallback:(id)callback;
- (id)enqueueAsyncActionWithCallback:(id)callback;
- (id)dequeueAsyncAction:(id)key;
- (void)cancelAsyncAction:(id)key;

// Executing actions
- (void)takeAppropriateAction;

// Block until all pending actions have completed
- (void)waitUntilDone;

@end

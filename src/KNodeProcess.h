#import "HDProcess.h"
#import <libkern/OSAtomic.h>

extern NSString *const KNodeIPCTypeInvocation;
extern NSString *const KNodeIPCTypeEvent;
extern NSString *const KNodeIPCTypeResponse;

@interface KNodeProcess : NSObject {
  HDProcess *process_;
  HDStream *channel_;
  BOOL channelHasConfirmedHandshake_;
  NSMutableDictionary *responseWaitQueue_; // callbacks keyed by rtag
  OSSpinLock responseWaitQueueLock_;
}

+ (KNodeProcess*)sharedProcess;
- (void)start;
- (void)terminate;

// Send a object
- (void)sendObject:(id)object;

/*!
 * Build and send a protocol message with an optional callback.
 *
 * Message format:
 *
 * {
 *   rtag: int,    // optional tag which if present need to be sent in a response
 *                 // as confirmation
 *   type: string, // type of request. One of: "invocation", "event", "response"
 *   name: string, // name of method to invoke or event to emit
 *   data: id,     // payload
 * }
 */
- (NSNumber*)send:(NSString*)requestType
             name:(NSString*)name
             args:(id)args                    // optional, can be nil
         callback:(void(^)(id args))callback; // optional, can be nil

// Convenience metod w/o callback
- (void)send:(NSString*)requestType name:(NSString*)name args:(id)args;

// Cancel a pending callback passed to send:name:args:callback:
- (void)cancelCallbackForRTag:(NSNumber*)rtag;

// Called when a message has been received from node
- (void)didReceiveMessage:(id)message;

@end

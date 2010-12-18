#import "KNodeProcess.h"
#import "kconf.h"
#import "JSON.h"
#import <dispatch/dispatch.h>
#import "common.h"

NSString *const KNodeIPCTypeInvocation = @"invocation";
NSString *const KNodeIPCTypeEvent = @"event";
NSString *const KNodeIPCTypeResponse = @"response";

static KNodeProcess *gSharedProcess = nil;
static uint64_t gNextRTag = 0;


static NSString *_dataToWeakString(const void *bytes, size_t length) {
  NSString *str;
  @try {
    str = [[[NSString alloc] initWithBytesNoCopy:(void*)bytes
                                          length:length
                                        encoding:NSUTF8StringEncoding
                                    freeWhenDone:NO] autorelease];
  } @catch(NSException *e) {
    str = [[NSData dataWithBytesNoCopy:(void*)bytes length:length
                          freeWhenDone:NO] description];
  }
  return str;
}


@implementation KNodeProcess


+ (void)initialize {
  NSAutoreleasePool * pool = [NSAutoreleasePool new];
  // Not everyone has /usr/local/bin in their path, which is the default
  // location of node
  setenv("PATH", [[[NSString stringWithUTF8String:getenv("PATH")]
                   stringByAppendingString:@":/usr/local/bin"] UTF8String], 1);
  [pool drain];
}


+ (id)sharedProcess {
  if (!gSharedProcess) {
    KNodeProcess *sharedProcess = [[self alloc] init];
    if (h_casid(&gSharedProcess, sharedProcess)) {
      [sharedProcess start];
    } else {
      // someone else won the race
      [sharedProcess release];
    }
  }
  return gSharedProcess;
}


- (id)init {
  if (!(self = [super init])) return nil;

  responseWaitQueueLock_ = OS_SPINLOCK_INIT;
  responseWaitQueue_ = [NSMutableDictionary new];

  // create process
  process_ = [HDProcess processWithProgram:@"node"];
  
  // exit handler
  [process_ on:@"exit" call:^(HDProcess *proc) {
    // TODO: restart?
    NSLog(@"[node]: exited with status %d", proc.exitStatus);
    [channel_ cancel];
    channel_ = nil;
  }];
  
  // dump node output to console
  process_.stdout.onData = ^(const void *bytes, size_t length) {
    NSLog(@"[node stdout]: %@", _dataToWeakString(bytes, length));
  };
  process_.stderr.onData = ^(const void *bytes, size_t length) {
    NSLog(@"[node stderr]: %@", _dataToWeakString(bytes, length));
  };
  
  return self;
}


- (void)start {
  kassert(process_);
  
  // start node with main.js
  NSString *mainScriptPath = [kconf_res_url(@"main.js") path];
  [process_ startWithArguments:mainScriptPath, nil];
  
  // open the IPC channel
  NSMutableData *recvBuffer = [NSMutableData data];
  channelHasConfirmedHandshake_ = NO;
  channel_ = [process_ openChannel:@"openchannel:kod.ipc"
  onData:^(const void *bytes, size_t length) {
    if (!channelHasConfirmedHandshake_) {
      // "hello\0"
      // We are making a somewhat risky assumption here that the full 8 byte
      // string will arrive in a single chunk. This is not guaranteed, but
      // because we know stuff, like the backing stream is an anonymous UNIX
      // socketpair, we run on Darwin kqueue, etc. this is pretty safe.
      if (length == 8 && memcmp((const char*)bytes, "\"hello\"\0", 8) == 0) {
        // this is safe w/o memory synchronization (since it's a bool)
        channelHasConfirmedHandshake_ = YES;
        DLOG("[node ipc]: handshake OK");
      } else {
        WLOG("[node ipc]: handshake failure: %@",
             _dataToWeakString(bytes, length));
        [channel_ cancel];
      }
    } else {
      // Parse data

      // Implementation of HDStream onData guaratees that there is at least one
      // extra byte available in |bytes|, thus it's safe to do this:
      ((char*)bytes)[length] = '\0';
      
      // TODO: look for more than one message in |bytes|, like we do in main.js

      // Check for \0 in |bytes| (message sentinel/delimiter). We utilize strlen
      // as it's efficiently implemented.
      size_t lengthUntilNull = strlen((const char*)bytes);
      if (lengthUntilNull < length) {
        // buffer included a null
        [recvBuffer appendBytes:bytes length:lengthUntilNull];
        // parse as JSON
        //id message = [recvBuffer JSONValue];
        id message =
          [[recvBuffer weakStringWithEncoding:NSUTF8StringEncoding] JSONValue];
        // handle remainder of data
        if (lengthUntilNull == length-1) {
          [recvBuffer setLength:0];
        } else {
          [recvBuffer setLength:length-lengthUntilNull];
          const char *remainder = (((char*)bytes)+(lengthUntilNull+1));
          [recvBuffer replaceBytesInRange:NSMakeRange(0, recvBuffer.length)
                                withBytes:remainder];
        }
        // emit "message" with parsed JSON object
        [self didReceiveMessage:message];
      } else {
        // no null in buffer -- append everything to recvBuffer
        [recvBuffer appendBytes:bytes length:length];
        DLOG("[node ipc]: received %lu bytes (partial message)", length);
      }
    }
  }];
  [channel_ on:@"close" call:^{
    DLOG("[node ipc]: closed");
    channel_ = nil;
    return;
  }];
  
  // xxx debug
  /*hd_timer_start(1000.0, NULL, (id)^(dispatch_source_t timer){
    DLOG("sending beacon");
    NSNumber *timestamp =
        [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]];
    [self send:KNodeIPCTypeEvent name:@"beacon" args:timestamp];
    [channel_ on:@"close" call:^{
      hd_timer_stop(timer);
    }];
  });
  
  // xxx debug
  [self on:@"beacon" call:^(NSNumber *timestamp) {
    DLOG("event: beacon(%@)", timestamp);
  }];*/
}


- (void)sendObject:(id)object {
  NSString *str = [object JSONRepresentation];
  NSMutableData *data = [str mutableDataUsingEncoding:NSUTF8StringEncoding];
  static const char nullchar = '\0';
  [data appendBytes:&nullchar length:1];
  [channel_ writeData:data];
}


- (NSNumber*)send:(NSString*)requestType
             name:(NSString*)name
             args:(id)args
         callback:(void(^)(id args))callback {
  kassert(requestType != nil);
  kassert(name != nil);
  if (!args) args = [NSNull null];
  NSNumber *rtag = nil;
  if (callback) {
    rtag = [NSNumber numberWithUnsignedLongLong:h_atomic_inc(&gNextRTag)];
    callback = [callback copy];
    OSSpinLockLock(&responseWaitQueueLock_);
    [responseWaitQueue_ setObject:callback forKey:rtag];
    OSSpinLockUnlock(&responseWaitQueueLock_);
    [callback release]; // our ref -- dict now owns the callback
  }
  NSDictionary *req = [NSDictionary dictionaryWithObjectsAndKeys:
      requestType, @"type", name, @"name", args, @"args", rtag, @"rtag", nil];
  [self sendObject:req];
  return rtag;
}


- (void)send:(NSString*)requestType name:(NSString*)name args:(id)args {
  [self send:requestType name:name args:args callback:nil]; 
}


- (void)cancelCallbackForRTag:(NSNumber*)rtag {
  OSSpinLockLock(&responseWaitQueueLock_);
  [responseWaitQueue_ removeObjectForKey:rtag];
  OSSpinLockUnlock(&responseWaitQueueLock_);
}


- (void)didReceiveMessage:(id)message {
  DLOG("[node ipc]: received message: %@", message);
  //[self emitEvent:@"message" argument:message];
  if ([message isKindOfClass:[NSDictionary class]]) {
    NSString *typ = [message objectForKey:@"type"];
    if ([typ isEqualToString:KNodeIPCTypeResponse]) {
      // handle response, which should have an rtag
      NSNumber *rtag = [message objectForKey:@"rtag"];
      if (rtag) {
        // invoke any queued callback
        void(^callback)(id);
        OSSpinLockLock(&responseWaitQueueLock_);
        callback = [responseWaitQueue_ objectForKey:rtag];
        [responseWaitQueue_ removeObjectForKey:rtag];
        OSSpinLockUnlock(&responseWaitQueueLock_);
        if (callback)
          callback([message objectForKey:@"data"]);
      } else {
        WLOG("[node ipc]: received response without an rtag");
      }
    } else if ([typ isEqualToString:KNodeIPCTypeEvent]) {
      // emit event on self
      NSString *name = [message objectForKey:@"name"];
      if (name) {
        id data = [message objectForKey:@"data"];
        if (data && [data isKindOfClass:[NSArray class]]) {
          [self emitEvent:name arguments:data];
        } else {
          [self emitEvent:name argument:data];
        }
      } else {
        WLOG("[node ipc]: received event without a name");
      }
    } else {
      WLOG("[node ipc]: received message of invalid type '%@'", typ);
    }
  } else {
    WLOG("[node ipc]: received invalid message (not a dict)");
  }
}


@end

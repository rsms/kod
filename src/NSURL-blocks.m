#import "NSURL-blocks.h"

// ----------------------------------------------------------------------------

@interface HURLConnectionDelegate : NSObject {}
@end
@implementation HURLConnectionDelegate

- (void)_onComplete:(HURLConnection*)c
              error:(NSError*)err
             cancel:(BOOL)cancel {
  if (cancel)
    [c cancel];
  if (c->onComplete)
    c->onComplete(err, c->receivedData);
  [c release];
  [self release];
}

- (void)connection:(HURLConnection*)c didReceiveResponse:(NSURLResponse *)re {
  assert([c isKindOfClass:[HURLConnection class]]);
  if (c->onResponse) {
    NSError *error = c->onResponse(re);
    if (error) [self _onComplete:c error:error cancel:YES];
  }
  if (c->receivedData)
    [c->receivedData setLength:0];
}

- (void)connection:(HURLConnection *)c didReceiveData:(NSData *)data {
  assert([c isKindOfClass:[HURLConnection class]]);
  if (c->onData) {
    NSError *error = c->onData(data);
    if (error) [self _onComplete:c error:error cancel:YES];
  }
  if (c->receivedData)
    [c->receivedData appendData:data];
}

- (void)connection:(HURLConnection *)c didFailWithError:(NSError *)error {
  assert([c isKindOfClass:[HURLConnection class]]);
  [self _onComplete:c error:error cancel:NO];
}

- (void)connectionDidFinishLoading:(HURLConnection *)c {
  assert([c isKindOfClass:[HURLConnection class]]);
  [self _onComplete:c error:nil cancel:NO];
}

@end

// ----------------------------------------------------------------------------

@implementation HURLConnection

- (id)initWithRequest:(NSURLRequest*)request
      onResponseBlock:(HURLOnResponseBlock)_onResponse
          onDataBlock:(HURLOnDataBlock)_onData
      onCompleteBlock:(HURLOnCompleteBlock)_onComplete
     startImmediately:(BOOL)startImmediately {
  self = [super initWithRequest:request
                       delegate:[HURLConnectionDelegate new]
               startImmediately:startImmediately];
  if (self) {
    if (_onResponse)
      onResponse = [_onResponse copy];
    
    if (_onData) {
      onData = [_onData copy];
    } else {
      receivedData = [[NSMutableData alloc] init];
    }
    
    if (_onComplete)
      onComplete = [_onComplete copy];
  }
  return self;
}


- (void)dealloc {
  // nullify values since struct access is allowed (making memory debug easier)
  if (onResponse) { [onResponse release]; onResponse = nil; }
  if (onData) { [onData release]; onData = nil; }
  if (onComplete) { [onComplete release]; onComplete = nil; }
  if (receivedData) { [receivedData release]; receivedData = nil; }
  [super dealloc];
}

@end

// ----------------------------------------------------------------------------


@implementation NSURL (fetch)


- (HURLConnection*)fetchWithOnResponseBlock:(HURLOnResponseBlock)onResponse
                                onDataBlock:(HURLOnDataBlock)onData
                            onCompleteBlock:(HURLOnCompleteBlock)onComplete
                           startImmediately:(BOOL)startImmediately {
  NSURLRequest *req = 
      [NSURLRequest requestWithURL:self
                       cachePolicy:NSURLRequestUseProtocolCachePolicy
                   timeoutInterval:60.0];
  HURLConnection *conn =
      [[HURLConnection alloc] initWithRequest:req
                              onResponseBlock:onResponse
                                  onDataBlock:onData
                              onCompleteBlock:onComplete
                             startImmediately:startImmediately];
  return conn;
}


- (HURLConnection*)fetchWithOnResponseBlock:(NSError*(^)(NSURLResponse *response))onResponse
                            onCompleteBlock:(void(^)(NSError *err, NSData *data))onComplete
                           startImmediately:(BOOL)startImmediately {
  return [self fetchWithOnResponseBlock:onResponse
                            onDataBlock:nil
                        onCompleteBlock:onComplete
                       startImmediately:startImmediately];
}


@end

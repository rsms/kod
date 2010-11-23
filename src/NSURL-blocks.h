@class HURLConnection;

typedef NSError* (^HURLOnResponseBlock)(NSURLResponse*);
typedef NSError* (^HURLOnDataBlock)(NSData*);
typedef void (^HURLOnCompleteBlock)(NSError*,NSData*);

@interface NSURL (blocks)
- (HURLConnection*) fetchWithOnResponseBlock:(NSError*(^)(NSURLResponse *response))onResponse
                                 onDataBlock:(NSError*(^)(NSData *data))onData
                             onCompleteBlock:(void(^)(NSError *err, NSData *data))onComplete
                            startImmediately:(BOOL)startImmediately;

- (HURLConnection*) fetchWithOnResponseBlock:(NSError*(^)(NSURLResponse *response))onResponse
                             onCompleteBlock:(void(^)(NSError *err, NSData *data))onComplete
                            startImmediately:(BOOL)startImmediately;

@end

@interface HURLConnection : NSURLConnection {
 @public // struct access allowed
  HURLOnResponseBlock onResponse;
  HURLOnDataBlock onData;
  HURLOnCompleteBlock onComplete;
  NSMutableData *receivedData;
}
- (id)initWithRequest:(NSURLRequest *)request
      onResponseBlock:(HURLOnResponseBlock)onResponse
          onDataBlock:(HURLOnDataBlock)onData
      onCompleteBlock:(HURLOnCompleteBlock)onComplete
     startImmediately:(BOOL)startImmediately;
@end

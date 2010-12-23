@class HDStream;

@interface KSudo : NSObject {
}

+ (void)execute:(NSString*)executable
      arguments:(NSArray*)arguments
         prompt:(NSString*)prompt
       callback:(void(^)(NSError*,NSData*))callback;

+ (void)execute:(NSString*)executable
      arguments:(NSArray*)arguments
       callback:(void(^)(NSError*,NSData*))callback;

@end

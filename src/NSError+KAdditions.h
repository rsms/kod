#import <Cocoa/Cocoa.h>

@interface NSError (KAdditions)
+ (NSError *)kodErrorWithDescription:(NSString *)msg code:(NSInteger)code;
+ (NSError *)kodErrorWithDescription:(NSString *)msg;
+ (NSError *)kodErrorWithCode:(NSInteger)code format:(NSString *)format, ...;
+ (NSError *)kodErrorWithFormat:(NSString *)format, ...;
+ (NSError*)kodErrorWithOSStatus:(OSStatus)status;
+ (NSError*)kodErrorWithHTTPStatusCode:(int)status;
+ (NSError*)kodErrorWithException:(NSException*)exc;
@end

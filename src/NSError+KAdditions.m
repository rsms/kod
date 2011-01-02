#import "NSError+KAdditions.h"

static NSString *KErrorDomain = nil; // TODO: centralize this

@implementation NSError (KAdditions)

+ (void)initialize {
  KErrorDomain = @"KErrorDomain";
}

+ (NSError *)kodErrorWithDescription:(NSString *)msg code:(NSInteger)code {
  NSDictionary *info = [NSDictionary dictionaryWithObject:msg
      forKey:NSLocalizedDescriptionKey];
  NSLog(@"KOD ERROR: %@", msg);
  return [NSError errorWithDomain:KErrorDomain code:code userInfo:info];
}

+ (NSError *)kodErrorWithDescription:(NSString *)msg {
  return [NSError kodErrorWithDescription:msg code:0];
}

+ (NSError *)kodErrorWithCode:(NSInteger)code format:(NSString *)format, ... {
  va_list src, dest;
  va_start(src, format);
  va_copy(dest, src);
  va_end(src);
  NSString *msg = [[NSString alloc] initWithFormat:format arguments:dest];
  return [NSError kodErrorWithDescription:msg code:code];
}

+ (NSError *)kodErrorWithFormat:(NSString *)format, ... {
  va_list src, dest;
  va_start(src, format);
  va_copy(dest, src);
  va_end(src);
  NSString *msg = [[NSString alloc] initWithFormat:format arguments:dest];
  return [NSError kodErrorWithDescription:msg code:0];
}

+ (NSError*)kodErrorWithOSStatus:(OSStatus)status {
  return [NSError errorWithDomain:NSOSStatusErrorDomain
                             code:status
                         userInfo:nil];
}

+ (NSError*)kodErrorWithHTTPStatusCode:(int)status {
  NSString *msg = [NSHTTPURLResponse localizedStringForStatusCode:status];
  NSDictionary *info =
      [NSDictionary dictionaryWithObject:msg forKey:NSLocalizedDescriptionKey];
  return [NSError errorWithDomain:NSURLErrorDomain code:status userInfo:info];
}

@end

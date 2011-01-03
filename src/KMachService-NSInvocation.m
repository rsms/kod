#import "KMachService-NSInvocation.h"

@implementation NSInvocation (KMachService)

- (void)invokeKMachServiceCallbackWithArgument:(id)arg {
  [self invokeKMachServiceCallbackWithArguments:arg, nil];
}

- (void)invokeKMachServiceCallbackWithArguments:(id)firstArg, ... {
  static const NSUInteger argOffset = 3;
  NSUInteger argc = firstArg ? 1 : 0;
  NSUInteger maxArgs = [[self methodSignature] numberOfArguments] - argOffset;
  argc = MIN(argc, maxArgs);
  if (argc) {
    [self setArgument:&firstArg atIndex:argOffset];
    va_list valist;
    va_start(valist, firstArg);
    id arg;
    NSUInteger i = argOffset+1;
    while ((arg = va_arg(valist, id)) && i < maxArgs) {
      [self setArgument:&arg atIndex:(i + argOffset)];
    }
    va_end(valist);
  }
  [self invoke];
}

@end

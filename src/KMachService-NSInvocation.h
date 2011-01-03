
@interface NSInvocation (KMachService)

- (void)invokeKMachServiceCallbackWithArgument:(id)arg;
- (void)invokeKMachServiceCallbackWithArguments:(id)firstArg, ...;

@end
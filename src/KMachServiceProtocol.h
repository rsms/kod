
#define K_SHARED_SERVICE_PORT_NAME @"se.hunch.kod.app"

@protocol KMachServiceProtocol
- (void)openURLs:(NSArray*)absoluteURLStrings;
@end

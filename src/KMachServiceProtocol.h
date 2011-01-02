
#define K_SHARED_SERVICE_PORT_NAME "se.hunch.kod.app"

@protocol KMachServiceProtocol

- (void)openURLs:(NSArray*)absoluteURLStrings callback:(NSInvocation*)callback;

- (void)openNewDocumentWithData:(NSData*)data
                         ofType:(NSString*)typeName
                       callback:(NSInvocation*)callback;

@end

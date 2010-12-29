#import "KURLHandler.h"

@interface KFileURLHandler : KURLHandler {
}

- (void)readURL:(NSURL*)absoluteURL
         ofType:(NSString*)typeName
          inTab:(KDocument*)tab
successCallback:(void(^)(void))successCallback;

@end

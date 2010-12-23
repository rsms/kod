#import "KTabContents.h"

/*!
 * Lives in the shared KDocumentController instance's urlHandlers_ dict,
 * where URI schemes are mapped to KURLHandler objects.
 */
@interface KURLHandler : NSObject {
}

+ (KURLHandler*)handler;

- (BOOL)canReadURL:(NSURL*)url;

- (void)readURL:(NSURL*)absoluteURL
         ofType:(NSString*)typeName
          inTab:(KTabContents*)tab;

@end

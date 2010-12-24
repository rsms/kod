#import "KTabContents.h"

/*!
 * Lives in the shared KDocumentController instance's urlHandlers_ dict,
 * where URI schemes are mapped to KURLHandler objects.
 */
@interface KURLHandler : NSObject {
}

+ (KURLHandler*)handler;

- (BOOL)canReadURL:(NSURL*)url;
- (BOOL)canWriteURL:(NSURL*)url;

- (void)readURL:(NSURL*)absoluteURL
         ofType:(NSString*)typeName
          inTab:(KTabContents*)tab;

- (void)writeData:(NSData*)data
           ofType:(NSString*)typeName
            toURL:(NSURL*)url
            inTab:(KTabContents*)tab
 forSaveOperation:(NSSaveOperationType)saveOperation
      originalURL:(NSURL*)absoluteOriginalContentsURL
         callback:(void(^)(NSError *err, NSDate *mtime))callback;

@end

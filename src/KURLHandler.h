// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.


#import "KDocument.h"

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
          inTab:(KDocument*)tab;

- (void)writeData:(NSData*)data
           ofType:(NSString*)typeName
            toURL:(NSURL*)url
            inTab:(KDocument*)tab
 forSaveOperation:(NSSaveOperationType)saveOperation
      originalURL:(NSURL*)absoluteOriginalContentsURL
         callback:(void(^)(NSError *err, NSDate *mtime))callback;

@end

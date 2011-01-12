// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "KURLHandler.h"

@interface KFileURLHandler : KURLHandler {
}

- (void)readURL:(NSURL*)absoluteURL
         ofType:(NSString*)typeName
          inTab:(KDocument*)tab
successCallback:(void(^)(void))successCallback;

@end

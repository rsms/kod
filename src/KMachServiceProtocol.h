// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#define K_SHARED_SERVICE_PORT_NAME "se.hunch.kod.app"

@protocol KMachServiceProtocol

- (void)openURLs:(NSArray*)absoluteURLStrings callback:(NSInvocation*)callback;

- (void)openNewDocumentWithData:(NSData*)data
                         ofType:(NSString*)typeName
                       callback:(NSInvocation*)callback;

@end

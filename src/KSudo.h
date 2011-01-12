// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

@class HDStream;

@interface KSudo : NSObject {
}

+ (void)execute:(NSString*)executable
      arguments:(NSArray*)arguments
         prompt:(NSString*)prompt
       callback:(void(^)(NSError*,NSData*))callback;

+ (void)execute:(NSString*)executable
      arguments:(NSArray*)arguments
       callback:(void(^)(NSError*,NSData*))callback;

@end

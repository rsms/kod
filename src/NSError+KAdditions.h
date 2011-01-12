// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import <Cocoa/Cocoa.h>

@interface NSError (KAdditions)
+ (NSError *)kodErrorWithDescription:(NSString *)msg code:(NSInteger)code;
+ (NSError *)kodErrorWithDescription:(NSString *)msg;
+ (NSError *)kodErrorWithCode:(NSInteger)code format:(NSString *)format, ...;
+ (NSError *)kodErrorWithFormat:(NSString *)format, ...;
+ (NSError*)kodErrorWithOSStatus:(OSStatus)status;
+ (NSError*)kodErrorWithHTTPStatusCode:(int)status;
+ (NSError*)kodErrorWithException:(NSException*)exc;
@end

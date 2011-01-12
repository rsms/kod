// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "ICUPattern.h"

// struct-style member access for speed
@interface KLangMapLinePattern : NSObject {
 @public
  NSString const *langId;
  ICUPattern *pattern;
}

- (id)initWithPattern:(NSString*)pattern
               langId:(NSString const*)langId;

@end
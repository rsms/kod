// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "KLangMapLinePattern.h"

@implementation KLangMapLinePattern

- (id)initWithPattern:(NSString*)p
               langId:(NSString const*)lid {
  if ((self = [super init])) {
    pattern = [[ICUPattern alloc] initWithString:p flags:0];
    langId = [lid retain];
  }
  return self;
}

- (void)dealloc {
  [pattern release];
  [langId release];
  [super dealloc];
}

- (NSString*)description {
  return [NSString stringWithFormat:@"<%@@%p {'%@', /%@/}>",
      NSStringFromClass([self class]), self, langId,
      pattern ? [pattern pattern] : @"(null)"];
}

@end
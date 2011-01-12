// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "NSString-intern.h"
#import <libkern/OSAtomic.h>

@implementation NSString (intern)

static NSMutableDictionary *internedStrings_;

+ (void)load {
  internedStrings_ = [NSMutableDictionary new];
}

+ (NSString*)internedStringWithString:(NSString*)str {
  if (!str) return str;
  OSMemoryBarrier();
  NSString *interned = [internedStrings_ objectForKey:str];
  if (!interned) {
    [internedStrings_ setObject:str forKey:str];
    interned = str;
    //NSLog(@"[NSString intern] created %@", str);
  }
  //else if (str == interned) NSLog(@"[NSString intern] same %@", str);
  //else NSLog(@"[NSString intern] found %@", str);
  return interned;
}


- (NSString*)internedString {
  return [isa internedStringWithString:self];
}

@end

// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "NSString-data.h"
#import "common.h"

@implementation NSString (data)

- (NSMutableData*)mutableDataUsingEncoding:(NSStringEncoding)encoding {
  return [self mutableDataUsingEncoding:encoding
                                  range:NSMakeRange(0, self.length)];
}

- (NSMutableData*)mutableDataUsingEncoding:(NSStringEncoding)encoding
                                     range:(NSRange)range {
  NSUInteger estimatedSize = [self maximumLengthOfBytesUsingEncoding:encoding];
  NSUInteger actualSize = 0;
  char *bytes = (char*)CFAllocatorAllocate(NULL, estimatedSize, 0);
  [self getBytes:bytes
       maxLength:estimatedSize
      usedLength:&actualSize
        encoding:encoding
         options:0
           range:range
  remainingRange:NULL];
  NSMutableData *data = [NSMutableData dataWithBytesNoCopy:bytes
                                                    length:actualSize
                                              freeWhenDone:YES];
  return data;
}

@end

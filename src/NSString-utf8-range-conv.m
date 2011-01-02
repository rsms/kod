/*
 This code has been derived from the RegexKit project.

 Copyright © 2007-2008, John Engelhart

 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.

 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.

 * Neither the name of the Zang Industries nor the names of its
 contributors may be used to endorse or promote products derived from
 this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
#import "NSString-utf8-range-conv.h"

static const unsigned char utf8ExtraBytes[] = {
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
  2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
  3,3,3,3,3,3,3,3,4,4,4,4,5,5,5,5 };

static const unsigned char utf8ExtraUTF16Characters[] = {
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
  1,1,1,1,1,1,1,1,1,1,1,1,2,2,2,2 };


@implementation NSString (UTF8_range_conversion)

+ (NSRange)UTF16RangeFromUTF8Range:(NSRange)utf8range
                      inUTF8String:(const char *)utf8pch
                          ofLength:(size_t)utf8len {
  assert(utf8pch != NULL);
  if (utf8range.location == NSNotFound) return utf8range;
  assert(utf8range.location < utf8len);
  assert(NSMaxRange(utf8range) <= utf8len);

  NSUInteger utf16len = 0;
  NSRange utf16range = NSMakeRange(NSNotFound, 0);
  NSUInteger utf8rangeEnd = NSMaxRange(utf8range);
  const char *p = utf8pch;

  while ((NSUInteger)(p - utf8pch) < utf8rangeEnd) {
    if ((NSUInteger)(p - utf8pch) == utf8range.location) {
      utf16range.location = utf16len;
    }
    const unsigned char c = *p;
    p++;
    utf16len++;
    if (c < 128) continue;
    const unsigned char idx = c & 0x3f;
    p += utf8ExtraBytes[idx];
    utf16len += utf8ExtraUTF16Characters[idx];
  }
  if ((NSUInteger)(p - utf8pch) == utf8range.location)
    utf16range.location = utf16len;
  utf16range.length = utf16len - utf16range.location;

  return utf16range;
}

@end
#import "NSString-cpp.h"
#import "common.h"

@implementation NSString (cpp)

- (NSUInteger)populateStdString:(std::string&)str
                  usingEncoding:(NSStringEncoding)encoding
                          range:(NSRange)range {
  // TODO: benchmark if this is actually faster than a double-copy
  // (i.e. str = std::string([self UTF8String]) )
  NSUInteger estimatedSize = [self maximumLengthOfBytesUsingEncoding:encoding];
  str.resize(estimatedSize);
  char *pch = (char*)str.data();
  NSUInteger usedBufferCount = 0;
  [self getBytes:pch
       maxLength:estimatedSize
      usedLength:&usedBufferCount
        encoding:encoding
         options:0
           range:range
  remainingRange:NULL];
  str.resize(usedBufferCount);
  /*DLOG("mk utf8 std::string %@ '%@' --> '%@'",
     NSStringFromRange(range),
     [self substringWithRange:range],
     [NSString stringWithUTF8String:str->c_str()]);*/
  return usedBufferCount;
}

@end
#import "NSData-kod.h"
#import "ICUPattern.h"
#import "ICUMatcher.h"
#import "common.h"

@implementation NSData (Kod)


- (NSString*)weakStringWithEncoding:(NSStringEncoding)encoding {
  return [[NSString alloc] initWithBytesNoCopy:(void*)self.bytes
                                        length:self.length
                                      encoding:encoding
                                  freeWhenDone:NO];
}


- (NSString*)weakStringWithEncoding:(NSStringEncoding)encoding
                              range:(NSRange)range {
  const uint8_t *bytes = (const uint8_t*)self.bytes + range.location;
  return [[NSString alloc] initWithBytesNoCopy:(void*)bytes
                                        length:range.length
                                      encoding:encoding
                                  freeWhenDone:NO];
}


- (NSString*)weakStringByGuessingEncoding:(NSStringEncoding*)outEncoding {
  NSString *text = nil;
  NSStringEncoding encoding = 0;

  // Guess encoding if no explicit encoding, or explicit decode failed
  NSUInteger bomOffset = 0;
  encoding = [self guessEncodingWithPeekByteLimit:512 headOffset:&bomOffset];
  //DLOG("Guessed encoding: %@", textEncoding_==0 ? @"(none)" :
  //     [NSString localizedNameOfStringEncoding:textEncoding_]);
  // try decoding unless we failed to guess
  if (encoding != 0) {
    NSRange range = NSMakeRange(bomOffset, self.length-bomOffset);
    text = [self weakStringWithEncoding:encoding range:range];
  }

  // We failed to guess -- lets try some common encodings
  if (!text) {
    encoding = NSUTF8StringEncoding;
    text = [self weakStringWithEncoding:encoding];
    if (!text) {
      // This should _always_ work as it spans the complete byte range
      encoding = NSISOLatin1StringEncoding;
      text = [self weakStringWithEncoding:encoding];
    }
  }

  if (outEncoding)
    *outEncoding = text ? encoding : 0;

  return text;
}


- (NSStringEncoding)guessEncodingWithPeekByteLimit:(NSUInteger)peekByteLimit
                                        headOffset:(NSUInteger*)outHeadOffset {
  // First, check for BOM
  NSUInteger size = self.length;

  // test UTF-16 big endian (FE FF)
  const uint8_t *bytes = (const uint8_t*)self.bytes;
  if (size > 1 && bytes[0]==0xFE && bytes[1]==0xFF) {
    if (outHeadOffset) *outHeadOffset = 2;
    return NSUTF16BigEndianStringEncoding;
  }

  // test UTF-16 little endian (FF FE)
  if (size > 1 && bytes[0]==0xFF && bytes[1]==0xFE) {
    if (outHeadOffset) *outHeadOffset = 2;
    return NSUTF16LittleEndianStringEncoding;
  }

  // test UTF-32 big endian (00 00 FE FF)
  if (size > 3 &&
      bytes[0]==0 && bytes[1]==0 && bytes[2]==0xFE && bytes[3]==0xFF) {
    if (outHeadOffset) *outHeadOffset = 4;
    return NSUTF32BigEndianStringEncoding;
  }

  // test UTF-32 little endian (00 00 FF FE)
  if (size > 3 &&
      bytes[0]==0 && bytes[1]==0 && bytes[2]==0xFF && bytes[3]==0xFE) {
    if (outHeadOffset) *outHeadOffset = 4;
    return NSUTF32LittleEndianStringEncoding;
  }

  // test UTF-8 "BOM" (not really a BOM, but some Windows programs write it)
  if (size > 2 && bytes[0]==0xEF && bytes[1]==0xBB && bytes[0]==0xBF) {
    if (outHeadOffset) *outHeadOffset = 3;
    return NSUTF8StringEncoding;
  }

  // first, abort unless we have enough bytes to dig into data
  if (size < 10) return 0;

  // all prefix tests failed -- no head/leader
  if (outHeadOffset) *outHeadOffset = 0;

  // start digging into the data
  NSRange range = NSMakeRange(0, MIN(peekByteLimit, self.length));
  NSString *string = [self weakStringWithEncoding:NSISOLatin1StringEncoding
                                            range:range];

  // TODO: make static global:
  ICUPattern *gEncodingGuessRegExp = [[ICUPattern alloc] initWithString:
      // HTML, XML, Python, Vim, Emacs, etc
      @"content=\".*charset=([^\"]+)\""
       "|(?:charset|encoding)\\s*[=:]\\s*(?:\"([^\"]+)\"|'([^']+)'|([\\w-]+))"
       "|coding:\\s*([\\w-]+)"
       //content="text/html;charset=text/html;charset=x-sjis"
      flags:ICUCaseInsensitiveMatching];

  // Using regular expressions, find IANA charset name(s)
  ICUMatcher *m = [ICUMatcher matcherWithPattern:gEncodingGuessRegExp
                                      overString:string];
  if ([m findFromIndex:0]) {
    int groupCount = [m numberOfGroups];
    for (int i=1; i <= groupCount; i++) {
      NSString *groupValue = [m groupAtIndex:i];
      if (groupValue.length != 0) {
        //DLOG("m[%d] => '%@'", i, groupValue);
        // try to interpret an IANA charset name
        CFStringEncoding enc =
            CFStringConvertIANACharSetNameToEncoding((CFStringRef)groupValue);
        if (enc > 0)
          return CFStringConvertEncodingToNSStringEncoding(enc);
      }
    }
  }

  return 0;
}

@end

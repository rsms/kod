#import "NSString-ranges.h"
#import "common.h"

@implementation NSString (ranges)

-(NSRange)rangeOfCharactersFromSet:(NSCharacterSet*)aSet
                           options:(NSStringCompareOptions)mask
                             range:(NSRange)range {
  NSInteger start, curr, end, step=1;
  if (mask & NSBackwardsSearch) {
    step = -1;
    start = range.location + range.length - 1;
    end = range.location-1;
  } else {
    start = range.location;
    end = start + range.length;
  }
  if (!(mask & NSAnchoredSearch)) {
    // find first character in set
    for (;start != end; start += step) {
      if ([aSet characterIsMember:[self characterAtIndex:start]]) {
        goto found;
      }
    }
    return (NSRange){NSNotFound, 0u};
  }
  if (![aSet characterIsMember:[self characterAtIndex:start]]) {
    // no characters found within given range
    return (NSRange){NSNotFound, 0u};
  }

  found:
  for (curr = start; curr != end; curr += step) {
    if (![aSet characterIsMember:[self characterAtIndex:curr]]) {
      break;
    }
  }
  if (curr < start) {
    // search was backwards
    range.location = curr+1;
    range.length = start - curr;
  } else {
    range.location = start;
    range.length = curr - start;
  }
  return range;
}


- (NSRange)rangeOfCharactersFromSet:(NSCharacterSet*)characterSet
                      afterLocation:(NSUInteger)startLocation
                          substring:(NSString**)outString {
  NSRange searchRange = NSMakeRange(startLocation, self.length - startLocation);
  NSRange range = [self rangeOfCharactersFromSet:characterSet
                                         options:NSLiteralSearch
                                           range:searchRange];
  if (outString && range.location != NSNotFound)
    *outString = [self substringWithRange:range];
  return range;
}


- (NSRange)rangeOfWhitespaceStringAtBeginningOfLineForRange:(NSRange)range
                                               substring:(NSString**)outString {
  NSCharacterSet *whitespace = [NSCharacterSet whitespaceCharacterSet];
  NSUInteger lineStart = [self lineStartForRange:range];
  if (lineStart != NSNotFound && lineStart < self.length) {
    unichar firstCharOfLine = [self characterAtIndex:lineStart];
    if ([whitespace characterIsMember:firstCharOfLine]) {
      // first char is whitespace, so let's find the full range
      return [self rangeOfCharactersFromSet:whitespace
                              afterLocation:lineStart
                                  substring:outString];
    }
  }
  return NSMakeRange(NSNotFound, 0);
}


- (NSRange)rangeOfWhitespaceStringAtBeginningOfLineForRange:(NSRange)range {
  return [self rangeOfWhitespaceStringAtBeginningOfLineForRange:range
                                                      substring:nil];
}


- (NSUInteger)lineStartForRange:(NSRange)diveInRange {
  NSUInteger lineStartIndex = 0;
  [self getLineStart:&lineStartIndex
                 end:NULL
         contentsEnd:NULL
            forRange:diveInRange];
  return lineStartIndex;
}


- (unichar*)copyOfCharactersInRange:(NSRange)range {
  unichar *buf = (unichar*)malloc(range.length * sizeof(unichar));
  [self getCharacters:buf range:range];
  return buf;
}


+ (void)kodEnumerateLinesOfCharacters:(const unichar*)characters
                             ofLength:(NSUInteger)characterCount
                            withBlock:(void(^)(NSRange lineRange))block {
  NSUInteger i = 0;
  NSRange lineRange = {0, 0};
  while (i < characterCount) {
    unichar ch = characters[i++];
    //DLOG("characters[%lu] '%C' (%d)", i, ch, (int)ch);
    if (ch == '\r') {
      // CR
      if (i < characterCount-1 && characters[i+1] == '\n') {
        // advance past LF in a CR LF sequence
        ++i;
      }
    } else if (ch != '\n' && ch != '\x0b' && ch != '\x0c' &&
               i < characterCount) {
      // NEITHER: line feed OR vertical tab OR form feed OR not end
      continue;
    }
    // if we got here, a new line just begun
    lineRange.length = i - lineRange.location;

    // invoke block
    block(lineRange);

    // begin new line
    lineRange.location = i;
  }
}


- (BOOL)hasPrefix:(NSString*)prefix options:(NSStringCompareOptions)options {
  NSRange range = NSMakeRange(0, prefix.length);
  if (self.length < range.length)
    return NO;
  return [self compare:prefix options:options range:range] == NSOrderedSame;
}


@end

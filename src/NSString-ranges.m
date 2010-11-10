#import "NSString-ranges.h"

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

@end

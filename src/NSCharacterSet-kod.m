#import "NSCharacterSet-kod.h"
#import "h-objc.h"

@implementation NSCharacterSet (Kod)

static NSCharacterSet * gWhitespaceAndCommaCharacterSet_;

+ (NSCharacterSet*)whitespaceAndCommaCharacterSet {
  if (!gWhitespaceAndCommaCharacterSet_) {
    NSCharacterSet *cs =
        [NSCharacterSet characterSetWithCharactersInString:@", "];
    [h_objc_swap(&gWhitespaceAndCommaCharacterSet_, [cs retain]) release];
  }
  return gWhitespaceAndCommaCharacterSet_;
}

@end

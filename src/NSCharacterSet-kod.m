#import "NSCharacterSet-kod.h"
#import "hobjc.h"

@implementation NSCharacterSet (Kod)

static NSCharacterSet * gWhitespaceAndCommaCharacterSet_;
static NSCharacterSet * gSlashCharacterSet_;

+ (NSCharacterSet*)whitespaceAndCommaCharacterSet {
  if (!gWhitespaceAndCommaCharacterSet_) {
    NSCharacterSet *cs =
        [NSCharacterSet characterSetWithCharactersInString:@", "];
    [h_objc_swap(&gWhitespaceAndCommaCharacterSet_, [cs retain]) release];
  }
  return gWhitespaceAndCommaCharacterSet_;
}

+ (NSCharacterSet*)slashCharacterSet {
  if (!gSlashCharacterSet_) {
    NSCharacterSet *cs =
        [NSCharacterSet characterSetWithCharactersInString:@"/"];
    [h_objc_swap(&gSlashCharacterSet_, [cs retain]) release];
  }
  return gSlashCharacterSet_;
}

@end

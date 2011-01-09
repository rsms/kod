#import "NSCharacterSet-kod.h"
#import "hcommon.h"

@implementation NSCharacterSet (Kod)

static NSCharacterSet * gWhitespaceAndCommaCharacterSet_;
static NSCharacterSet * gSlashCharacterSet_;

+ (NSCharacterSet*)whitespaceAndCommaCharacterSet {
  if (!gWhitespaceAndCommaCharacterSet_) {
    NSCharacterSet *cs =
        [NSCharacterSet characterSetWithCharactersInString:@", "];
    h_casid(&gWhitespaceAndCommaCharacterSet_, cs);
  }
  return gWhitespaceAndCommaCharacterSet_;
}

+ (NSCharacterSet*)slashCharacterSet {
  if (!gSlashCharacterSet_) {
    NSCharacterSet *cs =
        [NSCharacterSet characterSetWithCharactersInString:@"/"];
    h_casid(&gSlashCharacterSet_, cs);
  }
  return gSlashCharacterSet_;
}

@end

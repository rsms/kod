#import "KLangMapLinePattern.h"

@implementation KLangMapLinePattern

- (id)initWithPattern:(NSString*)p
               langId:(NSString*)lid {
  if ((self = [super init])) {
    pattern = [[ICUPattern alloc] initWithString:p flags:0];
    langId = [lid retain];
  }
  return self;
}

- (void)dealloc {
  [pattern release];
  [langId release];
  [super dealloc];
}

- (NSString*)description {
  return [NSString stringWithFormat:@"<%@@%p {'%@', /%@/}>",
      NSStringFromClass([self class]), self, langId,
      pattern ? [pattern pattern] : @"(null)"];
}

@end

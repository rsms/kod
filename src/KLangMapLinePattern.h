#import "ICUPattern.h"

// struct-style member access for speed
@interface KLangMapLinePattern : NSObject {
 @public
  NSString const *langId;
  ICUPattern *pattern;
}

- (id)initWithPattern:(NSString*)pattern
               langId:(NSString const*)langId;

@end
#import "ICUPattern.h"

// struct-style member access for speed
@interface KLangMapLinePattern : NSObject {
 @public
  NSString *langId;
  ICUPattern *pattern;
}

- (id)initWithPattern:(NSString*)pattern langId:(NSString*)langId;

@end

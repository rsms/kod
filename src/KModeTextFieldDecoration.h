#import "KTextFieldDecoration.h"

@interface KModeTextFieldDecoration : KTextFieldDecoration {
  NSImage *icon_;
  NSString *name_;
}
@property(retain) NSString *name;

- (id)initWithName:(NSString*)name;

@end

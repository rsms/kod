@interface NSString (intern)

+ (NSString*)internedStringWithString:(NSString*)str;
- (NSString*)internedString;

@end


@interface NSString (data)

- (NSMutableData*)mutableDataUsingEncoding:(NSStringEncoding)encoding;

- (NSMutableData*)mutableDataUsingEncoding:(NSStringEncoding)encoding
                                     range:(NSRange)range;

@end

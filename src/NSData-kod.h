@interface NSData (Kod)

// Returns an autoreleased string which will become invalid as soon as this data
// is deallocated. |range| is in bytes.
- (NSString*)weakStringWithEncoding:(NSStringEncoding)encoding
                              range:(NSRange)range;

- (NSString*)weakStringWithEncoding:(NSStringEncoding)encoding;

// If outEncoding is not nil, a successful encoding will be assigned (or zero)
- (NSString*)weakStringByGuessingEncoding:(NSStringEncoding*)outEncoding;

- (NSStringEncoding)guessEncodingWithPeekByteLimit:(NSUInteger)peekByteLimit
                                        headOffset:(NSUInteger*)outHeadOffset;

@end

@interface NSData (Kod)

// Returns an autoreleased string which will become invalid as soon as this data
// is deallocated. |range| is in bytes.
- (NSString*)weakStringWithEncoding:(NSStringEncoding)encoding
                              range:(NSRange)range;

- (NSString*)weakStringWithEncoding:(NSStringEncoding)encoding;

- (NSStringEncoding)guessEncodingWithPeekByteLimit:(NSUInteger)peekByteLimit
                                        headOffset:(NSUInteger*)outHeadOffset;

@end

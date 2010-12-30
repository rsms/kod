@interface NSString (ranges)

- (NSRange)rangeOfCharactersFromSet:(NSCharacterSet*)charset
                            options:(NSStringCompareOptions)opts
                              range:(NSRange)range;

- (NSRange)rangeOfCharactersFromSet:(NSCharacterSet*)characterSet
                      afterLocation:(NSUInteger)startLocation
                          substring:(NSString**)outString;

- (NSRange)rangeOfWhitespaceStringAtBeginningOfLineForRange:(NSRange)range
                                                substring:(NSString**)outString;

- (NSRange)rangeOfWhitespaceStringAtBeginningOfLineForRange:(NSRange)range;

- (NSUInteger)lineStartForRange:(NSRange)diveInRange;

- (unichar*)copyOfCharactersInRange:(NSRange)range;

+ (void)kodEnumerateLinesOfCharacters:(const unichar*)characters
                             ofLength:(NSUInteger)characterCount
                            withBlock:(void(^)(NSRange lineRange))block;

@end

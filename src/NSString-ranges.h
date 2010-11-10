@interface NSString (ranges)

-(NSRange)rangeOfCharactersFromSet:(NSCharacterSet*)charset
                           options:(NSStringCompareOptions)opts
                             range:(NSRange)range;
@end

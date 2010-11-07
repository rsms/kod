@interface NSString (UTF8_range_conversion)
+ (NSRange)UTF16RangeFromUTF8Range:(NSRange)utf8range
                      inUTF8String:(const char *)utf8pch
                          ofLength:(size_t)utf8len;
@end


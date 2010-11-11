// dealing with NSString and C++ std library
#ifdef __cplusplus
#import <string>

@interface NSString (cpp)
- (NSUInteger)populateStdString:(std::string&)str
                  usingEncoding:(NSStringEncoding)encoding
                          range:(NSRange)range;
@end

#endif // __cplusplus

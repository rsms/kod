@interface KTextView : NSTextView {
}

- (void)unindentLine:(NSUInteger)lineNumber;
- (void)indentLine:(NSUInteger)lineNumber;

@end

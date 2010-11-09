@interface KScroller : NSScroller {
  BOOL vertical_;
  BOOL hover_;
  NSColor *backgroundColor_;
}
+ (CGFloat)scrollerWidth;
+ (CGFloat)scrollerWidthForControlSize:(NSControlSize)controlSize;
@end

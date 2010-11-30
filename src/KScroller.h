@interface KScroller : NSScroller {
  BOOL vertical_;
  BOOL hover_;
  __weak NSTextView *parentTextView_; // owns us
}
+ (CGFloat)scrollerWidth;
+ (CGFloat)scrollerWidthForControlSize:(NSControlSize)controlSize;
@end

@class KDocument;
@interface KScroller : NSScroller {
  BOOL vertical_;
  BOOL hover_;
  KDocument *tab_; // weak
  NSTrackingArea *trackingArea_;
}
@property(assign) KDocument *tab;
@property(readonly, nonatomic) BOOL isCollapsed;
+ (CGFloat)scrollerWidth;
+ (CGFloat)scrollerWidthForControlSize:(NSControlSize)controlSize;
@end

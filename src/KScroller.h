@class KTabContents;
@interface KScroller : NSScroller {
  BOOL vertical_;
  BOOL hover_;
  KTabContents *tab_; // weak
  NSTrackingArea *trackingArea_;
}
@property(assign) KTabContents *tab;
@property(readonly, nonatomic) BOOL isCollapsed;
+ (CGFloat)scrollerWidth;
+ (CGFloat)scrollerWidthForControlSize:(NSControlSize)controlSize;
@end

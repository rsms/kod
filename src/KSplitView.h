#import "BWSplitView.h"

extern NSString * const KSplitViewDidChangeCollapseStateNotification;

@interface KSplitView : BWSplitView {
  NSRect dividerRect_;
  CGFloat position_;
  BOOL collapsed_;
}

@property(readonly, nonatomic) NSRect dividerRect;
@property(nonatomic) CGFloat position;
@property(nonatomic) BOOL isCollapsed;
@property(readonly, nonatomic) CGFloat collapsePositionThreshold;

@end

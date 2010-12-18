#import "BWSplitView.h"

@interface KSplitView : BWSplitView {
  NSRect dividerRect_;
  CGFloat position_;
}

@property(readonly, nonatomic) NSRect dividerRect;
@property(nonatomic) CGFloat position;

@end

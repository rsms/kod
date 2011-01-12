// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

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

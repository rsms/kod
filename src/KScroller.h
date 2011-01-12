// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

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

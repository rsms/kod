// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

@class KSplitView;

@interface KStatusBarView : NSView {
  KSplitView *splitView_;
  NSRect splitViewMarkerFrame_;
  CGFloat splitViewPositionForLayout_;
  NSTrackingArea *splitViewMarkerTrackingArea_;
  IBOutlet NSView *rightViewGroup_;
  IBOutlet NSTextField *cursorPositionTextField_;
  IBOutlet NSButton *toggleSplitViewButton_;
}

@property(retain) KSplitView *splitView;
@property(readonly, nonatomic) NSTextField *cursorPositionTextField;

- (void)splitViewDidResize;

@end

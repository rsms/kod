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

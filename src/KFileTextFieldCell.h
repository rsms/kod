
@interface KFileTextFieldCell : NSTextFieldCell {
@private
  NSImage *image_;
}

@property(retain) NSImage *image;

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
- (NSSize)cellSize;

@end

// KTextFieldCell customizes the look of the standard Cocoa text field.
// The border and focus ring are modified, as is the font baseline.  Subclasses
// can override |drawInteriorWithFrame:inView:| to provide custom drawing for
// decorations, but they must make sure to call the superclass' implementation
// with a modified frame after performing any custom drawing.

@interface KTextFieldCell : NSTextFieldCell {
  NSFont *font_;
  BOOL hasCalledInitCommon_;
}

@end

// Methods intended to be overridden by subclasses, not part of the public API
// and should not be called outside of subclasses.
@interface KTextFieldCell (ProtectedMethods)

// Convenience initializer for subclasses which require simple initialization.
// Called after any of the three "designated initializers" has been called on
// super. If you override any of the "designated initializers" (initWithCoder:,
// initTextCell:, and initImageCell:.) you must make sure to call this method.
- (void)initCommon;

// Return the portion of the cell to show the text cursor over.  The default
// implementation returns the full |cellFrame|.  Subclasses should override this
// method if they add any decorations.
- (NSRect)textCursorFrameForFrame:(NSRect)cellFrame;

// Return the portion of the cell to use for text display.  This corresponds to
// the frame with our added decorations sliced off.  The default implementation
// returns the full |cellFrame|, as by default there are no decorations.
// Subclasses should override this method if they add any decorations.
- (NSRect)textFrameForFrame:(NSRect)cellFrame;

// Baseline adjust for the text in this cell.  Defaults to 0.  Subclasses should
// override as needed.
- (CGFloat)baselineAdjust;

// Radius of the corners of the field.  Defaults to square corners (0.0).
- (CGFloat)cornerRadius;

// Returns YES if a light themed bezel should be drawn under the text field.
// Default implementation returns NO.
- (BOOL)shouldDrawBezel;

@end

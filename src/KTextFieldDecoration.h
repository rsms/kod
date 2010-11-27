
// Base class for decorations at the left and right of the location
// bar.  For instance, the location icon.

// |LocationBarDecoration| and subclasses should approximately
// parallel the classes provided under views/location_bar/.  The term
// "decoration" is used because "view" has strong connotations in
// Cocoa, and while these are view-like, they aren't views at all.
// Decorations are more like Cocoa cells, except implemented in C++ to
// allow more similarity to the other platform implementations.

// Width returned by |GetWidthForSpace()| when the item should be
// omitted for this width;
extern const CGFloat KTextFieldDecorationOmittedWidth;

@interface KTextFieldDecoration : NSObject {
  BOOL visible_;
}

@property(assign) BOOL visible;

// Decorations can change their size to fit the available space.
// Returns the width the decoration will use in the space allotted,
// or |kOmittedWidth| if it should be omitted.
- (CGFloat)widthForSpace:(CGFloat)width;

// Draw the decoration in the frame provided.  The frame will be
// generated from an earlier call to |GetWidthForSpace()|.
- (void)drawInteriorWithFrame:(NSRect)frame inView:(NSView*)controlView;

// Returns the tooltip for this decoration, return |nil| for no tooltip.
- (NSString*)toolTip; // default nil

// Decorations which do not accept mouse events are treated like the
// field's background for purposes of selecting text.  When such
// decorations are adjacent to the text area, they will show the
// I-beam cursor.  Decorations which do accept mouse events will get
// an arrow cursor when the mouse is over them.
- (BOOL)acceptsMousePress; // default NO

// Determine if the item can act as a drag source.
- (BOOL)isDraggable; // default NO

// The image to drag.
- (NSImage*)dragImage; // default nil

// Return the place within the decoration's frame where the
// |GetDragImage()| comes from.  This is used to make sure the image
// appears correctly under the mouse while dragging.  |frame|
// matches the frame passed to |DrawInFrame()|.
- (NSRect)dragImageFrameForDecorationRect:(NSRect)frame; // default NSZeroRect

// The pasteboard to drag.
- (NSPasteboard*)dragPasteboard; // default nil

// Called on mouse down.  Return |false| to indicate that the press
// was not processed and should be handled by the cell.
- (BOOL)mouseDownInRect:(NSRect)frame; // default NO

// Called to get the right-click menu, return |nil| for no menu.
- (NSMenu*)menu; // default nil

@end

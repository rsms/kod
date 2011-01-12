// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.


@class KTextFieldCell;

// An implementation of NSTextField that is designed to work with
// StyledTextFieldCell.  Provides methods to redraw the field when cell
// decorations have changed and overrides |mouseDown:| to properly handle clicks
// in sections of the cell with decorations.
@interface KTextField : NSTextField {
}

// Repositions and redraws the field editor.  Call this method when the cell's
// text frame has changed (whenever changing cell decorations).
- (void)resetFieldEditorFrameIfNeeded;

// Returns the amount of the field's width which is not being taken up
// by the text contents.  May be negative if the contents are large
// enough to scroll.
- (CGFloat)availableDecorationWidth;

- (KTextFieldCell*)kTextFieldCell;

@end

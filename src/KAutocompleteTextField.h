#import "KTextField.h"
#import "common.h"
#import <ChromiumTabs/url_drop_target.h>

@protocol KAutocompleteTextFieldDelegate;
@class KAutocompleteTextFieldCell;

@interface KAutocompleteTextField : KTextField<NSTextViewDelegate,
                                               URLDropTarget> {
 @private
  // Undo manager for this text field.  We use a specific instance rather than
  // the standard undo manager in order to let us clear the undo stack at will.
  scoped_nsobject<NSUndoManager> undoManager_;

  id<KAutocompleteTextFieldDelegate> delegate_;

  // Handles being a drag-and-drop target.
  scoped_nsobject<URLDropTargetHandler> dropHandler_;

  // Holds current tooltip strings, to keep them from being dealloced.
  scoped_nsobject<NSMutableArray> currentToolTips_;
}

@property (nonatomic, retain) id<KAutocompleteTextFieldDelegate> delegate;

// Convenience method to return the cell, casted appropriately.
- (KAutocompleteTextFieldCell*)cell;

// Superclass aborts editing before changing the string, which causes
// problems for undo.  This version modifies the field editor's
// contents if the control is already being edited.
- (void)setAttributedStringValue:(NSAttributedString*)aString;

// Clears the undo chain for this text field.
- (void)clearUndoChain;

// Updates cursor and tooltip rects depending on the contents of the text field
// e.g. the security icon should have a default pointer shown on hover instead
// of an I-beam.
- (void)updateCursorAndToolTipRects;

// Return the appropriate menu for any decoration under |event|.
- (NSMenu*)decorationMenuForEvent:(NSEvent*)event;

// Retains |tooltip| (in |currentToolTips_|) and adds this tooltip
// via -[NSView addToolTipRect:owner:userData:].
- (void)addToolTip:(NSString*)tooltip forRect:(NSRect)aRect;

@end

#import "KAutocompleteTextFieldDelegate.h"

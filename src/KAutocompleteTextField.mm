// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "KAutocompleteTextField.h"

#import "KAutocompleteTextFieldCell.h"
#import "KBrowserWindowController.h"
#import "KToolbarController.h"
#import "KAutocompleteTextFieldEditor.h"
#import "common.h"

#import <ChromiumTabs/url_drop_target.h>


@implementation KAutocompleteTextField

@synthesize delegate = delegate_;

+ (Class)cellClass {
  return [KAutocompleteTextFieldCell class];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

- (void)awakeFromNib {
  DCHECK([[self cell] isKindOfClass:[KAutocompleteTextFieldCell class]]);
  [[self cell] setTruncatesLastVisibleLine:YES];
  [[self cell] setLineBreakMode:NSLineBreakByTruncatingTail];
  currentToolTips_.reset([[NSMutableArray alloc] init]);
}

// Informs the receiver that the user has pressed or released a modifier key
// (Shift, Control, and so on).
- (void)flagsChanged:(NSEvent*)theEvent {
  if (delegate_) {
    [delegate_ flagsChanged:theEvent inAutocompleteTextField:self];
  }
}

- (KAutocompleteTextFieldCell*)cell {
  NSCell* cell = [super cell];
  if (!cell)
    return nil;

  DCHECK([cell isKindOfClass:[KAutocompleteTextFieldCell class]]);
  return static_cast<KAutocompleteTextFieldCell*>(cell);
}

// Reroute events for the decoration area to the field editor.  This
// will cause the cursor to be moved as close to the edge where the
// event was seen as possible.
//
// The reason for this code's existence is subtle.  NSTextField
// implements text selection and editing in terms of a "field editor".
// This is an NSTextView which is installed as a subview of the
// control when the field becomes first responder.  When the field
// editor is installed, it will get -mouseDown: events and handle
// them, rather than the text field - EXCEPT for the event which
// caused the change in first responder, or events which fall in the
// decorations outside the field editor's area.  In that case, the
// default NSTextField code will setup the field editor all over
// again, which has the side effect of doing "select all" on the text.
// This effect can be observed with a normal NSTextField if you click
// in the narrow border area, and is only really a problem because in
// our case the focus ring surrounds decorations which look clickable.
//
// When the user first clicks on the field, after installing the field
// editor the default NSTextField code detects if the hit is in the
// field editor area, and if so sets the selection to {0,0} to clear
// the selection before forwarding the event to the field editor for
// processing (it will set the cursor position).  This also starts the
// click-drag selection machinery.
//
// This code does the same thing for cases where the click was in the
// decoration area.  This allows the user to click-drag starting from
// a decoration area and get the expected selection behaviour,
// likewise for multiple clicks in those areas.
- (void)mouseDown:(NSEvent*)theEvent {
  // Close the popup before processing the event.  This prevents the
  // popup from being visible while a right-click context menu or
  // page-action menu is visible.  Also, it matches other platforms.
  if (delegate_)
    [delegate_ closePopupInAutocompleteTextField:self];

  // If the click was a Control-click, bring up the context menu.
  // |NSTextField| handles these cases inconsistently if the field is
  // not already first responder.
  if (([theEvent modifierFlags] & NSControlKeyMask) != 0) {
    NSText* editor = [self currentEditor];
    NSMenu* menu = [editor menuForEvent:theEvent];
    [NSMenu popUpContextMenu:menu withEvent:theEvent forView:editor];
    return;
  }

  const NSPoint location =
      [self convertPoint:[theEvent locationInWindow] fromView:nil];
  const NSRect bounds([self bounds]);

  KAutocompleteTextFieldCell* cell = [self cell];
  const NSRect textFrame([cell textFrameForFrame:bounds]);

  // A version of the textFrame which extends across the field's
  // entire width.

  const NSRect fullFrame(NSMakeRect(bounds.origin.x, textFrame.origin.y,
                                    bounds.size.width, textFrame.size.height));

  // If the mouse is in the editing area, or above or below where the
  // editing area would be if we didn't add decorations, forward to
  // NSTextField -mouseDown: because it does the right thing.  The
  // above/below test is needed because NSTextView treats mouse events
  // above/below as select-to-end-in-that-direction, which makes
  // things janky.
  BOOL flipped = [self isFlipped];
  if (NSMouseInRect(location, textFrame, flipped) ||
      !NSMouseInRect(location, fullFrame, flipped)) {
    [super mouseDown:theEvent];

    // After the event has been handled, if the current event is a
    // mouse up and no selection was created (the mouse didn't move),
    // select the entire field.
    // NOTE(shess): This does not interfere with single-clicking to
    // place caret after a selection is made.  An NSTextField only has
    // a selection when it has a field editor.  The field editor is an
    // NSText subview, which will receive the -mouseDown: in that
    // case, and this code will never fire.
    NSText* editor = [self currentEditor];
    if (editor) {
      NSEvent* currentEvent = [NSApp currentEvent];
      if ([currentEvent type] == NSLeftMouseUp &&
          ![editor selectedRange].length) {
        [editor selectAll:nil];
      }
    }

    return;
  }

  // Give the cell a chance to intercept clicks in page-actions and
  // other decorative items.
  if ([cell mouseDown:theEvent inRect:bounds ofView:self]) {
    return;
  }

  NSText* editor = [self currentEditor];

  // We should only be here if we accepted first-responder status and
  // have a field editor.  If one of these fires, it means some
  // assumptions are being broken.
  DCHECK(editor != nil);
  DCHECK([editor isDescendantOf:self]);

  // -becomeFirstResponder does a select-all, which we don't want
  // because it can lead to a dragged-text situation.  Clear the
  // selection (any valid empty selection will do).
  [editor setSelectedRange:NSMakeRange(0, 0)];

  // If the event is to the right of the editing area, scroll the
  // field editor to the end of the content so that the selection
  // doesn't initiate from somewhere in the middle of the text.
  if (location.x > NSMaxX(textFrame)) {
    [editor scrollRangeToVisible:NSMakeRange([[self stringValue] length], 0)];
  }

  [editor mouseDown:theEvent];
}

// Overridden to pass OnFrameChanged() notifications to |observer_|.
// Additionally, cursor and tooltip rects need to be updated.
- (void)setFrame:(NSRect)frameRect {
  [super setFrame:frameRect];
  if (delegate_) {
    [delegate_ frameDidChangeForAutocompleteTextField:self];
  }
  [self updateCursorAndToolTipRects];
}

// Due to theming, parts of the field are transparent.
- (BOOL)isOpaque {
  return NO;
}

- (void)setAttributedStringValue:(NSAttributedString*)aString {
  KAutocompleteTextFieldEditor* editor =
      static_cast<KAutocompleteTextFieldEditor*>([self currentEditor]);

  if (!editor) {
    [super setAttributedStringValue:aString];
  } else {
    // The type of the field editor must be KAutocompleteTextFieldEditor,
    // otherwise things won't work.
    DCHECK([editor isKindOfClass:[KAutocompleteTextFieldEditor class]]);

    [editor setAttributedString:aString];
  }
}

- (NSUndoManager*)undoManagerForTextView:(NSTextView*)textView {
  if (!undoManager_.get())
    undoManager_.reset([[NSUndoManager alloc] init]);
  return undoManager_.get();
}

- (void)clearUndoChain {
  [undoManager_ removeAllActions];
}

- (void)addToolTip:(NSString*)tooltip forRect:(NSRect)aRect {
  [currentToolTips_ addObject:tooltip];
  [self addToolTipRect:aRect owner:tooltip userData:nil];
}

// TODO(shess): -resetFieldEditorFrameIfNeeded is the place where
// changes to the cell layout should be flushed.  LocationBarViewMac
// and ToolbarController are calling this routine directly, and I
// think they are probably wrong.
// http://crbug.com/40053
- (void)updateCursorAndToolTipRects {
  // This will force |resetCursorRects| to be called, as it is not to be called
  // directly.
  [[self window] invalidateCursorRectsForView:self];

  // |removeAllToolTips| only removes those set on the current NSView, not any
  // subviews. Unless more tooltips are added to this view, this should suffice
  // in place of managing a set of NSToolTipTag objects.
  [self removeAllToolTips];

  // Reload the decoration tooltips.
  [currentToolTips_ removeAllObjects];
  [[self cell] updateToolTipsInRect:[self bounds] ofView:self];
}

// NOTE(shess): http://crbug.com/19116 describes a weird bug which
// happens when the user runs a Print panel on Leopard.  After that,
// spurious -controlTextDidBeginEditing notifications are sent when an
// NSTextField is firstResponder, even though -currentEditor on that
// field returns nil.  That notification caused significant problems
// in AutocompleteEditViewMac.  -textDidBeginEditing: was NOT being
// sent in those cases, so this approach doesn't have the problem.
- (void)textDidBeginEditing:(NSNotification*)aNotification {
  [super textDidBeginEditing:aNotification];
  if (delegate_) {
    [delegate_ didBeginEditingInAutocompleteTextField:self];
  }
}

- (void)textDidEndEditing:(NSNotification *)aNotification {
  [super textDidEndEditing:aNotification];
  if (delegate_) {
    [delegate_ didEndEditingInAutocompleteTextField:self];
  }
}

- (BOOL)textView:(NSTextView*)textView doCommandBySelector:(SEL)cmd {
  // TODO(shess): Review code for cases where we're fruitlessly attempting to
  // work in spite of not having an observer_.
  if (delegate_ &&
      [delegate_ doCommandBySelector:cmd inAutocompleteTextField:self]) {
    return YES;
  }

  // If the escape key was pressed and no revert happened and we're in
  // fullscreen mode, make it resign key.
  if (cmd == @selector(cancelOperation:)) {
    KBrowserWindowController* windowController =
        [KBrowserWindowController browserWindowControllerForView:self];
    if ([windowController isFullscreen]) {
      [windowController focusTabContents];
      return YES;
    }
  }

  return NO;
}

// When the window resigns, make sure the autocomplete popup is no
// longer visible, since the user's focus is elsewhere.
- (void)windowDidResignKey:(NSNotification*)notification {
  DCHECK_EQ([self window], [notification object]);
  if (delegate_)
    [delegate_ closePopupInAutocompleteTextField:self];
}

- (void)viewWillMoveToWindow:(NSWindow*)newWindow {
  if ([self window]) {
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self
                  name:NSWindowDidResignKeyNotification
                object:[self window]];
  }
}

- (void)viewDidMoveToWindow {
  if ([self window]) {
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(windowDidResignKey:)
               name:NSWindowDidResignKeyNotification
             object:[self window]];
    // Register for drops. Lazily create the drop handler when the type of
    // window is known.
    dropHandler_.reset([[URLDropTargetHandler alloc] initWithView:self]);
  }
}

// NSTextField becomes first responder by installing a "field editor"
// subview.  Clicks outside the field editor (such as a decoration)
// will attempt to make the field the first-responder again, which
// causes a select-all, even if the decoration handles the click.  If
// the field editor is already in place, don't accept first responder
// again.  This allows the selection to be unmodified if the click is
// handled by a decoration or context menu (|-mouseDown:| will still
// change it if appropriate).
- (BOOL)acceptsFirstResponder {
  if ([self currentEditor]) {
    DCHECK_EQ([self currentEditor], [[self window] firstResponder]);
    return NO;
  }
  return [super acceptsFirstResponder];
}

// (Overridden from NSResponder)
- (BOOL)becomeFirstResponder {
  BOOL doAccept = [super becomeFirstResponder];
  if (doAccept) {
    // TODO: [[KBrowserWindowController browserWindowControllerForView:self]
    //    lockBarVisibilityForOwner:self withAnimation:YES delay:NO];
    // depends on fullscreen impl in KBrowserWindowController

    // Tells the observer that we get the focus.
    // But we can't call observer_->OnKillFocus() in resignFirstResponder:,
    // because the first responder will be immediately set to the field editor
    // when calling [super becomeFirstResponder], thus we won't receive
    // resignFirstResponder: anymore when losing focus.
    if (delegate_) {
      [delegate_ autocompleteTextField:self
              willBecomeFirstResponder:[NSApp currentEvent]];
    }
  }
  return doAccept;
}

// (Overridden from NSResponder)
- (BOOL)resignFirstResponder {
  BOOL doResign = [super resignFirstResponder];
  if (doResign) {
    //[[KBrowserWindowController browserWindowControllerForView:self]
    //    releaseBarVisibilityForOwner:self withAnimation:YES delay:YES];
    // TODO: depends on fullscreen impl in KBrowserWindowController
  }
  return doResign;
}

// (URLDropTarget protocol)
- (id<URLDropTargetController>)urlDropController {
  KBrowserWindowController* windowController =
      [KBrowserWindowController browserWindowControllerForView:self];
  return [windowController toolbarController];
}

// (URLDropTarget protocol)
- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
  // Make ourself the first responder, which will select the text to indicate
  // that our contents would be replaced by a drop.
  // TODO(viettrungluu): crbug.com/30809 -- this is a hack since it steals focus
  // and doesn't return it.
  [[self window] makeFirstResponder:self];
  return [dropHandler_ draggingEntered:sender];
}

// (URLDropTarget protocol)
- (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender {
  return [dropHandler_ draggingUpdated:sender];
}

// (URLDropTarget protocol)
- (void)draggingExited:(id<NSDraggingInfo>)sender {
  return [dropHandler_ draggingExited:sender];
}

// (URLDropTarget protocol)
- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
  return [dropHandler_ performDragOperation:sender];
}

- (NSMenu*)decorationMenuForEvent:(NSEvent*)event {
  KAutocompleteTextFieldCell* cell = [self cell];
  return [cell decorationMenuForEvent:event inRect:[self bounds] ofView:self];
}

@end

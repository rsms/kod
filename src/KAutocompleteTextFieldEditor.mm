// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "KAutocompleteTextFieldEditor.h"
#import "KToolbarController.h"
#import "KAutocompleteTextField.h"
#import "KAutocompleteTextFieldCell.h"
#import "KBrowserWindowController.h"

@implementation KAutocompleteTextFieldEditor

- (id)initWithFrame:(NSRect)frameRect {
  if ((self = [super initWithFrame:frameRect])) {
    dropHandler_ = [[URLDropTargetHandler alloc] initWithView:self];
    forbiddenCharacters_ = [[NSCharacterSet controlCharacterSet] retain];
  }
  return self;
}

- (void)dealloc {
  [dropHandler_ release];
  [forbiddenCharacters_ release];
  [super dealloc];
}


// If the entire field is selected, drag the same data as would be
// dragged from the field's location icon.  In some cases the textual
// contents will not contain relevant data (for instance, "http://" is
// stripped from URLs).
- (BOOL)dragSelectionWithEvent:(NSEvent *)event
                        offset:(NSSize)mouseOffset
                     slideBack:(BOOL)slideBack {
  KAutocompleteTextField *atf = [self delegate];
  id<KAutocompleteTextFieldDelegate> atfDelegate = atf.delegate;
  DCHECK(atfDelegate);
  if (atfDelegate && [atfDelegate canCopyFromAutocompleteTextField:atf]) {
    NSPasteboard* pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
    [atfDelegate copyAutocompleteTextField:atf
                              toPasteboard:pboard];

    NSPoint p;
    NSImage* image = [self dragImageForSelectionWithEvent:event origin:&p];

    [self dragImage:image
                 at:p
             offset:mouseOffset
              event:event
         pasteboard:pboard
             source:self
          slideBack:slideBack];
    return YES;
  }
  return [super dragSelectionWithEvent:event
                                offset:mouseOffset
                             slideBack:slideBack];
}

- (void)copy:(id)sender {
  KAutocompleteTextField *atf = [self delegate];
  id<KAutocompleteTextFieldDelegate> atfDelegate = atf.delegate;
  DCHECK(atfDelegate);
  if (atfDelegate && [atfDelegate canCopyFromAutocompleteTextField:atf]) {
    NSPasteboard* pboard = [NSPasteboard generalPasteboard];
    [atfDelegate copyAutocompleteTextField:atf toPasteboard:pboard];
  }
}

- (void)cut:(id)sender {
  [self copy:sender];
  [self delete:nil];
}

// This class assumes that the delegate is an KAutocompleteTextField.
// Enforce that assumption.
- (KAutocompleteTextField*)delegate {
  KAutocompleteTextField* delegate =
      static_cast<KAutocompleteTextField*>([super delegate]);
  DCHECK(delegate == nil ||
         [delegate isKindOfClass:[KAutocompleteTextField class]]);
  return delegate;
}

- (void)setDelegate:(KAutocompleteTextField*)delegate {
  DCHECK(delegate == nil ||
         [delegate isKindOfClass:[KAutocompleteTextField class]]);
  [super setDelegate:delegate];
}

- (void)paste:(id)sender {
  KAutocompleteTextField *atf = [self delegate];
  id<KAutocompleteTextFieldDelegate> atfDelegate = atf.delegate;
  if (atfDelegate) {
    [atfDelegate pasteInAutocompleteTextField:atf];
  }
}

- (void)pasteAndGo:(id)sender {
  KAutocompleteTextField *atf = [self delegate];
  id<KAutocompleteTextFieldDelegate> atfDelegate = atf.delegate;
  if (atfDelegate) {
    [atfDelegate pasteAndGoInAutocompleteTextField:atf];
  }
}

// We have rich text, but it shouldn't be modified by the user, so
// don't update the font panel.  In theory, -setUsesFontPanel: should
// accomplish this, but that gets called frequently with YES when
// NSTextField and NSTextView synchronize their contents.  That is
// probably unavoidable because in most cases having rich text in the
// field you probably would expect it to update the font panel.
- (void)updateFontPanel {}

// No ruler bar, so don't update any of that state, either.
- (void)updateRuler {}

- (NSMenu*)menuForEvent:(NSEvent*)event {
  // Give the control a chance to provide page-action menus.
  // NOTE: Note that page actions aren't even in the editor's
  // boundaries!  The Cocoa control implementation seems to do a
  // blanket forward to here if nothing more specific is returned from
  // the control and cell calls.
  // TODO(shess): Determine if the page-action part of this can be
  // moved to the cell.
  NSMenu* actionMenu = [[self delegate] decorationMenuForEvent:event];
  if (actionMenu)
    return actionMenu;

  NSMenu* menu = [[[NSMenu alloc] initWithTitle:@"TITLE"] autorelease];
  // Note: NSLocalizedString derives it's values from [NSBundle mainBundle]
  [menu addItemWithTitle:NSLocalizedString(@"Cut", nil)
                  action:@selector(cut:)
           keyEquivalent:@""];
  [menu addItemWithTitle:NSLocalizedString(@"Copy", nil)
                  action:@selector(copy:)
           keyEquivalent:@""];
  [menu addItemWithTitle:NSLocalizedString(@"Paste", nil)
                  action:@selector(paste:)
           keyEquivalent:@""];

  // TODO(shess): If the control is not editable, should we show a
  // greyed-out "Paste and Go"?
  if ([self isEditable]) {
    // Paste and go/search.
    KAutocompleteTextField *atf = [self delegate];
    id<KAutocompleteTextFieldDelegate> atfDelegate = atf.delegate;
    DCHECK(atfDelegate);
    if (atfDelegate && [atfDelegate canPasteAndGoInAutocompleteTextField:atf]) {
      NSString* label =
          [atfDelegate pasteActionLabelForAutocompleteTextField:atf];
      // TODO(rohitrao): If the clipboard is empty, should we show a
      // greyed-out "Paste and Go" or nothing at all?
      if ([label length]) {
        [menu addItemWithTitle:label
                        action:@selector(pasteAndGo:)
                 keyEquivalent:@""];
      }
    }
  }

  return menu;
}

// (Overridden from NSResponder)
- (BOOL)becomeFirstResponder {
  BOOL doAccept = [super becomeFirstResponder];
  KAutocompleteTextField* field = [self delegate];
  // Only lock visibility if we've been set up with a delegate (the text field).
  if (doAccept && field) {
    // Give the text field ownership of the visibility lock. (The first
    // responder dance between the field and the field editor is a little
    // weird.)
    // TODO: depends on fullscreen impl in KBrowserWindowController
    //[[KBrowserWindowController browserWindowControllerForView:field]
    //    lockBarVisibilityForOwner:field withAnimation:YES delay:NO];
  }
  return doAccept;
}

// (Overridden from NSResponder)
- (BOOL)resignFirstResponder {
  BOOL doResign = [super resignFirstResponder];
  KAutocompleteTextField *atf = [self delegate];
  // Only lock visibility if we've been set up with a delegate (the text field).
  if (doResign && atf) {
    // Give the text field ownership of the visibility lock.
    // TODO: depends on fullscreen impl in KBrowserWindowController
    //[[BrowserWindowController browserWindowControllerForView:atf]
    //    releaseBarVisibilityForOwner:atf withAnimation:YES delay:YES];

    id<KAutocompleteTextFieldDelegate> atfDelegate = atf.delegate;
    DCHECK(atfDelegate);
    if (atfDelegate) {
      [atfDelegate autocompleteTextField:atf
                willResignFirstResponder:[NSApp currentEvent]];
    }
  }
  return doResign;
}

// (URLDropTarget protocol)
- (id<URLDropTargetController>)urlDropController {
  CTBrowserWindowController* windowController =
      [CTBrowserWindowController browserWindowControllerForView:self];
  return windowController.toolbarController;
}

// (URLDropTarget protocol)
- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
  // Make ourself the first responder (even though we're presumably already the
  // first responder), which will select the text to indicate that our contents
  // would be replaced by a drop.
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

// Prevent control characters from being entered into the Omnibox.
// This is invoked for keyboard entry, not for pasting.
- (void)insertText:(id)aString {
  // This method is documented as received either |NSString| or
  // |NSAttributedString|.  The autocomplete code will restyle the
  // results in any case, so simplify by always using |NSString|.
  if ([aString isKindOfClass:[NSAttributedString class]])
    aString = [aString string];

  // Repeatedly remove control characters.  The loop will only ever
  // execute at allwhen the user enters control characters (using
  // Ctrl-Alt- or Ctrl-Q).  Making this generally efficient would
  // probably be a loss, since the input always seems to be a single
  // character.
  NSRange range = [aString rangeOfCharacterFromSet:forbiddenCharacters_];
  while (range.location != NSNotFound) {
    aString = [aString stringByReplacingCharactersInRange:range withString:@""];
    range = [aString rangeOfCharacterFromSet:forbiddenCharacters_];
  }
  DCHECK_EQ(range.length, 0U);

  // NOTE: If |aString| is empty, this intentionally replaces the
  // selection with empty.  This seems consistent with the case where
  // the input contained a mixture of characters and the string ended
  // up not empty.
  [super insertText:aString];
}

- (void)setMarkedText:(id)aString selectedRange:(NSRange)selRange {
  [super setMarkedText:aString selectedRange:selRange];

  // Because the AutocompleteEditViewMac class treats marked text as content,
  // we need to treat the change to marked text as content change as well.
  [self didChangeText];
}

- (void)interpretKeyEvents:(NSArray *)eventArray {
  DCHECK(!interpretingKeyEvents_);
  interpretingKeyEvents_ = YES;
  textChangedByKeyEvents_ = NO;
  [super interpretKeyEvents:eventArray];

  KAutocompleteTextField *atf = [self delegate];
  id<KAutocompleteTextFieldDelegate> atfDelegate = atf.delegate;
  if (textChangedByKeyEvents_ && atfDelegate)
    [atfDelegate didModifyAutocompleteTextField:atf];

  DCHECK(interpretingKeyEvents_);
  interpretingKeyEvents_ = NO;
}

- (void)didChangeText {
  [super didChangeText];

  KAutocompleteTextField *atf = [self delegate];
  id<KAutocompleteTextFieldDelegate> atfDelegate = atf.delegate;
  if (atfDelegate) {
    if (!interpretingKeyEvents_) {
      [atfDelegate didModifyAutocompleteTextField:atf];
    } else {
      textChangedByKeyEvents_ = YES;
    }
  }
}

- (void)setAttributedString:(NSAttributedString*)aString {
  NSTextStorage* textStorage = [self textStorage];
  DCHECK(textStorage);
  [textStorage setAttributedString:aString];

  // The text has been changed programmatically. The observer should know
  // this change, so setting |textChangedByKeyEvents_| to NO to
  // prevent its OnDidChange() method from being called unnecessarily.
  textChangedByKeyEvents_ = NO;
}

- (void)mouseDown:(NSEvent*)theEvent {
  // Close the popup before processing the event.
  KAutocompleteTextField *atf = [self delegate];
  id<KAutocompleteTextFieldDelegate> atfDelegate = atf.delegate;
  if (atfDelegate)
    [atfDelegate closePopupInAutocompleteTextField:atf];

  [super mouseDown:theEvent];
}

@end

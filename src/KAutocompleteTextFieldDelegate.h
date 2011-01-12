// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@class KAutocompleteTextField;

@protocol KAutocompleteTextFieldDelegate

// Informs the receiver that the user has pressed or released a modifier key
// (Shift, Control, and so on) while the text field is first responder.
- (void)flagsChanged:(NSEvent*)theEvent
inAutocompleteTextField:(KAutocompleteTextField*)atf;

// Called when the user pastes into the field.
- (void)pasteInAutocompleteTextField:(KAutocompleteTextField*)atf;

// Return |true| if there is a selection to copy.
- (BOOL)canCopyFromAutocompleteTextField:(KAutocompleteTextField*)atf;

// Clears the |pboard| and adds the field's current selection.
// Called when the user does a copy or drag.
- (void)copyAutocompleteTextField:(KAutocompleteTextField*)atf
                     toPasteboard:(NSPasteboard*)pboard;

// Returns true if the current clipboard text supports paste and go
// (or paste and search).
- (BOOL)canPasteAndGoInAutocompleteTextField:(KAutocompleteTextField*)atf;

// Returns the appropriate "Paste and Go" or "Paste and Search"
// context menu string, depending on what is currently in the
// clipboard.  Must not be called unless CanPasteAndGo() returns
// true.
- (NSString*)pasteActionLabelForAutocompleteTextField:
    (KAutocompleteTextField*)atf;

// Called when the user initiates a "paste and go" or "paste and
// search" into the field.
- (void)pasteAndGoInAutocompleteTextField:(KAutocompleteTextField*)atf;

// Called when the field's frame changes.
- (void)frameDidChangeForAutocompleteTextField:(KAutocompleteTextField*)atf;

// Called when the popup is no longer appropriate, such as when the
// field's window loses focus or a page action is clicked.
- (void)closePopupInAutocompleteTextField:(KAutocompleteTextField*)atf;

// Called when the user begins editing the field, for every edit,
// and when the user is done editing the field.
- (void)didBeginEditingInAutocompleteTextField:(KAutocompleteTextField*)atf;
- (void)didModifyAutocompleteTextField:(KAutocompleteTextField*)atf;
- (void)didEndEditingInAutocompleteTextField:(KAutocompleteTextField*)atf;

// NSResponder translates certain keyboard actions into selectors
// passed to -doCommandBySelector:.  The selector is forwarded here,
// return true if |cmd| is handled, false if the caller should
// handle it.
// TODO(shess): For now, I think having the code which makes these
// decisions closer to the other autocomplete code is worthwhile,
// since it calls a wide variety of methods which otherwise aren't
// clearly relevent to expose here.  But consider pulling more of
// the AutocompleteEditViewMac calls up to here.
- (BOOL)doCommandBySelector:(SEL)cmd
    inAutocompleteTextField:(KAutocompleteTextField*)atf;

// Called whenever the autocomplete text field gets focused.
// To test if a modifier key is being pressed, inspect |ev|:
//
//    BOOL cmdPressed = ([ev modifierFlags] & NSCommandKeyMask) != 0;
//
- (void)autocompleteTextField:(KAutocompleteTextField*)atf
     willBecomeFirstResponder:(NSEvent*)ev;

// Called whenever the autocomplete text field is losing focus.
- (void)autocompleteTextField:(KAutocompleteTextField*)atf
     willResignFirstResponder:(NSEvent*)ev;

@end

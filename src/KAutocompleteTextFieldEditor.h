// Copyright (c) 2010 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "common.h"
#import <ChromiumTabs/url_drop_target.h>

@class KAutocompleteTextField;

// KAutocompleteTextFieldEditor customized the KAutocompleteTextField
// field editor (helper text-view used in editing).  It intercepts UI
// events for forwarding to the core Omnibox code.  It also undoes
// some of the effects of using styled text in the Omnibox (the text
// is styled but should not appear that way when copied to the
// pasteboard).

// Field editor used for the autocomplete field.
@interface KAutocompleteTextFieldEditor : NSTextView<URLDropTarget> {
  // Handles being a drag-and-drop target. We handle DnD directly instead
  // allowing the |AutocompletTextField| to handle it (by making an empty
  // |-updateDragTypeRegistration|), since the latter results in a weird
  // start-up time regression.
  URLDropTargetHandler *dropHandler_;

  NSCharacterSet *forbiddenCharacters_;

  // Indicates if the field editor's interpretKeyEvents: method is being called.
  // If it's YES, then we should postpone the call to the observer's
  // OnDidChange() method after the field editor's interpretKeyEvents: method
  // is finished, rather than calling it in textDidChange: method. Because the
  // input method may update the marked text after inserting some text, but we
  // need the observer be aware of the marked text as well.
  BOOL interpretingKeyEvents_;

  // Indicates if the text has been changed by key events.
  BOOL textChangedByKeyEvents_;
}

// The delegate is always an KAutocompleteTextField*.  Override the superclass
// implementations to allow for proper typing.
- (KAutocompleteTextField*)delegate;
- (void)setDelegate:(KAutocompleteTextField*)delegate;

// Sets attributed string programatically through the field editor's text
// storage object.
- (void)setAttributedString:(NSAttributedString*)aString;

@end

@interface KAutocompleteTextFieldEditor(PrivateTestMethods)
- (void)pasteAndGo:(id)sender;
@end

// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "KAutocompleteTextField.h"

@class CTTabContents;

@interface KLocationBarController : NSObject<KAutocompleteTextFieldDelegate> {
  // weak, owned by toolbar controller
  __weak KAutocompleteTextField *textField_;

  // state stored while an edit is active
  NSAttributedString *originalAttributedStringValue_;
  CTTabContents *currentContents_;
}

@property(nonatomic, readonly) NSURL *absoluteURL;

- (id)initWithAutocompleteTextField:(KAutocompleteTextField*)atf;

// called by KToolbarController when the contents changed
- (void)contentsDidChange:(CTTabContents*)contents;

- (void)recordStateWithContents:(CTTabContents*)contents;
- (void)restoreState;

- (void)commitEditing:(NSUInteger)modifierFlags;

@end

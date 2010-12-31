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

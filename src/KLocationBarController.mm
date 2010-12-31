#import "KLocationBarController.h"
#import "KBrowserWindowController.h"
#import "KDocumentController.h"
#import <ChromiumTabs/ChromiumTabs.h>
#import "virtual_key_codes.h"
#import "KModeTextFieldDecoration.h"
#import "KAutocompleteTextFieldCell.h"

@implementation KLocationBarController

- (id)initWithAutocompleteTextField:(KAutocompleteTextField*)atf {
  if ((self = [super init])) {
    textField_ = atf; // weak, owned by toolbar controller
    textField_.delegate = self;

    // mode decoration
    //KModeTextFieldDecoration *modeDecoration =
    //    [[KModeTextFieldDecoration alloc] initWithName:@"C++"];
    //KAutocompleteTextFieldCell *cell = (KAutocompleteTextFieldCell*)atf.cell;
    //[cell addRightDecoration:modeDecoration];
  }
  return self;
}


- (void)dealloc {
  [currentContents_ release];
  [originalAttributedStringValue_ release];
  [super dealloc];
}



- (void)recordStateWithContents:(CTTabContents*)contents {
  // Record state so we can restore it later
  h_objc_xch(&currentContents_, contents);
  h_objc_xch(&originalAttributedStringValue_,
             [[textField_ cell] attributedStringValue]);
}


- (void)restoreState {
  if (originalAttributedStringValue_) {
    [[textField_ cell] setAttributedStringValue:originalAttributedStringValue_];
    h_objc_xch(&originalAttributedStringValue_, nil);
  }
}


- (NSURL*)absoluteURLFromString:(NSString*)locationText {
  NSURL *absoluteURL = nil;
  if ([locationText hasPrefix:@"~"]) {
    // "~/foo/../bar/baz" -- absolute file in home directory
    NSString *absPath = [locationText stringByExpandingTildeInPath];
    absPath = [absPath stringByStandardizingPath];
    absoluteURL = [NSURL fileURLWithPath:absPath];
  } else if ([locationText hasPrefix:@"/"]) {
    // "/foo/../bar/baz" -- absolute file
    NSString *absPath = [locationText stringByStandardizingPath];
    absoluteURL = [NSURL fileURLWithPath:absPath];
  } else if ( ([locationText rangeOfString:@":"].location == NSNotFound) &&
              currentContents_) {
    // assume "http://" prefix
    if ([locationText rangeOfCharacterFromSet:
         [NSCharacterSet slashCharacterSet]].location == NSNotFound) {
      // no path -- assume hostname only -- append root path
      locationText = [locationText stringByAppendingString:@"/"];
    }
    absoluteURL = [NSURL URLWithString:
        [@"http://" stringByAppendingString:locationText]];
    absoluteURL = [absoluteURL absoluteURL];
  } else {
    // Hopefully a qualified URL
    absoluteURL = [[NSURL URLWithString:locationText] absoluteURL];
  }
  return absoluteURL;
}


- (NSURL*)absoluteURL {
  return [self absoluteURLFromString:[textField_ stringValue]];
}


- (void)commitEditing:(NSUInteger)modifierFlags {
  BOOL cmdPressed = (modifierFlags & NSCommandKeyMask) != 0;
  BOOL ctrlPressed = (modifierFlags & NSControlKeyMask) != 0;
  BOOL altPressed = (modifierFlags & NSAlternateKeyMask) != 0;
  DLOG("commitEditing (cmd: %d, ctrl: %d, alt: %d)", cmdPressed, ctrlPressed,
       altPressed);

  // get current string
  NSString *locationText = [textField_ stringValue];
  locationText = [locationText
      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
  if (locationText.length == 0) {
    // empty -- noop
    return;
  }


  // build a URL
  NSURL *absoluteURL = [self absoluteURL];
  if (!absoluteURL) {
    // TODO: Coman, please ... better UX. Like making the text red or something
    [NSApp presentError:[NSError kodErrorWithFormat:@"Failed to parse URL"]];
  } else if ([absoluteURL isEqual:currentContents_.fileURL]) {
    // Same URL -- noop

  } else {
    // find our window controller
    KBrowserWindowController *windowController = (KBrowserWindowController *)
        [CTBrowserWindowController browserWindowControllerForView:textField_];
    assert(windowController != nil);

    // find shared document controller
    KDocumentController *documentController =
        (KDocumentController*)[NSDocumentController sharedDocumentController];
    assert(documentController != nil);

    // use the high-level "open" API
    NSArray *urls = [NSArray arrayWithObject:absoluteURL];
    [documentController openDocumentsWithContentsOfURLs:urls
                                   withWindowController:windowController
                                           priority:DISPATCH_QUEUE_PRIORITY_HIGH
                         nonExistingFilesAsNewDocuments:YES
                                               callback:nil];
  }
}


- (void)contentsDidChange:(CTTabContents*)contents {
  [self recordStateWithContents:contents];
}

#pragma mark -
#pragma mark KAutocompleteTextFieldDelegate protocol

// Informs the receiver that the user has pressed or released a modifier key
// (Shift, Control, and so on) while the text field is first responder.
- (void)flagsChanged:(NSEvent*)theEvent
inAutocompleteTextField:(KAutocompleteTextField*)atf {
}

// Called when the user pastes into the field.
- (void)pasteInAutocompleteTextField:(KAutocompleteTextField*)atf {
  // This code currently expects |field_| to be focussed.
  kassert([textField_ currentEditor]);

  NSPasteboard *pboard = [NSPasteboard generalPasteboard];
  NSArray *classes = [NSArray arrayWithObject:[NSString class]];
  NSArray *items = [pboard readObjectsForClasses:classes options:nil];
  DLOG("pasted items: %@", items);
  if (items.count == 0)
    return;

  NSString *s = [items objectAtIndex:0];

  // -shouldChangeTextInRange:* and -didChangeText are documented in
  // NSTextView as things you need to do if you write additional
  // user-initiated editing functions.  They cause the appropriate
  // delegate methods to be called.
  // TODO(shess): It would be nice to separate the Cocoa-specific code
  // from the Chrome-specific code.
  NSTextView* editor = static_cast<NSTextView*>([textField_ currentEditor]);
  const NSRange selectedRange = [editor selectedRange];
  if ([editor shouldChangeTextInRange:selectedRange replacementString:s]) {
    // If this paste will be replacing all the text, record that, so
    // we can do different behaviors in such a case.
    //if (IsSelectAll())
    //  model_->on_paste_replacing_all();

    // Force a Paste operation to trigger the text_changed code in
    // OnAfterPossibleChange(), even if identical contents are pasted
    // into the text box.
    //text_before_change_.clear();

    [editor replaceCharactersInRange:selectedRange withString:s];
    [editor didChangeText];
  }
}

// Return |true| if there is a selection to copy.
- (BOOL)canCopyFromAutocompleteTextField:(KAutocompleteTextField*)atf {
  kassert([textField_ currentEditor]);
  NSRange selectedRange = [[textField_ currentEditor] selectedRange];
  return selectedRange.length > 0;
}

// Clears the |pboard| and adds the field's current selection.
// Called when the user does a copy or drag.
- (void)copyAutocompleteTextField:(KAutocompleteTextField*)atf
                     toPasteboard:(NSPasteboard*)pboard {
  NSRange selectedRange = [[textField_ currentEditor] selectedRange];
  NSString *stringValue = [textField_ stringValue];

  [pboard clearContents];

  if (selectedRange.location == 0 &&
      selectedRange.length == stringValue.length) {
    // full selection yields a valid URL and a textual rep
    NSURL *url = [self absoluteURL];
    NSArray *types = [NSArray arrayWithObjects:NSURLPboardType, NSStringPboardType, nil];
    [pboard declareTypes:types owner:self];
    [pboard setString:[url absoluteString] forType:NSStringPboardType];
    NSData *urlData = [NSArchiver archivedDataWithRootObject:url];
    [pboard setData:urlData forType:NSURLPboardType];
  } else {
    // selected substring yields only text
    NSArray *types = [NSArray arrayWithObjects:NSStringPboardType, nil];
    [pboard declareTypes:types owner:self];
    NSString *str = [stringValue substringWithRange:selectedRange];
    [pboard setString:str forType:NSStringPboardType];
  }
}

// Returns true if the current clipboard text supports paste and go
// (or paste and search).
- (BOOL)canPasteAndGoInAutocompleteTextField:(KAutocompleteTextField*)atf {
  return NO;
}

// Returns the appropriate "Paste and Go" or "Paste and Search"
// context menu string, depending on what is currently in the
// clipboard.  Only called if canPasteAndGoInAutocompleteTextField: returns
// true.
- (NSString*)pasteActionLabelForAutocompleteTextField:
    (KAutocompleteTextField*)atf {
  NOTREACHED();
}

// Called when the user initiates a "paste and go" or "paste and
// search" into the field.
- (void)pasteAndGoInAutocompleteTextField:(KAutocompleteTextField*)atf {
  NOTREACHED();
}

// Called when the field's frame changes.
- (void)frameDidChangeForAutocompleteTextField:(KAutocompleteTextField*)atf {
  //DLOG("TODO %s", __func__);
}

// Called when the popup is no longer appropriate, such as when the
// field's window loses focus or a page action is clicked.
- (void)closePopupInAutocompleteTextField:(KAutocompleteTextField*)atf {
  //DLOG("TODO %s", __func__);
}

// Called when the user begins editing the field, for every edit,
// and when the user is done editing the field.
- (void)didBeginEditingInAutocompleteTextField:(KAutocompleteTextField*)atf {
}
- (void)didModifyAutocompleteTextField:(KAutocompleteTextField*)atf {
  //DLOG("TODO %s", __func__);
}
- (void)didEndEditingInAutocompleteTextField:(KAutocompleteTextField*)atf {
  DLOG("didEndEditingInAutocompleteTextField (%@)", [NSApp currentEvent]);
  NSEvent *ev = [NSApp currentEvent];
  if (ev.type == NSKeyDown && ev.keyCode == kVK_Return) {
    // Note that if the user presses Cmd, CTRL or Alt the editing will not end,
    // but rather call doCommandBySelector:
    [self commitEditing:[ev modifierFlags]];
  } else {
    // this most likely means that the user "cancelled" editing by giving
    // someone first responder focus -- if we represent the empty string we
    // shoud restore our original state.
    if ([textField_ stringValue].length == 0) {
      [self restoreState];
    }
  }

}

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
    inAutocompleteTextField:(KAutocompleteTextField*)atf {
  DLOG("doCommandBySelector:%@ (%@)", NSStringFromSelector(cmd), [NSApp currentEvent]);
  NSEvent *ev = [NSApp currentEvent];
  if (ev.keyCode == kVK_Return) {
    [self commitEditing:[ev modifierFlags]];
    return YES;
  } else if (cmd == @selector(cancelOperation:)) {
    [self restoreState];
    // Lose focus to editor
    if (currentContents_)
      [currentContents_ becomeFirstResponder];
  }
  return NO;
}

// Called whenever the autocomplete text field gets focused.
// To test if a modifier key is being pressed, inspect |ev|:
//
//    BOOL cmdPressed = ([ev modifierFlags] & NSCommandKeyMask) != 0;
//
- (void)autocompleteTextField:(KAutocompleteTextField*)atf
     willBecomeFirstResponder:(NSEvent*)ev {
  DLOG("TODO %s", __func__);
}

// Called whenever the autocomplete text field is losing focus.
- (void)autocompleteTextField:(KAutocompleteTextField*)atf
     willResignFirstResponder:(NSEvent*)ev {
  DLOG("TODO %s", __func__);
}


@end

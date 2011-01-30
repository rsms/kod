// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "NSEvent-kod.h"

#define K_UC_ISFNKEY(c) ((c) >= 0xF700 && (c) <= 0xF8FF)

@implementation NSEvent (kod)

- (uint64_t)kodHash {
  // first 16 bits are the device-independent modifier flags (ctrl, alt, etc)
  uint64_t key = [self modifierFlags] & NSDeviceIndependentModifierFlagsMask;
  // we don't care about the NSFunctionKeyMask as it's implied by function chars
  key &= ~NSFunctionKeyMask;
  //DLOG("key0 %llx\n%s", key, dec2bin(key, 64));

  // the following 16-48 bits constitute the char code (1-3 unichars)
  NSString *chars = [self charactersIgnoringModifiers];
  NSUInteger L = chars.length;
  if (L > 0) {
    unichar c = [chars characterAtIndex:0];
    // special case for function chars to turn
    //  "ALT + rightwards arrow" == "A-N-<right>"
    // into
    //  "ALT + rightwards arrow" == "A-<right>"
    // as "A-<right>" sans N is "A-<end>"
    if (c >= NSUpArrowFunctionKey && c <= NSRightArrowFunctionKey) {
      key &= ~NSNumericPadKeyMask;
    }
    key = key >> 16;
    key |= ((uint64_t)c) << 16;
    //DLOG("key1 %llx\n%s", key, dec2bin(key, 64));
    if (L > 1) {
      key |= ((uint64_t)[chars characterAtIndex:1]) << 24;
      //DLOG("key2 %llx\n%s", key, dec2bin(key, 64));
      if (L > 2) {
        key |= ((uint64_t)[chars characterAtIndex:2]) << 48;
        //DLOG("key3 %llx\n%s", key, dec2bin(key, 64));
      }
    }
  } else {
    key = key >> 16;
  }
  //DLOG("return key:\n%s", dec2bin(key, 64));
  return key;
}


- (NSString*)kodInputBindingDescription {
  // we only handle key events (for now)
  NSEventType t = [self type];
  if (t != NSKeyDown && t != NSKeyUp) return nil;

  NSMutableString *seq = [NSMutableString stringWithCapacity:4];
  NSUInteger modifiers = [self modifierFlags];
  NSString *chars = [self charactersIgnoringModifiers];
  NSString *charsLower = nil;
  unichar functionKeyChar = 0;
  // TODO: support more than one key

  if (chars.length != 0) {
    unichar c = [chars characterAtIndex:0];
    if (K_UC_ISFNKEY(c)) {
      functionKeyChar = c;
      modifiers &= ~NSFunctionKeyMask;
      if (c >= NSUpArrowFunctionKey && c <= NSRightArrowFunctionKey)
        modifiers &= ~NSNumericPadKeyMask;
    } else {
      chars = [chars substringToIndex:1];
      charsLower = [chars lowercaseString];
      if (![chars isEqualToString:charsLower])
        modifiers |= NSShiftKeyMask;
    }
  }

  if (modifiers & NSAlternateKeyMask)  [seq appendString:@"A-"];
  if (modifiers & NSControlKeyMask)    [seq appendString:@"C-"];
  if (modifiers & NSFunctionKeyMask)   [seq appendString:@"F-"];
  if (modifiers & NSHelpKeyMask)       [seq appendString:@"H-"];
  if (modifiers & NSAlphaShiftKeyMask) [seq appendString:@"L-"];
  if (modifiers & NSCommandKeyMask)    [seq appendString:@"M-"];
  if (modifiers & NSNumericPadKeyMask) [seq appendString:@"N-"];
  if (modifiers & NSShiftKeyMask)      [seq appendString:@"S-"];

  if (charsLower) {
    [seq appendString:charsLower];
  } else if (functionKeyChar) {
    switch (functionKeyChar) {
      case NSUpArrowFunctionKey: [seq appendString:@"<up>"]; break;
      case NSDownArrowFunctionKey: [seq appendString:@"<down>"]; break;
      case NSLeftArrowFunctionKey: [seq appendString:@"<left>"]; break;
      case NSRightArrowFunctionKey: [seq appendString:@"<right>"]; break;
      case NSF1FunctionKey: [seq appendString:@"<f1>"]; break;
      case NSF2FunctionKey: [seq appendString:@"<f2>"]; break;
      case NSF3FunctionKey: [seq appendString:@"<f3>"]; break;
      case NSF4FunctionKey: [seq appendString:@"<f4>"]; break;
      case NSF5FunctionKey: [seq appendString:@"<f5>"]; break;
      case NSF6FunctionKey: [seq appendString:@"<f6>"]; break;
      case NSF7FunctionKey: [seq appendString:@"<f7>"]; break;
      case NSF8FunctionKey: [seq appendString:@"<f8>"]; break;
      case NSF9FunctionKey: [seq appendString:@"<f9>"]; break;
      case NSF10FunctionKey: [seq appendString:@"<f10>"]; break;
      case NSF11FunctionKey: [seq appendString:@"<f11>"]; break;
      case NSF12FunctionKey: [seq appendString:@"<f12>"]; break;
      case NSF13FunctionKey: [seq appendString:@"<f13>"]; break;
      case NSF14FunctionKey: [seq appendString:@"<f14>"]; break;
      case NSF15FunctionKey: [seq appendString:@"<f15>"]; break;
      case NSF16FunctionKey: [seq appendString:@"<f16>"]; break;
      case NSF17FunctionKey: [seq appendString:@"<f17>"]; break;
      case NSF18FunctionKey: [seq appendString:@"<f18>"]; break;
      case NSF19FunctionKey: [seq appendString:@"<f19>"]; break;
      case NSF20FunctionKey: [seq appendString:@"<f20>"]; break;
      case NSF21FunctionKey: [seq appendString:@"<f21>"]; break;
      case NSF22FunctionKey: [seq appendString:@"<f22>"]; break;
      case NSF23FunctionKey: [seq appendString:@"<f23>"]; break;
      case NSF24FunctionKey: [seq appendString:@"<f24>"]; break;
      case NSF25FunctionKey: [seq appendString:@"<f25>"]; break;
      case NSF26FunctionKey: [seq appendString:@"<f26>"]; break;
      case NSF27FunctionKey: [seq appendString:@"<f27>"]; break;
      case NSF28FunctionKey: [seq appendString:@"<f28>"]; break;
      case NSF29FunctionKey: [seq appendString:@"<f29>"]; break;
      case NSF30FunctionKey: [seq appendString:@"<f30>"]; break;
      case NSF31FunctionKey: [seq appendString:@"<f31>"]; break;
      case NSF32FunctionKey: [seq appendString:@"<f32>"]; break;
      case NSF33FunctionKey: [seq appendString:@"<f33>"]; break;
      case NSF34FunctionKey: [seq appendString:@"<f34>"]; break;
      case NSF35FunctionKey: [seq appendString:@"<f35>"]; break;
      case NSInsertFunctionKey: [seq appendString:@"<insert>"]; break;
      case NSDeleteFunctionKey: [seq appendString:@"<del>"]; break;
      case NSHomeFunctionKey: [seq appendString:@"<home>"]; break;
      case NSBeginFunctionKey: [seq appendString:@"<begin>"]; break;
      case NSEndFunctionKey: [seq appendString:@"<end>"]; break;
      case NSPageUpFunctionKey: [seq appendString:@"<pageup>"]; break;
      case NSPageDownFunctionKey: [seq appendString:@"<pagedown>"]; break;
      case NSPrintScreenFunctionKey: [seq appendString:@"<printscreen>"]; break;
      case NSScrollLockFunctionKey: [seq appendString:@"<scrollock>"]; break;
      case NSPauseFunctionKey: [seq appendString:@"<pause>"]; break;
      case NSSysReqFunctionKey: [seq appendString:@"<sysreq>"]; break;
      case NSBreakFunctionKey: [seq appendString:@"<break>"]; break;
      case NSResetFunctionKey: [seq appendString:@"<reset>"]; break;
      case NSStopFunctionKey: [seq appendString:@"<stop>"]; break;
      case NSMenuFunctionKey: [seq appendString:@"<menu>"]; break;
      case NSUserFunctionKey: [seq appendString:@"<user>"]; break;
      case NSSystemFunctionKey: [seq appendString:@"<system>"]; break;
      case NSPrintFunctionKey: [seq appendString:@"<print>"]; break;
      case NSClearLineFunctionKey: [seq appendString:@"<clearline>"]; break;
      case NSClearDisplayFunctionKey: [seq appendString:@"<cleardisplay>"]; break;
      case NSInsertLineFunctionKey: [seq appendString:@"<insertline>"]; break;
      case NSDeleteLineFunctionKey: [seq appendString:@"<deleteline>"]; break;
      case NSInsertCharFunctionKey: [seq appendString:@"<insertchar>"]; break;
      case NSDeleteCharFunctionKey: [seq appendString:@"<deletechar>"]; break;
      case NSPrevFunctionKey: [seq appendString:@"<prev>"]; break;
      case NSNextFunctionKey: [seq appendString:@"<next>"]; break;
      case NSSelectFunctionKey: [seq appendString:@"<select>"]; break;
      case NSExecuteFunctionKey: [seq appendString:@"<execute>"]; break;
      case NSUndoFunctionKey: [seq appendString:@"<undo>"]; break;
      case NSRedoFunctionKey: [seq appendString:@"<redo>"]; break;
      case NSFindFunctionKey: [seq appendString:@"<find>"]; break;
      case NSHelpFunctionKey: [seq appendString:@"<help>"]; break;
      case NSModeSwitchFunctionKey: [seq appendString:@"<modeswitch>"]; break;
      default: break;
    }
  }

  return seq;
}


@end

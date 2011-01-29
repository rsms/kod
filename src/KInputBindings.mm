#import "KInputBindings.h"
#import "common.h"

HUnorderedMapSharedPtr<std::string, KInputAction> KInputBindings::bindings_;


KInputAction *KInputBindings::get(NSEvent *event) {
  // we only handle key events (for now)
  NSEventType t = event.type;
  if (t != NSKeyDown && t != NSKeyUp) return NULL;

  std::string seq;
  NSUInteger modifiers = [event modifierFlags];
  NSString *chars = [event charactersIgnoringModifiers];
  NSString *charsLower = nil;
  unichar functionKeyChar = 0;
  // TODO: support more than one key

  if (chars.length != 0) {
    unichar ch = [chars characterAtIndex:0];
    if (ch >= 0xF700 && ch <= 0xF8FF) {
      functionKeyChar = ch;
      modifiers &= ~NSFunctionKeyMask;
    } else {
      chars = [chars substringToIndex:1];
      charsLower = [chars lowercaseString];
      if (![chars isEqualToString:charsLower])
        modifiers |= NSShiftKeyMask;
    }
  }

  if (modifiers & NSAlternateKeyMask)  seq += "A-";
  if (modifiers & NSControlKeyMask)    seq += "C-";
  if (modifiers & NSFunctionKeyMask)   seq += "F-";
  if (modifiers & NSHelpKeyMask)       seq += "H-";
  if (modifiers & NSAlphaShiftKeyMask) seq += "L-";
  if (modifiers & NSCommandKeyMask)    seq += "M-";
  if (modifiers & NSNumericPadKeyMask) seq += "N-";
  if (modifiers & NSShiftKeyMask)      seq += "S-";

  if (charsLower) {
    seq += [charsLower UTF8String];
  } else if (functionKeyChar) {
    switch (functionKeyChar) {
      case NSUpArrowFunctionKey: seq += "<up>"; break;
      case NSDownArrowFunctionKey: seq += "<down>"; break;
      case NSLeftArrowFunctionKey: seq += "<left>"; break;
      case NSRightArrowFunctionKey: seq += "<right>"; break;
      case NSF1FunctionKey: seq += "<f1>"; break;
      case NSF2FunctionKey: seq += "<f2>"; break;
      case NSF3FunctionKey: seq += "<f3>"; break;
      case NSF4FunctionKey: seq += "<f4>"; break;
      case NSF5FunctionKey: seq += "<f5>"; break;
      case NSF6FunctionKey: seq += "<f6>"; break;
      case NSF7FunctionKey: seq += "<f7>"; break;
      case NSF8FunctionKey: seq += "<f8>"; break;
      case NSF9FunctionKey: seq += "<f9>"; break;
      case NSF10FunctionKey: seq += "<f10>"; break;
      case NSF11FunctionKey: seq += "<f11>"; break;
      case NSF12FunctionKey: seq += "<f12>"; break;
      case NSF13FunctionKey: seq += "<f13>"; break;
      case NSF14FunctionKey: seq += "<f14>"; break;
      case NSF15FunctionKey: seq += "<f15>"; break;
      case NSF16FunctionKey: seq += "<f16>"; break;
      case NSF17FunctionKey: seq += "<f17>"; break;
      case NSF18FunctionKey: seq += "<f18>"; break;
      case NSF19FunctionKey: seq += "<f19>"; break;
      case NSF20FunctionKey: seq += "<f20>"; break;
      case NSF21FunctionKey: seq += "<f21>"; break;
      case NSF22FunctionKey: seq += "<f22>"; break;
      case NSF23FunctionKey: seq += "<f23>"; break;
      case NSF24FunctionKey: seq += "<f24>"; break;
      case NSF25FunctionKey: seq += "<f25>"; break;
      case NSF26FunctionKey: seq += "<f26>"; break;
      case NSF27FunctionKey: seq += "<f27>"; break;
      case NSF28FunctionKey: seq += "<f28>"; break;
      case NSF29FunctionKey: seq += "<f29>"; break;
      case NSF30FunctionKey: seq += "<f30>"; break;
      case NSF31FunctionKey: seq += "<f31>"; break;
      case NSF32FunctionKey: seq += "<f32>"; break;
      case NSF33FunctionKey: seq += "<f33>"; break;
      case NSF34FunctionKey: seq += "<f34>"; break;
      case NSF35FunctionKey: seq += "<f35>"; break;
      case NSInsertFunctionKey: seq += "<insert>"; break;
      case NSDeleteFunctionKey: seq += "<del>"; break;
      case NSHomeFunctionKey: seq += "<home>"; break;
      case NSBeginFunctionKey: seq += "<begin>"; break;
      case NSEndFunctionKey: seq += "<end>"; break;
      case NSPageUpFunctionKey: seq += "<pageup>"; break;
      case NSPageDownFunctionKey: seq += "<pagedown>"; break;
      case NSPrintScreenFunctionKey: seq += "<printscreen>"; break;
      case NSScrollLockFunctionKey: seq += "<scrollock>"; break;
      case NSPauseFunctionKey: seq += "<pause>"; break;
      case NSSysReqFunctionKey: seq += "<sysreq>"; break;
      case NSBreakFunctionKey: seq += "<break>"; break;
      case NSResetFunctionKey: seq += "<reset>"; break;
      case NSStopFunctionKey: seq += "<stop>"; break;
      case NSMenuFunctionKey: seq += "<menu>"; break;
      case NSUserFunctionKey: seq += "<user>"; break;
      case NSSystemFunctionKey: seq += "<system>"; break;
      case NSPrintFunctionKey: seq += "<print>"; break;
      case NSClearLineFunctionKey: seq += "<clearline>"; break;
      case NSClearDisplayFunctionKey: seq += "<cleardisplay>"; break;
      case NSInsertLineFunctionKey: seq += "<insertline>"; break;
      case NSDeleteLineFunctionKey: seq += "<deleteline>"; break;
      case NSInsertCharFunctionKey: seq += "<insertchar>"; break;
      case NSDeleteCharFunctionKey: seq += "<deletechar>"; break;
      case NSPrevFunctionKey: seq += "<prev>"; break;
      case NSNextFunctionKey: seq += "<next>"; break;
      case NSSelectFunctionKey: seq += "<select>"; break;
      case NSExecuteFunctionKey: seq += "<execute>"; break;
      case NSUndoFunctionKey: seq += "<undo>"; break;
      case NSRedoFunctionKey: seq += "<redo>"; break;
      case NSFindFunctionKey: seq += "<find>"; break;
      case NSHelpFunctionKey: seq += "<help>"; break;
      case NSModeSwitchFunctionKey: seq += "<modeswitch>"; break;
      default: break;
    }
  }

  DLOG("seq: '%s'", seq.c_str());

  return get(seq);
}

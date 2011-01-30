#import "KInputBindings.h"
#import "common.h"
#include "dec2bin.h"

#define K_UC_ISFNKEY(c) ((c) >= 0xF700 && (c) <= 0xF8FF)

KInputBindings::Map KInputBindings::bindings_[KInputBindings::MaxLevel];

static NSDictionary *gFuncKeyNamesToUnicodePoints = nil;

static void __attribute__((constructor)) __init() {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  gFuncKeyNamesToUnicodePoints = [[NSDictionary alloc] initWithObjectsAndKeys:
    [NSNumber numberWithShort:NSUpArrowFunctionKey], @"up",
    [NSNumber numberWithShort:NSDownArrowFunctionKey], @"down",
    [NSNumber numberWithShort:NSLeftArrowFunctionKey], @"left",
    [NSNumber numberWithShort:NSRightArrowFunctionKey], @"right",
    [NSNumber numberWithShort:NSF1FunctionKey], @"f1",
    [NSNumber numberWithShort:NSF2FunctionKey], @"f2",
    [NSNumber numberWithShort:NSF3FunctionKey], @"f3",
    [NSNumber numberWithShort:NSF4FunctionKey], @"f4",
    [NSNumber numberWithShort:NSF5FunctionKey], @"f5",
    [NSNumber numberWithShort:NSF6FunctionKey], @"f6",
    [NSNumber numberWithShort:NSF7FunctionKey], @"f7",
    [NSNumber numberWithShort:NSF8FunctionKey], @"f8",
    [NSNumber numberWithShort:NSF9FunctionKey], @"f9",
    [NSNumber numberWithShort:NSF10FunctionKey], @"f10",
    [NSNumber numberWithShort:NSF11FunctionKey], @"f11",
    [NSNumber numberWithShort:NSF12FunctionKey], @"f12",
    [NSNumber numberWithShort:NSF13FunctionKey], @"f13",
    [NSNumber numberWithShort:NSF14FunctionKey], @"f14",
    [NSNumber numberWithShort:NSF15FunctionKey], @"f15",
    [NSNumber numberWithShort:NSF16FunctionKey], @"f16",
    [NSNumber numberWithShort:NSF17FunctionKey], @"f17",
    [NSNumber numberWithShort:NSF18FunctionKey], @"f18",
    [NSNumber numberWithShort:NSF19FunctionKey], @"f19",
    [NSNumber numberWithShort:NSF20FunctionKey], @"f20",
    [NSNumber numberWithShort:NSF21FunctionKey], @"f21",
    [NSNumber numberWithShort:NSF22FunctionKey], @"f22",
    [NSNumber numberWithShort:NSF23FunctionKey], @"f23",
    [NSNumber numberWithShort:NSF24FunctionKey], @"f24",
    [NSNumber numberWithShort:NSF25FunctionKey], @"f25",
    [NSNumber numberWithShort:NSF26FunctionKey], @"f26",
    [NSNumber numberWithShort:NSF27FunctionKey], @"f27",
    [NSNumber numberWithShort:NSF28FunctionKey], @"f28",
    [NSNumber numberWithShort:NSF29FunctionKey], @"f29",
    [NSNumber numberWithShort:NSF30FunctionKey], @"f30",
    [NSNumber numberWithShort:NSF31FunctionKey], @"f31",
    [NSNumber numberWithShort:NSF32FunctionKey], @"f32",
    [NSNumber numberWithShort:NSF33FunctionKey], @"f33",
    [NSNumber numberWithShort:NSF34FunctionKey], @"f34",
    [NSNumber numberWithShort:NSF35FunctionKey], @"f35",
    [NSNumber numberWithShort:NSInsertFunctionKey], @"insert",
    [NSNumber numberWithShort:NSDeleteFunctionKey], @"del",
    [NSNumber numberWithShort:NSHomeFunctionKey], @"home",
    [NSNumber numberWithShort:NSBeginFunctionKey], @"begin",
    [NSNumber numberWithShort:NSEndFunctionKey], @"end",
    [NSNumber numberWithShort:NSPageUpFunctionKey], @"pageup",
    [NSNumber numberWithShort:NSPageDownFunctionKey], @"pagedown",
    [NSNumber numberWithShort:NSPrintScreenFunctionKey], @"printscreen",
    [NSNumber numberWithShort:NSScrollLockFunctionKey], @"scrollock",
    [NSNumber numberWithShort:NSPauseFunctionKey], @"pause",
    [NSNumber numberWithShort:NSSysReqFunctionKey], @"sysreq",
    [NSNumber numberWithShort:NSBreakFunctionKey], @"break",
    [NSNumber numberWithShort:NSResetFunctionKey], @"reset",
    [NSNumber numberWithShort:NSStopFunctionKey], @"stop",
    [NSNumber numberWithShort:NSMenuFunctionKey], @"menu",
    [NSNumber numberWithShort:NSUserFunctionKey], @"user",
    [NSNumber numberWithShort:NSSystemFunctionKey], @"system",
    [NSNumber numberWithShort:NSPrintFunctionKey], @"print",
    [NSNumber numberWithShort:NSClearLineFunctionKey], @"clearline",
    [NSNumber numberWithShort:NSClearDisplayFunctionKey], @"cleardisplay",
    [NSNumber numberWithShort:NSInsertLineFunctionKey], @"insertline",
    [NSNumber numberWithShort:NSDeleteLineFunctionKey], @"deleteline",
    [NSNumber numberWithShort:NSInsertCharFunctionKey], @"insertchar",
    [NSNumber numberWithShort:NSDeleteCharFunctionKey], @"deletechar",
    [NSNumber numberWithShort:NSPrevFunctionKey], @"prev",
    [NSNumber numberWithShort:NSNextFunctionKey], @"next",
    [NSNumber numberWithShort:NSSelectFunctionKey], @"select",
    [NSNumber numberWithShort:NSExecuteFunctionKey], @"execute",
    [NSNumber numberWithShort:NSUndoFunctionKey], @"undo",
    [NSNumber numberWithShort:NSRedoFunctionKey], @"redo",
    [NSNumber numberWithShort:NSFindFunctionKey], @"find",
    [NSNumber numberWithShort:NSHelpFunctionKey], @"help",
    [NSNumber numberWithShort:NSModeSwitchFunctionKey], @"modeswitch",
    nil];
  [pool drain];
}


uint64_t KInputBindings::parseSequence(NSString *seq) {
  uint64_t key = 0;
  static const int ucbufSize = 512;
  unichar ucbuf[ucbufSize];
  int charoffs = 16;
  NSRange r = NSMakeRange(0, MIN([seq length], ucbufSize));
  [seq getCharacters:ucbuf range:r];
  for (NSUInteger i=0; i<r.length; ++i) {
    unichar c = ucbuf[i];
    if (isupper(c)) {
      switch (c) {
        case 'A': key |= (NSAlternateKeyMask >> 16); break;
        case 'C': key |= (NSControlKeyMask >> 16); break;
        case 'F': key |= (NSFunctionKeyMask >> 16); break;
        case 'H': key |= (NSHelpKeyMask >> 16); break;
        case 'L': key |= (NSAlphaShiftKeyMask >> 16); break;
        case 'M': key |= (NSCommandKeyMask >> 16); break;
        case 'N': key |= (NSNumericPadKeyMask >> 16); break;
        case 'S': key |= (NSShiftKeyMask >> 16); break;
        default: break;
      }
      //DLOG("key ->\n%s", dec2bin(key, 64));
    } else if (c != '-') {
      if (c == '<') {
        // read named function key
        NSUInteger x = i;
        c = 0;
        for (x; x<r.length; ++x) {
          if (ucbuf[x] == '>') {
            NSString *funcname =
                [seq substringWithRange:NSMakeRange(i+1, x-(i+1))];
            //DLOG("funcname -> '%@'", funcname);
            NSNumber *n = [gFuncKeyNamesToUnicodePoints objectForKey:funcname];
            if (n) {
              c = [n shortValue];
              //if (c == NSRightArrowFunctionKey)
              //  DLOG("c = NSRightArrowFunctionKey");
            }
            break;
          }
        }
        if (c == 0)
          return 0; // malformed input
        i = x;
      }
      if (charoffs <= 48) {
        /*DLOG("c << charoffs  (%u << %d)", c, charoffs);
        if (K_UC_ISFNKEY(c)) {
          DLOG("c is a function key char");
        }*/
        key |= ((uint64_t)c) << charoffs;
        charoffs += 16;
        //DLOG("key ->\n%s", dec2bin(key, 64));
      } // else there are too many chars which we just skip
    }
  }
  //DLOG("return key ->\n%s", dec2bin(key, 64));
  return key;
}


BOOL KInputBindings::set(Level level, NSString *seqs, KInputAction *action) {
  for (NSString *seq in [seqs componentsSeparatedByString:@" "]) {
    uint64_t key = parseSequence(seq);
    // TODO: support more than one sequence
    if (key) {
      set(level, key, action);
      return YES;
    } else break;
  }
  return NO;
}


KInputAction *KInputBindings::get(Level level, NSString *seqs) {
  for (NSString *seq in [seqs componentsSeparatedByString:@" "]) {
    uint64_t key = parseSequence(seq);
    // TODO: support more than one sequence
    if (key) {
      return get(level, key);
    } else break;
  }
  return nil;
}


size_t KInputBindings::remove(uint64_t key) {
  size_t count = 0;
  for (int level=MaxLevel; --level >= 0; )
    count += bindings_[level].eraseSync(key);
  return count;
}


void KInputBindings::clear(Level level) {
  if (level < MaxLevel) {
    bindings_[level].clearSync();
  } else {
    for (int level=MaxLevel; --level >= 0; )
      bindings_[level].clearSync();
  }
}

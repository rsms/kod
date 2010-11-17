#import "KStyleElement.h"
#import "KSyntaxHighlighter.h"
#import "NSColor-web.h"
#import "NSString-intern.h"
#import "KLangSymbol.h"
#include <srchilite/formatterparams.h>
#import <ChromiumTabs/common.h>

static NSCharacterSet *kQuoteCharacterSet = nil;

// Using a dummy category to hook code into load sequence
@implementation NSObject (KStyleElement)
+ (void)load {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  kQuoteCharacterSet =
      [[NSCharacterSet characterSetWithCharactersInString:@"\""] retain];
  [pool drain];
}
@end


static NSFont* _kBaseFont = nil;

NSFont* KStyleElement::baseFont() {
  if (!_kBaseFont) {
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    _kBaseFont =
        [fontManager fontWithFamily:@"M+ 1m" traits:0 weight:0 size:13.0];
    if (!_kBaseFont) {
      //WLOG("unable to find default font \"M+\" -- using system default");
      _kBaseFont = [NSFont userFixedPitchFontOfSize:13.0];
    }
    [_kBaseFont retain];
  }
  return _kBaseFont;
}


NSString *KStyleElement::ClassAttributeName = @"ktfclass";


//static
void KStyleElement::clearAttributes(NSMutableAttributedString *astr,
                                     NSRange range,
                                     bool removeSpecials/*=0*/) {
  // remove all attributes we can possibly set
  [astr removeAttribute:NSFontAttributeName range:range];
  [astr removeAttribute:NSUnderlineStyleAttributeName range:range];
  [astr removeAttribute:NSForegroundColorAttributeName range:range];
  [astr removeAttribute:NSBackgroundColorAttributeName range:range];
  if (removeSpecials) {
    // remove special attribues we set
    [astr removeAttribute:ClassAttributeName range:range];
  }
}


KStyleElement::KStyleElement(NSString *name) : syntaxHighlighter_(NULL) {
  NSString const *symbol = [name internedString];
  textAttributes_ = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
      baseFont(), NSFontAttributeName,
      symbol, ClassAttributeName,
      nil];
}

KStyleElement::~KStyleElement() {
  objc_exch(&syntaxHighlighter_, nil);
  objc_exch(&textAttributes_, nil);
}

NSString *KStyleElement::symbol() {
  return [textAttributes_ objectForKey:ClassAttributeName];
}


void KStyleElement::setStyle(srchilite::StyleConstantsPtr style) {
  BOOL underlined = NO;
  NSFont *font = baseFont();
  NSFontTraitMask fontTraitMask = 0;
  if (style.get()) {
    for (srchilite::StyleConstantsIterator it = style->begin();
         it != style->end(); ++it) {
      switch (*it) {
        case srchilite::ISBOLD:
          fontTraitMask |= NSBoldFontMask;
          break;
        case srchilite::ISITALIC:
          fontTraitMask |= NSItalicFontMask;
          break;
        case srchilite::ISUNDERLINE:
          underlined = YES;
          break;
        /*case srchilite::ISFIXED:
          formatter->setMonospace(true);
          break;
        case srchilite::ISNOTFIXED:
          formatter->setMonospace(false);
          break;
        case srchilite::ISNOREF:
          break;*/
      }
    }
    if (fontTraitMask) {
      NSFontManager *fontManager = [NSFontManager sharedFontManager];
      NSFont *font2 = [fontManager fontWithFamily:[font familyName]
                                           traits:fontTraitMask
                                           weight:0
                                             size:[font pointSize]];
      if (font2)
        font = font2;
    }
    
    [textAttributes_ setObject:font forKey:NSFontAttributeName];
    
    if (underlined) {
      [textAttributes_ setObject:[NSNumber numberWithBool:YES]
                          forKey:NSUnderlineStyleAttributeName];
    } else {
      [textAttributes_ removeObjectForKey:NSUnderlineStyleAttributeName];
    }
  }
}


void KStyleElement::setForegroundColor(NSColor *color) {
  if (color) {
    [textAttributes_ setObject:color forKey:NSForegroundColorAttributeName];
  } else {
    [textAttributes_ removeObjectForKey:NSForegroundColorAttributeName];
  }
}

NSColor *KStyleElement::foregroundColor() {
  return [textAttributes_ objectForKey:NSForegroundColorAttributeName];
}


void KStyleElement::setBackgroundColor(NSColor *color) {
  if (color) {
    [textAttributes_ setObject:color forKey:NSBackgroundColorAttributeName];
  } else {
    [textAttributes_ removeObjectForKey:NSBackgroundColorAttributeName];
  }
}

NSColor *KStyleElement::backgroundColor() {
  return [textAttributes_ objectForKey:NSBackgroundColorAttributeName];
}


void KStyleElement::applyAttributes(NSMutableAttributedString *astr,
                                     NSRange range,
                                     bool replace/*=0*/) {
  if (replace) {
    [astr setAttributes:textAttributes_ range:range];
  } else {
    [astr addAttributes:textAttributes_ range:range];
  }
}


void KStyleElement::format(const std::string &s,
                            const srchilite::FormatterParams *params) {
  K_DEPRECATED;
  /*#if 0
  if ( (elem_ != "normal" || !s.size()) && params ) {
    DLOG("<%s>format(\"%s\", start=%d)",
         elem_.c_str(), s.c_str(), params->start);
  }
  #endif
  //NSLog(@"format: s='%s', elem='%s'", s.c_str(), elem_.c_str());
  [syntaxHighlighter_ setFormat:this
                        inRange:NSMakeRange(params->start, s.size())];*/
}

#import "common.h"
#import "KStyleElement.h"
#import "NSColor-web.h"
#import "NSString-intern.h"
#import "KLangSymbol.h"
#import "kconf.h"
#import "KStyle.h"
#import <srchilite/formatterparams.h>
#import <CSS/CSS.h>


NSString * const KStyleElementAttributeName = @"KStyleElement";


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
    [astr removeAttribute:KStyleElementAttributeName range:range];
  }
}


KStyleElement::KStyleElement(NSString *name, CSSStyle *style, KStyle *parent) {
  NSString const *symbol = [name internedString];
  textAttributes_ = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
      symbol, KStyleElementAttributeName,
      nil];
  if (style) {
    setStyle(style, parent);
  } else if (parent) {
    setFont(parent.baseFont);
  }
}


KStyleElement::~KStyleElement() {
  h_objc_xch(&textAttributes_, nil);
}


void KStyleElement::setStyle(CSSStyle *style, KStyle *parent) {
  // foreground color
  NSColor *color = style.color;
  if (!color || [color alphaComponent] == 0.0)
    color = kconf_color(@"defaultTextColor", [NSColor whiteColor]);
  setForegroundColor(color);

  // background color
  if ((color = style.backgroundColor) && [color alphaComponent] != 0.0)
    setBackgroundColor(color);

  // font
  NSFontTraitMask fontTraitMask = 0;
  NSNumber *obliqueness = nil;
  NSNumber *underlined = nil;
  NSNumber *strikethrough = nil;

  // font style
  switch (style.fontStyle) {
    case CSS_FONT_STYLE_ITALIC:
      fontTraitMask |= NSItalicFontMask;
      break;
    case CSS_FONT_STYLE_OBLIQUE:
      obliqueness = [NSNumber numberWithFloat:0.16];
      break;
  }

  // font variant
  if (style.fontVariant == CSS_FONT_VARIANT_SMALL_CAPS)
    fontTraitMask |= NSSmallCapsFontMask;

  // font weight (currently only "bold" is supported)
  switch (style.fontWeight) {
    case CSS_FONT_WEIGHT_BOLD:
    case CSS_FONT_WEIGHT_BOLDER:
      fontTraitMask |= NSBoldFontMask;
      break;
  }

  // text decoration
  switch (style.textDecoration) {
    case CSS_TEXT_DECORATION_UNDERLINE:
      underlined = [NSNumber numberWithBool:YES];
      break;
    case CSS_TEXT_DECORATION_LINE_THROUGH:
      strikethrough = [NSNumber numberWithInt:NSUnderlineStyleSingle];
      break;
  }

  // derive new font with traits
  if (parent) {
    NSFont *font = parent.baseFont;
    if (fontTraitMask) {
      NSFontManager *fontManager = [NSFontManager sharedFontManager];
      NSString *fontFamily = [[parent.baseFontDescriptor fontAttributes]
                              objectForKey:NSFontFamilyAttribute];
      NSFont *font2 = [fontManager fontWithFamily:[font familyName]
                                           traits:fontTraitMask
                                           weight:0
                                             size:[font pointSize]];
      if (font2) font = font2;
    }

    // font
    [textAttributes_ setObject:font forKey:NSFontAttributeName];
  }

  // cursor
  NSCursor *cursor = style.cursor;

  // set or clear attributes
  setAttribute(NSObliquenessAttributeName, obliqueness);
  setAttribute(NSUnderlineStyleAttributeName, underlined);
  setAttribute(NSStrikethroughStyleAttributeName, strikethrough);
  setAttribute(NSCursorAttributeName, cursor);
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

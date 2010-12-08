#import "KStyleElement.h"
#import "NSColor-web.h"
#import "NSString-intern.h"
#import "KLangSymbol.h"
#import "KConfig.h"
#import <srchilite/formatterparams.h>
#import <ChromiumTabs/common.h>
#import <CSS/CSS.h>


NSString * const KStyleElementAttributeName = @"KStyleElement";

static NSFontDescriptor* gBaseFontDescriptor = nil;

// TODO: move this to KStyle
NSFontDescriptor *KStyleElement::fontDescriptor() {
  if (!gBaseFontDescriptor) {
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    NSFont *font =
        [fontManager fontWithFamily:@"M+ 1m" traits:0 weight:0 size:11.0];
    if (!font) {
      //WLOG("unable to find default font \"M+\" -- using system default");
      font = [NSFont userFixedPitchFontOfSize:11.0];
    }
    gBaseFontDescriptor = [[font fontDescriptor] retain];
  }
  return gBaseFontDescriptor;
}


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


KStyleElement::KStyleElement(NSString *name, CSSStyle *style) {
  NSString const *symbol = [name internedString];
  textAttributes_ = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
      symbol, KStyleElementAttributeName,
      nil];
  if (style) {
    setStyle(style);
  } else {
    setFont([NSFont fontWithDescriptor:fontDescriptor() size:11.0]);
  }
}


KStyleElement::~KStyleElement() {
  h_objc_xch(&textAttributes_, nil);
}


void KStyleElement::setStyle(CSSStyle *style) {
  // foreground color
  NSColor *color = style.color;
  if (!color || [color alphaComponent] == 0.0)
    color = KConfig.getColor(@"defaultTextColor", [NSColor whiteColor]);
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
  NSFont *font = [NSFont fontWithDescriptor:fontDescriptor() size:11.0];
  if (fontTraitMask) {
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    NSString *fontFamily = [[fontDescriptor() fontAttributes]
                            objectForKey:NSFontFamilyAttribute];
    NSFont *font2 = [fontManager fontWithFamily:[font familyName]
                                         traits:fontTraitMask
                                         weight:0
                                           size:[font pointSize]];
    if (font2) font = font2;
  }
  
  // font
  [textAttributes_ setObject:font forKey:NSFontAttributeName];
  
  // set or clear attributes
  setAttribute(NSObliquenessAttributeName, obliqueness);
  setAttribute(NSUnderlineStyleAttributeName, underlined);
  setAttribute(NSStrikethroughStyleAttributeName, strikethrough);
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

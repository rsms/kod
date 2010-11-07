#import "KTextFormatter.h"
#import "KSyntaxHighlighter.h"
#import "NSColor-web.h"
#include <srchilite/formatterparams.h>
#import <ChromiumTabs/common.h>

static NSCharacterSet *kQuoteCharacterSet = nil;

// Using a dummy category to hook code into load sequence
@implementation NSObject (dummycat_ktextformatter)
+ (void)load {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  kQuoteCharacterSet =
      [[NSCharacterSet characterSetWithCharactersInString:@"\""] retain];
  [pool drain];
}
@end


static NSColor *_NSColorFromStdStr(const std::string &color) {
  assert(color.size());
  NSString *colorDef = [NSString stringWithUTF8String:color.c_str()];
  colorDef = [colorDef stringByTrimmingCharactersInSet:kQuoteCharacterSet];
  return [NSColor colorWithCssDefinition:colorDef];
}


static NSFont* _kBaseFont = nil;

NSFont* KTextFormatter::baseFont() {
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


KTextFormatter::KTextFormatter(const std::string &elem)
    : elem_(elem)
    , syntaxHighlighter_(NULL) {
  textAttributes_ = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
      baseFont(), NSFontAttributeName, nil];
}

KTextFormatter::~KTextFormatter() {
  objc_exch(&syntaxHighlighter_, nil);
  objc_exch(&textAttributes_, nil);
}


void KTextFormatter::setStyle(srchilite::StyleConstantsPtr style) {
  NSNumber *underlined = [NSNumber numberWithInt:0];
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
          underlined = [NSNumber numberWithInt:1];
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
    [textAttributes_ setObject:underlined forKey:NSUnderlineStyleAttributeName];
  }
}


void KTextFormatter::setForegroundColor(NSColor *color) {
  [textAttributes_ setObject:color forKey:NSForegroundColorAttributeName];
}

void KTextFormatter::setForegroundColor(const std::string &color) {
  setForegroundColor(_NSColorFromStdStr(color));
}

NSColor *KTextFormatter::foregroundColor() {
  return [textAttributes_ objectForKey:NSForegroundColorAttributeName];
}


void KTextFormatter::setBackgroundColor(NSColor *color) {
  [textAttributes_ setObject:color forKey:NSBackgroundColorAttributeName];
}

void KTextFormatter::setBackgroundColor(const std::string &color) {
  setBackgroundColor(_NSColorFromStdStr(color));
}

NSColor *KTextFormatter::backgroundColor() {
  return [textAttributes_ objectForKey:NSBackgroundColorAttributeName];
}


/**
 * Formats the passed string.
 *
 * @param the string to format
 * @param params possible additional parameters for the formatter
 */
void KTextFormatter::format(const std::string &s,
                            const srchilite::FormatterParams *params) {
  //NSLog(@"format: s='%s', elem='%s'", s.c_str(), elem_.c_str());
  [syntaxHighlighter_ setFormat:this
                        inRange:NSMakeRange(params->start, s.size())];
}

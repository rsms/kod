#import "common.h"

extern NSString * const KStyleElementAttributeName;

#ifdef __cplusplus

#import <boost/shared_ptr.hpp>
#import <srchilite/formatter.h>
#import <srchilite/formatterfactory.h>

@class CSSStyle, KStyle;

/**
 * Constitutes the text attributes for a specific language element.
 *
 * Part of the source-highlight API. srchilite::Formatter is an interface which
 * defines a single method |format(text, params)|.
 *
 * KStyleElements are owned by KStyle objects:
 *
 *    KStyle
 *      dict { element-id => KStyleElement , .. }
 *
 */
class KStyleElement {
 protected:
  NSMutableDictionary *textAttributes_;

 public:
  static void clearAttributes(NSMutableAttributedString *astr,
                              NSRange range,
                              bool removeSpecials=false);

  KStyleElement(NSString *name=@"body", CSSStyle *style=nil, KStyle *parent=nil);
  virtual ~KStyleElement();

  /// the language element represented by this formatter
  NSString *symbol() {
    return [textAttributes_ objectForKey:KStyleElementAttributeName];
  }

  void setStyle(CSSStyle *style, KStyle *parent=nil);
  inline NSDictionary *textAttributes() { return textAttributes_; }

  inline void setAttribute(NSString *key, id value) {
    if (value) [textAttributes_ setObject:value forKey:key];
    else [textAttributes_ removeObjectForKey:key];
  }
  inline id attribute(NSString *key) {
    return [textAttributes_ objectForKey:key];
  }

  void setFont(NSFont *font) {
    setAttribute(NSFontAttributeName, font);
  }
  NSFont *font() { return attribute(NSFontAttributeName); }

  void setForegroundColor(NSColor *color) {
    setAttribute(NSForegroundColorAttributeName, color);
  }
  NSColor *foregroundColor() {
    return attribute(NSForegroundColorAttributeName);
  }

  void setBackgroundColor(NSColor *color) {
    setAttribute(NSBackgroundColorAttributeName, color);
  }
  NSColor *backgroundColor() {
    return attribute(NSBackgroundColorAttributeName);
  }

  /**
   * Applies attributes to |astr| in |range|. If |replace| is true, any existing
   * atributes will be removed (replaced with my attributes).
   */
  void applyAttributes(NSMutableAttributedString *astr,
                       NSRange range,
                       bool replace=false);
};

/// shared pointer for KStyleElement
typedef boost::shared_ptr<KStyleElement> KStyleElementPtr;

#endif  // __cplusplus

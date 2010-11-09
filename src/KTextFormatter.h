#import <string>
#import <boost/shared_ptr.hpp>
#import <srchilite/formatter.h>
#import <srchilite/formatterfactory.h>

@class KSyntaxHighlighter;

/**
* A specialization of srchilite::Formatter in order to format parts of
* a document, instead of outputting the formatted text.
*/
class KTextFormatter: public srchilite::Formatter {
 protected:
  /// the language element represented by this formatter
  std::string elem_;
  
  /// reference to related KSyntaxHighlighter
  KSyntaxHighlighter *syntaxHighlighter_;
  
  NSMutableDictionary *textAttributes_;

 public:
  static NSFont *baseFont();
  static NSString *ClassAttributeName;
  
  KTextFormatter(const std::string &elem = "normal");
  virtual ~KTextFormatter();

  /// the language element represented by this formatter
  const std::string &getElem() const { return elem_; }
  void setElem(const std::string &e) { elem_ = e; }

  inline void setSyntaxHighlighter(KSyntaxHighlighter *syntaxHighlighter) {
    id old = syntaxHighlighter_;
    syntaxHighlighter_ = [syntaxHighlighter retain];
    if (old) [old release];
  }
  
  /// Set the style of this formatter
  void setStyle(srchilite::StyleConstantsPtr style);
  inline NSDictionary *textAttributes() { return textAttributes_; }

  void setForegroundColor(const std::string &color);
  void setForegroundColor(NSColor *color);
  NSColor *foregroundColor();

  void setBackgroundColor(const std::string &color);
  void setBackgroundColor(NSColor *color);
  NSColor *backgroundColor();

  /**
   * Formats the passed string.
   *
   * @param the string to format
   * @param params possible additional parameters for the formatter
   */
  void format(const std::string &s,
              const srchilite::FormatterParams *params = 0);
};

/// shared pointer for KTextFormatter
typedef boost::shared_ptr<KTextFormatter> KTextFormatterPtr;

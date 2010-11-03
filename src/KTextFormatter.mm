#import "KTextFormatter.h"
#import "KSyntaxHighlighter.h"
#include <srchilite/formatterparams.h>

KTextFormatter::KTextFormatter(const std::string &elem) : elem_(elem)
                                                    , syntaxHighlighter_(NULL) {
}

KTextFormatter::~KTextFormatter() {
  if (syntaxHighlighter_) {
    [syntaxHighlighter_ release];
    syntaxHighlighter_ = nil;
  }
}


void KTextFormatter::setStyle(srchilite::StyleConstantsPtr style) {
  // TODO implementation
  /*if (styleconstants.get()) {
    for (StyleConstantsIterator it = styleconstants->begin(); it
         != styleconstants->end(); ++it) {
      switch (*it) {
        case ISBOLD:
          formatter->setBold(true);
          break;
        case ISITALIC:
          formatter->setItalic(true);
          break;
        case ISUNDERLINE:
          formatter->setUnderline(true);
          break;
        case ISFIXED:
          formatter->setMonospace(true);
          break;
        case ISNOTFIXED:
          formatter->setMonospace(false);
          break;
        case ISNOREF:
          break;
      }
    }
  }*/
}


void KTextFormatter::setTextColor(const std::string &color) {
  // TODO implementation
  NSLog(@"TODO %s", __PRETTY_FUNCTION__);
}

void KTextFormatter::setBackgroundColor(const std::string &color) {
  // TODO implementation
  NSLog(@"TODO %s", __PRETTY_FUNCTION__);
}


/**
 * Formats the passed string.
 *
 * @param the string to format
 * @param params possible additional parameters for the formatter
 */
void KTextFormatter::format(const std::string &s,
                            const srchilite::FormatterParams *params) {
  //syntaxHighlighter_->formatString(params->start, s.size(), textFormat);
  NSLog(@"s='%s', elem='%s'", s.c_str(), elem_.c_str());
}

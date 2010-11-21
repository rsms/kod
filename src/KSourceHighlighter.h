#ifndef K_SOURCE_HIGHLIGHTER_H_
#define K_SOURCE_HIGHLIGHTER_H_

#import "common.h"

#include <stack>
#include <sstream>
#include <boost/shared_ptr.hpp>
#import "HUnorderedMap.h"
#import "KTextStorage.h"

#include <srchilite/eventgenerator.h>
#include <srchilite/highlightstate.h>

class KSourceHighlighter;
@class KSourceHighlightState, KStyle;

namespace srchilite {
class FormatterManager;
class LangDefManager;
struct HighlightToken;
struct FormatterParams;
class HighlightEventListener;
struct HighlightEvent;
}

typedef std::stack<srchilite::HighlightStatePtr> KHighlightStateStack;
typedef boost::shared_ptr<KHighlightStateStack> KHighlightStateStackPtr;
typedef boost::shared_ptr<KSourceHighlighter> KSourceHighlighterPtr;

// map { state id -> KSourceHighlightState* }
typedef HUnorderedMapObjC<unsigned int> KSourceHighlightStateMap;

// NSAttributedString attribute reflecting a srchilite::HighlightState
extern NSString * const KSourceHighlightStateAttribute;

/**
 * The main class performing the highlighting of a single line.
 * It relies on a HighlightState (and its HighlightRule objects).
 *
 * It provides the method highlightParagraph() to highlight a single line.
 *
 * The current highlighting state can be retrieved with getCurrentState().
 *
 * The highlighting state is not reset after highlighting a line, thus, the
 * same object can be used to highlight, for instance, an entire file, by
 * calling highlightParagraph on each line.
 */
class KSourceHighlighter {
  
  // ---------------------------------------

  /// the main (and initial) highlight state
  srchilite::HighlightStatePtr mainHighlightState_;
  
  /// the current highlight state
  srchilite::HighlightStatePtr currentHighlightState_;
  //KSourceHighlightState *currentHighlightState_;
  
  /// the stack for the highlight states
  KHighlightStateStackPtr stateStack;
  
  /// Additional parameters for the formatters
  srchilite::FormatterParams *formatterParams;
  
  /// interned string used for cache lookup etc.
  NSString const *langId_;
  
  /// Maps state id -> KSourceHighlightState instances
  KSourceHighlightStateMap sourceHighlightStateMap_;
  
  /**
   * Enters a new state (using the stack)
   * @param state
   */
  void enterState(srchilite::HighlightStatePtr state);
  
  /**
   * Exits level states (-1 means exit all states)
   * @param level
   */
  void exitState(int level);
  
  /**
   * Exits all states in the stack (and thus go back to the initial main state)
   */
  void exitAll();
  
  /**
   * Computes the (possible) next state for the given rule (if required, also
   * performs reference replacement)
   * @param token
   */
  srchilite::HighlightStatePtr getNextState(
      const srchilite::HighlightToken &token);
  
  
  /**
   * Makes sure to flush the possible buffer of the current element
   * (e.g., during optimizations)
   */
  void flush();
  
  /**
   * Replace state and clear the stack if needed.
   * Returns true if state changed.
   */
  bool setState(const srchilite::HighlightStatePtr &newState);
  
  // -----------------------------
  // highlighting support
  
  KTextStorage *textStorage_; // weak
  KStyle *style_; // weak
  NSString *text_; // weak
  NSRange fullRange_;
  std::string *paragraph_; // weak
  bool paragraphIsMultibyte_;
  bool receivedWillHighlight_;
  
  NSMutableArray *attributesBuffer_;
  
  // current matched range
  NSRange matchRange_;
  
  void highlightLine(std::string::const_iterator &paragraphStart,
                     std::string::const_iterator &start,
                     std::string::const_iterator &end,
                     srchilite::MatchingParameters &mParams);
  
  NSRange calcOptimalRange(NSRange editedRange);
  id rangeOfLangElement(NSUInteger index, NSRange &range);
  
  inline NSRange matchUnicodeRange() {
    if (paragraphIsMultibyte_) {
      return [NSString UTF16RangeFromUTF8Range:matchRange_
                                  inUTF8String:paragraph_->data()
                                      ofLength:paragraph_->size()];
    } else {
      return matchRange_;
    }
  }
  
 public:
  
  /**
   * @param mainState the main and initial state for highlighting
   */
  KSourceHighlighter();
  ~KSourceHighlighter();
  
  bool setLanguage(NSString const *langId, NSURL *url=NULL);
  
  /**
   * Highlights a paragraph (a line actually)
   * @param paragraph
   */
  void format(const std::string &elem);
  
  /**
   * Clears the statck of states
   */
  void clearStateStack();
  
  bool beginBufferingOfAttributes();
  void bufferAttributes(NSDictionary *attrs, NSRange range);
  void endFlushBufferedAttributes(NSTextStorage *textStorage);
  
  srchilite::HighlightStatePtr getMainState() const {
    return mainHighlightState_;
  }
  
  void setFormatterParams(srchilite::FormatterParams *p) {
    formatterParams = p;
  }
  
  // ---------------------------------------------------------------
  
  void willHighlight(NSTextStorage *textStorage, NSRange editedRange);
  void highlight(NSTextStorage *textStorage, KStyle *style, NSRange editRange);
};

#endif K_SOURCE_HIGHLIGHTER_H_

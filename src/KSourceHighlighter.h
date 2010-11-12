#ifndef K_SOURCE_HIGHLIGHTER_H_
#define K_SOURCE_HIGHLIGHTER_H_

#import "common.h"

#include <stack>
#include <sstream>
#include <boost/shared_ptr.hpp>

#include <srchilite/highlightstate.h>
#include <srchilite/eventgenerator.h>

@class KSyntaxHighlighter;

namespace srchilite {
class FormatterManager;
struct HighlightToken;
struct FormatterParams;
class HighlightEventListener;
struct HighlightEvent;
}

typedef std::stack<srchilite::HighlightStatePtr> KHighlightStateStack;
typedef boost::shared_ptr<KHighlightStateStack> KHighlightStateStackPtr;

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
class KSourceHighlighter :
    public srchilite::EventGenerator<srchilite::HighlightEventListener,
                                     srchilite::HighlightEvent> {
  /// Parent highlighter
  __weak KSyntaxHighlighter *syntaxHighlighter_;

  /// the main (and initial) highlight state
  srchilite::HighlightStatePtr mainHighlightState;
  
  /// the current highlight state
  srchilite::HighlightStatePtr currentHighlightState;
  
  /// the stack for the highlight states
  KHighlightStateStackPtr stateStack;
  
  /// the formatter manager, used to format element strings
  // TODO: remove this -- we don't need or use it
  const srchilite::FormatterManager *formatterManager;
  
  /**
   * Whether formatting is currently suspended.  Note that matching for
   * regular expressions is not suspended: only the actual output of formatted
   * code is suspended.
   */
  bool suspended;
  
  /**
   * Additional parameters for the formatters
   */
  srchilite::FormatterParams *formatterParams;
  
  /**
   * The current element being formatted (used for optmization and buffering)
   */
  std::string currentElement;
  
  /**
   * The buffer for the text for the current element
   */
  std::ostringstream currentElementBuffer;
  
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
  srchilite::HighlightStatePtr
  getNextState(const srchilite::HighlightToken &token);
  
  /**
   * Formats the given string as the specified element
   * @param elem
   * @param s
   */
  void format(const std::string &elem, const std::string &s);
  
  /**
   * Makes sure to flush the possible buffer of the current element
   * (e.g., during optimizations)
   */
  void flush();
  
 public:
  /**
   * @param mainState the main and initial state for highlighting
   */
  KSourceHighlighter(srchilite::HighlightStatePtr mainState,
                     KSyntaxHighlighter *syntaxHighlighter);
  ~KSourceHighlighter();
  
  /**
   * Highlights a paragraph (a line actually)
   * @param paragraph
   */
  void highlightParagraph(const std::string &paragraph);
  
  srchilite::HighlightStatePtr getCurrentState() const {
    return currentHighlightState;
  }
  
  void setCurrentState(srchilite::HighlightStatePtr state) {
    currentHighlightState = state;
  }
  
  KHighlightStateStackPtr getStateStack() {
    return stateStack;
  }
  
  void setStateStack(KHighlightStateStackPtr state) {
    stateStack = state;
  }
  
  /**
   * Clears the statck of states
   */
  void clearStateStack();
  
  srchilite::HighlightStatePtr getMainState() const {
    return mainHighlightState;
  }
  
  // TODO: remove
  const srchilite::FormatterManager *getFormatterManager() const {
    return formatterManager;
  }
  
  // TODO: remove
  void setFormatterManager(const srchilite::FormatterManager *_formatterManager) {
    formatterManager = _formatterManager;
  }
  
  void setFormatterParams(srchilite::FormatterParams *p) {
    formatterParams = p;
  }
  
  bool isSuspended() const {
    return suspended;
  }
  
  void setSuspended(bool b = true) {
    suspended = b;
  }
};

#endif K_SOURCE_HIGHLIGHTER_H_

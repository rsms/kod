#ifndef K_SOURCE_HIGHLIGHTER_H_
#define K_SOURCE_HIGHLIGHTER_H_

#import "common.h"

#include <deque>
#include <sstream>
#include <boost/shared_ptr.hpp>
#import "HUnorderedMap.h"
#import "KTextStorage.h"
#import "HUTF8MappedUTF16String.h"

#include <srchilite/highlightstate.h>

class KSourceHighlighter;
@class KSourceHighlightState, KStyle;

namespace srchilite {
struct HighlightToken;
struct FormatterParams;
}

typedef std::deque<srchilite::HighlightStatePtr> KHighlightStateStack;
typedef boost::shared_ptr<KHighlightStateStack> KHighlightStateStackPtr;
typedef boost::shared_ptr<KSourceHighlighter> KSourceHighlighterPtr;

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
  KHighlightStateStackPtr stateStack_;

  /// Additional parameters for the formatters
  srchilite::FormatterParams *formatterParams;

  /// interned string used for cache lookup etc.
  NSString const *langId_;

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
  bool setMainState(const srchilite::HighlightStatePtr &newState);

  // set current state from a KSourceHighlightState object
  void setCurrentState(KSourceHighlightState *state);

  inline void resetState() {
    currentHighlightState_ = mainHighlightState_;
    clearStateStack();
  }

  // -----------------------------

  KTextStorage *textStorage_; // weak
  KStyle *style_; // weak
  NSString *text_; // weak
  NSRange fullRange_;
  NSRange highlightRange_;
  bool paragraphIsMultibyte_;
  bool isCancelled_;
  HUTF8MappedUTF16String mappedString_;
  int stateDepthDelta_;
  //bool receivedWillHighlight_;
  int changeInLength_;

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
    NSRange range;
    if (paragraphIsMultibyte_) {
      //return mappedString_.UTF16RangeForUTF8Range(matchRange_);
      return mappedString_.unsafeUTF16RangeForUTF8Range(matchRange_);
      //range = [NSString UTF16RangeFromUTF8Range:matchRange_
      //                             inUTF8String:paragraph_->data()
      //                                 ofLength:paragraph_->size()];
    } else {
      range = matchRange_;
    }

    // idea: keep state on UTF8 range offset since we know that formatting is
    // unidirectional, thus we always get called for a "next substring".

    // convert/offset to textStorage_'s space
    range.location += highlightRange_.location;
    return range;
  }

  inline KSourceHighlightState *stateAtIndex(NSUInteger index) {
    return [textStorage_ attribute:KSourceHighlightStateAttribute
                           atIndex:index
                    effectiveRange:NULL];
  }

  inline KSourceHighlightState *stateAtIndex(NSUInteger index,
                                             NSRangePointer effectiveRange) {
    return [textStorage_ attribute:KSourceHighlightStateAttribute
                           atIndex:index
                    effectiveRange:effectiveRange];

    //return [textStorage_ attribute:KSourceHighlightStateAttribute
    //                       atIndex:index
    //         longestEffectiveRange:effectiveRange
    //                       inRange:fullRange_];

    //NSUInteger index = selectedRange.location;
    //if (index >= textStorage.length) index = textStorage.length-1;
    //NSDictionary *attrs = [textStorage attributesAtIndex:index
    //                                      effectiveRange:&selectedRange];
  }

  void highlightPass(bool beginningOfLine);

  // advances |highlightRange_| to the end of itself and sets length to
  // zero. Returns false if end of fullRange_ was hit (meaning there's no
  // more ranges after the current range).
  inline bool advanceHighlightRange() {
    highlightRange_.location += highlightRange_.length;
    highlightRange_.length = 0;
    if (highlightRange_.location >= fullRange_.length) {
      highlightRange_.location = fullRange_.length-1;
      return false;
    }
    return true;
  }

  // Find offset of newline(s)
  inline NSUInteger findNewlineOffset(NSUInteger offset, int nlsToFind) {
    while (nlsToFind--) {
      static NSUInteger bufsize = 1024;
      unichar buf[bufsize];
      NSRange searchRange =
          NSMakeRange(offset, MIN(fullRange_.length-offset, bufsize));
      [text_ getCharacters:buf range:searchRange];
      unichar *bufp = buf;
      while (*bufp++ != '\n') {
        if (searchRange.length-- == 0) {
          // if we hit the end of string, reverse one char and break
          bufp--;
          offset += bufp-buf;
          return offset;
        }
      }
      offset += bufp-buf;
    }
    return offset-1;
  }

 public:

  /**
   * @param mainState the main and initial state for highlighting
   */
  KSourceHighlighter();
  ~KSourceHighlighter();

  bool setLanguage(NSString const *langId, NSURL *url=NULL);

  // apply formatting
  void format(const std::string &elem);

  // Clears the stack of states
  void clearStateStack();

  // Attribute buffering
  bool beginBufferingOfAttributes();
  void bufferAttributes(NSDictionary *attrs, NSRange range);
  void endFlushBufferedAttributes(NSTextStorage *textStorage);
  void clearBufferedAttributes();

  // cancellation
  inline bool isCancelled() { return isCancelled_; }
  inline bool resetCancelled() {
    OSMemoryBarrier();
    isCancelled_ = false;
  }
  inline void cancel() {
    OSMemoryBarrier();
    isCancelled_ = true;
  }

  // Range currently being highlighted
  inline NSRange currentRange() { return highlightRange_; }

  // Change length delta for the current highlight process
  inline int currentChangeInLength() { return changeInLength_; }

  // Syntax state
  srchilite::HighlightStatePtr getMainState() const {
    return mainHighlightState_;
  }

  void setFormatterParams(srchilite::FormatterParams *p) {
    formatterParams = p;
  }

  inline uint32_t currentStateHash() {
    uint32_t hash = currentHighlightState_->getId();
    if (!stateStack_->empty()) {
      KHighlightStateStack::reverse_iterator rit = stateStack_->rbegin(),
                                             rend = stateStack_->rend();
      while (rit != rend) {
        hash = (*(rit++))->getId() + (hash << 6) + (hash << 16) - hash;
      }
    }
    return hash;
  }

  // ---------------------------------------------------------------

  //void willHighlight(NSTextStorage *textStorage, NSRange editedRange);
  NSRange highlight(NSTextStorage *textStorage, KStyle *style, NSRange inRange,
                    KSourceHighlightState *editedHighlightState,
                    NSRange editedHighlightStateRange, int changeInLength);
};

#endif K_SOURCE_HIGHLIGHTER_H_

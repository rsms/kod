#import "KSourceHighlighter.h"
#import "KLangMap.h"
#import "KLangRegexRuleFactory.h"
#import "KLangSymbol.h"
#import "KLangManager.h"
#import "KStyle.h"
#import "KSourceHighlightState.h"
#import "KRUsage.hh"
#import "kconf.h"
#import "common.h"

#import <iterator>

#include <srchilite/highlighttoken.h>
#include <srchilite/matchingparameters.h>
#include <srchilite/highlightrule.h>
#include <srchilite/formatterparams.h>

// toggle debug logging of highlighting
#define DEBUG_HL 0
#if DEBUG_HL
  #define DLOG_HL DLOG
#else
  #define DLOG_HL(...) ((void)0)
#endif

using namespace std;
using namespace srchilite;

typedef std::string::const_iterator str_const_iterator;

/// represents highlighting as default
static HighlightToken defaultHighlightToken;

/// Language { langId -> highlighter }
typedef HUnorderedMap<NSString const*, HighlightStatePtr>
        HighlightStateCacheMap;
static HighlightStateCacheMap g_state_cache;
static HSemaphore g_state_cache_sem(1); // 1=unlocked, 0=locked
static HighlightStatePtr g_empty_state;

// Global highlight state+stack cache
// map { state+stack hash -> KSourceHighlightState* }
typedef HUnorderedMapObjC<uint32_t> StateStackCacheType;
static StateStackCacheType g_statestack_cache;

/// Runtime constructor
__attribute__((constructor)) static void __init() {
  g_empty_state = HighlightStatePtr(new HighlightState);
}


KSourceHighlighter::KSourceHighlighter()
    : langId_(nil)
    , stateStack_(KHighlightStateStackPtr(new KHighlightStateStack))
    , formatterParams(0)
    , textStorage_(nil)
    , style_(nil)
    , text_(nil)
    , attributesBuffer_(nil)
    , paragraphIsMultibyte_(false) {
  mainHighlightState_ = g_empty_state;
  currentHighlightState_ = g_empty_state;
}

KSourceHighlighter::~KSourceHighlighter() {
}


bool KSourceHighlighter::setLanguage(NSString const *langId, NSURL *url) {
  h_objc_xch(&langId_, langId);

  // no language?
  if (!langId) {
    return setMainState(g_empty_state);
  }

  // avoid race conditions where multiple threads load the same language file
  HSemaphore::Scope sem_scope(g_state_cache_sem);

  // locate any cached language state tree
  HighlightStateCacheMap::iterator it = g_state_cache.find(langId);
  if (it != g_state_cache.map().end()) {
    // found one
    return setMainState(it->second);
  }

  // Find URL for this langId
  if (!url) {
    if (!(url = [[KLangMap sharedLangMap] langFileURLForLangId:langId])) {
      // no known definition file
      g_state_cache.insert(langId, g_empty_state);
      return setMainState(g_empty_state);
    }
  }

  // we currently only support local files
  kassert([url isFileURL]);

  // Load state
  NSString *path = [[url absoluteURL] path];
  NSString *dirname = [path stringByDeletingLastPathComponent];
  NSString *basename = [path lastPathComponent];
  HighlightStatePtr state =
      KLangManager::buildHighlightState([dirname UTF8String],
                                        [basename UTF8String]);

  // put into cache and assign state
  g_state_cache.insert(langId, state);
  return setMainState(state);
}


#define APPLY_FORMAT(elemstr, toksize) \
  [syntaxHighlighter_ setStyleForElementOfType: \
      KLangSymbol::symbolForString(elemstr) \
      inUTF8Range:NSMakeRange(formatterParams->start, (toksize))]

HighlightStatePtr KSourceHighlighter::getNextState(const HighlightToken &token) {
  HighlightStatePtr nextState = token.rule->getNextState();

  if (token.rule->isNested()) {
    // we must enter another instance of the current state
    nextState = currentHighlightState_;
  }

  if (nextState.get() && nextState->getNeedsReferenceReplacement()) {
    // perform replacement for the next state
    // in case use the original state
    if (nextState->getOriginalState().get()) {
      // in case we had already performed replacements on the next state
      nextState = nextState->getOriginalState();
    }

    HighlightStatePtr copyState =
        HighlightStatePtr(new HighlightState(*nextState));
    copyState->setOriginalState(nextState);
    copyState->replaceReferences(token.matchedSubExps);
    return copyState;
  }

  return nextState;
}

void KSourceHighlighter::enterState(HighlightStatePtr state) {
  DLOG_HL("enterState: %d %s",
          state->getId(), state->getDefaultElement().c_str());
  stateStack_->push_back(currentHighlightState_);
  currentHighlightState_ = state;
}

/**
 * Exits level states
 * @param level
 */
void KSourceHighlighter::exitState(int level) {
  DLOG_HL("exitState: %d %s", currentHighlightState_->getId(),
          currentHighlightState_->getDefaultElement().c_str());

  // remove additional levels
  for (int l = 1; l < level; ++l) {
    HighlightStatePtr state = stateStack_->back();
    DLOG_HL("exitState: %d %s", state->getId(),
            state->getDefaultElement().c_str());
    stateStack_->pop_back();
  }
  currentHighlightState_ = stateStack_->back();
  stateStack_->pop_back();
}

void KSourceHighlighter::exitAll() {
  currentHighlightState_ = mainHighlightState_;
  clearStateStack();
}

void KSourceHighlighter::clearStateStack() {
  while (!stateStack_->empty())
    stateStack_->pop_back();
}

bool KSourceHighlighter::setMainState(const HighlightStatePtr &newState) {
  if (mainHighlightState_ != newState) {
    mainHighlightState_ = newState;
    currentHighlightState_ = newState;
    clearStateStack();
    return true;
  }
  return false;
}

void KSourceHighlighter::setCurrentState(KSourceHighlightState *state) {
  if (!state) return;
  currentHighlightState_ = state->highlightState;
  // shallow copy-in stack
  stateStack_ = KHighlightStateStackPtr(
      new KHighlightStateStack( *(state->stateStack) ));
  /*
      srchilite::HighlightStateStack *stateStack =
      new srchilite::HighlightStateStack(*(currentState_->data->stateStack));
    sourceHighlighter_->setCurrentState(currentState_->data->currentState);
    sourceHighlighter_->setStateStack(srchilite::HighlightStateStackPtr(stateStack));*/
}

// --------------------------------------------------------------------------


NSString * const KSourceHighlightStateAttribute = @"KHighlightState";



bool KSourceHighlighter::beginBufferingOfAttributes() {
  h_objc_swap(&attributesBuffer_, [NSMutableArray new]);
}

void KSourceHighlighter::bufferAttributes(NSDictionary* attrs, NSRange range) {
  [attributesBuffer_ addObject:attrs];
  [attributesBuffer_ addObject:[NSValue valueWithRange:range]];
}

void KSourceHighlighter::endFlushBufferedAttributes(NSTextStorage *textStorage) {
  NSUInteger i, count = attributesBuffer_.count;
  kassert(textStorage != nil || textStorage_ != nil);
  if (!textStorage) textStorage = textStorage_;
  for (i = 0; i < count; i += 2) {
    NSDictionary *attrs = [attributesBuffer_ objectAtIndex:i];
    NSRange range = [[attributesBuffer_ objectAtIndex:i+1] rangeValue];
    [textStorage setAttributes:attrs range:range];
  }
  h_objc_swap(&attributesBuffer_, nil);
}

void KSourceHighlighter::clearBufferedAttributes() {
  h_objc_swap(&attributesBuffer_, nil);
}


void KSourceHighlighter::format(const std::string &elem) {
  if (isCancelled()) return;
  NSString const *typeSymbol = KLangSymbol::symbolForString(elem);
  NSRange range = matchUnicodeRange();
  uint32_t stateHash = currentStateHash();

  // lookup state+stack entry in global cache
  KSourceHighlightState *state = g_statestack_cache.getSync(stateHash);
  if (!state) {
    // shallow copy-out stack
    KHighlightStateStack *stackCopy = new KHighlightStateStack(*(stateStack_));
    state = [[KSourceHighlightState alloc]
             initWithHighlightState:currentHighlightState_
                         stateStack:KHighlightStateStackPtr(stackCopy)];
    g_statestack_cache.putSync(stateHash, state);
    [state release];
    //DLOG("g_statestack_cache MISS for %d %@", stateHash, state);
  } //else DLOG("g_statestack_cache HIT for %d %@", stateHash, state);

  // build text attributes
  NSDictionary *attrs;
  if (style_) {
    // FIXME: NSDictionary COPIES it's keys, making this a slow operation
    KStyleElement *styleElement = [style_ styleElementForSymbol:typeSymbol];
    attrs = [styleElement->textAttributes() mutableCopy];
    [(NSMutableDictionary*)attrs setObject:state
                                    forKey:KSourceHighlightStateAttribute];
  } else {
    attrs = [NSDictionary dictionaryWithObject:state
                                        forKey:KSourceHighlightStateAttribute];
  }

  // set attributes
  if (attributesBuffer_) {
    bufferAttributes(attrs, range);
  } else {
    [textStorage_ setAttributes:attrs range:range];
  }

  #if 0
  DLOG("KSourceHighlighter::format(<%@>, %@, '%@') <-- %@", typeSymbol,
       NSStringFromRange(range), [text_ substringWithRange:range], attrs);
  #endif
}



void KSourceHighlighter::highlightLine(str_const_iterator &paragraphStart,
                                       str_const_iterator &start,
                                       str_const_iterator &end,
                                       MatchingParameters &mParams) {
  //DLOG("line> '%s'", std::string(start, end).c_str());
  str_const_iterator location = start;
  bool matched = true;
  HighlightToken token;

  // note that we go on even if the string is empty, since it is crucial
  // to try to match also the end of buffer (some rules rely on that)
  while (matched && !isCancelled()) {
    matched =
        currentHighlightState_->findBestMatch(location, end, token, mParams);
    if (isCancelled())
      break;
    if (matched) {
      // format any prefix
      if (token.prefix.size()) {
        // this is the index in the paragraph of the matched part
        matchRange_.location = std::distance(paragraphStart, location);
        matchRange_.length = token.prefix.size();
        // format non matched part with the current state's default element
        //format(currentHighlightState_->getDefaultElement(), token.prefix);
        //APPLY_FORMAT(currentHighlightState_->getDefaultElement(),
        //             token.prefix.size());
        format(currentHighlightState_->getDefaultElement());
      }

      // the length of the previous matched string in the matched elem list
      int prevLen = 0;

      // now format the matched strings
      for (MatchedElements::const_iterator it = token.matched.begin();
           it != token.matched.end(); ++it) {

        // update match range
        matchRange_.location = std::distance(paragraphStart, location) +
                               token.prefix.size() + prevLen;
        matchRange_.length = it->second.size();

        // format lang element
        format(it->first);

        // advance prevLen
        prevLen += it->second.size();
      }

      // now we're not at the beginning of line anymore, if we matched some chars
      if (token.matchedSize)
        mParams.beginningOfLine = false;

      // check whether we must enter a new state
      HighlightStatePtr nextState = getNextState(token);
      if (nextState.get()) {
        enterState(nextState);
      } else if (token.rule->getExitLevel()) {
        // the rule requires to exit some states
        if (token.rule->getExitLevel() < 0) {
          exitAll();
        } else {
          exitState(token.rule->getExitLevel());
        }
      }

      // advance in the string, so that the part not matched
      // can be highlighted in the next loop
      location += (token.prefix.size() + token.matchedSize);
    } else {
      // no rule matched, so we highlight it with the current state's default element
      // provided the string is not empty (if it is empty this is really useless)
      matchRange_.length = end - location;
      if (matchRange_.length) {
        // this is the index in the paragraph of the matched part
        matchRange_.location = std::distance(paragraphStart, location);
        format(currentHighlightState_->getDefaultElement());
      }
    }

  } // while (matched)
}



// called _before_ an edit is committed
/*void KSourceHighlighter::willHighlight(NSTextStorage *textStorage,
                                       NSRange editedRange) {
  // update instance-locals
  textStorage_ = [textStorage retain];
  text_ = [[textStorage_ string] retain];
  fullRange_ = NSMakeRange(0, textStorage_.length);
  receivedWillHighlight_ = true;

  // normalize a full range to a special-meaning NSNotFound "everything" range
  if (editedRange.location == 0 && editedRange.length == fullRange_.length) {
    editedRange.location = NSNotFound;
  }

  if (editedRange.location != NSNotFound) {
    // find KSourceHighlightStateAttribute
    fprintf(stderr, "------------------ willHighlight ------------------\n");
    NSRange effectiveRange;
    NSUInteger index = MIN(editedRange.location, fullRange_.length-1);
    KSourceHighlightState* attrValue =
        [textStorage attribute:KSourceHighlightStateAttribute
                       atIndex:index
         longestEffectiveRange:&effectiveRange
                       inRange:fullRange_];
    DLOG_RANGE(effectiveRange, text_);
    DLOG("highlight state at edited index: %@", attrValue);
    // TODO: save info to be used by |highlight|
  }
}*/


// this method is called when an edit was detected in |textStorage| or when
// |textStorage| should be completely re-highlighted.
NSRange KSourceHighlighter::highlight(NSTextStorage *textStorage,
                                      KStyle *style,
                                      NSRange editedRange,
                                    KSourceHighlightState *editedHighlightState,
                                      NSRange editedHighlightStateRange,
                                      int changeInLength) {
  #if !NDEBUG && DEBUG_HL
  fprintf(stderr, "------------------ highlight ------------------\n");
  #endif

  // simulate slowness
  //sleep(2);

  // update instance-locals
  kassert(textStorage != nil);
  fullRange_ = NSMakeRange(0, textStorage.length);
  if (fullRange_.length == 0) {
    DLOG_HL("textStorage.length == 0 -- returning directly");
    return fullRange_;
  }

  //kassert(textStorage_ == nil);
  if (textStorage_) [textStorage_ autorelease];
  if (text_) [text_ autorelease];
  textStorage_ = [textStorage retain];
  text_ = [[textStorage_ string] retain];
  changeInLength_ = changeInLength;
  resetCancelled();

  // Hold on to the style
  style_ = [style retain];

  // Range of restored state
  NSRange restoredStateRange = {NSNotFound,0};

  // Effective length of edit (negative for deletions, positive for additions)
  bool beginningOfLine = true;

  // convert editedHighlightStateRange to contain the edit which has occured
  if (editedHighlightState)
    editedHighlightStateRange.length += changeInLength_;

  // A edit range location of NSNotFound means "highlight everything"
  //DLOG("editedRange %@", NSStringFromRange(editedRange));
  if (editedRange.location == NSNotFound) {
    highlightRange_ = fullRange_;
    resetState();
  } else {
    // expand editedRange to span full lines
    highlightRange_ = [text_ lineRangeForRange:editedRange];

    // find any state at our starting point
    //NSUInteger index = MIN(highlightRange_.location, fullRange_.length-1);
    if (highlightRange_.location >= fullRange_.length) {
      // warning: underlying text storage might have changed since we got called
      highlightRange_.location = fullRange_.length-1;
      //return {NSNotFound, 0};
    }
    KSourceHighlightState *state = stateAtIndex(highlightRange_.location,
                                                &restoredStateRange);

    //DLOG_RANGE(highlightRange_, text_);
    DLOG_HL("highlight state at starting point {%u}: %@", highlightRange_.location,
            state);
    //DLOG_RANGE(restoredStateRange, text_);

    // set or reset state
    if (state) {
      setCurrentState(state);
    } else {
      resetState();
    }
  }

  // Union of all ranges we did highlight
  NSRange highlightedRanges = highlightRange_;

  // ad-hoc set on one >1 pass to reference the expected exit state
  KSourceHighlightState *expectedExitState = nil;
  BOOL didTryToFindExpectedExitState = NO;

  // this is used to know if we have tried to expand our search based on
  // editedHighlightState.
  BOOL hasPassedEditedHighlightState = NO;

  // deletion
  if (changeInLength_ < 0) {
    DLOG_HL("[DELETE] editedHighlightState => %@", editedHighlightState);
    expectedExitState = editedHighlightState;
    didTryToFindExpectedExitState = YES;
  } else {
    DLOG_HL("[INSERT/REPLACE]");
  }

  // Save a local reference to the initial state
  srchilite::HighlightStatePtr entryState = currentHighlightState_;
  int passCount = 0;

  long long stackSizeAtStart = stateStack_->size();

  while (++passCount && !isCancelled()) {
    DLOG_HL("highlightPass()");
    #if DEBUG_HL
    DLOG_RANGE(highlightRange_, text_);
    #endif

    long long stackSizeBeforeMakingPass = stateStack_->size();

    // make one highlight pass
    highlightPass(beginningOfLine);

    // end of text_?
    if (isCancelled() ||
        highlightRange_.location + highlightRange_.length
            >= fullRange_.length) {
      break;
    }

    // stack size deltas
    long long stackSizeOfEditedState = -1;
    if (editedHighlightState)
      stackSizeOfEditedState = editedHighlightState->stateStack->size();
    long long stackSizeAfterMakingPass = stateStack_->size();
    long long editedToExitStackSizeDelta =
        stackSizeAfterMakingPass - stackSizeOfEditedState;

    // debug logging
    DLOG_HL("## stack size delta: (pass: %lld, edit: %lld, start: %lld) -- edit type: %s",
            stackSizeAfterMakingPass - stackSizeBeforeMakingPass,
            stackSizeAfterMakingPass - stackSizeOfEditedState,
            stackSizeAfterMakingPass - stackSizeAtStart,
            changeInLength_<0?"delete":"insert");
    DLOG_HL("## entry state: %d, edited state: %d, end state: %d",
            entryState->getId(),
            editedHighlightState ? editedHighlightState->highlightState->getId() : -1,
            currentHighlightState_->getId());

    // logic test 1
    bool shouldLookFurther = false;
    NSUInteger highlightRangeEnd;

    if (editedHighlightState &&
        editedHighlightState->highlightState->getId()
        != currentHighlightState_->getId()) {
      // case: edited state was broken in some aspect (finalized, expanded or reduced)
      if (changeInLength_ < 1) { // is delete
        // state was expanded
        if (editedToExitStackSizeDelta > 0) {
          // state was not finalized
          shouldLookFurther = true;

          // advance highlightRange_
          if (!advanceHighlightRange()) {
            // end of text
            DLOG_HL("END OF TEXT[2] -- bailing");
            break;
          }
          highlightRangeEnd = highlightRange_.location + highlightRange_.length;
          // note: further down we will expand highlightRange_ to next line end
        } else {
          // state was finalized
          shouldLookFurther = false;
          if (editedHighlightState) {
            //DLOG_HL("editedHighlightState:");
            //DLOG_RANGE(editedHighlightStateRange, text_);
            NSUInteger editedHighlightStateRangeEnd =
                editedHighlightStateRange.location +
                editedHighlightStateRange.length;
            highlightRangeEnd = highlightRange_.location + highlightRange_.length;
            if (editedHighlightStateRangeEnd > highlightRangeEnd) {
              highlightRange_.length +=
                  editedHighlightStateRangeEnd - highlightRangeEnd;
              if (highlightRange_.length+highlightRange_.location > fullRange_.length) {
                highlightRange_.length -=
                    ((highlightRange_.length+highlightRange_.location) -
                     fullRange_.length);
              }
              shouldLookFurther = true;
            }
          }
        }
      } else { // is insert
        // state was reduced -- evaluate reminder of the edited state
        shouldLookFurther = true;

        // if insert and stack delta < 0 then only evaluate editedStateRange
        /*if ( hasPassedEditedHighlightState
             //&& expectedExitState
             //&& (expectedExitState->highlightState->getId() ==
             //   currentHighlightState_->getId())
            ) {
          DLOG_HL("met expected exit state derived from previous block");
          break;
        }*/

        if (editedToExitStackSizeDelta == 0) {
          DLOG_HL("editedToExitStackSizeDelta is zero -- clean exit");
          break;
        }

        if ((stackSizeAfterMakingPass - stackSizeAtStart) == 0) {
          if (entryState->getId() == currentHighlightState_->getId()) {
            DLOG_HL("entryToExitStackSizeDelta is zero and entryToExit state is"
                    " nominal -- clean exit");
            break;
          } else {
            DLOG_HL("entryToExitStackSizeDelta is zero, but entryToExit state"
                    " differ");
          }
        }

        // advance
        if (!advanceHighlightRange()) {
          // end of text
          DLOG_HL("END OF TEXT[3] -- bailing");
          break;
        }
        highlightRangeEnd = highlightRange_.location + highlightRange_.length;

        if (!hasPassedEditedHighlightState) {
          // expand highlightRange_ to contain the reminder of edited highlight
          // state
          NSUInteger editedHighlightStateRangeEnd =
              editedHighlightStateRange.location +
              editedHighlightStateRange.length;
          if (editedHighlightStateRangeEnd > highlightRangeEnd) {
            highlightRange_.length +=
                editedHighlightStateRangeEnd - highlightRangeEnd;
          }
          highlightRangeEnd = highlightRange_.location + highlightRange_.length;

          // find expected exit state (state before editedHighlightState)
          NSUInteger prevBlockIndex = editedHighlightStateRange.location;
          if (prevBlockIndex > 0) {
            kassert(prevBlockIndex != NSNotFound);
            prevBlockIndex--;
            expectedExitState = stateAtIndex(prevBlockIndex, NULL);
          }

          hasPassedEditedHighlightState = YES;
        }
        //DLOG("new highlight range:");
        //DLOG_RANGE(highlightRange_, text_);
      }

      // debug logging (exit state != modified state)
      DLOG_HL("%s look further (state is %s)",
              shouldLookFurther ? "should" : "should NOT",
              changeInLength_<1 ? "expanding -- need to evaluate following lines"
                             : "being reduced -- need to evaluate the range"
                               " after the edit");
    }

    // debug logging
    #if DEBUG_HL
    if (expectedExitState) {
      if (currentHighlightState_ == expectedExitState->highlightState) {
        DLOG("did reach expected exit state");
      } else {
        DLOG("did NOT reach expected exit state");
      }
    }
    #endif

    //if ((stackSizeAfterMakingPass - stackSizeBeforeMakingPass) == 0) {
    if (!shouldLookFurther) {
      break;
    }

    // expand to (N=passCount) lines
    highlightRangeEnd = highlightRange_.location + highlightRange_.length;
    NSUInteger nlOffset = findNewlineOffset(highlightRangeEnd, passCount);
    highlightRange_.length += nlOffset-highlightRangeEnd;

    // next pass will start from beginning of line
    beginningOfLine = true;

    DLOG_HL("extra highlight pass commencing...");

    // add new highlight range to the union range
    highlightedRanges = NSUnionRange(highlightedRanges, highlightRange_);
  }

  // clear temporal refs
  h_objc_xch(&textStorage_, nil);
  h_objc_xch(&text_, nil);
  h_objc_xch(&style_, nil);

  // reset
  //receivedWillHighlight_ = false;

  return highlightedRanges;
}


void KSourceHighlighter::highlightPass(bool beginningOfLine) {
  // Reset matched range
  matchRange_.location = 0;
  MatchingParameters mParams;
  mParams.beginningOfLine = beginningOfLine;
  // future: set mParams.beginningOfLine = false if we are not at the beginning of
  // a line. Do this when we support highlighting of chunks smaller than whole
  // lines (right now we are always highlighting full lines).

  // make a std::string copy
  std::string paragraph;
  mappedString_.setNSString(text_, highlightRange_);
  mappedString_.convert(paragraph);
  //NSUInteger size = [text_ populateStdString:paragraph
  //                             usingEncoding:NSUTF8StringEncoding
  //                                     range:highlightRange_];
  paragraphIsMultibyte_ = (paragraph.size() != highlightRange_.length);
  DLOG_HL("paragraphIsMultibyte_ => %@", paragraphIsMultibyte_?@"YES":@"NO");

  // get start and end iterators
  str_const_iterator paragraphStart = paragraph.begin();
  str_const_iterator paragraphEnd = paragraph.end();
  str_const_iterator start = paragraphStart;
  str_const_iterator end = paragraphStart;

  // process each line
  while (!isCancelled()) {
    // fast-forward to next newline
    // TODO: Handle CR linebreaks. Currently only CRLF and LF are handled.
    while (end != paragraphEnd && *end++ != '\n') {}

    highlightLine(paragraphStart, start, end, mParams);

    if (end == paragraphEnd)
      break;
    mParams.beginningOfLine = true;
    start = end;
  };
}





id KSourceHighlighter::rangeOfLangElement(NSUInteger index, NSRange &range) {
  // Algorithm
  /* - start by looking at |index|
   * - read the attribute |KStyleElementAttributeName|
   * - if we found such an attribute
   *   - let |start| be index and move location to the left until the attribute
   *     is no longer present.
   *   - let |end| be index and move location to the right until the attribute
   *     is no longer present
   */
  return [textStorage_ attribute:KSourceHighlightStateAttribute
                         atIndex:index
           longestEffectiveRange:&range
                         inRange:fullRange_];
}


NSRange KSourceHighlighter::calcOptimalRange(NSRange editedRange) {
  // result
  NSRange highlightRange;

  // index
  NSUInteger index = editedRange.location;

  // move one character to the left of the edit, unless we are at the beginning
  if (index > 0) index--;

  // Find the effective range of which index is contained and the attribute
  // |KStyleElementAttributeName| does not change value
  rangeOfLangElement(index, highlightRange);

  highlightRange = NSUnionRange(editedRange, highlightRange);

  if (editedRange.location > 0 && editedRange.location < fullRange_.length-1) {
    index = editedRange.location + 1;
    NSRange highlightRange2;

    rangeOfLangElement(index, highlightRange2);

    highlightRange = NSUnionRange(highlightRange, highlightRange2);

    // --experimental line extension BEGIN--
    /*
     * This is the case when NOT using line extension:
     *   1. initial state:  "void foo(int a) {"
     *   2. we break "foo": "void fo o(int a) {"
     *   3. "fo o" gets re-highlighted and correctly receives the "norma"
     *      format.
     *   4. we remove the space we added to foo, thus the line become:
     *      "void foo(int a) {"
     *   5. "foo" gets re-highlighted, but since the highlighter determine
     *      element type (format) from _context_ "foo" will incorrectly
     *      receive the "body" format rather than the "function" format.
     *
     * By including the full line we ensure the highlighter will at least
     * have some context to work with. This is far from optimal and should
     * work in one of the following ways:
     *
     *   a. Expanding the range to include one different element (not
     *      counting whitespace/newlines) in each direction, thus the
     *      above use-case would include "void foo(" at step 4.
     *
     *   b. Use a special text attribute (like how state is tracked with
     *      KHighlightState) which replaces the current
     *      KStyleElementAttributeName symbol representing the
     *      format. Maybe a struct e.g:
     *
     *        KTextFormat {
     *           NSString *symbol;
     *           int numberOfPreDependants;
     *           int numberOfPostDependants;
     *        }
     *
     *      Where |numberOfPreDependants| indicates how many elements this
     *      format need to consider when being modified, then when
     *      breaking such an element (step 2. in our use-case above) the
     *      highlighter "body" the following calculation to the new
     *      format struct ("normal" in our use-case):
     *
     *        newFormat.numberOfPreDependants =
     *          MAX(newFormat.numberOfPreDependants,
     *              previousFormat.numberOfPreDependants);
     *
     *      Thus, when we later cut out the " " (space) -- as illustrated
     *      by step 4. in the above use-case -- the highlighter will look
     *      at enough context. Maybe.
     *
     * When there is time, I should probably try to implement (a.).
     * However, it's not a guarantee [find previous non-empty element,
     * find next non-empty element, highlight subrange] is a cheaper
     * operation than [find line range, highlight subrange] -- depends on
     * how element scanning is implemented I guess.
     */
    highlightRange2 = [text_ lineRangeForRange:highlightRange];
    highlightRange = NSUnionRange(highlightRange, highlightRange2);
    // skip LF
    //NSUInteger end = highlightRange.location + highlightRange.length;
    //if (end < fullRange.length && [text characterAtIndex:end] == '\n') {
    //  highlightRange.length--;
    //}
    //
    // --experimental line extension END--
    //
  }

  return highlightRange;
}


// original version:
/*void highlight(NSTextStorage *textStorage,
                                   NSRange editedRange) {
  //_textStorage = textStorage;
  NSString *text = [textStorage string];

  NSRange highlightRange;
  NSRange deltaRange = editedRange;
  NSRange fullRange = NSMakeRange(0, [textStorage length]);

  // calculate what range to highlight
  if (editedRange.location == NSNotFound ||
      (editedRange.location == 0 && editedRange.length == fullRange.length)) {
    // complete document
    highlightRange = NSMakeRange(NSNotFound, 0);
    deltaRange = highlightRange;
  } else {
    // optimal subrange
    highlightRange = calculateOptimalHighlightRange(textStorage, text,
                                                    editedRange, fullRange);
  }

  DLOG_RANGE(highlightRange, text);

  // nextRange indicate if and what range we should highlight after highlighting
  // another range. If an edit broke or created a new "state" (e.g. started a
  // multiline comment), that might have implications on other parts of the
  // document, thus the |nextRange| is an indication that we need to highlight
  // more parts of the document.
  NSRange nextRange = NSMakeRange(0, 0);

  while (nextRange.location != fullRange.length) {
    //highlightSection(textStorage, highlightRange, deltaRange);

    nextRange = [syntaxHighlighter highlightMAString:textStorage
                                             inRange:highlightRange
                                          deltaRange:deltaRange
                                           withStyle:style_];
    //[textStorage ensureAttributesAreFixedInRange:highlightRange];
    if (nextRange.location == fullRange.length) {
      DLOG("info: code tree is incomplete (open state at end of document)");
      break;
    } else if (nextRange.location == NSNotFound) {
      break;
    }
    deltaRange = nextRange;
    if (deltaRange.length == 0) {
      deltaRange = [text lineRangeForRange:deltaRange];
      DLOG("adjusted deltaRange to line: %@", NSStringFromRange(deltaRange));
    }
    // adjust one line break backward
    if (deltaRange.location > 1) {
      deltaRange.location -= 1;
      deltaRange.length += 1;
    }
    DLOG_EXPR(deltaRange);
    highlightRange = deltaRange;
  }
}*/



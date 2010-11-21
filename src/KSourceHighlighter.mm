#import "KSourceHighlighter.h"
#import "KLangMap.h"
#import "KLangRegexRuleFactory.h"
#import "KLangSymbol.h"
#import "KLangManager.h"
#import "KStyle.h"
#import "KSourceHighlightState.h"
#import "KConfig.h"
#import "common.h"

#import <iterator>

#include <srchilite/langdefmanager.h>
#include <srchilite/highlighttoken.h>
#include <srchilite/matchingparameters.h>
#include <srchilite/highlightrule.h>
#include <srchilite/formattermanager.h>
#include <srchilite/formatterparams.h>


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


// UTI "public.c-plus-plus-source" --> URL
// 

/// UTI => URL


/// Runtime constructor
__attribute__((constructor)) static void __init() {
  g_empty_state = HighlightStatePtr(new HighlightState);
}


KSourceHighlighter::KSourceHighlighter()
    : langId_(nil)
    , stateStack(KHighlightStateStackPtr(new KHighlightStateStack))
    , formatterParams(0)
    , attributesBuffer_(nil) {
  mainHighlightState_ = g_empty_state;
  currentHighlightState_ = g_empty_state;
}

KSourceHighlighter::~KSourceHighlighter() {
}


bool KSourceHighlighter::setLanguage(NSString const *langId, NSURL *url) {
  h_objc_xch(&langId_, langId);

  // no language?
  if (!langId) {
    return setState(g_empty_state);
  }
  
  // avoid race conditions where multiple threads load the same language file
  HSemaphore::Scope sem_scope(g_state_cache_sem);
  
  // locate any cached language state tree
  HighlightStateCacheMap::iterator it = g_state_cache.find(langId);
  if (it != g_state_cache.map().end()) {
    // found one
    return setState(it->second);
  }
  
  // Find URL for this langId
  if (!url) {
    if (!(url = [[KLangMap sharedLangMap] langFileURLForLangId:langId])) {
      // no known definition file
      g_state_cache.insert(langId, g_empty_state);
      return setState(g_empty_state);
    }
  }
  
  // we currently only support local files
  assert([url isFileURL]);
  
  // Load state
  NSString *path = [[url absoluteURL] path];
  NSString *dirname = [path stringByDeletingLastPathComponent];
  NSString *basename = [path lastPathComponent];
  HighlightStatePtr state = 
      KLangManager::buildHighlightState([dirname UTF8String],
                                        [basename UTF8String]);
  
  // put into cache and assign state
  g_state_cache.insert(langId, state);
  return setState(state);
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
  DLOG("enterState: %d %s", state->getId(), state->getDefaultElement().c_str());
  stateStack->push(currentHighlightState_);
  currentHighlightState_ = state;
}

/**
 * Exits level states
 * @param level
 */
void KSourceHighlighter::exitState(int level) {
  DLOG("exitState: %d %s", currentHighlightState_->getId(),
       currentHighlightState_->getDefaultElement().c_str());
  
  // remove additional levels
  for (int l = 1; l < level; ++l) {
    HighlightStatePtr state = stateStack->top();
    DLOG("exitState: %d %s", state->getId(), state->getDefaultElement().c_str());
    stateStack->pop();
  }
  currentHighlightState_ = stateStack->top();
  stateStack->pop();
}

void KSourceHighlighter::exitAll() {
  currentHighlightState_ = mainHighlightState_;
  clearStateStack();
}

void KSourceHighlighter::clearStateStack() {
  while (!stateStack->empty())
    stateStack->pop();
}

bool KSourceHighlighter::setState(const HighlightStatePtr &newState) {
  if (mainHighlightState_ != newState) {
    mainHighlightState_ = newState;
    currentHighlightState_ = newState;
    clearStateStack();
    return true;
  }
  return false;
}

// --------------------------------------------------------------------------


NSString * const KSourceHighlightStateAttribute =
  @"KSourceHighlightState";



bool KSourceHighlighter::beginBufferingOfAttributes() {
  id old = attributesBuffer_;
  attributesBuffer_ = [[NSMutableArray alloc] init];
  [old release];
}

void KSourceHighlighter::bufferAttributes(NSDictionary* attrs, NSRange range) {
  [attributesBuffer_ addObject:attrs];
  [attributesBuffer_ addObject:[NSValue valueWithRange:range]];
}

void KSourceHighlighter::endFlushBufferedAttributes(NSTextStorage *textStorage) {
  NSUInteger i, count = attributesBuffer_.count;
  assert(textStorage != nil || textStorage_ != nil);
  if (!textStorage) textStorage = textStorage_;
  for (i = 0; i < count; i += 2) {
    NSDictionary *attrs = [attributesBuffer_ objectAtIndex:i];
    NSRange range = [[attributesBuffer_ objectAtIndex:i+1] rangeValue];
    [textStorage setAttributes:attrs range:range];
  }
  h_objc_swap(&attributesBuffer_, nil);
}



void KSourceHighlighter::format(const std::string &elem) {
  NSString const *typeSymbol = KLangSymbol::symbolForString(elem);
  NSRange range = matchUnicodeRange();
  
  // get state
  unsigned int stateId = currentHighlightState_->getId();
  KSourceHighlightState *state = sourceHighlightStateMap_.get(stateId);
  if (!state) { // TODO: thread safe
    state = [[KSourceHighlightState alloc] initWithHighlightState:
        currentHighlightState_];
    sourceHighlightStateMap_.put(stateId, state);
  }
  
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
  str_const_iterator location = start;
  bool matched = true;
  HighlightToken token;
  mParams.beginningOfLine = true;
  
  // note that we go on even if the string is empty, since it is crucial
  // to try to match also the end of buffer (some rules rely on that)
  while (matched) {
    matched =
        currentHighlightState_->findBestMatch(location, end, token, mParams);
    
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
void KSourceHighlighter::willHighlight(NSTextStorage *textStorage,
                                       NSRange editedRange) {
  // update instance-locals
  textStorage_ = [textStorage retain];
  text_ = [[textStorage_ string] retain];
  fullRange_ = NSMakeRange(0, textStorage_.length);
  receivedWillHighlight_ = true;
  
  if (editedRange.location == 0 && editedRange.length == fullRange_.length) {
    editedRange.location = NSNotFound;
  }

  if (editedRange.location != NSNotFound) {
    // find KSourceHighlightStateAttribute
    NSRange effectiveRange;
    KSourceHighlightState* attrValue =
        [textStorage attribute:KSourceHighlightStateAttribute
                       atIndex:editedRange.location
                effectiveRange:&effectiveRange];
    DLOG_RANGE(effectiveRange, text_);
    // TODO: save info to be used by |highlight|
  }
}



// this method is called when an edit was detected in |textStorage| or when
// |textStorage| should be completely re-highlighted.
void KSourceHighlighter::highlight(NSTextStorage *textStorage,
                                   KStyle *style,
                                   NSRange editedRange) {
  // update instance-locals
  if (receivedWillHighlight_) {
    assert(textStorage_ == textStorage);
    assert(text_ == [textStorage_ string]);
  } else {
    textStorage_ = [textStorage retain];
    text_ = [[textStorage_ string] retain];
    fullRange_ = NSMakeRange(0, textStorage_.length);
  }
  
  style_ = [style retain];
  
  NSRange highlightRange = fullRange_;
  //NSRange highlightRange = [text_ lineRangeForRange:editedRange]; // FIXME
  //DLOG_RANGE(editedRange, text_);
  
  matchRange_.location = 0;
  
  MatchingParameters mParams;
  // TODO: set mParams.beginningOfLine = false if we are not at the beginning of
  // a line.
  
  // make a std::string copy
  std::string paragraph;
  NSUInteger size = [text_ populateStdString:paragraph
                               usingEncoding:NSUTF8StringEncoding
                                       range:highlightRange];
  paragraph_ = &paragraph;
  paragraphIsMultibyte_ = (size != highlightRange.length);
  
  // get start and end iterators
  str_const_iterator paragraphStart = paragraph.begin();
  str_const_iterator paragraphEnd = paragraph.end();
  str_const_iterator start = paragraphStart;
  str_const_iterator end = paragraphStart;
  
  // process each line
  do {
    // fast-forward to next newline
    // TODO: Handle CR linebreaks. Currently only CRLF and LF are handled.
    while (end != paragraphEnd && *end++ != '\n') {}
    
    DLOG("line =>\n'%s'", std::string(start, end).c_str());
    
    highlightLine(paragraphStart, start, end, mParams);

    start = end;
  } while (end != paragraphEnd);
  
  h_objc_xch(&textStorage_, nil);
  h_objc_xch(&text_, nil);
  h_objc_xch(&style_, nil);
  paragraph_ = NULL;
  receivedWillHighlight_ = false;
}





id KSourceHighlighter::rangeOfLangElement(NSUInteger index, NSRange &range) {
  // Algorithm
  /* - start by looking at |index|
   * - read the attribute |KStyleElement::ClassAttributeName|
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
  // |KStyleElement::ClassAttributeName| does not change value
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
     *      receive the "normal" format rather than the "function" format.
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
     *      KStyleElement::ClassAttributeName symbol representing the
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
     *      highlighter applies the following calculation to the new
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



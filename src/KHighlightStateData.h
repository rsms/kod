/*
 *  Copyright (C) 2008-2010  Lorenzo Bettini, http://www.lorenzobettini.it
 *  License: See COPYING file that comes with this distribution
 */

#ifndef HIGHLIGHTSTATEDATA_H_
#define HIGHLIGHTSTATEDATA_H_

#include <srchilite/sourcehighlighter.h>

/**
 * Utility class to deal with current highlighting state (and stack of states)
 */
struct KHighlightStateData {
  /// the current state for the SourceHighlighter object
  srchilite::HighlightStatePtr currentState;

  /// the current stack for the SourceHighlighter object
  srchilite::HighlightStateStackPtr stateStack;

  KHighlightStateData() {
  }

  /**
   * Performs a deep copy of the passed object (by duplicating the stack)
   * @param data
   */
  KHighlightStateData(const KHighlightStateData& data) :
        currentState(data.currentState),
        stateStack(srchilite::HighlightStateStackPtr(
            new srchilite::HighlightStateStack(*(data.stateStack)))) {
  }

  KHighlightStateData(srchilite::HighlightStatePtr currentState_,
      srchilite::HighlightStateStackPtr stateStack_) :
    currentState(currentState_), stateStack(stateStack_) {
  }

  /**
   * Performs a deep copy of the passed object (by duplicating the stack)
   */
  void copyFrom(const KHighlightStateData& data) {
    currentState = data.currentState;
    stateStack = srchilite::HighlightStateStackPtr(
        new srchilite::HighlightStateStack(*(data.stateStack)));
  }
};

#endif /* HIGHLIGHTSTATEDATA_H_ */

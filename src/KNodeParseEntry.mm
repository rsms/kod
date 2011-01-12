// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "KNodeParseEntry.h"
#import "common.h"

//#define DEBUG_mergeWith 1
#if DEBUG_mergeWith
#define IFDEBUG_mergeWith(expr) do() { expr }while(0)
#else
#define IFDEBUG_mergeWith(expr) ((void)0)
#endif

bool KNodeParseEntry::mergeWith(KNodeParseEntry *prev) {
  if (!prev)
    return true;

  NSUInteger &prev_index = prev->modificationIndex();
  NSInteger &prev_changeDelta = prev->changeDelta();
  NSUInteger &curr_index = modificationIndex_;
  NSInteger &curr_changeDelta = changeDelta_;

  #if DEBUG_mergeWith
  DLOG_EXPR(curr_index);
  DLOG_EXPR(prev_index);
  DLOG_EXPR(curr_changeDelta);
  DLOG_EXPR(prev_changeDelta);
  #endif

  // test 1: {'a',0,1} + {'ab',1,1} --> {'ab',0,2}
  if (curr_index > prev_index &&
      curr_changeDelta > 0 &&
      prev_changeDelta > 0) {
    IFDEBUG_mergeWith(NSLog(@"path 1 -- union (extend)"););
    // 'abc def ghi' >> {'abc def',0,4} + {'abc def ghi',7,4} -->
    //                        {'abc def ghi',0,11}
    curr_changeDelta += (curr_index - prev_index);
    curr_index = prev_index;
    return true;
  }

  // test 2: {'abc',2,1} + {'ab',2,-1} --> null
  if (curr_index == prev_index &&
      curr_changeDelta + prev_changeDelta == 0 &&
      curr_changeDelta < 0) {
    IFDEBUG_mergeWith(NSLog(@"path 2 -- noop"););
    return false;
  }

  // test 3: {'abc',2,1} + {'',3,-3} --> {'',2,-2}
  if (prev_changeDelta > -1) { // [0..
    IFDEBUG_mergeWith(NSLog(@"path 3 -- union (shrink)"););
    curr_changeDelta += prev_changeDelta;
    curr_index = prev_index;
    return true;
  }
  // else: prev_changeDelta < 0

  if (curr_index != prev_index) {
    // 'abc def ghi' >> {'abc def',7,-4} + {'def',0,-4} --> {'def',0,11}
    curr_changeDelta = (prev_index - prev_changeDelta);
  } else {
    // 'abc def ghi' >> {'abc  ghi',4,-3} + {'abc xyz123 ghi',4,6} --> {..,4,6}
  }
  IFDEBUG_mergeWith(NSLog(@"path 5 -- replace"););
  return true;
}

// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#include "ASTNode.h"
#include "common.h"

using namespace kod;

NSRange ASTNode::absoluteSourceRange() {
  //DLOG("absoluteSourceRange: '%@' [%u, %u]", kind_->weakNSString(),
  //     sourceLocation_, sourceLength_);
  if (sourceRange_.location == NSNotFound)
    return sourceRange_;
  NSRange range = sourceRange_;
  if (parentNode_.get()) {
    NSRange &parentRange = parentNode_->sourceRange();
    if (parentRange.location != NSNotFound)
      range.location += parentRange.location;
  }
  return range;
}

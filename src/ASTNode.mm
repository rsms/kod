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

// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#include "ASTNode.hh"

namespace kod {


ASTNode::~ASTNode() {
  fprintf(stderr, "ASTNode '%s' DEALLOC\n", ruleName_);
  if (parserState_) {
    gzl_free_parse_state(parserState_);
    parserState_ = NULL;
  }
}


void ASTNode::setParseState(gzl_parse_state *parserState) {
  if (parserState_) gzl_free_parse_state(parserState_);
  parserState_ = parserState;
}


void ASTNode::copyParseState(gzl_parse_state *parserState) {
  if (parserState_) gzl_free_parse_state(parserState_);
  parserState_ = gzl_dup_parse_state(parserState);
  /*printf("\ncopy token buffer:\n");
  for(int i = 0; i < parserState_->token_buffer_len; i++) {
        char *name;
    struct gzl_offset offset;
    size_t len;
    printf("{ name: '%s', offset: %zu, len: %zu }\n",
           parserState_->token_buffer[i].name,
           parserState_->token_buffer[i].offset.byte,
           parserState_->token_buffer[i].len);
  }*/
}


void ASTNode::clearParseState() {
  if (parserState_) {
    gzl_free_parse_state(parserState_);
    parserState_ = NULL;
  }
}


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


ASTNode *ASTNode::findAffectedBranch(NSRange &mrange,
                                     NSUInteger absoluteSourceOffset,
                                     NSUInteger *absoluteSourceLocation,
                                     ASTNode **continueAtNode,
                                     size_t *affectedParentOffset) {
  NSRange &rrange = this->sourceRange();

  if (rrange.length != 0 &&
     (// node appears after the changed area?
      (rrange.location + absoluteSourceOffset
       >= mrange.location + mrange.length) ||
      // node appears before the changed area?
      (rrange.location + absoluteSourceOffset + rrange.length
       < mrange.location)
     )
  ) {
    /*printf("rrange.location + absoluteSourceOffset = %lu\n", rrange.location + absoluteSourceOffset);
    printf("mrange.location + mrange.length = %lu\n", mrange.location + mrange.length);
    printf("rrange.location + absoluteSourceOffset + rrange.length = %lu\n",
           rrange.location + absoluteSourceOffset + rrange.length);
    printf("mrange.location = %lu\n", mrange.location);*/
    //printf("skip node (outside of mrange)\n");
    return NULL;
  }

  ASTNode *found = NULL, *prevNode = NULL;
  NSUInteger prevNodeLocation = 0;
  std::vector<kod::ASTNodePtr>::iterator beginit = this->childNodes().begin();
  std::vector<kod::ASTNodePtr>::iterator it = beginit;
  std::vector<kod::ASTNodePtr>::iterator endit = this->childNodes().end();
  for ( ; it < endit; ++it ) {
    ASTNodePtr &n = *it;
    NSRange r = n->sourceRange();
    r.location += absoluteSourceOffset;
    //printf("r = [%lu, %lu]\n", r.location, r.length);
    if (r.length == 0 ||
        (mrange.location >= r.location &&
         mrange.location < r.location + r.length) ) {
      //DLOG("digging");
      found = n.get()->findAffectedBranch(mrange,
                                          r.location,
                                          absoluteSourceLocation,
                                          continueAtNode,
                                          affectedParentOffset);
      if (!found) {
        found = n.get();
        //*absoluteSourceLocation = r.location;
        *continueAtNode = prevNode;
        *absoluteSourceLocation = prevNodeLocation;
        //*continueAtAbsoluteSourceLocation = prevNodeLocation;
        *affectedParentOffset = it-beginit;
      }
      break;
    }
    prevNode = n.get();
    prevNodeLocation = r.location;
  }
  return found;
}


void ASTNode::_inspect(std::string &str, int depth, bool deep) {
  char buf[512];
  snprintf(buf, sizeof(buf)-1, "%*snull\n", depth*2, "");
  snprintf(buf, sizeof(buf)-1,
           "%s%*s{ rule: \"%s\", sourceRange: [%lu, %lu]",
           depth ? "\n":"",
           depth*2, "",
           ruleName(), sourceRange().location, sourceRange().length);
  str.append(buf);
  /*if (parserState_) {
    snprintf(buf, sizeof(buf)-1, ", snapshot: { offset:%zu, stackSize: %d } ",
             parserState_->offset.byte, parserState_->parse_stack_len);
    str.append(buf);
  }*/
  if (!childNodes().empty()) {
    if (!deep) {
      snprintf(buf, sizeof(buf)-1, ", childNodes: (%zu) },",
               childNodes().size());
      str.append(buf);
    } else {
      str.append(", childNodes: [");
      std::vector<kod::ASTNodePtr>::iterator it = childNodes().begin();
      std::vector<kod::ASTNodePtr>::iterator endit = childNodes().end();
      for ( ; it < endit; ++it ) {
        if (!*it) {
          snprintf(buf, sizeof(buf)-1, "%*snull\n", (depth+1)*2, "");
          str.append(buf);
        } else {
          (*it)->_inspect(str, depth+1, true);
        }
      }
      str.append("] },");
    }
  } else {
    str.append("},");
  }
}


std::string ASTNode::inspect(bool deep) {
  std::string str;
  _inspect(str, 0, deep);
  return str;
}


}  // namespace kod

#include "ASTParser.hh"

#define DEBUG_PARSER 0
#if DEBUG_PARSER
  #define DLOG(fmt, ...) fprintf(stderr, fmt "\n", ##__VA_ARGS__ );
#else
  #define DLOG(fmt, ...) ((void)0)
#endif

//inline static int MIN(int a, int b) { return (a < b) ? a : b; }

namespace kod {


void ASTParser::onWillStartRule(gzl_rtn *frame,
                             const char *name,
                             gzl_offset *offset) {
  // Save a snapshot of the current state in the node.
  // Note: This will be cleared for leaves (nodes w/o children) on a successful
  // pop.
  //gzl_parse_state *parserStateCopy1_ = gzl_dup_parse_state(state());
  //currentASTNode_->copyParseState(state());
}


void ASTParser::onDidStartRule(gzl_rtn_frame *frame, const char *name) {
  // push AST node
  gzl_parse_stack_frame *prevFrame = stackFrameAt(1);
  NSUInteger prevLocation = prevFrame ? prevFrame->start_offset.byte : 0;
  size_t currLocation = ((gzl_parse_stack_frame*)frame)->start_offset.byte;
  NSUInteger relativeLocation = currLocation - prevLocation;

  // include the char which started the rule
  //if (relativeLocation) --relativeLocation;
  pushASTNode(new ASTNode(name, relativeLocation));

  // Save a snapshot of the current state in the node.
  // Note: This will be cleared for leaves (nodes w/o children) on a successful
  // pop.
  /*if (parserStateCopy1_) {
    currentASTNode_->setParseState(parserStateCopy1_);
    parserStateCopy1_ = NULL;
  }*/
  //currentASTNode_->copyParseState(state());

  //DLOG("pushed AST node \"%s\" at {%lu, ...}", currentASTNode_->ruleName(),
  //     currentASTNode_->sourceRange().location);

  DLOG(">>%*s start rule '%s'", (stackDepth()-1)*2, "", name);
}


void ASTParser::onEndRule(gzl_rtn_frame *frame, const char *name) {
  // update current node's range
  assert(currentASTNode_.get() != NULL);
  bool isRoot = !currentASTNode_->parentNode().get();

  if (!isRoot) {
    currentASTNode_->parentNode()->sourceRange().length =
      currentASTNode_->sourceRange().location +
      currentASTNode_->sourceRange().length;
  }

  /*if (currentASTNode_->sourceRange().length == 0) {
    currentASTNode_->sourceRange().length =
        state()->offset.byte - stackFrameAt(0)->start_offset.byte;
  }*/

  // if the node does not have any children, discard the saved state
  //if (currentASTNode_->childNodes().empty()) {
  //  currentASTNode_->clearParseState();
  //}

  //if (!currentASTNode_->childNodes().empty())
  currentASTNode_->copyParseState(state());

  // pop the node
  //DLOG("pop AST node \"%s\" at {%lu, %lu}", currentASTNode_->ruleName(),
  //     currentASTNode_->sourceRange().location,
  //     currentASTNode_->sourceRange().length);
  popASTNode();

  DLOG(">>%*s end rule '%s'", (stackDepth()-1)*2, "", name);
}


void ASTParser::onTerminal(gzl_terminal *terminal) {
  DLOG(">>%*s terminal '%s'", stackDepth()*2, "", terminal->name);
  if (currentASTNode_.get()) {
    currentASTNode_->sourceRange().length =
      state()->offset.byte - stackFrameAt(0)->start_offset.byte;
    //printf("set len: %lu\n", currentASTNode_->sourceRange().length);
  }
}


void ASTParser::onUnknownTransitionError(int ch) {
  DLOG("error: unknown transition from character '%c' at input:%zu:%zu[%zu]",
       ch, line(), column(), offset());
}


static void _unwindAndGuessLength(ASTNode *node, NSUInteger &totalLength) {
  node->sourceRange().length = totalLength;
  ASTNode::NodeList::iterator it = node->childNodes().begin();
  ASTNode::NodeList::iterator endit = node->childNodes().end();
  for ( ; it < endit; ++it ) {
    NSRange &r = (*it)->sourceRange();
    if ( (r.length != 0) &&
         // if last child node location+length < my length then last child node
         // is incomplete
         !(it == endit-1 && r.location + r.length < node->sourceRange().length)
       ) {
      continue;
    }
    r.length = totalLength - r.location;
    _unwindAndGuessLength((*it).get(), totalLength);
  }
}


void ASTParser::onUnexpectedTerminalError(gzl_terminal *terminal) {
  // TODO: as this will abort parsing, we need to unwind the tree and apply
  // best-effort range lengths. This is an incomplete implementation:
  if (rootASTNode_->sourceRange().length == 0) {
    NSUInteger totalLength = state()->offset.byte;
    _unwindAndGuessLength(rootASTNode_.get(), totalLength);

    // it's not really possible to unwind the stack right now since it requires
    // running the parse tree heuristics which really should be handled by
    // parse.c
    /*size_t stacksize = state()->parse_stack_len;
    while (stacksize-- != 0) {
      // invoke onEndRule
      gzl_parse_stack_frame *frame = DYNARRAY_GET_TOP(state()->parse_stack);
      if (frame->frame_type == gzl_parse_stack_frame::GZL_FRAME_TYPE_RTN) {
        printf("pop\n");
        gzl_rtn_frame *rtn_frame = &frame->f.rtn_frame;
        onEndRule(rtn_frame, rtn_frame->rtn->name);
      } else {
        printf("frame->frame_type => %d\n", frame->frame_type);
      }
    }
    state()->parse_stack_len = 0;*/
  }

#if DEBUG_PARSER
  // extract source line where the error occured
  size_t start_offset = terminal->offset.byte - MIN(30,terminal->offset.byte);
  while (start_offset < terminal->offset.byte &&
         sourceBuf_[start_offset++] != '\n');
  const char *p = sourceBuf_ + start_offset;
  size_t len, end = terminal->offset.byte;
  while (1) {
    if (end == sourceLen_) {
      len = MIN(sourceLen_ - start_offset, 60);
      break;
    } else if (sourceBuf_[++end] == '\n') {
      len = MIN(end-start_offset, 60);
      break;
    }
  }
  int error_offset = terminal->offset.byte - start_offset;
  char *source_line = (char*)malloc((len+1)*sizeof(char));
  memcpy(source_line, p, len);
  DLOG("error: unexpected terminal '%s' -- aborting (input:%zu:%zu[%zu])\n"
       "  %s\n"
       "  %*s",
       terminal->name,
       terminal->offset.line, terminal->offset.column, terminal->offset.byte,
       source_line,
       error_offset, "^");
  free(source_line);
#endif  // DEBUG_PARSER
}


NSRange ASTParser::absoluteSourceRangeFromChangeInfo(NSUInteger changeLocation,
                                                     long changeDelta) {
  NSRange mrange;
  if (changeDelta < 0) {
    mrange.location = changeLocation + changeDelta;
    mrange.length = -changeDelta;
  } else {
    mrange.location = changeLocation;
    mrange.length = changeDelta;
  }
  return mrange;
}


// return a string representation of a gzl status code
const char *ASTParser::gazelleStatusString(gzl_status status) {
  switch (status) {
    case GZL_STATUS_OK: return "GZL_STATUS_OK";
    case GZL_STATUS_ERROR: return "GZL_STATUS_ERROR";
    case GZL_STATUS_CANCELLED: return "GZL_STATUS_CANCELLED";
    case GZL_STATUS_HARD_EOF: return "GZL_STATUS_HARD_EOF";
    case GZL_STATUS_RESOURCE_LIMIT_EXCEEDED:
      return "GZL_STATUS_RESOURCE_LIMIT_EXCEEDED";
    case GZL_STATUS_IO_ERROR: return "GZL_STATUS_IO_ERROR";
    case GZL_STATUS_PREMATURE_EOF_ERROR:
      return "GZL_STATUS_PREMATURE_EOF_ERROR";
    default: return "unknown";
  }
}


}  // namespace kod

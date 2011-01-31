#ifndef KOD_PARSER_H_
#define KOD_PARSER_H_

#include <gazelle/Parser.hh>
#include <tr1/memory>
#include "ASTNode.hh"

namespace kod {

class ASTParser : public gazelle::Parser {
 protected:
  // Reference to our source
  const char *sourceBuf_;
  size_t sourceLen_;

  // Current AST node
  ASTNodePtr currentASTNode_;
  ASTNodePtr rootASTNode_;

  NSUInteger explicitNextChildNodeIndex_;

 public:

  ASTParser() : explicitNextChildNodeIndex_(NSNotFound) { reset(); }
  /*ASTParser(gazelle::Grammar *grammar) : explicitNextChildNodeIndex_(NSNotFound) {
    reset();

  }*/
  virtual ~ASTParser() {}

  void reset() {
    rootASTNode_.reset(new ASTNode("root", 0));
    currentASTNode_ = rootASTNode_;
    setState(gzl_alloc_parse_state());
  }

  void setSource(const char *source) {
    sourceBuf_ = source;
    sourceLen_ = strlen(source);
  }

  void setExplicitNextChildNodeIndex(NSUInteger nextChildNodeIndex) {
    explicitNextChildNodeIndex_ = nextChildNodeIndex;
  }

  void pushASTNode(ASTNode *node) {
    ASTNodePtr nodeptr(node);
    node->parentNode() = currentASTNode_;
    if (explicitNextChildNodeIndex_ != NSNotFound) {
      currentASTNode_->childNodes()[explicitNextChildNodeIndex_] = nodeptr;
      explicitNextChildNodeIndex_ = NSNotFound;
    } else {
      currentASTNode_->childNodes().push_back(nodeptr);
    }
    currentASTNode_ = nodeptr;
  }

  void popASTNode() {
    //assert(currentASTNode_->parentNode().get());
    currentASTNode_ = currentASTNode_->parentNode();
  }

  ASTNodePtr &currentASTNode() { return currentASTNode_; }
  ASTNodePtr &rootASTNode() { return rootASTNode_; }

  void onWillStartRule(gzl_rtn *frame, const char *name, gzl_offset *offset);
  void onDidStartRule(gzl_rtn_frame *frame, const char *name);
  void onEndRule(gzl_rtn_frame *frame, const char *name);
  void onTerminal(gzl_terminal *terminal);
  void onUnknownTransitionError(int ch);
  void onUnexpectedTerminalError(gzl_terminal *terminal);

  static NSRange absoluteSourceRangeFromChangeInfo(NSUInteger changeLocation,
                                                   long changeDelta);
  static const char *gazelleStatusString(gzl_status status);
};

typedef std::tr1::shared_ptr<ASTParser> ASTParserPtr;

}  // namespace kod

#endif  // KOD_PARSER_H_

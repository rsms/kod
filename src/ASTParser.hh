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
  ASTNodePtr currentNode_;
  ASTNodePtr rootNode_;

  NSUInteger explicitNextChildNodeIndex_;

 public:

  explicit ASTParser() : explicitNextChildNodeIndex_(NSNotFound) { reset(); }
  virtual ~ASTParser() {}

  void reset() {
    rootNode_.reset(new ASTNode("root", 0));
    currentNode_ = rootNode_;
    setState(gzl_alloc_parse_state());
  }

  void setSource(const char *source) {
    sourceBuf_ = source;
    sourceLen_ = strlen(source);
  }

  void setExplicitNextChildNodeIndex(NSUInteger nextChildNodeIndex) {
    explicitNextChildNodeIndex_ = nextChildNodeIndex;
  }

  void pushASTNode(ASTNode *node);

  void popASTNode() {
    //assert(currentNode_->parentNode().get());
    currentNode_ = currentNode_->parentNode();
  }

  ASTNodePtr &currentNode() { return currentNode_; }
  ASTNodePtr &rootNode() { return rootNode_; }

  void onWillStartRule(gzl_rtn *frame, const char *name, gzl_offset *offset);
  void onDidStartRule(gzl_rtn_frame *frame, const char *name);
  void onWillEndRule(gzl_rtn_frame *frame, const char *name);
  void onDidEndRule(gzl_rtn_frame *frame, const char *name);
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

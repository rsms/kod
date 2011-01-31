// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#ifndef KOD_AST_NODE_H_
#define KOD_AST_NODE_H_

#include <vector>
#include <string>
#include <tr1/memory>
#include <gazelle/parse.h>

namespace kod {

class ASTNode;
typedef std::tr1::shared_ptr<ASTNode> ASTNodePtr;

class ASTNode {
 public:
  typedef std::vector<kod::ASTNodePtr> NodeList;

  explicit ASTNode(const char *ruleName=NULL,
                   NSUInteger startLocation=NSNotFound)
      : parserState_(NULL) {
    sourceRange_ = (NSRange){startLocation, 0};
    ruleName_ = ruleName;
  }
  ~ASTNode();

  ASTNodePtr &parentNode() { return parentNode_; }
  std::vector<ASTNodePtr> &childNodes() { return childNodes_; }
  const char *&ruleName() { return ruleName_; }
  NSRange &sourceRange() { return sourceRange_; }

  NSRange absoluteSourceRange();

  gzl_parse_state *parseState() { return parserState_; }
  void setParseState(gzl_parse_state *parserState);
  void copyParseState(gzl_parse_state *parserState);
  void clearParseState();

  ASTNode *findAffectedBranch(NSRange &mrange,
                              NSUInteger absoluteSourceOffset,
                              NSUInteger *absoluteSourceLocation,
                              ASTNode **continueAtNode,
                              size_t *affectedParentOffset);

  std::string inspect(bool deep=true);

 protected:
  ASTNodePtr parentNode_;
  NodeList childNodes_;
  const char *ruleName_; // weak
  NSRange sourceRange_;
  gzl_parse_state *parserState_;

 private:
  void _inspect(std::string &str, int depth, bool deep);
};


};  // namespace kod

#endif  // KOD_AST_NODE_H_

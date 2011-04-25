// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#ifndef KOD_AST_NODE_H_
#define KOD_AST_NODE_H_

#include <vector>
#include <string>
#include <tr1/memory>
#include <gazelle/parse.h>

#import <CSS/CSS.h>

namespace kod {

class ASTNode;
typedef std::tr1::shared_ptr<ASTNode> ASTNodePtr;

class ASTParser;

class ASTNode {
 public:
  typedef std::vector<kod::ASTNodePtr> NodeList;

  explicit ASTNode(const char *ruleName=NULL,
                   NSUInteger startLocation=NSNotFound,
                   ASTParser *parser=NULL)
      : parserState_(NULL) {
    sourceRange_ = (NSRange){startLocation, 0};
    ruleName_ = NULL;
    if (ruleName) {
      lwc_intern_string(ruleName, strlen(ruleName), &ruleName_);
    }
    parser_ = parser;
  }
  ~ASTNode();

  ASTNodePtr &parentNode() { return parentNode_; }
  std::vector<ASTNodePtr> &childNodes() { return childNodes_; }
  NSString *ruleNameString() { return [NSString stringWithLWCString:ruleName_]; }
  lwc_string *ruleName() { return ruleName_; }
  NSRange &sourceRange() { return sourceRange_; }

  NSRange absoluteSourceRange();
  NSMutableArray *ruleNamePath();

  gzl_parse_state *parseState() { return parserState_; }
  void setParseState(gzl_parse_state *parserState);
  void copyParseState(gzl_parse_state *parserState);
  void clearParseState();

  ASTParser *parser() { return parser_; }
  lwc_string *grammarIdentifier();

  ASTNode *findAffectedBranch(NSRange &mrange,
                              NSUInteger absoluteSourceOffset,
                              NSUInteger *absoluteSourceLocation,
                              ASTNode **continueAtNode,
                              size_t *affectedParentOffset);

  std::string inspect(bool deep=true);

 protected:
  ASTNodePtr parentNode_;
  NodeList childNodes_;
  lwc_string *ruleName_;
  NSRange sourceRange_;
  gzl_parse_state *parserState_;
  ASTParser *parser_;  // weak

 private:
  void _inspect(std::string &str, int depth, bool deep);
};


};  // namespace kod

#endif  // KOD_AST_NODE_H_

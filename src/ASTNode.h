// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#ifndef KOD_AST_NODE_H_
#define KOD_AST_NODE_H_

#include "ExternalUTF16String.h"

#include <vector>
#include <string>
#include <tr1/memory>

namespace kod {

class ASTNode;
typedef std::tr1::shared_ptr<ASTNode> ASTNodePtr;

class ASTNode {
 public:
  ASTNode() { sourceRange_ = (NSRange){NSNotFound, 0}; }
  ~ASTNode() {}

  ASTNodePtr &parentNode() { return parentNode_; }
  std::vector<ASTNodePtr> &childNodes() { return childNodes_; }
  ExternalUTF16StringPtr &kind() { return kind_; }
  NSRange &sourceRange() { return sourceRange_; }

  NSRange absoluteSourceRange();

 protected:
  ASTNodePtr parentNode_;
  std::vector<ASTNodePtr> childNodes_;
  ExternalUTF16StringPtr kind_;
  NSRange sourceRange_;
};


};  // namespace kod

#endif  // KOD_AST_NODE_H_

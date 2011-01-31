// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#ifndef KOD_AST_H_
#define KOD_AST_H_

#include "ASTNode.hh"
#include "ASTParser.hh"
#include "Grammar.hh"
#include "common.h"

#include <vector>
#include <string>
#include <tr1/memory>

@class KDocument;

namespace kod {

class AST {
 public:
  explicit AST(KDocument *document=NULL);
  ~AST() {}

  const ASTNodePtr &rootNode() const { return rootNode_; }
  bool setRootNode(ASTNodePtr rootNode) {
    // TODO(rsms): using CAS or spinlock
    h_atomic_barrier();
    rootNode_ = rootNode;
  }

  bool parse();
  bool parseEdit(NSUInteger changeLocation, long changeDelta);

 protected:
  KDocument *document_; // weak, owns us
  ASTParserPtr parser_;
  GrammarPtr grammar_;
  ASTNodePtr rootNode_;

  // state
  bool isOpenEnded_;
};

typedef std::tr1::shared_ptr<AST> ASTPtr;


};  // namespace kod
#endif  // KOD_AST_H_

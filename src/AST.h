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

typedef enum {
  KParseStatusUnknown = 0,
  KParseStatusOK,
  KParseStatusBroken,
} KParseStatus;

@class KDocument;

namespace kod {

class AST {
 public:
  explicit AST(KDocument *document=NULL);
  ~AST() {}

  ASTNodePtr &rootNode() const { return parser_->rootNode(); }

  bool parse();
  bool parseEdit(NSUInteger changeLocation, long changeDelta);

  KParseStatus status();

  bool isOpenEnded() {
    return parser_->currentNode().get() != parser_->rootNode().get();
  }

 protected:
  KDocument *document_; // weak, owns us
  ASTParserPtr parser_;
  GrammarPtr grammar_;
  bool needFullParse_;
  gzl_status status_;
};

typedef std::tr1::shared_ptr<AST> ASTPtr;


};  // namespace kod
#endif  // KOD_AST_H_

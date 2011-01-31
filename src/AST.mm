// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "KDocument.h"
#import "AST.h"

using namespace kod;


AST::AST(KDocument *document)
    : document_(document)
    , isOpenEnded_(false) {
  // xxx fixme
  grammar_.reset(new Grammar);
  parser_.reset(new ASTParser);
  if (grammar_->loadFile("/Users/rasmus/src/gazelle/test2/json.gzc")) {
    parser_->setGrammar(grammar_.get());
  } else {
    WLOG("failed to load grammar");
  }
}


bool AST::parse() {

  Grammar *grammar = new Grammar;
  assert(grammar->loadFile("/Users/rasmus/src/gazelle/test2/json.gzc"));
  ASTParser parser;
  parser.setGrammar(grammar);

  NSString *text = [[document_ textView] textStorage].string;
  const char *source = [text UTF8String]; // FIXME unichar
  //const char *source = "{\n\"foo\": 12.34, \"bar\": 4\n}";

  parser.setSource(source);
  DLOG("parsing");
  gzl_status status = parser.parse(source, 0, true);

  DLOG("parse status: %s", ASTParser::gazelleStatusString(status));

  isOpenEnded_ =
      parser.currentASTNode().get() != parser.rootASTNode().get();

  fprintf(stderr, "isOpenEnded_: %d\n", isOpenEnded_);
  fprintf(stderr, "AST:\n%s\n", parser.rootASTNode()->inspect().c_str());

  return status == GZL_STATUS_OK;
}


bool AST::parseEdit(NSUInteger changeLocation, long changeDelta) {
  NSString *text = [[document_ textView] textStorage].string;
  //parser.setSource([text UTF8String]);
  //parser.setSource(source);
  //gzl_status status = parser.parse(source, 0, true);
}

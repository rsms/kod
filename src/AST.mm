// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "KDocument.h"
#import "AST.h"
#import "kconf.h"

using namespace kod;


AST::AST(KDocument *document)
    : document_(document)
    , status_(GZL_STATUS_OK)
    , needFullParse_(true) {
  // xxx fixme
  grammar_.reset(new Grammar("JSON"));
  parser_.reset(new ASTParser());
  const char *grammarFile = [[kconf_res_url(@"json.gzc") path] UTF8String];
  if (grammar_->loadFile(grammarFile)) {
    parser_->setGrammar(grammar_.get());
  } else {
    WLOG("failed to load grammar");
  }
}


bool AST::parse() {
  if (!grammar_->grammar())
    return false;
  parser_->reset();
  parser_->setGrammar(grammar_.get());

  NSString *text = [[document_ textView] textStorage].string;
  const char *source = [text UTF8String]; // FIXME unichar
  //const char *source = "{\n\"foo\": 12.34, \"bar\": 4\n}";

  parser_->setSource(source);
  DLOG("parsing");
  status_ = parser_->parse(source, 0, true);

  DLOG("parse status: %s", ASTParser::gazelleStatusString(status_));
  DLOG("isOpenEnded: %d", isOpenEnded());
  //DLOG("AST:\n%s", parser_->rootNode()->inspect().c_str());

  needFullParse_ = false;
  lastAffectedNode_ = parser_->rootNode();

  [document_ ASTWasUpdatedForSourceRange:NSMakeRange(0, text.length)
                                    node:lastAffectedNode_];
  return true;
}


bool AST::parseEdit(NSUInteger changeLocation, long changeDelta) {
  // if a full parse is needed, take the "quick" route
  if (needFullParse_)
    return parse();

  // bail unless we have a valid grammar
  if (!grammar_->grammar())
    return false;

  // find affected node
  NSRange mrange =
      ASTParser::absoluteSourceRangeFromChangeInfo(changeLocation, changeDelta);
  DLOG("mrange = %@", NSStringFromRange(mrange));
  NSUInteger continueAtSourceLocation = 0;
  size_t affectedParentOffset = 0;
  ASTNode *continueAtNode = NULL;
  ASTNode *affectedNode =
      parser_->rootNode()->findAffectedBranch(mrange,
                                              0,
                                              &continueAtSourceLocation,
                                              &continueAtNode,
                                              &affectedParentOffset);
  if (!continueAtNode)
    return parse(); // FIXME
  // TODO: logic instead of assertions
  kassert(continueAtNode != NULL);
  kassert(affectedNode != NULL);
  DLOG("affected node: %s", affectedNode->inspect(false).c_str());
  DLOG("continue after node: %s", continueAtNode->inspect(false).c_str());

  // tell parser to replace the old node with the new one
  parser_->setExplicitNextChildNodeIndex(affectedParentOffset);

  // resuscitate parser state
  gzl_parse_state *newState = continueAtNode->parseState();
  assert(newState != NULL);
  parser_->setState(gzl_dup_parse_state(newState));

  // get source
  NSString *text = [[document_ textView] textStorage].string;
  const char *source = [text UTF8String]; // FIXME unichar

  // parse
  size_t sourceLen = strlen(source);
  //DLOG("source -> (%zu) '%s'", sourceLen, source);
  parser_->setSource(source);
  parser_->currentNode() = affectedNode->parentNode();
  DLOG("currentNode(): %s", parser_->currentNode()->inspect(false).c_str());
  status_ = parser_->parse(source, sourceLen, true);

  // check status
  DLOG("parse status: %s", ASTParser::gazelleStatusString(status_));
  DLOG("isOpenEnded: %d", isOpenEnded());
  //DLOG("AST:\n%s\n", parser_->rootNode()->inspect().c_str());

  lastAffectedNode_.reset(affectedNode);
  NSRange affectedSourceRange = affectedNode->sourceRange();
  if (isOpenEnded())
    affectedSourceRange.length = text.length - affectedSourceRange.location;

  ASTNodePtr affectedNodePtr(affectedNode);
  [document_ ASTWasUpdatedForSourceRange:affectedSourceRange
                                    node:affectedNodePtr];
  return true;
}


KParseStatus AST::status() {
  switch (status_) {
    case GZL_STATUS_OK:
    case GZL_STATUS_HARD_EOF:
      return KParseStatusOK;
    case GZL_STATUS_ERROR:
    case GZL_STATUS_PREMATURE_EOF_ERROR:
    case GZL_STATUS_CANCELLED:
    case GZL_STATUS_BAD_GRAMMAR:
      return KParseStatusBroken;
    default:
      return KParseStatusUnknown;
  }
}





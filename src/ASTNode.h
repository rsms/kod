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
  static const uint32_t NotFound = UINT32_MAX;
  ASTNode() : sourceLocation_(NotFound), sourceLength_(0) {}
  ~ASTNode() {}

  ASTNodePtr &parentNode() { return parentNode_; }
  std::vector<ASTNodePtr> &childNodes() { return childNodes_; }
  ExternalUTF16StringPtr &kind() { return kind_; }
  uint32_t &sourceLocation() { return sourceLocation_; }
  uint32_t &sourceLength() { return sourceLength_; }

 protected:
  ASTNodePtr parentNode_;
  std::vector<ASTNodePtr> childNodes_;
  ExternalUTF16StringPtr kind_;
  uint32_t sourceLocation_;
  uint32_t sourceLength_;
  // Note: uint32 spans [0, 4 294 967 295] which is definitely enough
};


};  // namespace kod

#endif  // KOD_AST_NODE_H_

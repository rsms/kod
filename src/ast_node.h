#ifndef KOD_AST_NODE_H_
#define KOD_AST_NODE_H_

#include "ExternalUTF16String.h"

#include <vector>
#include <boost/shared_ptr.hpp>

namespace kod {

class ASTNode;
typedef boost::shared_ptr<ASTNode> ASTNodePtr;

class ASTNode {
 public:
  static const uint32_t NotFound = UINT32_MAX;
  ASTNode() : rangeStart_(NotFound), rangeLength_(0) {
  }
  ~ASTNode() {}

  ASTNodePtr &parentNode() { return parentNode_; }
  std::vector<ASTNodePtr> &childNodes() { return childNodes_; }
  ExternalUTF16StringPtr &kind() { return kind_; }

 protected:
  ASTNodePtr parentNode_;
  std::vector<ASTNodePtr> childNodes_;
  ExternalUTF16StringPtr kind_;
  uint32_t rangeStart_;
  uint32_t rangeLength_;
};


};  // namespace kod

#endif  // KOD_AST_NODE_H_

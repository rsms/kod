#ifndef KOD_NODE_AST_NODE_WRAPPER_H_
#define KOD_NODE_AST_NODE_WRAPPER_H_

#include <node.h>
#include "../ASTNode.h"

namespace kod {

class ASTNodeWrapper : public node::ObjectWrap {
 public:
  static v8::Persistent<v8::FunctionTemplate> constructor_template;
  static void Initialize(v8::Handle<v8::Object> target);
  static v8::Handle<v8::Value> New(const v8::Arguments& args);

  static ASTNodePtr UnwrapNode(v8::Handle<v8::Object> obj);

  ASTNodeWrapper() { node_.reset(new ASTNode()); }
  ~ASTNodeWrapper();

  static v8::Handle<v8::Value> PushChild(const v8::Arguments& args);

  static v8::Handle<v8::Value> GetSourceLength(v8::Local<v8::String> property,
                                               const v8::AccessorInfo& info);
  static void SetSourceLength(v8::Local<v8::String> property,
                              v8::Local<v8::Value> value,
                              const v8::AccessorInfo& info);

 protected:
  ASTNodePtr node_;
};


};  // namespace kod

#endif  // KOD_NODE_AST_NODE_WRAPPER_H_

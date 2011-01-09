#include "ASTNodeWrapper.h"

using namespace v8;
using namespace node;
using namespace kod;

Persistent<FunctionTemplate> ASTNodeWrapper::constructor_template;

// -----------------------------------------------------------------------------
// implementation


Handle<Value> ASTNodeWrapper::New(const Arguments& args) {
  HandleScope scope;
  // todo: if called with a string argument, try to parse and load it as a link
  (new ASTNodeWrapper())->Wrap(args.This());
  return args.This();
}


static Handle<Value> GetParentNode(Local<String> property,
                                   const AccessorInfo& info) {
  HandleScope scope;
  ASTNodeWrapper *p = ObjectWrap::Unwrap<ASTNodeWrapper>(info.This());
  return Undefined();
}


void ASTNodeWrapper::Initialize(Handle<Object> target) {
  HandleScope scope;

  Local<String> className = String::NewSymbol("ASTNode");

  Local<FunctionTemplate> t = FunctionTemplate::New(New);
  constructor_template = Persistent<FunctionTemplate>::New(t);
  constructor_template->SetClassName(className);

  Local<ObjectTemplate> instance_t = constructor_template->InstanceTemplate();
  instance_t->SetInternalFieldCount(1);
  instance_t->SetAccessor(String::New("parentNode"), GetParentNode);

  target->Set(className, constructor_template->GetFunction());
}

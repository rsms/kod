#include "ASTNodeWrapper.h"
#include "node_kod.h"

using namespace v8;
using namespace node;
using namespace kod;

Persistent<FunctionTemplate> ASTNodeWrapper::constructor_template;

#define DLOG(fmt, ...) \
    fprintf(stderr, "[%s:%d] " fmt "\n", __FILENAME__, __LINE__, ##__VA_ARGS__);


// -----------------------------------------------------------------------------
// implementation


ASTNodeWrapper::~ASTNodeWrapper() {
  //DLOG("dealloc");
}


ASTNodePtr ASTNodeWrapper::UnwrapNode(v8::Handle<Object> obj) {
  if (obj->InternalFieldCount() > 0) {
    ASTNodeWrapper *nodeWrapper =
        static_cast<ASTNodeWrapper*>(obj->GetPointerFromInternalField(0));
    assert(nodeWrapper != NULL);
    return nodeWrapper->node_;
  } else {
    return ASTNodePtr();
  }
}


v8::Handle<Value> ASTNodeWrapper::New(const Arguments& args) {
  HandleScope scope;
  ASTNodeWrapper *p = new ASTNodeWrapper();
  (p)->Wrap(args.This());

  // parse args:
  // [kind, [sourceLocation, [sourceLength, [parentNode]]]]
  //DLOG("args.Length() -> %d", args.Length());
  if (args.Length() > 0) {
    // kind is currently a string, but should become an int symbol or something
    Local<String> s = args[0]->ToString();
    // TODO(rsms): move this into a ExternalUTF16String constructor
    int len = s->Length();
    uint16_t *ubuf = new uint16_t[len];
    len = s->Write(ubuf, 0, len);
    p->node_->kind() =
        ExternalUTF16StringPtr(new ExternalUTF16String(ubuf, len));

    // sourceLocation and sourceLength
    if (args.Length() > 1)
      p->node_->sourceRange().location = args[1]->IntegerValue();
    if (args.Length() > 2)
      p->node_->sourceRange().length = args[2]->IntegerValue();

    if (args.Length() > 3 && args[3]->IsObject()) {
      // parentNode
      ASTNodePtr parentNode = UnwrapNode(args[3]->ToObject());
      if (!parentNode.get())
        return KN_THROW(TypeError, "last argument must be of instance ASTNode");
      p->node_->parentNode() = parentNode;
    }
  }

  return args.This();
}


v8::Handle<Value> ASTNodeWrapper::PushChild(const Arguments& args) {
  HandleScope scope;

  if (args.Length() != 1 || !args[0]->IsObject())
    return KN_THROW(TypeError, "requires an argument");

  ASTNodePtr childNode = UnwrapNode(args[0]->ToObject());
  if (!childNode.get())
    return KN_THROW(TypeError, "argument must be of instance ASTNode");

  ASTNodeWrapper *self = ASTNodeWrapper::Unwrap<ASTNodeWrapper>(args.This());
  self->node_->childNodes().push_back(childNode);

  return Undefined();
}


static v8::Handle<Value> GetParentNode(Local<String> property,
                                       const AccessorInfo& info) {
  HandleScope scope;
  ASTNodeWrapper *self = ASTNodeWrapper::Unwrap<ASTNodeWrapper>(info.This());
  // TODO implementation
  return Undefined();
}


v8::Handle<Value> ASTNodeWrapper::GetSourceLength(Local<String> property,
                                                  const AccessorInfo& info) {
  HandleScope scope;
  ASTNodeWrapper *self = ASTNodeWrapper::Unwrap<ASTNodeWrapper>(info.This());
  if (self->node_.get()) {
    return scope.Close(Integer::New(self->node_->sourceRange().length));
  }
  return Undefined();
}


void ASTNodeWrapper::SetSourceLength(Local<String> property,
                                     Local<Value> value,
                                     const AccessorInfo& info) {
  HandleScope scope;
  ASTNodeWrapper *self = ASTNodeWrapper::Unwrap<ASTNodeWrapper>(info.This());
  if (self->node_.get()) {
    self->node_->sourceRange().length = value->IntegerValue();
  }
}


void ASTNodeWrapper::Initialize(v8::Handle<Object> target) {
  HandleScope scope;

  Local<String> className = String::NewSymbol("ASTNode");

  Local<FunctionTemplate> t = FunctionTemplate::New(New);
  constructor_template = Persistent<FunctionTemplate>::New(t);
  constructor_template->SetClassName(className);

  NODE_SET_PROTOTYPE_METHOD(t, "pushChild", ASTNodeWrapper::PushChild);

  Local<ObjectTemplate> instance_t = constructor_template->InstanceTemplate();
  instance_t->SetInternalFieldCount(1);
  instance_t->SetAccessor(String::New("parentNode"), GetParentNode);
  instance_t->SetAccessor(String::New("sourceLength"), GetSourceLength,
                          SetSourceLength);

  target->Set(className, constructor_template->GetFunction());
}

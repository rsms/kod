#import "node_kod.h"
#include <map>

#define KN_OBJC_CLASS_ADDITIONS_BEGIN(name) \
  @interface name##_node_ : NSObject {} @end @implementation name##_node_

class KObjectProxy : public node::EventEmitter {
 public:
  static v8::Persistent<v8::FunctionTemplate> Initialize(
      v8::Handle<v8::Object> target,
      v8::Handle<v8::String> className,
      const char *srcObjCClassName=NULL);

  KObjectProxy(id representedObject);
  virtual ~KObjectProxy();

  static v8::Handle<v8::Value> New(const v8::Arguments& args);
  static v8::Local<v8::Object> New(v8::Handle<v8::FunctionTemplate> constructor,
                                   id representedObject);
  static v8::Local<v8::Object> New(id representedObject);

  id representedObject_;

 protected:

  typedef std::map<void*, v8::Persistent<v8::FunctionTemplate> >
      PtrToFunctionTemplateMap;
  static PtrToFunctionTemplateMap constructorMap_;
};

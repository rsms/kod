#import "index.h"
#import "kod_node_interface.h"
#import "knode_ns_additions.h"
#import "kod_version.h"

#import "KDocumentController.h"
#import "KNodeThread.h"


static v8::Handle<Value> GetAllDocuments(const Arguments& args) {
  HandleScope scope;
  KDocumentController *kodController = [KDocumentController kodController];
  NSArray *documents = [kodController documents];
  Local<Value> v = [documents v8Value];
  return scope.Close(v);
}


static v8::Handle<Value> HandleUncaughtException(const Arguments& args) {
  HandleScope scope;
  id err = nil;
  if (args.Length() > 0) {
    if (args[0]->IsObject()) {
      // don't include arguments (just gets messy when converted to objc)
      args[0]->ToObject()->Delete(String::New("arguments"));
    }
    err = [NSObject fromV8Value:args[0]];
  }
  [KNodeThread handleUncaughtException:err];
  return Undefined();
}


extern "C" void init(v8::Handle<Object> target) {
  HandleScope scope;

  // Constants
  target->Set(String::NewSymbol("version"), String::New(K_VERSION_STR));
  target->Set(String::NewSymbol("externalFunctions"), Object::New());

  // Functions
  NODE_SET_METHOD(target, "getAllDocuments", GetAllDocuments);
  NODE_SET_METHOD(target, "handleUncaughtException", HandleUncaughtException);
  
  // init Kod-Node interface
  KNodeInitNode(target);
}

#include "index.h"

// An Objective-C method is simply a C function that take at least two
// arguments—self and _cmd. You can add a function to a class as a method using
// the function class_addMethod. Therefore, given the following function:
//void dynamicMethodIMP(id self, SEL _cmd) {
//  // implementation ....
//}

static Handle<Value> SomeFunction(const Arguments& /*args*/){
  HandleScope scope;
  return scope.Close(Undefined());
}

extern "C" void init(Handle<Object> target) {
  HandleScope scope;

  // Constants
  target->Set(String::NewSymbol("version"), String::New("0.1"));

  // Functions
  //NODE_SET_METHOD(target, "someFunction", SomeFunction);
}

// Main module
#ifndef NODE_KOD_INDEX_H_
#define NODE_KOD_INDEX_H_

// Commonly used headers
#include <node.h>           // includes v8.h, ev.h, eio.h, sys/types.h, etc
#include <node_events.h>    // EventEmitter

// Since we are not building a C++ API, we dont' care about namespaces in .h's
using namespace v8;
using namespace node;

// -----------------------------------------------------------------------------
// Constants

// -----------------------------------------------------------------------------
// Aiding construction of types

// Property getter interface boilerplate
#define GETTER_H(name)\
  static Handle<Value> name(Local<String> property, const AccessorInfo& info)

// Property getter implementation boilerplate
#define GETTER_C(name)\
  Handle<Value> name(Local<String> property, const AccessorInfo& info)

// -----------------------------------------------------------------------------
// Helpers

// Emitting WIP/development notes
#define TODO(tmpl, ...)\
  fprintf(stderr, "TODO [node-kod %s:%d] " tmpl "\n", \
          __FILE__, __LINE__, ##__VA_ARGS__)

// Dump a message to stderr
#define DPRINTF(tmpl, ...)\
  do {\
    fprintf(stderr, "D [node-kod %s:%d] " tmpl "\n", \
            __FILE__, __LINE__, ##__VA_ARGS__);\
    fflush(stderr);\
  } while (0)

// Throwing exceptions
#define JS_THROW(t, s) ThrowException(Exception::t(String::New(s)))
#define JS_THROWF(tmpl, ...) {\
  char msg[1024];\
  snprintf(msg, sizeof(msg), tmpl, __VA_ARGS__);\
  JS_THROW(msg);\
}

// Creates a new UTF-8 C string from a Value.
// Note: if you only need to access the string (i.e. not make a copy of it) you
// can use String::Utf8Value:
//   String::Utf8Value foo(value);
//   const char *temp = *foo;
static inline char* ToCString(Handle<Value> value) {
  Local<String> str = value->ToString();
  char *p = new char[str->Utf8Length()];
  str->WriteUtf8(p);
  return p;
}

// -----------------------------------------------------------------------------
#endif  // NODE_KOD_INDEX_H_

// Main module
#ifndef NODE_KOD_INDEX_H_
#define NODE_KOD_INDEX_H_

// Commonly used headers
#import <node.h>           // includes v8.h, ev.h, eio.h, sys/types.h, etc
#import <node_events.h>    // EventEmitter

#ifdef __OBJC__
#import <Cocoa/Cocoa.h>
#endif

// -----------------------------------------------------------------------------
// Constants

// -----------------------------------------------------------------------------
// Aiding construction of types

// Property getter interface boilerplate
#define KN_GETTER_H(name)\
  static Handle<Value> name(Local<String> property, const AccessorInfo& info)

// Property getter implementation boilerplate
#define KN_GETTER_C(name)\
  Handle<Value> name(Local<String> property, const AccessorInfo& info)

// -----------------------------------------------------------------------------
// Helpers

#ifndef __FILENAME__
  #define __FILENAME__ ((strrchr(__FILE__, '/') ?: __FILE__ - 1) + 1)
#endif

#if !NDEBUG
  // Emitting WIP/development notes
  #define KN_TODO(tmpl, ...)\
    fprintf(stderr, "TODO [node-kod %s:%d] " tmpl "\n", \
            __FILENAME__, __LINE__, ##__VA_ARGS__)
  // Dump a message to stderr
  #define KN_DLOG(tmpl, ...)\
    do {\
      fprintf(stderr, "D [node-kod %s:%d] " tmpl "\n", \
              __FILENAME__, __LINE__, ##__VA_ARGS__);\
      fflush(stderr);\
    } while (0)
#else
  #define KN_DLOG(...) ((void)0)
#endif  // !NDEBUG

// Throwing exceptions
#define KN_THROW(t, s) ThrowException(Exception::t(String::New(s)))
#define KN_THROWF(tmpl, ...) {\
  char msg[1024];\
  snprintf(msg, sizeof(msg), tmpl, __VA_ARGS__);\
  KN_THROW(msg);\
}

// Creates a new UTF-8 C string from a Value.
// Note: if you only need to access the string (i.e. not make a copy of it) you
// can use String::Utf8Value:
//   String::Utf8Value foo(value);
//   const char *temp = *foo;
static inline char* KNToCString(v8::Handle<v8::Value> value) {
  v8::Local<v8::String> str = value->ToString();
  char *p = new char[str->Utf8Length()];
  str->WriteUtf8(p);
  return p;
}

// Initialize this module
void node_kod_init(v8::Handle<v8::Object> target);

// -----------------------------------------------------------------------------
#endif  // NODE_KOD_INDEX_H_

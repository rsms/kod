#import "knode_ns_additions.h"

#import <err.h>
#import <node_buffer.h>
#import <vector>
#import <objc/runtime.h>

using namespace v8;

static Local<Value> _NodeEval(v8::Handle<String> source,
                              v8::Handle<String> name) {
  HandleScope scope;
  Local<v8::Script> script = v8::Script::Compile(source, name);
  Local<Value> result;
  if (!script.IsEmpty()) result = script->Run();
  return scope.Close(result);
}


class BuildContext {
 public:
  static Persistent<Function> indexOf;

  Persistent<Array> values;
  int depth;
  std::vector<NSObject*> objects;

  BuildContext() : depth(0) {
    HandleScope scope;
    if (indexOf.IsEmpty()) {
      Local<Value> v = _NodeEval(String::New("Array.prototype.indexOf"),
                                 String::NewSymbol("<string>"));
      assert(!v.IsEmpty() && v->IsFunction());
      indexOf = Persistent<Function>::New(Local<Function>::Cast(v));
    }
    values = Persistent<Array>::New(Array::New());
  }

  ~BuildContext() {
    values.Dispose();
    values.Clear();
  }

  class Scope {
    BuildContext *bctx_;
   public:
    Scope(BuildContext *bctx) : bctx_(bctx) {
      ++bctx_->depth;
      if (bctx_->depth > 256)
        errx(33, "fatal: depth limit hit in [NSObject fromV8Value]");
    }
    ~Scope() { --bctx_->depth; }
  };

  NSObject *ObjectForValue(Local<Value> value) {
    HandleScope scope;
    Local<Value> v = indexOf->Call(values, 1, &value);
    assert(!v.IsEmpty() && v->IsInt32());
    int i = v->Int32Value();
    if (i != -1) {
      return objects[i];
    }
    return nil;
  }

  void SetObjectForValue(NSObject* object, Local<Value> value) {
    HandleScope scope;
    values->Set(values->Length(), value);
    objects.push_back(object);
  }
};

Persistent<Function> BuildContext::indexOf;

@implementation NSObject (v8)

+ (id)fromV8Value:(v8::Local<v8::Value>)v buildContext:(BuildContext*)bctx {
  BuildContext::Scope bscope(bctx);
  if (v.IsEmpty()) return nil;
  if (v->IsUndefined() || v->IsNull()) return [NSNull null];
  if (v->IsBoolean()) return [NSNumber numberWithBool:v->BooleanValue()];
  if (v->IsInt32())   return [NSNumber numberWithInt:v->Int32Value()];
  if (v->IsUint32())  return [NSNumber numberWithUnsignedInt:v->Uint32Value()];
  if (v->IsNumber())  return [NSNumber numberWithDouble:v->NumberValue()];
  HandleScope scope;
  if (v->IsExternal())
    return [NSValue valueWithPointer:(External::Unwrap(v))];
  if (v->IsString() || v->IsRegExp())
    return [NSString stringWithV8String:v->ToString()];
  //if (v->IsFunction())
  //  return nil; // not supported

  // Date --> NSDate
  if (v->IsDate()) {
    double ms = Local<Date>::Cast(v)->NumberValue();
    return [NSDate dateWithTimeIntervalSince1970:ms/1000.0];
  }

  // Array --> NSArray
  if (v->IsArray()) {
    NSObject *obj = bctx->ObjectForValue(v);
    if (obj) return obj;
    Local<Array> a = Local<Array>::Cast(v);
    uint32 i = 0, count = a->Length();
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:count];
    bctx->SetObjectForValue(array, v);
    for (; i < count; ++i) {
      obj = [self fromV8Value:a->Get(i) buildContext:bctx];
      if (obj) [array addObject:obj];
    }
    return array;
  }

  // node::Buffer --> NSData
  if (v->IsObject() && node::Buffer::HasInstance(v)) {
    NSObject *obj = bctx->ObjectForValue(v);
    if (obj) return obj;
    Local<Object> bufobj = v->ToObject();
    char* data = node::Buffer::Data(bufobj);
    size_t length = node::Buffer::Length(bufobj);
    NSData *nsdata = [NSData dataWithBytes:data length:length];
    bctx->SetObjectForValue(nsdata, v);
    return nsdata;
  }

  // Object --> Dictionary
  if (v->IsObject()) {
    NSObject *obj = bctx->ObjectForValue(v);
    if (obj) return obj;
    Local<Object> o = v->ToObject();
    Local<Array> props = o->GetPropertyNames();
    uint32 i = 0, count = props->Length();
    NSMutableDictionary* dict =
        [NSMutableDictionary dictionaryWithCapacity:count];
    bctx->SetObjectForValue(dict, v);
    for (; i < count; ++i) {
      Local<String> k = props->Get(i)->ToString();
      NSString *kobj = [NSString stringWithV8String:k];
      NSObject *vobj = [self fromV8Value:o->Get(k) buildContext:bctx];
      if (vobj)
        [dict setObject:vobj forKey:kobj];
    }
    return dict;
  }

  return nil;
}

+ (id)fromV8Value:(v8::Local<v8::Value>)v {
  BuildContext bctx;
  return [self fromV8Value:v buildContext:&bctx];
}

- (Local<Value>)v8Value {
  // generic converter
  HandleScope scope;
  return scope.Close(String::New([[self description] UTF8String]));
}

@end

@implementation NSNumber (v8)
- (Local<Value>)v8Value {
  HandleScope scope;
  const char *ts = [self objCType];
  assert(ts != NULL);
  switch (ts[0]) {
    case _C_UCHR:
    case _C_SHT:
    case _C_USHT:
    case _C_INT:
      return scope.Close(Integer::New([self intValue]));
    case _C_UINT:
      return scope.Close(Integer::New([self unsignedIntValue]));
    case _C_LNG:
      return scope.Close(Integer::New([self longValue]));
    case _C_ULNG:
      return scope.Close(Integer::New([self unsignedLongValue]));
    case _C_LNG_LNG:
      return scope.Close(Integer::New([self longLongValue]));
    case _C_ULNG_LNG:
      return scope.Close(Integer::New([self unsignedLongLongValue]));
    case _C_FLT:
      return scope.Close(Number::New([self floatValue]));
    case _C_DBL:
      return scope.Close(Number::New([self doubleValue]));
    case _C_BOOL:
    case _C_CHR:
      return scope.Close(Local<Value>::New(
          v8::Boolean::New([self boolValue] == YES)));
    default:
      break;
  }
  return *Undefined();
}
@end

@implementation NSString (v8)
- (Local<Value>)v8Value {
  HandleScope scope;
  return scope.Close(String::New([self UTF8String]));
}
+ (NSString*)stringWithV8String:(Local<String>)str {
  String::Utf8Value utf8(str);
  return [NSString stringWithUTF8String:*utf8];
}
@end

@implementation NSNull (v8)
- (Local<Value>)v8Value {
  HandleScope scope;
  return scope.Close(Local<Value>::New(v8::Null()));
}
@end

@implementation NSDate (v8)
- (Local<Value>)v8Value {
  HandleScope scope;
  return scope.Close(Date::New((double)[self timeIntervalSince1970] * 1000.0));
}
@end

@implementation NSValue (v8)
- (Local<Value>)v8Value {
  HandleScope scope;
  return scope.Close(External::Wrap([self pointerValue]));
}
@end

@implementation NSArray (v8)
- (Local<Value>)v8Value {
  HandleScope scope;
  NSUInteger i = 0, count = [self count];
  Local<Array> a = Array::New(count);
  for (; i < count; i++) {
    a->Set(i, [[self objectAtIndex:i] v8Value]);
  }
  return scope.Close(a);
}
@end

@implementation NSSet (v8)
- (Local<Value>)v8Value {
  HandleScope scope;
  NSUInteger i = 0, count = [self count];
  Local<Array> a = Array::New(count);
  for (NSObject* obj in self) {
    a->Set(i++, [obj v8Value]);
  }
  return scope.Close(a);
}
@end

@implementation NSDictionary (v8)
- (Local<Value>)v8Value {
  HandleScope scope;
  Local<Object> o = Object::New();
  [self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop){
    assert([key isKindOfClass:[NSString class]]);
    o->Set(String::New([key UTF8String]), [obj v8Value]);
  }];
  return scope.Close(o);
}
@end


@implementation NSData (node)
- (Local<Value>)v8Value {
  HandleScope scope;

  // Note: The following _might_ cause a race condition if called at the same
  // time by two node threads and might cause unknown magic spooky stuff if
  // called by one node thread and later used by another.
  static Persistent<Function> BufferConstructor;
  if (BufferConstructor.IsEmpty()) {
    HandleScope tmplscope;
    Local<Object> global = Context::GetCurrent()->Global();
    Local<Value> Buffer_v = global->Get(String::NewSymbol("Buffer"));
    assert(Buffer_v->IsFunction());
    BufferConstructor = Persistent<Function>::New(
        tmplscope.Close(Local<Function>::Cast(Buffer_v)));
  }

  Local<Value> argv[] = {Integer::New([self length])};
  Local<Value> buf = BufferConstructor->NewInstance(1, argv);

  char *dataptr = node::Buffer::Data(Local<Object>::Cast(buf));
  assert(dataptr != NULL);
  [self getBytes:dataptr length:[self length]];

  return scope.Close(buf);
}
@end

// ----------------------------------------------------------------------------

// acquire a pointer to an UTF-8 representation of |value|s
inline const char* ToCString(const v8::String::Utf8Value& value) {
  return *value ? *value : "<str conversion failed>";
}


static NSString *ExceptionToNSString(Local<Value> &er) {
  if (er.IsEmpty()) return [NSString stringWithString:@"undefined"];
  String::Utf8Value msg(!er->IsObject() ? er->ToString()
                                        : er->ToObject()->Get(
                                         String::New("message"))->ToString());
  return [NSString stringWithUTF8String:*msg];
}


static NSMutableDictionary* TryCatchToErrorDict(TryCatch &try_catch) {
  NSMutableDictionary* info = [NSMutableDictionary dictionary];
  v8::Handle<Message> message = try_catch.Message();
  if (!message.IsEmpty()) {
    String::Utf8Value filename(message->GetScriptResourceName());
    [info setObject:[NSString stringWithUTF8String:ToCString(filename)]
             forKey:@"filename"];
    [info setObject:[NSNumber numberWithInt:message->GetLineNumber()]
             forKey:@"lineno"];
    String::Utf8Value sourceline(message->GetSourceLine());
    [info setObject:[NSString stringWithUTF8String:ToCString(sourceline)]
             forKey:@"sourceline"];
  }
  String::Utf8Value trace(try_catch.StackTrace());
  if (trace.length() > 0) {
    [info setObject:[NSString stringWithUTF8String:*trace]
             forKey:NSLocalizedDescriptionKey];
  } else {
    // this really only happens for RangeErrors, since they're the only
    // kind that won't have all this info in the trace.
    Local<Value> er = try_catch.Exception();
    if (!er.IsEmpty())
      [info setObject:ExceptionToNSString(er) forKey:NSLocalizedDescriptionKey];
  }
  return info;
}


NSString * const KNodeErrorDomain = @"node.js";

@implementation NSError (v8)
+ (NSError*)nodeErrorWithTryCatch:(TryCatch &)try_catch {
  NSMutableDictionary* info = nil;
  if (try_catch.HasCaught())
    info = TryCatchToErrorDict(try_catch);
  return [NSError errorWithDomain:KNodeErrorDomain code:0 userInfo:info];
}

+ (NSError *)nodeErrorWithFormat:(NSString *)format, ... {
  va_list src, dest;
  va_start(src, format);
  va_copy(dest, src);
  va_end(src);
  NSString *msg = [[NSString alloc] initWithFormat:format arguments:dest];
  return [NSError errorWithDomain:KNodeErrorDomain code:0 userInfo:
      [NSDictionary dictionaryWithObject:msg forKey:NSLocalizedDescriptionKey]];
}
@end

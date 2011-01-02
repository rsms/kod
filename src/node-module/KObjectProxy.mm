#import "KObjectProxy.h"
#import "knode_ns_additions.h"
#import "kod_node_interface.h"
#import "k_objc_prop.h"
#import "common.h"

#include <objc/runtime.h>
#include <objc/message.h>

using namespace v8;
using namespace node;

Persistent<FunctionTemplate> KObjectProxy::constructor_template;

// ----------------------------------------------------------------------------

class ARPoolScope {
 public:
  NSAutoreleasePool *pool_;
  ARPoolScope() { pool_ = [NSAutoreleasePool new]; }
  ~ARPoolScope() { [pool_ drain]; pool_ = nil; }
};

// ----------------------------------------------------------------------------

// Unique key for the persistent wrapper associated object
static char kPersistentWrapperKey = 'a';

@interface _KObjectProxyShelf : NSObject {} @end
@implementation _KObjectProxyShelf
- (void)_KObjectProxy_dealloc_associations {
  //DLOG("_KObjectProxy_dealloc_associations for %p", self);

  // clear wrapper
  NSValue *v = objc_getAssociatedObject(self, &kPersistentWrapperKey);
  if (v) {
    Persistent<Object> *pobj = (Persistent<Object>*)[v pointerValue];
    if (!pobj->IsEmpty()) {
      KObjectProxy *p = ObjectWrap::Unwrap<KObjectProxy>(*pobj);
      // clear the represented object, but only if it's self
      if (h_atomic_cas(&(p->representedObject_), self, nil)) {
        // queue object for being totally cleared
        KNodePerformInNode(
            new KNodeInvocationIOEntry(*pobj, "onProxyTargetDeleted"));
      }
      pobj->Dispose();
      pobj->Clear();
    }
    delete pobj;
  }

  // remove the NSValue
  objc_setAssociatedObject(self, &kPersistentWrapperKey, nil,
                           OBJC_ASSOCIATION_RETAIN);

  // invokes the actual dealloc method (we are swizzling, baby)
  [self _KObjectProxy_dealloc_associations];
}
@end

// ----------------------------------------------------------------------------

#define CHECKPOINT() do { \
  fprintf(stderr, "\n-- CHECKPOINT %s:%d --\n", __FILE__, __LINE__); \
  fflush(stderr); } while(0)


/*static inline void hobjc_swizzle(Class cls, SEL origsel, SEL newsel) {
  Method origMethod = class_getInstanceMethod(cls, origsel);
  Method newMethod = class_getInstanceMethod(cls, newsel);
  if (class_addMethod(cls, origsel, method_getImplementation(newMethod),
                      method_getTypeEncoding(newMethod))) {
    class_replaceMethod(cls, newsel, method_getImplementation(origMethod),
                        method_getTypeEncoding(origMethod));
  } else {
    method_exchangeImplementations(origMethod, newMethod);
  }
}*/

static BOOL KNodeEnableProxyForObjCClass(const char *name,
                                         const char *srcName) {
  static const char *suffix = "_node_";
  Class srcCls;

  if (!srcName) {
    char srcNameBuf[1024];
    int len = MIN(1023-strlen(suffix), strlen(name));
    if (!strncpy(srcNameBuf, name, len)) return NO;
    if (!strncpy(srcNameBuf+len, suffix, strlen(suffix))) return NO;
    len += strlen(suffix);
    srcNameBuf[len] = '\0';
    srcCls = (Class)objc_getClass(srcNameBuf);
  } else {
    srcCls = (Class)objc_getClass(srcName);
  }
  if (!srcCls) return NO;

  Class dstCls = (Class)objc_getClass(name);
  if (!dstCls) return NO;

  // copy all methods
  unsigned int methodsCount = 0;
  Method *methods = class_copyMethodList(srcCls, &methodsCount);
  for (unsigned int i=0; i<methodsCount; ++i) {
    Method m = methods[i];
    SEL name = method_getName(m);
    IMP imp = method_getImplementation(m);
    const char *types = method_getTypeEncoding(m);
    class_addMethod(dstCls, name, imp, types);
    // note: class_addMethod returns true if the method was not already defined
    // and thus was added. NO is returned when the method is already defined
  }
  free(methods);

  // mixin a dealloc method which releases any associated objects
  SEL origsel = @selector(dealloc);
  SEL newsel = @selector(_KObjectProxy_dealloc_associations);
  Class shelfClass = [_KObjectProxyShelf class];
  Method origm = class_getInstanceMethod(dstCls, origsel);
  Method newm = class_getInstanceMethod(shelfClass, newsel);
  if (class_addMethod(dstCls, origsel, method_getImplementation(newm),
                      method_getTypeEncoding(newm))) {
    //DLOG("added new -dealloc for class '%s'", name);
    // we added @dealloc with impl from @_KObjectProxy_dealloc_associations
    Class superCls = class_getSuperclass(dstCls); 
    Method m = class_getInstanceMethod(superCls, origsel);
    class_replaceMethod(dstCls, newsel, method_getImplementation(m),
                        method_getTypeEncoding(m));
  } else {
    // there is already a dealloc function defined -- let's define newsel
    Method m = class_getInstanceMethod(dstCls, origsel);
    class_addMethod(dstCls, newsel, method_getImplementation(newm),
                    method_getTypeEncoding(newm));
    newm = class_getInstanceMethod(dstCls, newsel);
    method_exchangeImplementations(origm, newm);
  }

  return YES;
}

// ----------------------------------------------------------------------------
// KObjectProxy implementation

KObjectProxy::KObjectProxy(id representedObject) : node::EventEmitter() {
  representedObject_ = representedObject ? [representedObject retain] : NULL;
  //fprintf(stderr, "\n------------> allocated KObjectProxy %p\n\n", this);
}

KObjectProxy::~KObjectProxy() {
  //fprintf(stderr, "\n------------> dealloc KObjectProxy %p wrapping %p\n\n",
  //        this, representedObject_);
  [representedObject_ release];
}

v8::Local<Object> KObjectProxy::New(id representedObject) {
  Local<Object> instance =
      constructor_template->GetFunction()->NewInstance(0, NULL);
  KObjectProxy *p = ObjectWrap::Unwrap<KObjectProxy>(instance);
  p->representedObject_ = representedObject ? [representedObject retain] : NULL;
  return instance;
}

v8::Handle<Value> KObjectProxy::New(const Arguments& args) {
  (new KObjectProxy(NULL))->Wrap(args.This());
  return args.This();
}

// ----------------------------------------------------------------------------
// named property handlers


static NSInvocation *_findInvocation(KObjectProxy *p, NSString *selectorName) {
  HandleScope scope;
  if (!selectorName || !p->representedObject_)
    return NULL;

  // find method with name "key"
  SEL sel = NSSelectorFromString(selectorName);
  //NSLog(@"keysel -> %@", keysel ? NSStringFromSelector(keysel) : nil);
  NSInvocation *invocation = nil;
  NSMethodSignature *msig =
      [p->representedObject_ methodSignatureForSelector:sel];
  //NSLog(@"msig -> %@", msig);
  if (msig) {
    invocation = [NSInvocation invocationWithMethodSignature:msig];
    [invocation setSelector:sel];
    [invocation setTarget:p->representedObject_];
    //[invocation setArgument:&newThickness atIndex:2];
  }
  return invocation;
}


static BOOL _invokeSetter(NSInvocation *invocation,
                          char typecode,
                          Local<Value> &value) {
  switch (typecode) {
    case '"': {
      String::Utf8Value utf8pch(value->ToString());
      id arg2 = [NSString stringWithUTF8String:*utf8pch];
      // Note(rsms): we need to use objc_msgSend directly in the case of string
      // arguments for some weird reason. [invocation invoke] causes
      // "+[NSCFString length]: unrecognized selector" and finally a
      // NSInvalidArgumentException to be raised.
      objc_msgSend([invocation target], [invocation selector], arg2);
      //[invocation setArgument:arg2 atIndex:2];
      //[invocation invoke];
      break;
    }
    case _C_ID: {
      String::Utf8Value utf8pch(value->ToString());
      [invocation setArgument:[NSString stringWithUTF8String:*utf8pch]
                      atIndex:2];
      [invocation invoke];
      break;
    }
    case _C_INT:
    case _C_UINT:
    case _C_LNG:
    case _C_ULNG:
    case _C_LNG_LNG:
    case _C_ULNG_LNG: {
      int64_t d = value->IntegerValue();
      [invocation setArgument:(void*)&d atIndex:2];
      [invocation invoke];
      break;
    }
    case _C_FLT:
    case _C_DBL: {
      double f = value->NumberValue();
      [invocation setArgument:(void*)&f atIndex:2];
      [invocation invoke];
      break;
    }
    case _C_CHR:
    case _C_BOOL: {
      BOOL b = !!value->BooleanValue();
      [invocation setArgument:(void*)&b atIndex:2];
      [invocation invoke];
      break;
    }
    case _C_CHARPTR: {
      String::Utf8Value utf8pch(value->ToString());
      const char *pch = *utf8pch;
      [invocation setArgument:(void*)&pch atIndex:2];
      [invocation invoke];
      break;
    }
    default:
      KN_DLOG("_invokeSetter: unable to handle typecode '%c'", typecode);
      return NO;
  }
  return YES;
}


static BOOL _invokeGetter(NSInvocation *invocation,
                          Local<Value> &returnValue) {
  [invocation invoke];
  NSMethodSignature *msig = [invocation methodSignature];
  const char *rtype = [msig methodReturnType];
  assert(rtype != NULL);
  //NSLog(@"rtype[0] -> %c", rtype[0]);
  switch (rtype[0]) {
    case _C_ID: {
      id rv = nil;
      [invocation getReturnValue:&rv];
      returnValue = rv ? [rv v8Value] : *v8::Null();
      break;
    }
    case _C_INT: {
      int rv;
      [invocation getReturnValue:&rv];
      returnValue = Integer::New(rv);
      break;
    }
    case _C_UINT: {
      unsigned int rv;
      [invocation getReturnValue:&rv];
      returnValue = Integer::New(rv);
      break;
    }
    case _C_LNG: {
      long rv;
      [invocation getReturnValue:&rv];
      returnValue = Integer::New(rv);
      break;
    }
    case _C_ULNG: {
      unsigned long rv;
      [invocation getReturnValue:&rv];
      returnValue = Integer::New(rv);
      break;
    }
    case _C_LNG_LNG: {
      long long rv;
      [invocation getReturnValue:&rv];
      returnValue = Integer::New(rv);
      break;
    }
    case _C_ULNG_LNG: {
      unsigned long long rv;
      [invocation getReturnValue:&rv];
      returnValue = Integer::New(rv);
      break;
    }
    case _C_FLT: {
      float rv;
      [invocation getReturnValue:&rv];
      returnValue = Number::New(rv);
      break;
    }
    case _C_DBL: {
      double rv;
      [invocation getReturnValue:&rv];
      returnValue = Number::New(rv);
      break;
    }
    case _C_CHR:
    case _C_BOOL: {
      BOOL rv;
      [invocation getReturnValue:&rv];
      returnValue = *v8::Boolean::New(!!rv);
      break;
    }
    case _C_CHARPTR: {
      char *rv;
      [invocation getReturnValue:&rv];
      if (rv) returnValue = String::New(rv);
      else returnValue = *v8::Null();
      break;
    }
    default:
      return NO;
  }
  return YES;
}


static v8::Handle<Value> NamedGetter(Local<String> property,
                                     const AccessorInfo& info) {
  HandleScope scope;
  ARPoolScope poolScope;

  KObjectProxy *p = ObjectWrap::Unwrap<KObjectProxy>(info.This());
  String::Utf8Value _name(property); const char *name = *_name;
  Local<Value> returnValue;

  NSString *selectorName = [NSString stringWithUTF8String:name];
  if ([selectorName isEqualToString:@"inspect"]) {
    // special case -- called to return an inspect function for util.inspect
    selectorName = @"nodeInspect";
    name = "nodeInspect";
  }

  //KN_DLOG("%s '%s'", __FUNCTION__, name);

  objc_property_t prop = class_getProperty([p->representedObject_ class], name);
  if (prop) {
    KObjCPropFlags propflags =
        k_objc_propattrs(prop, NULL, &selectorName, NULL);
    NSInvocation *invocation;
    if ((propflags & KObjCPropReadable) &&
        (invocation = _findInvocation(p, selectorName))) {
      //KN_DLOG("%s (property: %s, invocation: %p, sel: %s)", __FUNCTION__,
      //        name, invocation, [selectorName UTF8String]);
      _invokeGetter(invocation, returnValue);
    }
  } else {
    NSInvocation *invocation = _findInvocation(p, selectorName);
    if (invocation) {
      KN_DLOG("TODO find and return wrapped function '%s'", name);
    }
  }

  // do something with p
  return scope.Close(returnValue);
}



static v8::Handle<Value> NamedSetter(Local<String> property,
                                     Local<Value> value,
                                     const AccessorInfo& info) {
  HandleScope scope;
  ARPoolScope poolScope;
  Local<Value> r;

  KObjectProxy *p = ObjectWrap::Unwrap<KObjectProxy>(info.This());
  String::Utf8Value _name(property); const char *name = *_name;
  //KN_DLOG("%s '%s'", __FUNCTION__, name);

  objc_property_t prop = class_getProperty([p->representedObject_ class], name);
  if (prop) {
    char typecode;
    NSString *getterName, *setterName;
    KObjCPropFlags propflags =
        k_objc_propattrs(prop, &typecode, &getterName, &setterName);
    if (propflags & KObjCPropWritable) {
      NSInvocation *invocation = _findInvocation(p, setterName);
      if (invocation) {
        if (_invokeSetter(invocation, typecode, value)) {
          return scope.Close(value);
        }
      }
    }
  }

  return scope.Close(r);
}


/**
 * Returns a non-empty handle if the interceptor intercepts the request.
 * The result is an integer encoding property attributes (like v8::None,
 * v8::DontEnum, etc.)
 */
static v8::Handle<Integer> NamedQuery(Local<String> property,
                                      const AccessorInfo& info) {
  HandleScope scope;
  KObjectProxy *p = ObjectWrap::Unwrap<KObjectProxy>(info.This());
  String::Utf8Value _name(property); const char *name = *_name;
  //KN_DLOG("%s '%s'", __FUNCTION__, name);
  v8::Local<Integer> r;
  objc_property_t prop = class_getProperty([p->representedObject_ class], name);
  if (prop) {
    int flags = v8::DontDelete;
    KObjCPropFlags propflags = k_objc_propattrs(prop, NULL, NULL, NULL);
    if (!(propflags & KObjCPropWritable))
      flags |= v8::ReadOnly;
    r = Integer::New(flags);
  }
  return scope.Close(r);
}


/**
 * Returns a non-empty handle if the deleter intercepts the request.
 * The return value is true if the property could be deleted and false
 * otherwise.
 */
static v8::Handle<v8::Boolean> NamedDeleter(Local<String> property,
                                            const AccessorInfo& info) {
  HandleScope scope;
  v8::Local<v8::Boolean> r;
  KObjectProxy *p = ObjectWrap::Unwrap<KObjectProxy>(info.This());
  String::Utf8Value _name(property); const char *name = *_name;
  objc_property_t prop = class_getProperty([p->representedObject_ class], name);
  if (prop) {
    // No properties can be deleted from a proxy object
    r = *v8::False();
  }
  return scope.Close(r);
}


/**
 * Returns an array containing the names of the properties the named
 * property getter intercepts.
 */
static v8::Handle<Array> NamedEnumerator(const AccessorInfo& info) {
  HandleScope scope;
  //KN_DLOG("%s", __PRETTY_FUNCTION__);
  KObjectProxy *p = ObjectWrap::Unwrap<KObjectProxy>(info.This());

  unsigned int propsCount;
  Class cls = [p->representedObject_ class];
  objc_property_t *props = class_copyPropertyList(cls, &propsCount);
  Local<Array> list = Array::New(propsCount);
  uint32_t index = 0;

  for (unsigned int i=0; i<propsCount; ++i) {
    KObjCPropFlags propflags = k_objc_propattrs(props[i], NULL, NULL, NULL);
    if (propflags & KObjCPropReadable) {
      list->Set(index++, String::New(property_getName(props[i])));
    }
  }
  free(props);

  // TODO: list methods and include methods which match the property pattern:
  //  -*
  //  -set*: AND -* exists
  //
  // Other methods should be included as well when we support wrapping methods
  // in v8 functions

  return scope.Close(list);
}


static v8::Handle<Value> OnProxyTargetDeleted(const Arguments& args) {
  HandleScope scope;

  // remove _all_ properties
  Local<Object> self = args.This();
  Local<Array> propertyNames = self->GetPropertyNames();
  int i = 0, L = propertyNames->Length();
  for (; i<L; ++i) {
    Local<String> k = propertyNames->Get(i)->ToString();
    self->ForceDelete(k);
  }

  return scope.Close(Undefined());
}



void KObjectProxy::Initialize(v8::Handle<Object> target,
                              v8::Handle<v8::String> className,
                              const char *srcObjCClassName) {
  HandleScope scope;
  Local<FunctionTemplate> t = FunctionTemplate::New(New);
  constructor_template = Persistent<FunctionTemplate>::New(t);
  constructor_template->SetClassName(className);
  constructor_template->Inherit(EventEmitter::constructor_template);
  
  NODE_SET_PROTOTYPE_METHOD(constructor_template, "onProxyTargetDeleted",
                            OnProxyTargetDeleted);

  Local<ObjectTemplate> instance_t = constructor_template->InstanceTemplate();
  instance_t->SetInternalFieldCount(1);

  /**
   * Sets a named property handler on the object template.
   *
   * Whenever a named property is accessed on objects created from
   * this object template, the provided callback is invoked instead of
   * accessing the property directly on the JavaScript object.
   *
   * \param getter The callback to invoke when getting a property.
   * \param setter The callback to invoke when setting a property.
   * \param query The callback to invoke to check if a property is present,
   *   and if present, get its attributes.
   * \param deleter The callback to invoke when deleting a property.
   * \param enumerator The callback to invoke to enumerate all the named
   *   properties of an object.
   * \param data A piece of data that will be passed to the callbacks
   *   whenever they are invoked.
   */
  instance_t->SetNamedPropertyHandler(NamedGetter, NamedSetter,
                                      NamedQuery, NamedDeleter,
                                      NamedEnumerator
                                      //Handle<Value> data = Handle<Value>()
                                      );

  target->Set(className, constructor_template->GetFunction());


  // Curry Objective-C class
  if (!srcObjCClassName)
    srcObjCClassName = "NSObject_node_";
  String::Utf8Value utf8name(className);
  if (KNodeEnableProxyForObjCClass(*utf8name, srcObjCClassName)) {
    KN_DLOG("curried objc class '%s' from '%s'", *utf8name, srcObjCClassName);
  } else {
    WLOG("failed to curry objc class '%s'", *utf8name);
  }
}


// ----------------------------------------------------------------------------

// Standard base curry source (sauce?)
KN_OBJC_CLASS_ADDITIONS_BEGIN(NSObject)

// this can be implemented by classes being wrapped in order for their wrappers
// to be persistent. A persistent wrapper will persist(doh!), thus any custom
// assigned properties will not disappear between calls. However, a persisten
// wrapper uses some extra memory.
- (BOOL)nodeWrapperIsPersistent {
  return NO;
}

// Returns a wrapper for the receiver
- (v8::Local<v8::Value>)v8Value {
  HandleScope scope;
  if ([self nodeWrapperIsPersistent]) {
    NSValue *v = objc_getAssociatedObject(self, &kPersistentWrapperKey);
    if (!v) {
      Local<Object> obj = KObjectProxy::New(self);
      Persistent<Object> *pobj = KNodePersistentObjectCreate(obj);
      v = [NSValue valueWithPointer:pobj];
      objc_setAssociatedObject(self, &kPersistentWrapperKey, v,
                               OBJC_ASSOCIATION_RETAIN);
      [self autorelease]; // to avoid referencing ourselves
      return scope.Close(obj);
    } else {
      //DLOG("return cached persistent");
      Persistent<Object> *pobj = (Persistent<Object>*)[v pointerValue];
      return scope.Close(*pobj);
    }
  } else {
    Local<Value> instance = KObjectProxy::New(self);
    return scope.Close(instance);
  }
  return *Undefined();
}


@end

#import "common.h"
#import "kod_node_interface.h"
#import "knode_ns_additions.h"

#import <node.h>
#import <ev.h>
#import <libkern/OSAtomic.h>

/*!
 * --- hack hack hack ---
 * This code is compiled into Kod, and not this module
 */

using namespace v8;

void DummyFunction() { }
#define KnownAddress ((char *) ::DummyFunction)
#define cxx_offsetof(type, member) \
  (((char *) &((type *) KnownAddress)->member) - KnownAddress)

static inline v8::Persistent<v8::Object>* pobj_create(
    const v8::Local<v8::Value> &v) {
  v8::Persistent<v8::Object> *pobj = new v8::Persistent<v8::Object>();
  *pobj = v8::Persistent<v8::Object>::New(v8::Local<v8::Object>::Cast(v));
  return pobj;
}

static inline v8::Persistent<v8::Object>* pobj_unwrap(void *data) {
  v8::Persistent<v8::Object> *pobj =
    reinterpret_cast<v8::Persistent<v8::Object>*>(data);
  assert((*pobj)->IsObject());
  return pobj;
}

static inline void pobj_destroy(v8::Persistent<v8::Object> *pobj) {
  pobj->Dispose();
  delete pobj;
}

// ----------------------

// queue with entries of type KNodeIOEntry*
static OSQueueHead KNodeIOInputQueue;

// ev notifier
static ev_async KNodeIOInputQueueNotifier;

// maps mathod names to functions
static v8::Persistent<v8::Object> *kExposedFunctions = NULL;

// publicly available "kod" module object (based on EventEmitter)
Persistent<Object> gKodNodeModule;

// max number of entries to dequeue in one flush
#define KNODE_MAX_DEQUEUE 100

// ----------------------

// Triggered when there are stuff on inputQueue_
static void InputQueueNotification(EV_P_ ev_async *watcher, int revents) {
  HandleScope scope;
  //NSLog(@"InputQueueNotification");

  // enumerate queue
  // since we use a LIFO queue for atomicity, we need to reverse the order
  KNodeIOEntry* entries[KNODE_MAX_DEQUEUE+1];
  int i = 0;
  KNodeIOEntry* entry;
  while ( (entry = (KNodeIOEntry*)OSAtomicDequeue(
           &KNodeIOInputQueue, cxx_offsetof(KNodeIOEntry, next_)))
          && (i < KNODE_MAX_DEQUEUE) ) {
    //NSLog(@"dequeued KNodeIOEntry@%p", entry);
    entries[i++] = entry;
  }
  entries[i] = NULL; // sentinel

  // perform entries in the order they where queued
  while (i && (entry = entries[--i])) {
    entry->perform();
    // Note: |entry| is invalid beyond this point as it probably deleted itself
  }
}


KNodeBlockFun::KNodeBlockFun(KNodeFunctionBlock block) {
  block_ = [block copy];
  Local<FunctionTemplate> t =
      FunctionTemplate::New(&KNodeBlockFun::InvocationProxy,
                            External::Wrap(this));
  fun_ = Persistent<Function>::New(t->GetFunction());
}

KNodeBlockFun::~KNodeBlockFun() {
  [block_ release];
  if (!fun_.IsEmpty()) {
    fun_.Dispose();
    fun_.Clear();
  }
}

// static
v8::Handle<Value> KNodeBlockFun::InvocationProxy(const Arguments& args) {
  Local<Value> data = args.Data();
  assert(!data.IsEmpty());
  KNodeBlockFun* blockFun = (KNodeBlockFun*)External::Unwrap(data);
  assert(((void*)blockFun->block_) != NULL);
  blockFun->block_(args);
  delete blockFun;
  return Undefined();
}


bool KNodeInvokeExposedJSFunction(const char *name,
                                  int argc,
                                  v8::Handle<v8::Value> argv[]) {
  Local<Value> v = (*kExposedFunctions)->Get(String::New(name));
  if (!v->IsFunction())
    return false;
  Local<Function> fun = Function::Cast(*v);
  //Local<Value> returnValue =
  fun->Call(*kExposedFunctions, argc, argv);
  return true;
}


bool KNodeInvokeExposedJSFunction(const char *functionName,
                                  int argc,
                                  v8::Handle<v8::Value> argv[],
                                  KNodeCallbackBlock callback) {
  // call from kod-land
  //DLOG("[knode] 1 calling node from kod");
  KNodePerformInNode(^(KNodeReturnBlock returnCallback){
    //DLOG("[knode] 1 called in node");
    //DLOG("[knode] 1 calling kod from node");
    v8::HandleScope scope;

    // create a block function
    __block BOOL blockFunDidExecute = NO;
    KNodeBlockFun *blockFun = new KNodeBlockFun(^(const v8::Arguments& args){
      // TODO: pass args to callback (convert to cocoa first)
      // TODO: check if first arg is an object and if so, treat it as an error
      NSArray *args2 = nil;
      NSError *err = nil;
      if (args.Length() > 0) {
        Local<Value> v = args[0];
        if (v->IsString() || v->IsObject()) {
          String::Utf8Value utf8pch(v->ToString());
          err = [NSError nodeErrorWithFormat:@"%s", *utf8pch];
        }
        if (args.Length() > 1) {
          args2 = [NSMutableArray arrayWithCapacity:args.Length()-1];
          for (NSUInteger i = 1; i < args.Length(); ++i)
            [(NSMutableArray*)args2 addObject:[NSObject fromV8Value:args[i]]];
        }
      }
      returnCallback(callback, err, args2);
      blockFunDidExecute = YES;
    });

    // invoke the block function
    v8::TryCatch tryCatch;
    v8::Local<v8::Value> fun = blockFun->function();
    bool didFindAndCallFun;
    if (argc > 0) {
      v8::Handle<v8::Value> *argv2 = new v8::Handle<v8::Value>[argc+1];
      for (int i = 1; i<argc; ++i)
        argv2[i] = argv[i];
      argv2[0] = fun;
      didFindAndCallFun =
          KNodeInvokeExposedJSFunction(functionName, argc+1, argv2);
      delete argv2;
    } else {
      didFindAndCallFun = KNodeInvokeExposedJSFunction(functionName, 1, &fun);
    }
    NSError *error = nil;
    if (tryCatch.HasCaught()) {
      error = [NSError nodeErrorWithTryCatch:tryCatch];
    } else if (!didFindAndCallFun) {
      error = [NSError nodeErrorWithFormat:@"Unknown method '%s'",
               functionName];
    }
    if (error) { DLOG("[knode] error while calling into node: %@", error); }
    if (!blockFunDidExecute) {
      // dispose of block function
      delete blockFun;
      // Invoke callback with error
      returnCallback(callback, error, nil);
    }
  });
}


bool KNodeInvokeExposedJSFunction(const char *functionName,
                                  NSArray *args,
                                  KNodeCallbackBlock callback) {
  v8::HandleScope scope;
  int argc = 0;
  v8::Handle<v8::Value> *argv = NULL;
  if (args && (argc = args.count)) {
    argv = new v8::Handle<v8::Value>[argc];
    for (NSUInteger i = 0; i<argc; ++i)
      argv[i] = [[args objectAtIndex:i] v8Value];
  }
  return KNodeInvokeExposedJSFunction(functionName, argc, argv, callback);
}


bool KNodeInvokeExposedJSFunction(const char *functionName,
                                  KNodeCallbackBlock callback) {
  return KNodeInvokeExposedJSFunction(functionName, 0, NULL, callback);
}


bool KNodeEmitEventv(const char *eventName, int argc, id *argv) {
  KNodeEventIOEntry *entry = new KNodeEventIOEntry(eventName, argc, argv);
  KNodePerformInNode(entry);
}


bool KNodeEmitEvent(const char *eventName, ...) {
  static const int argcmax = 16;
  va_list valist;
  va_start(valist, eventName);
  id argv[argcmax];
  id arg;
  int argc = 0;
  while ((arg = va_arg(valist, id)) && argc < argcmax) {
    argv[argc++] = arg;
  }
  va_end(valist);
  return KNodeEmitEventv(eventName, argc, argv);
}


void KNodeInitNode(v8::Handle<Object> kodModule) {
  // get reference to method-name-to-js-func dict
  v8::Local<Value> exposedFunctions =
      kodModule->Get(String::New("exposedFunctions"))->ToObject();
  kExposedFunctions = pobj_create(exposedFunctions);

  // setup notifier
  KNodeIOInputQueueNotifier.data = NULL;
  ev_async_init(&KNodeIOInputQueueNotifier, &InputQueueNotification);
  ev_async_start(EV_DEFAULT_UC_ &KNodeIOInputQueueNotifier);

  // stuff might have been queued before we initialized, so trigger a dequeue
  ev_async_send(EV_DEFAULT_UC_ &KNodeIOInputQueueNotifier);
}


void KNodePerformInNode(KNodeIOEntry *entry) {
  OSAtomicEnqueue(&KNodeIOInputQueue, entry, cxx_offsetof(KNodeIOEntry, next_));
  ev_async_send(EV_DEFAULT_UC_ &KNodeIOInputQueueNotifier);
}


void KNodePerformInNode(KNodePerformBlock block) {
  KNodeIOEntry *entry =
      new KNodeTransactionalIOEntry(block, dispatch_get_current_queue());
  KNodePerformInNode(entry);
}


// ---------------------------------------------------------------------------

KNodeEventIOEntry::KNodeEventIOEntry(const char *name, int argc, id *argv) {
  v8::HandleScope scope;
  argc_ = argc + 1;
  argv_ = new Persistent<Value>[argc];
  argv_[0] = Persistent<Value>::New(String::NewSymbol(name));
  for (int i = 1; i<argc_; ++i) {
    //DLOG("argv[%d] => %@", i, argv[i-1]);
    argv_[i] = Persistent<Value>::New([argv[i-1] v8Value]);
  }
}


KNodeEventIOEntry::~KNodeEventIOEntry() {
  if (argv_) {
    for (int i=0; i<argc_; ++i) {
      v8::Persistent<v8::Value> v = argv_[i];
      if (v.IsEmpty()) continue;
      v.Clear();
      v.Dispose();
    }
    delete argv_;
    argv_ = NULL;
  }
}


void KNodeEventIOEntry::perform() {
  v8::HandleScope scope;
  // TODO(rsms): optimize this by keeping a global reference to the emit func
  if (!gKodNodeModule.IsEmpty()) {
    Local<Value> v = gKodNodeModule->Get(String::New("emit"));
    if (v->IsFunction()) {
      Local<Function> fun = Local<Function>::Cast(v);
      Local<Value> ret = fun->Call(gKodNodeModule, argc_, argv_);
    }
  }
  KNodeIOEntry::perform();
}


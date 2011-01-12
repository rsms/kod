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


static void _freePersistentArgs(int argc, Persistent<Value> *argv) {
  for (int i=0; i<argc; ++i) {
    Persistent<Value> v = argv[i];
    if (v.IsEmpty()) continue;
    v.Dispose();
    v.Clear();
  }
  if (argv) delete argv;
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


static bool _invokeExposedJSFunction(const char *name,
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


v8::Handle<v8::Value> KNodeCallFunction(v8::Handle<Object> target,
                                        v8::Handle<Function> fun,
                                        int argc, id *objc_argv,
                                        v8::Local<Value> *arg0/*=NULL*/) {
  v8::HandleScope scope;

  // increment arg count if we got a firstArgAsString
  if (arg0)
    ++argc;

  // allocate list of arguments
  Local<Value> *argv = new Local<Value>[argc];

  // add firstArgAsString
  if (arg0)
    argv[0] = *arg0;

  // add all objc args
  int i = arg0 ? 1 : 0, L = argc;
  for (; i<L; ++i) {
    id arg = objc_argv[i-(arg0 ? 1 : 0)];
    if (arg) {
      argv[i] = Local<Value>::New([arg v8Value]);
    } else {
      argv[i] = *v8::Null();
    }
  }

  // invoke function
  Local<Value> ret = fun->Call(target, argc, argv);
  delete argv;

  return scope.Close(ret);
}


bool KNodeInvokeExposedJSFunction(const char *functionName,
                                  NSArray *args,
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
    TryCatch tryCatch;
    Local<Value> fun = blockFun->function();
    bool didFindAndCallFun;
    NSUInteger argc = args ? args.count : 0;
    if (argc != 0) {
      Local<Value> *argv = new Local<Value>[argc+1];
      argv[0] = fun;
      for (NSUInteger i = 0; i<argc; ++i) {
        argv[i+1] = [[args objectAtIndex:i] v8Value];
      }
      didFindAndCallFun = _invokeExposedJSFunction(functionName, argc+1, argv);
      delete argv;
    } else {
      didFindAndCallFun = _invokeExposedJSFunction(functionName, 1, &fun);
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
                                  KNodeCallbackBlock callback) {
  return KNodeInvokeExposedJSFunction(functionName, nil, callback);
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
  kExposedFunctions = KNodePersistentObjectCreate(exposedFunctions);

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

KNodeInvocationIOEntry::KNodeInvocationIOEntry(v8::Handle<Object> target,
                                               const char *funcName,
                                               int argc, id *argv) {
  v8::HandleScope scope;
  target_ = Persistent<Object>::New(target);
  funcName_ = strdup(funcName);
  argc_ = argc;
  if (argc_ == 0) {
    argv_ = NULL;
  } else {
    argv_ = new Persistent<Value>[argc_];
    for (int i = 0; i<argc_; ++i) {
      argv_[i] = Persistent<Value>::New([argv[i] v8Value]);
    }
  }
}


KNodeInvocationIOEntry::KNodeInvocationIOEntry(v8::Handle<Object> target,
                                               const char *funcName,
                                               int argc,
                                               v8::Handle<Value> argv[]) {
  v8::HandleScope scope;
  target_ = Persistent<Object>::New(target);
  funcName_ = strdup(funcName);
  argc_ = argc;
  if (argc_ == 0) {
    argv_ = NULL;
  } else {
    argv_ = new Persistent<Value>[argc_];
    for (int i = 0; i<argc_; ++i) {
      argv_[i] = Persistent<Value>::New(argv[i]);
    }
  }
}


KNodeInvocationIOEntry::~KNodeInvocationIOEntry() {
  if (!target_.IsEmpty()) {
    target_.Dispose();
    target_.Clear();
  }
  _freePersistentArgs(argc_, argv_);
  if (funcName_) {
    free(funcName_);
  }
}


void KNodeInvocationIOEntry::perform() {
  v8::HandleScope scope;
  DLOG("KNodeInvocationIOEntry::perform()");
  if (!target_.IsEmpty()) {
    Local<Value> v = target_->Get(String::New(funcName_));
    if (v->IsFunction()) {
      DLOG("KNodeInvocationIOEntry::perform() invoke '%s' with %d arguments",
           funcName_, argc_);
      Local<Function> fun = Local<Function>::Cast(v);
      Local<Value> ret = fun->Call(target_, argc_, argv_);
    }
  }
  KNodeIOEntry::perform();
}


// ---------------------------------------------------------------------------

KNodeEventIOEntry::KNodeEventIOEntry(const char *name, int argc, id *argv) {
  kassert(name != NULL);
  name_ = strdup(name);
  argc_ = argc;
  argv_ = new id[argc];
  for (int i = 0; i<argc_; ++i) {
    argv_[i] = [argv[i] retain];
  }
}


KNodeEventIOEntry::~KNodeEventIOEntry() {
  for (int i = 0; i<argc_; ++i) {
    [argv_[i] release];
  }
  delete argv_; argv_ = NULL;
  free(name_); name_ = NULL;
}


void KNodeEventIOEntry::perform() {
  v8::HandleScope scope;
  // TODO(rsms): optimize this by keeping a global reference to the emit func
  if (!gKodNodeModule.IsEmpty()) {
    Local<Value> v = gKodNodeModule->Get(String::New("emit"));
    if (v->IsFunction()) {
      Local<Value> eventName = Local<Value>::New(String::NewSymbol(name_));
      KNodeCallFunction(gKodNodeModule, Local<Function>::Cast(v),
                        argc_, argv_, &eventName);
    }
  }
  KNodeIOEntry::perform();
}


//v8::Persistent<v8::Object> obj_;

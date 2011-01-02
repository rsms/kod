#import <Cocoa/Cocoa.h>
#import <dispatch/dispatch.h>
#import <node.h>

class KNodeIOEntry;
class KNodeBlockFun;

typedef void (^KNodeCallbackBlock)(NSError *err, NSArray *args);
typedef void (^KNodeReturnBlock)(KNodeCallbackBlock, NSError*, NSArray*);
typedef void (^KNodePerformBlock)(KNodeReturnBlock);
typedef void (^KNodeFunctionBlock)(const v8::Arguments& args);

extern v8::Persistent<v8::Object> gKodNodeModule;

// initialize (must be called from node)
void KNodeInitNode(v8::Handle<v8::Object> kodModule);

// perform |block| in the node runtime
extern void KNodePerformInNode(KNodePerformBlock block);
extern void KNodePerformInNode(KNodeIOEntry *entry);

// Invoke a named exported function in node
bool KNodeInvokeExposedJSFunction(const char *name,
                                  int argc,
                                  v8::Handle<v8::Value> argv[]);

bool KNodeInvokeExposedJSFunction(const char *functionName,
                                  int argc,
                                  v8::Handle<v8::Value> argv[],
                                  KNodeCallbackBlock callback);

bool KNodeInvokeExposedJSFunction(const char *functionName,
                                  NSArray *args,
                                  KNodeCallbackBlock callback);

bool KNodeInvokeExposedJSFunction(const char *functionName,
                                  KNodeCallbackBlock callback);

// emit an event on the kod module, passing args
bool KNodeEmitEventv(const char *eventName, int argc, id *argv);

// emit an event on the kod module, passing nil-terminated list of args
bool KNodeEmitEvent(const char *eventName, ...);

// perform |block| in the kod runtime (queue defaults to main thread)
static inline void KNodePerformInKod(KNodeCallbackBlock block,
                                     NSError *err=nil,
                                     NSArray *args=nil,
                                     dispatch_queue_t queue=NULL) {
  if (!queue) queue = dispatch_get_main_queue();
  dispatch_async(queue, ^{ block(err, args); });
}


// Input/Output queue entry base class
class KNodeIOEntry {
 public:
  KNodeIOEntry() {}
  virtual ~KNodeIOEntry() {}
  virtual void perform() { delete this; }
  KNodeIOEntry *next_;
};


// Invocation transaction I/O queue entry
class KNodeTransactionalIOEntry : public KNodeIOEntry {
 public:
  KNodeTransactionalIOEntry(KNodePerformBlock block,
                            dispatch_queue_t returnDispatchQueue=NULL) {
    performBlock_ = [block copy];
    if (returnDispatchQueue) {
      returnDispatchQueue_ = returnDispatchQueue;
      dispatch_retain(returnDispatchQueue_);
    } else {
      returnDispatchQueue_ = NULL;
    }
  }

  virtual ~KNodeTransactionalIOEntry() {
    [performBlock_ release];
    dispatch_release(returnDispatchQueue_);
  }

  void perform() {
    performBlock_(^(KNodeCallbackBlock callback, NSError *err, NSArray *args) {
      if (callback)
        KNodePerformInKod(callback, err, args, returnDispatchQueue_);
    });
    KNodeIOEntry::perform();
  }

  KNodeIOEntry *next_;
 protected:
  KNodePerformBlock performBlock_;
  dispatch_queue_t returnDispatchQueue_;
};


// Invokes funcName on target passing arguments
class KNodeInvocationIOEntry : public KNodeIOEntry {
 public:
  KNodeInvocationIOEntry(v8::Handle<v8::Object> target, const char *funcName,
                         int argc=0, id *argv=NULL);
  KNodeInvocationIOEntry(v8::Handle<v8::Object> target,
                         const char *funcName,
                         int argc, v8::Handle<v8::Value> argv[]);
  virtual ~KNodeInvocationIOEntry();
  void perform();
 protected:
  char *funcName_;
  v8::Persistent<v8::Object> target_;
  int argc_;
  v8::Persistent<v8::Value> *argv_;
};


// Event I/O queue entry
class KNodeEventIOEntry : public KNodeIOEntry {
 public:
  KNodeEventIOEntry(const char *name, int argc, id *argv);
  virtual ~KNodeEventIOEntry();
  void perform();
 protected:
  int argc_;
  v8::Persistent<v8::Value> *argv_;
};


// -------------------

class KNodeBlockFun {
  KNodeFunctionBlock block_;
  v8::Persistent<v8::Function> fun_;
 public:
  KNodeBlockFun(KNodeFunctionBlock block);
  ~KNodeBlockFun();
  inline v8::Local<v8::Value> function() { return *fun_; }
  static v8::Handle<v8::Value> InvocationProxy(const v8::Arguments& args);
};

// -------------------

static inline v8::Persistent<v8::Object>* KNodePersistentObjectCreate(
    const v8::Local<v8::Value> &v) {
  v8::Persistent<v8::Object> *pobj = new v8::Persistent<v8::Object>();
  *pobj = v8::Persistent<v8::Object>::New(v8::Local<v8::Object>::Cast(v));
  return pobj;
}

static inline v8::Persistent<v8::Object>* KNodePersistentObjectUnwrap(void *data) {
  v8::Persistent<v8::Object> *pobj =
    reinterpret_cast<v8::Persistent<v8::Object>*>(data);
  assert((*pobj)->IsObject());
  return pobj;
}

static inline void KNodePersistentObjectDestroy(v8::Persistent<v8::Object> *pobj) {
  pobj->Dispose();
  delete pobj;
}


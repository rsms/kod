#import <Cocoa/Cocoa.h>
#import <dispatch/dispatch.h>
#import <node.h>

class KNodeIOEntry;
class KNodeBlockFun;

typedef void (^KNodeCallbackBlock)(NSError *err, NSArray *args);
typedef void (^KNodeReturnBlock)(KNodeCallbackBlock, NSError*, NSArray*);
typedef void (^KNodePerformBlock)(KNodeReturnBlock);
typedef void (^KNodeFunctionBlock)(const v8::Arguments& args);

// initialize (must be called from node)
extern void KNodeInitNode(v8::Handle<v8::Object> kodModule);

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

// perform |block| in the kod runtime (queue defaults to main thread)
static inline void KNodePerformInKod(KNodeCallbackBlock block,
                                     NSError *err=nil,
                                     NSArray *args=nil,
                                     dispatch_queue_t queue=NULL) {
  if (!queue) queue = dispatch_get_main_queue();
  dispatch_async(queue, ^{ block(err, args); });
}

// Input/Output queue entry
class KNodeIOEntry {
 public:
  KNodeIOEntry(KNodePerformBlock block,
               dispatch_queue_t returnDispatchQueue=NULL) {
    performBlock_ = [block copy];
    if (returnDispatchQueue) {
      returnDispatchQueue_ = returnDispatchQueue;
      dispatch_retain(returnDispatchQueue_);
    } else {
      returnDispatchQueue_ = NULL;
    }
  }

  ~KNodeIOEntry() {
    [performBlock_ release];
    dispatch_release(returnDispatchQueue_);
  }

  void perform() {
    performBlock_(^(KNodeCallbackBlock callback, NSError *err, NSArray *args) {
      KNodePerformInKod(callback, err, args, returnDispatchQueue_);
    });
    delete this;
  }

  KNodeIOEntry *next_;
 protected:
  KNodePerformBlock performBlock_;
  dispatch_queue_t returnDispatchQueue_;
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


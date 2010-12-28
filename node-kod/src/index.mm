#include "index.h"
#include "../../src/kod_version.h"


// Triggered when there are stuff on inputQueue_
/*static void InputQueueNotification(EV_P_ ev_async *watcher, int revents) {
  HandleScope scope;

  // retrieve our thread instance
  KNodeThread* self = (NodeJSThread*)watcher->data;
  //NSLog(@"InputQueueNotification");

  // enumerate queue
  PerformEntry* entry;
  while ( (entry = (PerformEntry*)OSAtomicDequeue(
      &self->inputQueue_, cxx_offsetof(PerformEntry, next_))) ) {
    //NSLog(@"dequeued %p", entry);
    entry->Perform();
  }
}*/


static Handle<Value> SomeFunction(const Arguments& /*args*/){
  HandleScope scope;
  return scope.Close(Undefined());
}


extern "C" void init(Handle<Object> target) {
  HandleScope scope;

  // Constants
  target->Set(String::NewSymbol("version"), String::New(K_VERSION_STR));

  // Functions
  //NODE_SET_METHOD(target, "someFunction", SomeFunction);
}

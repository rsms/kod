#import "common.h"
#import "kconf.h"
#import "KNodeThread.h"
#import "node_kod.h"
#import "kod_node_interface.h"

#import <node.h>
#import <node_events.h>

using namespace v8;

static ev_prepare gPrepareNodeWatcher;

static void _KPrepareNode(EV_P_ ev_prepare *watcher, int revents) {
  HandleScope scope;
  kassert(watcher == &gPrepareNodeWatcher);
  kassert(revents == EV_PREPARE);
  //fprintf(stderr, "_KPrepareTick\n"); fflush(stderr);

  // Create _kod module
  Local<FunctionTemplate> kod_template = FunctionTemplate::New();
  node::EventEmitter::Initialize(kod_template);
  gKodNodeModule =
      Persistent<Object>::New(kod_template->GetFunction()->NewInstance());
  node_kod_init(gKodNodeModule);
  Local<Object> global = v8::Context::GetCurrent()->Global();
  global->Set(String::New("_kod"), gKodNodeModule);

  ev_prepare_stop(&gPrepareNodeWatcher);
}


@implementation KNodeThread


- (id)init {
  if (!(self = [super init])) return nil;
  [self setName:@"se.hunch.kod.node"];
  return self;
}


- (void)main {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];

  // args
  const char *argv[] = {NULL,"","",NULL};
  argv[0] = [[kconf_bundle() executablePath] UTF8String];
  #if !NDEBUG
  argv[1] = "--expose-gc";
  argv[2] = "--trace-gc";
  static const int argc = 4;
  #else
  static const int argc = 2;
  #endif
  argv[argc-1] = [[kconf_res_url(@"main.js") path] UTF8String];
  

  // NODE_PATH
  NSString *nodelibPath = [kconf_bundle() sharedSupportPath];
  nodelibPath = [nodelibPath stringByAppendingPathComponent:@"nodelib"];
  const char *NODE_PATH_pch = getenv("NODE_PATH");
  NSString *NODE_PATH;
  if (NODE_PATH_pch) {
    NODE_PATH = [NSString stringWithFormat:@"%@:%s",nodelibPath, NODE_PATH_pch];
  } else {
    NODE_PATH = nodelibPath;
  }
  setenv("NODE_PATH", [NODE_PATH UTF8String], 1);

  // Make sure HOME is correct and set
  setenv("HOME", [NSHomeDirectory() UTF8String], 1);

  // Export some basic info about kod
  setenv("KOD_APP_BUNDLE", [[kconf_bundle() bundlePath] UTF8String], 1);

  // register our initializer
  ev_prepare_init(&gPrepareNodeWatcher, _KPrepareNode);
  // set max priority so _KPrepareNode gets called before main.js is executed
  ev_set_priority(&gPrepareNodeWatcher, EV_MAXPRI);
  
  while (![self isCancelled]) {

    ev_prepare_start(EV_DEFAULT_UC_ &gPrepareNodeWatcher);
    // Note: We do NOT ev_unref here since we want to keep node alive for as long
    // as we are not canceled.

    // start
    DLOG("[node] starting in %@", self);
    int exitStatus = node::Start(argc, (char**)argv);
    DLOG("[node] exited with status %d in %@", exitStatus, self);

    // show an alert if node "crashed"
    if (![self isCancelled]) {
      WLOG("forcing program termination due to Node.js unexpectedly exiting");
      /*NSAlert *alert =
      [NSAlert alertWithMessageText:@"Node.js terminated prematurely"
                      defaultButton:@"Try to restart"
                    alternateButton:@"Terminate Kod"
                        otherButton:nil
          informativeTextWithFormat:@"Node.js exited due to an internal error"
                                     " and is vital to Kod, thus Node.js need"
                                     " to be restarted or Kod be terminated to"
                                     " avoid crashing."];
      [alert setAlertStyle:NSCriticalAlertStyle];
      NSInteger buttonPressed = [alert runModal];
      if (buttonPressed == NSAlertAlternateReturn) {*/
        [self cancel];
      //}
    }
  }

  // clean up
  if (!gKodNodeModule.IsEmpty()) {
    gKodNodeModule.Clear();
    // Note(rsms): Calling gKodNodeModule.Dispose() here seems to bug out on
    // program termination
  }

  [NSApp terminate:nil];
  [pool drain];
}


- (void)cancel {
  // break all currently active ev_run's
  ev_break(EV_DEFAULT_UC_ EVBREAK_ALL);
  
  [super cancel];
}


+ (void)handleUncaughtException:(id)err {
  // called in the node thead
  id msg = err;
  if ([err isKindOfClass:[NSDictionary class]]) {
    if (!(msg = [err objectForKey:@"stack"]))
      msg = err;
  }
  WLOG("[node] unhandled exception: %@", msg);
}


@end

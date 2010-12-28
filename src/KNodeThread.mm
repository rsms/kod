#import "common.h"
#import "kconf.h"
#import "KNodeThread.h"
#import <node.h>

@implementation KNodeThread


- (id)init {
  if (!(self = [super init])) return nil;
  [self setName:@"se.hunch.kod.node"];
  return self;
}


- (void)main {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  
  // args
  int argc = 2;
  char *argv[] = {NULL,NULL};
  argv[0] = (char*)[[kconf_bundle() executablePath] UTF8String];
  argv[1] = (char*)[[kconf_res_url(@"main.js") path] UTF8String];
  
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
  
  // start
  DLOG("[node] starting in %@", self);
  int exitStatus = node::Start(argc, argv);
  DLOG("[node] exited with status %d in %@", exitStatus, self);
  
  [pool drain];
}


@end

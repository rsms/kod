#import "KASTViewerWindowController.h"
#import "KASTViewerController.h"
#import "common.h"

static KASTViewerWindowController *gSharedInstance_ = nil;

@implementation KASTViewerWindowController

@synthesize outlineViewController = outlineViewController_;

+ (KASTViewerWindowController*)sharedInstance {
  if (!gSharedInstance_) {
    KASTViewerWindowController *controller =
        [[self alloc] initWithWindowNibName:@"ast-viewer"];
    if (h_casid(&gSharedInstance_, controller)) {
      [controller showWindow:self];
    }
    [controller release];
  }
  return gSharedInstance_;
}

@end

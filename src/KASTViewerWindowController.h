@class KASTViewerController;

@interface KASTViewerWindowController : NSWindowController {
  IBOutlet KASTViewerController* outlineViewController_;
}

@property(assign) KASTViewerController* outlineViewController;

+ (KASTViewerWindowController*)sharedInstance;

@end

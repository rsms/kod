#import "KBrowser.h"
#import "KTabContents.h"
#import "KBrowserWindowController.h"

@implementation KBrowser

static KBrowser* _currentMain = nil; // weak

+ (KBrowser*)mainBrowser {
  return _currentMain;
}

-(id)init {
  if ((self = [super init])) {
    if (!_currentMain) {
      // TODO: potential race-condition since we can be called from background
      //       threads.
      _currentMain = self;
    }
  }
  return self;
}

-(void)dealloc {
  if (_currentMain == self)
    _currentMain = nil;
  [super dealloc];
}

-(void)finalize {
  if (_currentMain == self) {
      // TODO: potential race-condition since we can be called from a background
      //       thread (gc collector).
    _currentMain = nil;
  }
  [super finalize];
}

-(void)windowDidBeginToClose {
  [super windowDidBeginToClose];
  if (_currentMain == self)
    _currentMain = nil;
}

- (void)windowDidBecomeMain:(NSNotification*)notification {
  assert([NSThread isMainThread]); // since we don't lock
  _currentMain = self;
}

- (void)windowDidResignMain:(NSNotification*)notification {
  if (_currentMain == self) {
    assert([NSThread isMainThread]); // since we don't lock
    _currentMain = nil;
  }
}

// This method is called when a new tab is being created. We need to return a
// new CTTabContents object which will represent the contents of the new tab.
-(CTTabContents*)createBlankTabBasedOn:(CTTabContents*)baseContents {
  // Create a new instance of our tab type
  return [[KTabContents alloc] initWithBaseTabContents:baseContents];
}

// Create a new window controller. The default implementation will create a
// controller loaded with a nib called "BrowserWindow". If the nib can't be
// found in the main bundle, a fallback nib will be loaded from the framework.
// This is usually enough since all UI which normally is customized is comprised
// within each tab (CTTabContents view).
-(CTBrowserWindowController *)createWindowController {
  NSString *windowNibPath = [CTUtil pathForResource:@"BrowserWindow"
                                             ofType:@"nib"];
  return [[KBrowserWindowController alloc] initWithWindowNibPath:windowNibPath
                                                         browser:self];
}

@end

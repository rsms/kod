#import "KDocumentController.h"
#import "KTabContents.h"
#import "KBrowserWindowController.h"
#import "KBrowser.h"

#import <ChromiumTabs/common.h>

@implementation KDocumentController

- (id)makeUntitledDocumentOfType:(NSString *)typeName error:(NSError **)error {
  DLOG_TRACE();
  return [[KTabContents alloc] initWithBaseTabContents:nil];
}

- (id)openUntitledDocumentAndDisplay:(BOOL)display error:(NSError **)error {
  DLOG_TRACE();
  KTabContents* tab = [self makeUntitledDocumentOfType:@"text" error:error];
  if (tab) {
    assert([NSThread isMainThread]);
    [self finalizeOpenDocument:tab inBrowser:[KBrowser mainBrowser]];
  }
  return tab;
}


- (void)finalizeOpenDocument:(KTabContents*)tab inBrowser:(KBrowser*)browser {
  assert([NSThread isMainThread]);
  if (!browser) {
    // Try to get mainBrowser again, as it might have occured since we first got 
    // dispatched.
    if (!(browser = [KBrowser mainBrowser])) {
      // defering creation of a new browser (in the case it does not exist when
      // starting a read) makes the calls sequential, thus avoid race-conditions
      // which could create multiple new browser instances.
      browser = [[[KBrowser alloc] init] autorelease];
    }
  }
  if (!browser.windowController) {
    [browser createWindowControllerInstance];
  }
  // TODO: if there is one single, unmodified and empty document (i.e. a new
  // window with a default empty document): remove the document first.
  // This is a common use-case where you open a new window which comes with a
  // new empty document, and then Open... one or more files.
  [browser addTabContents:tab];
  if (![[browser.windowController window] isVisible])
    [browser.windowController showWindow:self];
}

- (void)finalizeOpenDocument:(NSArray*)args {
  assert([NSThread isMainThread]);
  [self finalizeOpenDocument:[args objectAtIndex:0]
                   inBrowser:[args count] > 1 ? [args objectAtIndex:1] : nil];
}

- (id)openDocumentWithContentsOfURL:(NSURL *)absoluteURL
                            display:(BOOL)display
                              error:(NSError **)error {
  DLOG_TRACE();
  return [self openDocumentWithContentsOfURL:absoluteURL
                                   inBrowser:[KBrowser mainBrowser]
                                     display:NO
                                       error:error];
}

- (id)openDocumentWithContentsOfURL:(NSURL *)url
                          inBrowser:(KBrowser*)browser
                            display:(BOOL)display
                              error:(NSError **)error {
  DLOG_TRACE();
  KTabContents* tab = [[KTabContents alloc] initWithBaseTabContents:nil];
  if (tab) {
    if ([tab readFromURL:url ofType:@"text" error:error] && !(*error)) {
      // set tab title
      tab.title = [url lastPathComponent];
      
      // add the tab to |browser|
      if (![NSThread isMainThread]) {
        // if we worked in a background thread
        NSArray* args = [NSArray arrayWithObjects:tab, browser, nil];
        [self performSelectorOnMainThread:@selector(finalizeOpenDocument:)
                               withObject:args
                            waitUntilDone:YES];
        // NODE: if we don't wait for the above to complete, we'll need to
        // manage the references of |args|. Now we just let it autorelease.
      } else {
        [self finalizeOpenDocument:tab inBrowser:browser];
      }
      return tab;
    } else {
      [tab release];
    }
  }
  return nil;
}

- (id)makeDocumentWithContentsOfURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)error {
  DLOG_TRACE();
  return [super makeDocumentWithContentsOfURL:url ofType:typeName error:error];
}

- (NSString *)defaultType {
  DLOG_TRACE();
  return @"KTabContents";
}

- (NSArray*)documentClassNames {
  DLOG_TRACE();
  return [NSArray arrayWithObject:[self defaultType]];
}

- (Class)documentClassForType:(NSString *)documentTypeName {
  DLOG_TRACE();
  return [KTabContents class];
}

- (NSString *)displayNameForType:(NSString *)documentTypeName {
  DLOG_TRACE();
  return documentTypeName;
}

- (NSString *)typeForContentsOfURL:(NSURL *)url error:(NSError **)error {
  DLOG_TRACE();
  return [self defaultType];
}


@end

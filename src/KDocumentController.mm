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
  KTabContents* tab = [self makeUntitledDocumentOfType:[self defaultType]
                                                 error:error];
  if (tab) {
    assert([NSThread isMainThread]);
    [self finalizeOpenDocument:tab inBrowser:(KBrowser*)[KBrowser mainBrowser]];
  }
  return tab;
}


- (void)finalizeOpenDocument:(KTabContents*)tab inBrowser:(KBrowser*)browser {
  assert([NSThread isMainThread]);
  if (!browser) {
    // Try to get mainBrowser again, as it might have occured since we first got 
    // dispatched.
    if (!(browser = (KBrowser*)[KBrowser mainBrowser])) {
      // defering creation of a new browser (in the case it does not exist when
      // starting a read) makes the calls sequential, thus avoid race-conditions
      // which could create multiple new browser instances.
      browser = [[[KBrowser alloc] init] autorelease];
    }
  }
  if (!browser.windowController) {
    [browser createWindowControllerInstance];
  }
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
                                   inBrowser:(KBrowser*)[KBrowser mainBrowser]
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
    if ([tab readFromURL:url ofType:@"txt" error:error] && !(*error)) {
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
  return @"txt";
}

/*- (NSArray*)documentClassNames {
  DLOG_TRACE();
  return [NSArray arrayWithObject:@"KTabContents"];
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
}*/


@end

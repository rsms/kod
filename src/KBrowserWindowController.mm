#import "KBrowserWindowController.h"
#import "KAppDelegate.h"
#import "KBrowser.h"
#import "KTabContents.h"
#import <ChromiumTabs/common.h>

@implementation KBrowserWindowController


- (void)saveAllDocuments:(id)sender {
  [[NSDocumentController sharedDocumentController] saveAllDocuments:sender];
}
- (void)openDocument:(id)sender {
  [[NSDocumentController sharedDocumentController] openDocument:sender];
}
- (void)newDocument:(id)sender {
  [[NSDocumentController sharedDocumentController] newDocument:sender];
}


- (NSRect) window:(NSWindow *)window
willPositionSheet:(NSWindow *)sheet
        usingRect:(NSRect)rect {
  rect.origin.y -= 20.0;
  return rect;
}


/*- (void)setDocument:(NSDocument *)document {
  DLOG_TRACE();
  [super setDocument:document];
}*/


// Future trouble ahead...
/*- (BOOL)windowShouldClose:(id)sender {
  DLOG_TRACE();
  return YES;
  if (browser_ &&
      browser_.windowController &&
      [browser_.windowController window]) {
    int tabCount = [browser_ tabCount];
    NSMutableArray *modified = [NSMutableArray array];
    for (int i = 0; i < tabCount; i++) {
      KTabContents* tab = (KTabContents*)[browser_ tabContentsAtIndex:i];
      if ([tab isDocumentEdited]) {
        [modified addObject:tab];
      }
    }
    if ([modified count] > 0) {
      //// TODO: only if not in focus/key
      //NSInteger attentionRequestId =
      //    [NSApp requestUserAttention:NSCriticalRequest];
      // TODO: display modal
      [(KTabContents*)[modified objectAtIndex:0] showWindows];
      NSInteger modalResult =
          [NSApp runModalForWindow:[browser_.windowController window]];
      DLOG("TODO: modal: %d unsaved documents -- really close?", [modified count]);
      return NO;
    }
  }
  return YES;
}*/

/*- (void)windowWillClose:(NSNotification*)notification {
  DLOG_TRACE();
  if (browser_) {
    [browser_ closeAllTabs];
  }
}*/

#pragma mark -
#pragma mark Proxy for selected tab

// Since we become firstResponder, we need to forward objc invocations to the
// currently selected tab (if any), following the NSDocument architecture.

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
  NSMethodSignature* sig = [super methodSignatureForSelector:selector];
	if (!sig) {
    KTabContents* tab = (KTabContents*)[browser_ selectedTabContents];
    if (tab)
      sig = [tab methodSignatureForSelector:selector];
  }
  return sig;
}

- (BOOL)respondsToSelector:(SEL)selector {
	BOOL y = [super respondsToSelector:selector];
  if (!y) {
    KTabContents* tab = (KTabContents*)[browser_ selectedTabContents];
    y = !!tab && [tab respondsToSelector:selector];
  }
  return y;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
  SEL selector = [invocation selector];
  KTabContents* tab = (KTabContents*)[browser_ selectedTabContents];
  if (tab && [tab respondsToSelector:selector])
    [invocation invokeWithTarget:tab];
  else
    [self doesNotRecognizeSelector:selector];
}


@end

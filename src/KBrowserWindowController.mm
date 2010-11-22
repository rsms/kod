#import <ChromiumTabs/common.h>

#import "KBrowserWindowController.h"
#import "KAppDelegate.h"
#import "KBrowser.h"
#import "KTabContents.h"
#import "KFileTreeController.h"
#import "KFileOutlineView.h"
#import "KScroller.h"


@implementation KBrowserWindowController

@synthesize
    verticalSplitView = verticalSplitView_,
    leftmostSubviewOfVerticalSplitView = leftmostSubviewOfVerticalSplitView_;


- (id)initWithWindowNibPath:(NSString *)windowNibPath
                    browser:(CTBrowser*)browser {
  self = [super initWithWindowNibPath:windowNibPath browser:browser];

  // Setup file tree view
  [fileOutlineView_ registerForDraggedTypes:
      [NSArray arrayWithObject:NSFilenamesPboardType]];
  [fileOutlineView_ setBackgroundColor:KFileOutlineViewBackgroundColor];

  // Setup file tree controller
  fileTreeController_ =
      [[KFileTreeController alloc] initWithOutlineView:fileOutlineView_];

  // Setup scrollers
  NSScrollView *fileTreeScrollView =
      (NSScrollView*)[[fileOutlineView_ superview] superview];
  DLOG("fileTreeScrollView => %@", fileTreeScrollView);
  KScroller *hScroller = [[KScroller alloc] initWithFrame:NSZeroRect];
  /*[fileTreeScrollView setHasHorizontalScroller:YES];
  [fileTreeScrollView setAutohidesScrollers:NO];
  [fileTreeScrollView setHorizontalScroller:hScroller];*/
  //[fileTreeScrollView setHasHorizontalScroller:YES];
  //[fileTreeScrollView setHasVerticalScroller:YES];
  //[fileTreeScrollView setAutohidesScrollers:NO];

  return self;
}


- (BOOL)splitView:(NSSplitView*)sv shouldAdjustSizeOfSubview:(NSView*)subview {
  if (sv == verticalSplitView_ &&
      subview == leftmostSubviewOfVerticalSplitView_) {
    return NO;
  }
  return YES;
}


- (NSRect) window:(NSWindow *)window
willPositionSheet:(NSWindow *)sheet
        usingRect:(NSRect)rect {
  rect.origin.y -= 20.0;
  return rect;
}


- (void)setDocument:(NSDocument *)document {
  //DLOG("%s %@", __func__, document);
  [super setDocument:document];
}


- (void)layoutTabContentArea:(NSRect)newFrame {
  // Adjust height after the tabstrip have been introduced to the window top
  NSRect splitViewFrame = verticalSplitView_.frame;
  splitViewFrame.size.height = newFrame.size.height;
  [verticalSplitView_ setFrame:splitViewFrame];
  [super layoutTabContentArea:newFrame];
}


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

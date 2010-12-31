#import "common.h"
#import <ChromiumTabs/fast_resize_view.h>
#import <ChromiumTabs/CTBrowserWindow.h>

#import "HEventEmitter.h"
#import "KBrowserWindowController.h"
#import "KAppDelegate.h"
#import "KBrowser.h"
#import "KDocument.h"
#import "KFileTreeController.h"
#import "KFileOutlineView.h"
#import "KScroller.h"
#import "KSplitView.h"
#import "KToolbarController.h"
#import "KStatusBarController.h"
#import "KStyle.h"
#import "KPopUp.h"
#import "kconf.h"


@implementation KBrowserWindowController

@synthesize verticalSplitView = splitView_;

#pragma mark -
#pragma mark Initialization


- (id)initWithWindowNibPath:(NSString *)windowNibPath
                    browser:(CTBrowser*)browser {
  self = [super initWithWindowNibPath:windowNibPath browser:browser];

  // Setup file tree view
  [fileOutlineView_ registerForDraggedTypes:
      [NSArray arrayWithObjects:NSFilenamesPboardType, NSURLPboardType, nil]];
  [fileOutlineView_ setBackgroundColor:KFileOutlineViewBackgroundColor];

  // Setup file tree controller
  fileTreeController_ =
      [[KFileTreeController alloc] initWithOutlineView:fileOutlineView_];

  // We don't use the "New tab" button
  kassert(tabStripController_);
  self.showsNewTabButton = kconf_bool(@"window/newTabButton/enable", NO);

  // setup split view
  kassert(splitView_ != nil); // should get a ref from unarchived NIB
  splitView_.position = kconf_double(@"editor/splitView/position", 180.0);
  splitView_.isCollapsed = YES; //kconf_bool(@"editor/splitView/collapsed", YES);
  // register for split view resize notification so we can store conf value

  [self observe:NSSplitViewDidResizeSubviewsNotification
         source:splitView_
        handler:@selector(splitViewDidResize:)];
  [self observe:KSplitViewDidChangeCollapseStateNotification
         source:splitView_
        handler:@selector(splitViewDidChangeCollapseState:)];

  // set splitView of toolbarController_
  if (toolbarController_) {
    ((KToolbarController*)toolbarController_).splitView = splitView_;
    [toolbarController_ addObserver:self forKeyPath:@"directoryURL" options:NSKeyValueObservingOptionOld context:nil];
  }

  // setup status bar
  if (statusBarController_) {
    [self observe:KStatusBarDidChangeHiddenStateNotification
           source:statusBarController_
          handler:@selector(statusBarDidChangeHiddenState:)];
    statusBarController_.isHidden = kconf_bool(@"editor/statusBar/hidden", NO);
  }

  return self;
}


- (id)init {
  // subclasses could override this to provide a custom |CTBrowser|
  return [self initWithBrowser:[KBrowser browser]];
}


/*- (id)retain {
  fprintf(stderr, ">>>>> %s retain %lu\n", [[self description] UTF8String], [self retainCount]);
  return [super retain];
}
- (void)release {
  //DLOG("%@ release %@", self, [NSThread callStackSymbols]);
  fprintf(stderr, ">>>>> %s release %lu\n", [[self description] UTF8String], [self retainCount]);
  [super release];
}
- (void)dealloc {
  DLOG("%@ dealloc %@", self, [NSThread callStackSymbols]);
  [self stopObserving];
  [[self window] setDelegate:nil];
  [super dealloc];
}*/
/*- (id)autorelease {
  DLOG("%@ autorelease %@", self, [NSThread callStackSymbols]);
  return [super autorelease];
}*/



#pragma mark -
#pragma mark Properties


- (CGFloat)statusBarHeight {
  NSView *view;
  if (statusBarController_ && (view = statusBarController_.view) &&
      ![view isHidden]) {
    return view.frame.size.height;
  }
  return 0.0;
}


#pragma mark -
#pragma mark Actions


/*- (void)setDocument:(NSDocument *)document {
  DLOG("%s %@", __func__, document);
  [super setDocument:document];
}*/


- (IBAction)focusLocationBar:(id)sender {
  if (toolbarController_) {
    [((KToolbarController*)toolbarController_).locationBarTextField becomeFirstResponder];
  }
}


- (IBAction)toggleStatusBarVisibility:(id)sender {
  if (statusBarController_)
    [statusBarController_ toggleStatusBarVisibility:sender];
}


- (IBAction)toggleSplitView:(id)sender {
  [splitView_ toggleCollapse:sender];
}


- (IBAction)reloadStyle:(id)sender {
  [[KStyle sharedStyle] reload];
}


- (IBAction)goToLine:(id)sender {
  if (goToLinePopUp_) return;
  goToLinePopUp_ = [KPopUp popupWithSize:NSMakeSize(120.0, 55.0)
                        centeredInWindow:self.window];
  goToLinePopUp_.onClose = ^(KPopUp *popup){ goToLinePopUp_ = nil; };

  // Add label "Go to line:"
  NSTextField *label = [[[NSTextField alloc] initWithFrame:
      NSMakeRect(10.0, 30.0, 100.0, 20.0)] autorelease];
  [label setEditable:NO];
  [label setSelectable:NO];
  [label setDrawsBackground:NO];
  [label setBordered:NO];
  [label setStringValue:NSLocalizedString(@"Go to line", nil)];
  NSTextFieldCell *tfcell = [label cell];
  [tfcell setAlignment:NSCenterTextAlignment];
  [goToLinePopUp_.contentView addSubview:label];

  // Add a text field for inputing line number
  NSTextField *textField = [[[NSTextField alloc] initWithFrame:
      NSMakeRect(10.0, 10.0, 100.0, 20.0)] autorelease];
  [textField setEditable:YES];
  [textField setSelectable:YES];
  [textField setEnabled:YES];
  [textField setFocusRingType:NSFocusRingTypeNone];
  [textField setTarget:self];
  [textField setAction:@selector(goToLineAction:)];
  if (goToLineLastValue_ > 0)
    [textField setIntegerValue:goToLineLastValue_];
  [goToLinePopUp_.contentView addSubview:textField];

  [goToLinePopUp_ makeKeyWindow];
  [textField becomeFirstResponder];
}


- (IBAction)goToLineAction:(id)sender {
  if (![sender isKindOfClass:[NSTextField class]])
    return;
  NSTextField *textField = (NSTextField*)sender;
  if (goToLinePopUp_) [goToLinePopUp_ close];

  goToLineLastValue_ = [textField.cell integerValue];
  if (goToLineLastValue_ < 1)
    return; // 0 if the text field was empty or non-number
  KDocument *tab = (KDocument*)[self selectedTabContents];
  if (!tab) return;
  NSRange lineRange = [tab rangeOfLineAtLineNumber:goToLineLastValue_];
  if (lineRange.location == NSNotFound) {
    DLOG("out-of-range line jump requested but ignored");
  } else {
    //DLOG("selecting line %ld %@", goToLineLastValue_,
    //     NSStringFromRange(lineRange));
    [tab.textView setSelectedRange:lineRange];
    [tab.textView scrollRangeToVisible:lineRange];
    [tab.textView showFindIndicatorForRange:lineRange];
  }
}


- (BOOL)validateMenuItem:(NSMenuItem *)item {
  BOOL y = NO;
  KDocument *selectedTab = (KDocument*)[self selectedTabContents];
  if (item.action == @selector(saveAllDocuments:)) {
    return [[NSDocumentController sharedDocumentController] hasEditedDocuments];
  } else if (item.action == @selector(saveDocument:)) {
    return (selectedTab && selectedTab.canSaveDocument);
  } else if (item.action == @selector(revertDocumentToSaved:)) {
    if (selectedTab && selectedTab.hasRemoteSource) {
      [item setTitle:NSLocalizedString(@"Reload",0)];
      return YES; // can always reload a remote source
    } else {
      [item setTitle:NSLocalizedString(@"Revert to saved",0)];
      return selectedTab && selectedTab.fileURL && selectedTab.isDocumentEdited;
    }
  } else if (item.action == @selector(toggleSplitView:)) {
    [item setState:!splitView_.isCollapsed];
    return YES;
  } else if (item.action == @selector(toggleStatusBarVisibility:)) {
    // Note: There's a bug in the sidebar where its contents are not properly
    // realigned and resized in respect to the status bar.
    if (!statusBarController_) {
      return NO;
    } else {
      [item setState:!statusBarController_.isHidden];
      return YES;
    }
  } else {
    y = [super validateMenuItem:item];
    #if 0
    DLOG("validateMenuItem:%@ (%@) -> %@", item,
         NSStringFromSelector(item.action), y?@"YES":@"NO");
    #endif
  }
  return y;
}


#pragma mark -
#pragma mark Notifications

/*- (void)setDocumentEdited:(BOOL)documentEdited {
  DLOG("setDocumentEdited %@", [NSThread callStackSymbols]);
  [super setDocumentEdited:documentEdited];
}*/


- (void)splitViewDidResize:(NSNotification*)notification {
  if (!splitView_.isCollapsed)
    kconf_set_double(@"editor/splitView/position", splitView_.position);
}


- (void)splitViewDidChangeCollapseState:(NSNotification*)notification {
  kconf_set_bool(@"editor/splitView/collapsed", splitView_.isCollapsed);
}


- (void)statusBarDidChangeHiddenState:(NSNotification*)notification {
  kconf_set_bool(@"editor/statusBar/hidden", statusBarController_.isHidden);
  [self layoutSubviews];
  [self.window display];
}


#pragma mark -
#pragma mark NSSplitView Delegate Methods

// Add the resize handle rect to the split view hot zone
- (NSRect)splitView:(NSSplitView *)splitView
      effectiveRect:(NSRect)effectiveRect
       forDrawnRect:(NSRect)drawnRect
   ofDividerAtIndex:(NSInteger)dividerIndex {
  // Note: we don't check splitView as we only have one split view
  // Note: we don't check dividerIndex since we only have one divider

  // Expand by 4px to the left (we can not expand to the right since the text
  // view is tracked)
  effectiveRect.origin.x -= 2.0;
  effectiveRect.size.width += 2.0;

  // extend into toolbar
  if (toolbarController_) {
    NSRect toolbarFrame = toolbarController_.view.frame;
    effectiveRect.size.height += toolbarFrame.size.height;
    effectiveRect.origin.y -= toolbarFrame.size.height;
  }

  // Note: we do not extend info status bar since the window can be moved by
  //       dragging in the status bar, and that would mess things up.

  return effectiveRect;
}


#pragma mark -
#pragma mark NSWindowDelegate protocol


- (NSRect) window:(NSWindow *)window
willPositionSheet:(NSWindow *)sheet
        usingRect:(NSRect)rect {
  rect.origin.y -= 17.0;
  return rect;
}


- (id)windowWillReturnFieldEditor:(NSWindow*)sender toObject:(id)obj {
  // Ask the toolbar controller if it wants to return a custom field editor
  // for the specific object.
  return [toolbarController_ customFieldEditorForObject:obj];
}


#pragma mark -
#pragma mark CTBrowserWindowController impl


- (void)updateToolbarWithContents:(CTTabContents*)contents
               shouldRestoreState:(BOOL)shouldRestore {
  // safe even if toolbarController_ is nil
  [toolbarController_ updateToolbarWithContents:contents
                             shouldRestoreState:shouldRestore];
  [statusBarController_ updateWithContents:(KDocument*)contents];
}


- (void)layoutTabContentArea:(NSRect)newFrame {
  // Adjust height after the tabstrip have been introduced to the window top
  NSRect splitViewFrame = splitView_.frame;
  newFrame.size.height -= [self statusBarHeight];
  newFrame.origin.y = [self statusBarHeight];
  splitViewFrame.size = newFrame.size;
  splitViewFrame.origin.x = 0.0;
  splitViewFrame.origin.y = newFrame.origin.y;
  [splitView_ setFrame:splitViewFrame];

  [super layoutTabContentArea:newFrame];
}


- (void)layoutSubviews {
  [super layoutSubviews];
  // Normally, we don't need to tell the toolbar whether or not to show the
  // divider, but things break down during animation.
  if (toolbarController_) {
    [toolbarController_ setDividerOpacity:0.6];
  }
}


#pragma mark -
#pragma mark Proxy for selected tab

// Since we become firstResponder, we need to forward objc invocations to the
// currently selected tab (if any), following the NSDocument architecture.

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
  NSMethodSignature* sig = [super methodSignatureForSelector:selector];
  if (!sig) {
    KDocument* tab = (KDocument*)[browser_ selectedTabContents];
    if (tab)
      sig = [tab methodSignatureForSelector:selector];
  }
  return sig;
}

- (BOOL)respondsToSelector:(SEL)selector {
  BOOL y = [super respondsToSelector:selector];
  if (!y) {
    KDocument* tab = (KDocument*)[browser_ selectedTabContents];
    y = !!tab && [tab respondsToSelector:selector];
  }
  return y;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
  SEL selector = [invocation selector];
  KDocument* tab = (KDocument*)[browser_ selectedTabContents];
  if (tab && [tab respondsToSelector:selector])
    [invocation invokeWithTarget:tab];
  else
    [self doesNotRecognizeSelector:selector];
}


#pragma mark -
#pragma mark Opening a directory


- (BOOL)openFileDirectoryAtURL:(NSURL *)absoluteURL error:(NSError **)outError {
  if (!fileTreeController_) {
    *outError = [NSError kodErrorWithFormat:
                 @"Internal error (fileTreeController_ is nil)"];
    return NO;
  } else {
    ((KToolbarController *)toolbarController_).directoryURL = absoluteURL;
    return YES;
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
  NSURL *absoluteURL = ((KToolbarController *)toolbarController_).directoryURL;
  NSString *path = [absoluteURL path];
  NSError *error = nil;
  BOOL success = [fileTreeController_ setRootTreeNodeFromDirectoryAtPath:path error:&error];
  if (success) {
    // make sure the sidebar is visible
    splitView_.isCollapsed = NO;
  }
}

@end

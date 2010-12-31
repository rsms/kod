#import "KPopUp.h"
#import "KPopUpContentView.h"
#import "KAnimation.h"
#import "common.h"

@implementation KPopUp

@synthesize closesWhenResignsKey = closesWhenResignsKey_,
            animatesAppearance = animatesAppearance_,
            onClose = onClose_;

- (id)initWithContentRect:(NSRect)contentRect {
  self = [super initWithContentRect:contentRect
                          styleMask:NSBorderlessWindowMask
                            backing:NSBackingStoreBuffered
                              defer:NO];
  if (!self) return nil;

  [super setBackgroundColor:[NSColor clearColor]];
  [self setMovableByWindowBackground:NO];
  [self setExcludedFromWindowsMenu:YES];
  [self setAlphaValue:1.0];
  [self setOpaque:NO];
  [self setHasShadow:YES];
  [self useOptimizedDrawing:YES];
  [self setMovable:NO];
  [self setCollectionBehavior:NSWindowCollectionBehaviorTransient];
  animatesAppearance_ = YES;

  KPopUpContentView *contentView =
      [[KPopUpContentView alloc] initWithFrame:NSZeroRect];
  [self setContentView:contentView];
  [contentView release];

  return self;
}


- (id)initWithSize:(NSSize)size centeredInWindow:(NSWindow*)parentWindow {
  NSRect winFrame = parentWindow.frame;
  NSRect frame = NSMakeRect(
      winFrame.origin.x + ((winFrame.size.width - size.width) / 2.0),
      winFrame.origin.y + ((winFrame.size.height - size.height) / 2.0),
      size.width, size.height);
  if (!(self = [self initWithContentRect:frame]))
    return nil;
  [self setParentWindow:parentWindow];
  [parentWindow addChildWindow:self ordered:NSWindowAbove];
  self.escapeKeyTriggersClose = YES;
  self.closesWhenResignsKey = YES;
  return self;
}


- (void)dealloc {
  if (onClose_) [onClose_ release];
  [super dealloc];
}



+ (KPopUp*)popupWithSize:(NSSize)size centeredInWindow:(NSWindow*)parentWindow {
  KPopUp *popup = [[self alloc] initWithSize:size
                            centeredInWindow:parentWindow];
  [popup retain]; // ref we hold on to until closed
  [popup setReleasedWhenClosed:YES];
  return [popup autorelease];
}


static const NSInteger kCancelButtonTag = 194779208747102;


- (NSButton*)_findEscapeKeyTriggersCloseButton {
  for (NSView *subview in [self.contentView subviews]) {
    if ([subview isKindOfClass:[NSButton class]] &&
        [(NSButton*)subview tag] == kCancelButtonTag) {
      return (NSButton*)subview;
    }
  }
  return nil;
}


- (BOOL)escapeKeyTriggersClose {
  return !![self _findEscapeKeyTriggersCloseButton];
}


- (void)setEscapeKeyTriggersClose:(BOOL)close {
  NSButton *button = [self _findEscapeKeyTriggersCloseButton];
  if (close && !button) {
    // Add invisible button which triggers on ESC
    button = [[NSButton alloc] initWithFrame:NSZeroRect];
    [button setTag:kCancelButtonTag];
    [button setRefusesFirstResponder:YES];
    [button setKeyEquivalent:[NSString stringWithFormat:@"%C", 27]];
    [button setTarget:self];
    [button setAction:@selector(performClose:)];
    [self.contentView addSubview:button];
    [button release];
  } else if (!close && button) {
    [button removeFromSuperview];
  }
}


- (void)resignKeyWindow {
  if (closesWhenResignsKey_) {
    [self close];
  }
}


- (BOOL)canBecomeMainWindow { return NO; }
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)isExcludedFromWindowsMenu { return YES; }


static const CGFloat kAnimationFrameYOffset = 10.0;


- (void)_startRevealAnimation {
  KAnimation *animation = [KAnimation animationWithDuration:0.05
                                             animationCurve:NSAnimationEaseOut];
  animation.onProgress = ^(float progress) {
    [self setAlphaValue:progress];
    NSRect frame = originalFrame_;
    frame.origin.y +=
        kAnimationFrameYOffset - (kAnimationFrameYOffset * progress);
    [self setFrame:frame display:YES];
  };

  [self setAlphaValue:0.0];

  originalFrame_ = self.frame;
  NSRect frame = originalFrame_;
  frame.origin.y += kAnimationFrameYOffset;
  [self setFrame:frame display:YES];

  [animation startAnimation];
}


- (void)makeKeyWindow {
  if (animatesAppearance_)
    [self _startRevealAnimation];
  [super makeKeyWindow];
}


- (void)_kpopup_close {
  // Note: this can NOT be named _close since it appears NSWindow has a private
  // method of the same name which causes an infinite call loop.
  isClosing_ = NO;
  // retain since the call to close might release us
  [self retain];
  [super close];
  if (onClose_) onClose_(self);
  [self release];
}


- (void)_closeWithAnimationInParentWindow:(NSWindow*)parentWindow {
  KAnimation *animation = [KAnimation animationWithDuration:0.05
                                             animationCurve:NSAnimationEaseOut];
  animation.onProgress = ^(float progress) {
    [self setAlphaValue:1.0-progress];
  };
  animation.onEnd = ^{
    DLOG("animation ended -- closing window");
    [self _kpopup_close];
  };
  [animation startAnimation];
  // restore focus to parent window, if any
  if (parentWindow)
    [parentWindow makeKeyWindow];
}


- (void)close {
  if (isClosing_) return;
  isClosing_ = YES;
  NSWindow *parentWindow = [self parentWindow];
  if (parentWindow) {
    [parentWindow removeChildWindow:self];
    [self setParentWindow:nil];
  }
  if (animatesAppearance_) {
    [self _closeWithAnimationInParentWindow:parentWindow];
  } else {
    [self _kpopup_close];
  }
}


- (IBAction)performClose:(id)sender {
  // default impl of this needs a valid close button, which we don't have, so
  // call close directly
  [self close];
}


@end

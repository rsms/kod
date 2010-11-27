#import "KTextFieldDecoration.h"
#import "common.h"

const CGFloat KTextFieldDecorationOmittedWidth = 0.0;


@implementation KTextFieldDecoration

@synthesize visible = visible_;

// These need to be implemented by subclasses

- (CGFloat)widthForSpace:(CGFloat)width {
  NOTREACHED();
  return KTextFieldDecorationOmittedWidth;
}

- (void)drawInteriorWithFrame:(NSRect)frame inView:(NSView*)controlView {
  NOTREACHED();
}


// Default impls for optional methods

- (NSString*)toolTip { return nil; }
- (BOOL)acceptsMousePress { return NO; }
- (BOOL)isDraggable { return NO; }
- (NSImage*)dragImage { return nil; }
- (NSRect)dragImageFrameForDecorationRect:(NSRect)frame { return NSZeroRect; }
- (NSPasteboard*)dragPasteboard { return nil; }
- (BOOL)mouseDownInRect:(NSRect)frame { return NO; }
- (NSMenu*)menu { return nil; }

@end

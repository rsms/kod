// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "KParseStatusDecoration.h"

@implementation KParseStatusDecoration

@dynamic status;


- (id)init {
  if ((self = [super init])) {
    visible_ = NO;
    status_ = KParseStatusUnknown;
  }
  return self;
}


// Decorations can change their size to fit the available space.
// Returns the width the decoration will use in the space allotted,
// or |kOmittedWidth| if it should be omitted.
- (CGFloat)widthForSpace:(CGFloat)width {
  return 16.0;
}


// Decorations which do not accept mouse events are treated like the
// field's background for purposes of selecting text.  When such
// decorations are adjacent to the text area, they will show the
// I-beam cursor.  Decorations which do accept mouse events will get
// an arrow cursor when the mouse is over them.
- (BOOL)acceptsMousePress { return YES; }


// status property getter and setter
- (KParseStatus)status { return status_; }
- (void)setStatus:(KParseStatus)status {
  status_ = status;
  visible_ = (status_ != KParseStatusUnknown);
}


// Returns the tooltip for this decoration, return |nil| for no tooltip.
- (NSString*)toolTip {
  // TODO: NSLocalizedString
  switch (status_) {
    case KParseStatusOK:
      return @"The document was successfully parsed";
    case KParseStatusBroken:
      return @"The document is broken or incomplete";
    default:
      return nil;
  }
}


- (NSImage*)iconImage {
  switch (status_) {
    case KParseStatusOK:
      return [NSImage imageNamed:@"parse-status-ok"];
    case KParseStatusBroken:
      return [NSImage imageNamed:@"parse-status-broken"];
    default:
      return nil;
  }
}


// Draw the decoration in the frame provided.  The frame will be
// generated from an earlier call to |GetWidthForSpace()|.
- (void)drawInteriorWithFrame:(NSRect)frame inView:(NSView*)controlView {
  NSImage *icon = [self iconImage];
  if (!icon) return;

  NSRect dstRect = frame;
  NSSize iconSize = [icon size];
  dstRect.size = iconSize;
  dstRect.origin.x += frame.size.width - iconSize.width;
  dstRect.origin.y += ceil((frame.size.height - iconSize.height)/2.0);

  //[[NSColor redColor] set]; NSRectFill(dstRect);
  [icon drawInRect:dstRect
           fromRect:NSZeroRect
          operation:NSCompositeSourceOver
           fraction:1.0
     respectFlipped:YES
              hints:nil];
}


@end

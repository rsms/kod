// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

@interface NSOutlineView (KFileOutlineView)
- (NSArray *)selectedItems;
- (void)setSelectedItems:(NSArray *)items;
@end

extern NSColor *KFileOutlineViewBackgroundColor;
extern NSColor *KFileOutlineViewRowBackgroundColorBlur;
extern NSColor *KFileOutlineViewRowBackgroundColorFocus;

@interface KFileOutlineView : NSOutlineView {
  BOOL firstResponder_;
}

@property(readonly) BOOL firstResponder;

- (void)draggedImage:(NSImage *)image
             endedAt:(NSPoint)screenPoint
           operation:(NSDragOperation)operation;
@end

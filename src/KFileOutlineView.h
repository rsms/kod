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

#import "KFileOutlineView.h"
#import "KFileTextFieldCell.h"

@implementation NSOutlineView (KFileOutlineView)


- (NSArray *)selectedItems {
  NSMutableArray *items = [NSMutableArray array];
  NSIndexSet *selectedRows = [self selectedRowIndexes];
  if (selectedRows != nil) {
    for (NSInteger row = [selectedRows firstIndex];
         row != NSNotFound;
         row = [selectedRows indexGreaterThanIndex:row]) {
      [items addObject:[self itemAtRow:row]];
    }
  }
  return items;
}


- (void)setSelectedItems:(NSArray *)items {
  // If we are extending the selection, we start with the existing selection;
  // otherwise, we create a new blank set of the indexes.
  NSMutableIndexSet *newSelection = [[NSMutableIndexSet alloc] init];

  for (NSInteger i = 0; i < [items count]; i++) {
    NSInteger row = [self rowForItem:[items objectAtIndex:i]];
    if (row >= 0) {
      [newSelection addIndex:row];
    }
  }

  [self selectRowIndexes:newSelection byExtendingSelection:NO];

  [newSelection release];
}

@end


@implementation KFileOutlineView


NSColor *KFileOutlineViewBackgroundColor;
NSColor *KFileOutlineViewRowBackgroundColorBlur;
NSColor *KFileOutlineViewRowBackgroundColorFocus;
static Class KFileTextFieldCellClass;


+ (void)load {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  KFileOutlineViewBackgroundColor =
    [[NSColor colorWithCalibratedWhite:0.225 alpha:1.0] retain];
  KFileOutlineViewRowBackgroundColorBlur =
    [[NSColor colorWithCalibratedWhite:1.0 alpha:0.2] retain];
  KFileOutlineViewRowBackgroundColorFocus =
    [[NSColor colorWithCalibratedRed:0.6 green:0.8 blue:1.0 alpha:0.9] retain];
  KFileTextFieldCellClass = [KFileTextFieldCell class];
  [pool drain];
}


/*
This NSOutlineView subclass is necessary only if you want to delete items by
dragging them to the trash.  In order to support drags to the trash, you need to
implement draggedImage:endedAt:operation: and handle the NSDragOperationDelete
operation. For any other operation, pass the message to the superclass.
*/
- (void)draggedImage:(NSImage *)image endedAt:(NSPoint)screenPoint operation:(NSDragOperation)operation {
  if (operation == NSDragOperationDelete) {
    // Tell all of the dragged nodes to remove themselves from the model.
    NSArray *selection = [NSArray array];// FIXME [(AppController *)[self dataSource] draggedNodes];
    for (NSTreeNode *node in selection) {
      [[[node parentNode] mutableChildNodes] removeObject:node];
    }
    [self reloadData];
    [self deselectAll:nil];
  } else {
    [super draggedImage:image endedAt:screenPoint operation:operation];
  }
}


- (BOOL)firstResponder {
  return firstResponder_;
}


- (void)setFirstResponder:(BOOL)y {
  firstResponder_ = y;
  __block NSRect dirtyRect = NSZeroRect;
  NSIndexSet *selectedRows = [self selectedRowIndexes];
  if (selectedRows) {
    [selectedRows enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop){
      NSRect r = [self rectOfRow:row];
      if (NSIsEmptyRect(dirtyRect)) {
        dirtyRect = r;
      } else {
        dirtyRect = NSUnionRect(dirtyRect, r);
      }
    }];
    [self setNeedsDisplayInRect:dirtyRect];
  }
}


- (BOOL)becomeFirstResponder {
  [self setFirstResponder:YES];
  return YES;
}


- (BOOL)resignFirstResponder {
  [self setFirstResponder:NO];
  return YES;
}


- (id)_highlightColorForCell:(NSCell*)cell; {
  if (![cell isKindOfClass:KFileTextFieldCellClass])
    return firstResponder_ ? KFileOutlineViewRowBackgroundColorFocus
                           : KFileOutlineViewRowBackgroundColorBlur;
  return nil;
}


@end

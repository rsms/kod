#import "KFileTreeController.h"
#import "KFileTreeNodeData.h"
#import "KFileTextFieldCell.h"
#import "KFileOutlineView.h"
#import "KDocumentController.h"
#import "common.h"
#import "kconf.h"

static NSString *kNameColumnId = @"name";

@implementation KFileTreeController


- (id)init {
  self = [super init];
  useGroupRowLook_ = NO;
  allowOnDropOnContainer_ = YES;
  allowBetweenDrop_ = YES;

  KFileTreeNodeData *nodeData = [[KFileTreeNodeData new] autorelease];
  nodeData.container = YES;
  rootTreeNode_ = [[NSTreeNode treeNodeWithRepresentedObject:nodeData] retain];

  return self;
}


- (id)initWithOutlineView:(NSOutlineView*)outlineView {
  self = [self init];
  h_objc_xch(&outlineView_, outlineView);
  [outlineView_ setDelegate:self];
  [outlineView_ setDataSource:self];
  [outlineView_ setTarget:self];
  [outlineView_ setDoubleAction:@selector(doubleClickOnOutlineView:)];
  return self;
}


- (NSTreeNode*)rootTreeNode {
  return rootTreeNode_;
}


- (void)setRootTreeNode:(NSTreeNode*)node {
  id old = rootTreeNode_;
  rootTreeNode_ = [node retain];
  [old release];
  NSString *autosaveName = @"dir:";
  if (rootTreeNode_) {
    KFileTreeNodeData *nodeData = rootTreeNode_.representedObject;
    if (nodeData)
      autosaveName =
        [autosaveName stringByAppendingString:[nodeData.url absoluteString]];
  }
  [outlineView_ setAutosaveName:autosaveName];
}


- (BOOL)setRootTreeNodeFromDirectoryAtPath:(NSString*)path
                                     error:(NSError**)error {
  NSTreeNode *n = [self treeNodeFromDirectoryAtPath:path error:error];
  if (n) {
    [[rootTreeNode_ retain] autorelease];
    h_casid(&rootTreeNode_, n);
    [outlineView_ reloadData];
    return YES;
  }
  return NO; // error set
}


- (NSTreeNode*)treeNodeFromDirectoryAtPath:(NSString*)path
                                     error:(NSError**)error {
  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL isDir = NO;
  if (![fm fileExistsAtPath:path isDirectory:&isDir] || !isDir) {
    NSString *msg = [NSString stringWithFormat:@"Not a directory: %@", path];
    *error = [NSError errorWithDomain:NSStringFromClass([isa class])
                                 code:0
                             userInfo:[NSDictionary dictionaryWithObject:msg
                                       forKey:NSLocalizedDescriptionKey]];
    return nil;
  }

  static NSArray *metaKeys = nil;
  if (!metaKeys) {
    metaKeys = [[NSArray alloc] initWithObjects:
      //NSURLIsRegularFileKey,
      NSURLIsDirectoryKey,
      NSURLIsSymbolicLinkKey,
      //NSURLContentModificationDateKey, NSURLTypeIdentifierKey,
      //NSURLLabelNumberKey, NSURLLabelColorKey,
      NSURLEffectiveIconKey,
      nil];
  }

  NSURL *dirurl = [NSURL fileURLWithPath:path isDirectory:YES];
  NSArray *urls = [fm contentsOfDirectoryAtURL:dirurl
                    includingPropertiesForKeys:metaKeys
                                  options:NSDirectoryEnumerationSkipsHiddenFiles
                                         error:error];
  if (!urls) return nil;

  KFileTreeNodeData *nodeData =
      [KFileTreeNodeData fileTreeNodeDataWithPath:path];
  nodeData.container = YES;
  NSTreeNode *root = [NSTreeNode treeNodeWithRepresentedObject:nodeData];
  NSMutableArray *childNodes = [root mutableChildNodes];

  for (NSURL *url in urls) {
    NSDictionary *meta = [url resourceValuesForKeys:metaKeys error:nil];
    if (!meta) continue;
    NSTreeNode *node;
    if ([[meta objectForKey:NSURLIsDirectoryKey] boolValue]) {
      node = [self treeNodeFromDirectoryAtPath:url.path error:error];
      // don't abort on error, but let |error| be assigned and continue with
      // next entry.
      if (node) {
        nodeData = [node representedObject];
      }
    } else {
      nodeData = [KFileTreeNodeData fileTreeNodeDataWithPath:[url path]];
      node = [NSTreeNode treeNodeWithRepresentedObject:nodeData];
      nodeData.container = NO;
    }
    if (node && nodeData) {
      nodeData.image = [meta objectForKey:NSURLEffectiveIconKey];
      [childNodes addObject:node];
    }
  }

  return root;
}

/*- (void)treeNodeFromDirectoryAtPath:(NSString*)path
                           callback:(void(^)(NSError*,NSTreeNode*))callback {
  //__block NSThread *originThread = [NSThread currentThread];
  CFRunLoopRef originRunLoop = CFRunLoopGetCurrent();
  dispatch_queue_t g_queue =
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  dispatch_async(g_queue, ^{
    __block NSError *error = nil;
    __block NSTreeNode *node = [self treeNodeFromDirectoryAtPath:path];
    CFRunLoopPerformBlock(originRunLoop, kCFRunLoopDefaultMode, ^{
      callback(error, node);
    });
  });
}*/


#pragma mark -
#pragma mark NSOutlineViewDataSource methods

// The NSOutlineView uses 'nil' to indicate the root item. We return our root tree node for that case.
- (NSArray *)childrenForItem:(id)item {
  if (item == nil) {
    return [rootTreeNode_ childNodes];
  } else {
    return [item childNodes];
  }
}

// Required methods.
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
  // 'item' may potentially be nil for the root item.
  NSArray *children = [self childrenForItem:item];
  // This will return an NSTreeNode with our model object as the representedObject
  return [children objectAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
  // 'item' will always be non-nil. It is an NSTreeNode, since those are always the objects we give NSOutlineView. We access our model object from it.
  KFileTreeNodeData *nodeData = [item representedObject];
  // We can expand items if the model tells us it is a container
  return nodeData.container;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
  // 'item' may potentially be nil for the root item.
  NSArray *children = [self childrenForItem:item];
  return [children count];
}

- (id)outlineView:(NSOutlineView *)outlineView
objectValueForTableColumn:(NSTableColumn *)tableColumn
           byItem:(id)item {
  KFileTreeNodeData *nodeData = [item representedObject];
  return nodeData.name;
}

// Optional method: needed to allow editing.
- (void)outlineView:(NSOutlineView *)outlineView
     setObjectValue:(id)object
     forTableColumn:(NSTableColumn *)tableColumn
             byItem:(id)item  {
  KFileTreeNodeData *nodeData = [item representedObject];
  nodeData.name = object;
}

// We can return a different cell for each row, if we want
- (NSCell *)outlineView:(NSOutlineView *)outlineView
 dataCellForTableColumn:(NSTableColumn *)tableColumn
                   item:(id)item {
  // If we return a cell for the 'nil' tableColumn, it will be used as a "full width" cell and span all the columns
  if (useGroupRowLook_ && (tableColumn == nil)) {
    KFileTreeNodeData *nodeData = [item representedObject];
    if (nodeData.container) {
      // We want to use the cell for the name column, but we could construct a new cell if we wanted to, or return a different cell for each row.
      return [[outlineView tableColumnWithIdentifier:kNameColumnId] dataCell];
    }
  }
  return [tableColumn dataCell];
}

// To get the "group row" look, we implement this method.
- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item {
  KFileTreeNodeData *nodeData = [item representedObject];
  return nodeData.container && useGroupRowLook_;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item {
  // Query our model for the answer to this question
  KFileTreeNodeData *nodeData = [item representedObject];
  return nodeData.expandable;
}

- (void)outlineView:(NSOutlineView *)outlineView
    willDisplayCell:(NSCell *)cell
     forTableColumn:(NSTableColumn *)tableColumn
               item:(id)item {
  KFileTreeNodeData *nodeData = [item representedObject];
  // Make sure the image and text cell has an image.
  // If not, lazily fill in a random image
  if (nodeData.image == nil) {
    nodeData.image =
        [[NSWorkspace sharedWorkspace] iconForFile:nodeData.name];
  }
  // We know that the cell at this column is our image and text cell, so grab it
  KFileTextFieldCell *fileTextFieldCell = (KFileTextFieldCell *)cell;
  // Set the image here since the value returned from outlineView
  // objectValueForTableColumn:... didn't specify the image part...
  fileTextFieldCell.image = nodeData.image;
  // For all the other columns, we don't do anything.
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
  // Control selection of a particular item.
  KFileTreeNodeData *nodeData = [item representedObject];
  return nodeData && nodeData.selectable;
}


- (BOOL)_openFileAtRow:(NSInteger)row {
  // open file if it has a URL and isn't a directory
  if (row == NSNotFound) return NO;
  NSTreeNode *treeNode = [outlineView_ itemAtRow:row];
  if (!treeNode) return NO;
  KFileTreeNodeData *nodeData = [treeNode representedObject];
  if (!nodeData) return NO;
  if (nodeData.url && !nodeData.container) {
    KDocumentController *documentController =
      (KDocumentController*)[NSDocumentController sharedDocumentController];
    NSArray *fileURLs = [NSArray arrayWithObject:nodeData.url];
    [documentController openDocumentsWithContentsOfURLs:fileURLs
                                               callback:nil];
    return YES;
  }
  return NO;
}


- (void)outlineViewSelectionDidChange:(NSNotification *)notification {
  NSIndexSet *selectedRows = [outlineView_ selectedRowIndexes];
  if (selectedRows && selectedRows.count == 1) {
    [self _openFileAtRow:[selectedRows firstIndex]];
  }
}

- (IBAction)doubleClickOnOutlineView:(id)sender {
  NSTreeNode *treeNode = [outlineView_ itemAtRow:[outlineView_ clickedRow]];
  KFileTreeNodeData *nodeData = [treeNode representedObject];
  if (nodeData && nodeData.url && nodeData.container) {
    KDocumentController *documentController =
    (KDocumentController*)[NSDocumentController sharedDocumentController];
    NSArray *fileURLs = [NSArray arrayWithObject:nodeData.url];
    [documentController openDocumentsWithContentsOfURLs:fileURLs
                                               callback:nil];
  }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView
    shouldTrackCell:(NSCell *)cell
     forTableColumn:(NSTableColumn *)tableColumn
               item:(id)item {
  // We want to allow tracking for all the button cells, even if we don't allow selecting that particular row.
  if ([cell isKindOfClass:[NSButtonCell class]]) {
    // We can also take a peek and make sure that the part of the cell clicked is an area that is normally tracked. Otherwise, clicking outside of the checkbox may make it check the checkbox
    NSRect cellFrame = [outlineView frameOfCellAtColumn:[[outlineView tableColumns] indexOfObject:tableColumn] row:[outlineView rowForItem:item]];
    NSUInteger hitTestResult = [cell hitTestForEvent:[NSApp currentEvent] inRect:cellFrame ofView:outlineView];
    if ((hitTestResult & NSCellHitTrackableArea) != 0) {
      return YES;
    } else {
      return NO;
    }
  } else {
    // Only allow tracking on selected rows. This is what NSTableView does by default.
    return [outlineView isRowSelected:[outlineView rowForItem:item]];
  }
}

static NSString *GenerateUniqueFileNameAtPath(NSString *path, NSString *basename, NSString *extension) {
  NSString *filename = [NSString stringWithFormat:@"%@.%@", basename, extension];
  NSString *result = [path stringByAppendingPathComponent:filename];
  NSInteger i = 1;
  while ([[NSFileManager defaultManager] fileExistsAtPath:result]) {
    filename = [NSString stringWithFormat:@"%@ %ld.%@", basename, (long)i, extension];
    result = [path stringByAppendingPathComponent:filename];
    i++;
  }
  return result;
}

// We promised the files, so now lets make good on that promise!
- (NSArray *)outlineView:(NSOutlineView *)outlineView
namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination
         forDraggedItems:(NSArray *)items {
  NSMutableArray *result = nil;

  for (NSInteger i = 0; i < [items count]; i++) {
    NSString *filepath =
        GenerateUniqueFileNameAtPath([dropDestination path], @"PromiseTestFile",
                                     @"txt");
    // We write out the tree node's description
    NSTreeNode *treeNode = [items objectAtIndex:i];
    KFileTreeNodeData *nodeData = treeNode.representedObject;
    NSString *itemString = [nodeData description];
    NSError *error = nil;
    if (![itemString writeToURL:[NSURL fileURLWithPath:filepath] atomically:NO encoding:NSUTF8StringEncoding error:&error]) {
      [NSApp presentError:error];

    }
  }
  return result;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView
         writeItems:(NSArray *)items
       toPasteboard:(NSPasteboard *)pboard {
  // Don't retain draggedNodes_ since this is just holding temporaral drag
  // information, and it is only used during a drag! We could put this in the
  // pboard actually.
  draggedNodes_ = items;

  // Provide data for our custom type, and simple NSStrings.
  NSArray *pbTypes = [NSArray arrayWithObjects:NSStringPboardType,
                                               NSFilesPromisePboardType, nil];
  [pboard declareTypes:pbTypes owner:self];

  // Put string data on the pboard
  NSString *text = nil;
  for (NSTreeNode *node in draggedNodes_) {
    if (text == nil) {
      text = [node.representedObject path];
    } else {
      text = [text stringByAppendingFormat:@"\n%@",
              [node.representedObject path]];
    }
  }
  if (text)
    [pboard setString:text forType:NSStringPboardType];

  // Put the promised type we handle on the pasteboard.
  [pboard setPropertyList:[NSArray arrayWithObjects:@"txt", nil] forType:NSFilesPromisePboardType];

  return YES;
}

- (BOOL)treeNode:(NSTreeNode *)treeNode isDescendantOfNode:(NSTreeNode *)parentNode {
  while (treeNode != nil) {
    if (treeNode == parentNode) {
      return YES;
    }
    treeNode = [treeNode parentNode];
  }
  return NO;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView
                  validateDrop:(id <NSDraggingInfo>)info
                  proposedItem:(id)item
            proposedChildIndex:(NSInteger)childIndex {
  DLOG("validateDrop:%@ item:%@", info, item);
  // To make it easier to see exactly what is called, uncomment the following line:
  //    NSLog(@"outlineView:validateDrop:proposedItem:%@ proposedChildIndex:%ld", item, (long)childIndex);

  // This method validates whether or not the proposal is a valid one.
  // We start out by assuming that we will do a "generic" drag operation, which means we are accepting the drop. If we return NSDragOperationNone, then we are not accepting the drop.
  NSDragOperation result = NSDragOperationGeneric;

  // Check to see what we are proposed to be dropping on
  NSTreeNode *targetNode = item;
  // A target of "nil" means we are on the main root tree
  if (targetNode == nil) {
    targetNode = rootTreeNode_;
  }
  KFileTreeNodeData *nodeData = [targetNode representedObject];
  if (nodeData.container) {
    // See if we allow dropping "on" or "between"
    if (childIndex == NSOutlineViewDropOnItemIndex) {
      if (!allowOnDropOnContainer_) {
        // Refuse to drop on a container if we are not allowing that
        result = NSDragOperationNone;
      }
    } else {
      if (!allowBetweenDrop_) {
        // Refuse to drop between an item if we are not allowing that
        result = NSDragOperationNone;
      }
    }
  } else {
    // The target node is not a container, but a leaf.
    if (childIndex == NSOutlineViewDropOnItemIndex) {
      result = NSDragOperationNone;
    }
  }

  // If we are allowing the drop, we see if we are draggng from ourselves and
  // dropping into a descendent, which wouldn't be allowed...
  if (result != NSDragOperationNone) {
    if ([info draggingSource] == outlineView) {
      // Yup, the drag is originating from ourselves. See if the appropriate drag information is available on the pasteboard
      if (targetNode != rootTreeNode_
          /*&& [[info draggingPasteboard] availableTypeFromArray:[NSArray
          arrayWithObject:SIMPLE_BPOARD_TYPE]] != nil*/ ) {
        for (NSTreeNode *draggedNode in draggedNodes_) {
          if ([self treeNode:targetNode isDescendantOfNode:draggedNode]) {
            // Yup, it is, refuse it.
            result = NSDragOperationNone;
            break;
          }
        }
      }
    }
  }
  // To see what we decide to return, uncomment this line
  //    NSLog(result == NSDragOperationNone ? @" - Refusing drop" : @" + Accepting drop");

  return result;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView
         acceptDrop:(id <NSDraggingInfo>)info
               item:(id)item
         childIndex:(NSInteger)childIndex {
  DLOG("acceptDrop:%@ item:%@", info, item);
  NSArray *oldSelectedNodes = [outlineView selectedItems];

  NSTreeNode *targetNode = item;
  // A target of "nil" means we are on the main root tree
  if (targetNode == nil) {
    targetNode = rootTreeNode_;
  }
  KFileTreeNodeData *nodeData = [targetNode representedObject];

  // Determine the parent to insert into and the child index to insert at.
  if (!nodeData.container) {
    // If our target is a leaf, and we are dropping on it
    if (childIndex == NSOutlineViewDropOnItemIndex) {
      // If we are dropping on a leaf, we will have to turn it into a container node
      nodeData.container = YES;
      nodeData.expandable = YES;
      childIndex = 0;
    } else {
      // We will be dropping on the item's parent at the target index of this child, plus one
      NSTreeNode *oldTargetNode = targetNode;
      targetNode = [targetNode parentNode];
      childIndex = [[targetNode childNodes] indexOfObject:oldTargetNode] + 1;
    }
  } else {
    if (childIndex == NSOutlineViewDropOnItemIndex) {
      // Insert it at the start, if we were dropping on it
      childIndex = 0;
    }
  }

  NSArray *currentDraggedNodes = nil;
  // If the source was ourselves, we use our dragged nodes.
  if ([info draggingSource] == outlineView
      /* && [[info draggingPasteboard] availableTypeFromArray:[NSArray
      arrayWithObject:SIMPLE_BPOARD_TYPE]] != nil*/ ) {
    // Yup, the drag is originating from ourselves. See if the appropriate drag information is available on the pasteboard
    currentDraggedNodes = draggedNodes_;
  } else {
    // We create a new model item for the dropped data, and wrap it in an
    // NSTreeNode. Try the filename -- it is an array of filenames, so we just
    // grab one.
    id plist =
        [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
    if (![plist isKindOfClass:[NSArray class]])
      return NO;
    NSArray *draggedFiles = plist;
    NSString *path = [draggedFiles lastObject];
    if (!path)
      return NO;
    KFileTreeNodeData *newNodeData =
        [KFileTreeNodeData fileTreeNodeDataWithPath:path];
    NSTreeNode *treeNode =
        [NSTreeNode treeNodeWithRepresentedObject:newNodeData];
    newNodeData.container = NO;
    // Finally, add it to the array of dragged items to insert
    currentDraggedNodes = [NSArray arrayWithObject:treeNode];
  }

  NSMutableArray *childNodeArray = [targetNode mutableChildNodes];
  // Go ahead and move things.
  for (NSTreeNode *treeNode in currentDraggedNodes) {
    // Remove the node from its old location
    NSInteger oldIndex = [childNodeArray indexOfObject:treeNode];
    NSInteger newIndex = childIndex;
    if (oldIndex != NSNotFound) {
      [childNodeArray removeObjectAtIndex:oldIndex];
      if (childIndex > oldIndex) {
        newIndex--; // account for the remove
      }
    } else {
      // Remove it from the old parent
      [[[treeNode parentNode] mutableChildNodes] removeObject:treeNode];
    }
    [childNodeArray insertObject:treeNode atIndex:newIndex];
    newIndex++;
  }

  [outlineView reloadData];
  // Make sure the target is expanded
  [outlineView expandItem:targetNode];
  // Reselect old items.
  [outlineView setSelectedItems:oldSelectedNodes];

  // Return YES to indicate we were successful with the drop. Otherwise, it would slide back the drag image.
  return YES;
}

// On Mac OS 10.5 and above, NSTableView and NSOutlineView have better contextual menu support. We now see a highlighted item for what was clicked on, and can access that item to do particular things (such as dynamically change the menu, as we do here!). Each of the contextual menus in the nib file have the delegate set to be the AppController instance. In menuNeedsUpdate, we dynamically update the menus based on the currently clicked upon row/column pair.
/*- (void)menuNeedsUpdate:(NSMenu *)menu {
  NSInteger clickedRow = [outlineView clickedRow];
  id item = nil;
  KFileTreeNodeData *nodeData = nil;
  BOOL clickedOnMultipleItems = NO;

  if (clickedRow != -1) {
    // If we clicked on a selected row, then we want to consider all rows in the selection. Otherwise, we only consider the clicked on row.
    item = [outlineView itemAtRow:clickedRow];
    nodeData = [item representedObject];
    clickedOnMultipleItems = [outlineView isRowSelected:clickedRow] && ([outlineView numberOfSelectedRows] > 1);
  }

  if (menu == outlineViewContextMenu) {
    NSMenuItem *menuItem = [menu itemAtIndex:0];
    if (nodeData != nil) {
      if (clickedOnMultipleItems) {
        // We could walk through the selection and note what was clicked on at this point
        [menuItem setTitle:[NSString stringWithFormat:@"You clicked on %ld items!", (long)[outlineView numberOfSelectedRows]]];
      } else {
        [menuItem setTitle:[NSString stringWithFormat:@"You clicked on: '%@'", nodeData.name]];
      }
      [menuItem setEnabled:YES];
    } else {
      [menuItem setTitle:@"You didn't click on any rows..."];
      [menuItem setEnabled:NO];
    }

  } else if (menu == expandableColumnMenu) {
    NSMenuItem *menuItem = [menu itemAtIndex:0];
    if (!clickedOnMultipleItems && (nodeData != nil)) {
      // The item will be enabled only if it is a group
      [menuItem setEnabled:nodeData.container];
      // Check it if it is expandable
      [menuItem setState:nodeData.expandable ? 1 : 0];
    } else {
      [menuItem setEnabled:NO];
    }
  }
}

- (IBAction)expandableMenuItemAction:(id)sender {
  // The tag of the clicked row contains the item that was clicked on
  NSInteger clickedRow = [outlineView clickedRow];
  NSTreeNode *treeNode = [outlineView itemAtRow:clickedRow];
  KFileTreeNodeData *nodeData = [treeNode representedObject];
  // Flip the expandable state,
  nodeData.expandable = !nodeData.expandable;
  // Refresh that row (since its state has changed)
  [outlineView setNeedsDisplayInRect:[outlineView rectOfRow:clickedRow]];
  // And collopse it if we can no longer expand it
  if (!nodeData.expandable && [outlineView isItemExpanded:treeNode]) {
    [outlineView collapseItem:treeNode];
  }
}

- (IBAction)useGroupGrowLook:(id)sender {
  // We simply need to redraw things.
  [outlineView setNeedsDisplay:YES];
}*/

@end

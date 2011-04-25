// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "KASTViewerController.h"
#import "KASTOutlineView.h"
#import "KFileTreeNodeData.h"
#import "KFileTextFieldCell.h"
#import "KFileOutlineView.h"
#import "KDocumentController.h"
#import "KDocument.h"
#import "common.h"
#import "kconf.h"

using namespace kod;

static NSString *kNameColumnId = @"name";


@interface ASTNodePtrObjCWrapper : NSObject {
 @public
  ASTNodePtr ptr;
}
@end
@implementation ASTNodePtrObjCWrapper
@end


@implementation KASTViewerController


- (void)awakeFromNib {
  rootTreeNode_ = [[NSTreeNode treeNodeWithRepresentedObject:nil] retain];
  [outlineView_ setDelegate:self];
  [outlineView_ setDataSource:self];
}


- (NSTreeNode*)rootTreeNode {
  return rootTreeNode_;
}


- (void)setRootTreeNode:(NSTreeNode*)node {
  if (h_casid(&rootTreeNode_, node)) {
    //DLOG_TRACE();
    kassert(outlineView_ != nil);
    [outlineView_ reloadData];
    [outlineView_ expandItem:nil expandChildren:YES];
  }
}


- (NSTreeNode*)_makeTreeNodeFromASTNode:(ASTNodePtr)astNode {
  if (!astNode.get())
    return nil;

  ASTNodePtrObjCWrapper *nodeData = [[ASTNodePtrObjCWrapper new] autorelease];
  nodeData->ptr = astNode;
  NSTreeNode *node = [NSTreeNode treeNodeWithRepresentedObject:nodeData];

  if (!astNode->childNodes().empty()) {
    NSMutableArray *childNodes = [node mutableChildNodes];
    std::vector<ASTNodePtr>::iterator it = astNode->childNodes().begin();
    std::vector<ASTNodePtr>::iterator endit = astNode->childNodes().end();
    for ( ; it < endit; ++it ) {
      NSTreeNode *childNode = [self _makeTreeNodeFromASTNode:*it];
      if (childNode)
        [childNodes addObject:childNode];
    }
  }

  return node;
}


- (void)setRootTreeNodeWithASTNode:(ASTNodePtr)astNode {
  NSTreeNode *root = [self _makeTreeNodeFromASTNode:astNode];
  [self setRootTreeNode:root];
}


- (KDocument*)representedDocument {
  return representedDocument_;
}


- (void)setRepresentedDocument:(KDocument*)representedDocument {
  h_casid(&rootTreeNode_, nil);
  if (h_casid(&representedDocument_, representedDocument)) {
    [self setRootTreeNodeWithASTNode:representedDocument.astRootNode];
  }
}


#pragma mark -
#pragma mark NSOutlineViewDataSource methods


- (NSArray *)childrenForItem:(id)item {
  if (item == nil) {
    return [rootTreeNode_ childNodes];
  } else {
    return [item childNodes];
  }
}


- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
  // 'item' may potentially be nil for the root item.
  NSArray *children = [self childrenForItem:item];
  // This will return an NSTreeNode with our model object as the representedObject
  return [children objectAtIndex:index];
}


- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
  return ![item isLeaf];
}


- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
  return [[self childrenForItem:item] count];
}


- (id)outlineView:(NSOutlineView *)outlineView
objectValueForTableColumn:(NSTableColumn *)tableColumn
           byItem:(id)item {
  ASTNodePtrObjCWrapper *nodeData = [item representedObject];
  if ([tableColumn.identifier isEqualToString:@"kind"]) {
    //return nodeData->ptr->kind()->weakNSString();
    return nodeData->ptr->ruleNameString();
  } else if ([tableColumn.identifier isEqualToString:@"sourceRange"]) {
    return [NSString stringWithFormat:@"%lu, %lu",
            nodeData->ptr->sourceRange().location,
            nodeData->ptr->sourceRange().length];
  }
}


- (BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item {
  return ![item isLeaf];
}


- (void)outlineViewSelectionDidChange:(NSNotification*)notification {
  if (!representedDocument_) return;
  NSTreeNode *treeNode = [outlineView_ itemAtRow:[outlineView_ selectedRow]];
  ASTNodePtrObjCWrapper *nodeData = [treeNode representedObject];
  if (nodeData && nodeData->ptr.get()) {
    NSRange sourceRange = nodeData->ptr->absoluteSourceRange();
    if (sourceRange.location != NSNotFound) {
      [representedDocument_.textView setSelectedRange:sourceRange];
    }
  }
}


@end

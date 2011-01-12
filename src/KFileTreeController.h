// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

@interface KFileTreeController : NSObject <NSOutlineViewDataSource,
                                           NSOutlineViewDelegate> {
  NSOutlineView* outlineView_;
  NSTreeNode *rootTreeNode_;
  __weak NSArray *draggedNodes_;
  BOOL useGroupRowLook_;
  BOOL allowOnDropOnContainer_;
  BOOL allowBetweenDrop_;
}

@property(retain, nonatomic) NSTreeNode *rootTreeNode;

- (id)initWithOutlineView:(NSOutlineView*)outlineView;

- (NSTreeNode*)treeNodeFromDirectoryAtPath:(NSString*)path
                                     error:(NSError**)error;

- (BOOL)setRootTreeNodeFromDirectoryAtPath:(NSString*)path
                                     error:(NSError**)error;

@end

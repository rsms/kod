// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#include "ASTNode.h"

// Important note: This uses a highly inefficient implementation and is only
// meant to be used for debugging and development

@class KDocument, KASTOutlineView;

@interface KASTViewerController : NSObject <NSOutlineViewDataSource,
                                            NSOutlineViewDelegate> {
  IBOutlet KASTOutlineView* outlineView_;
  NSTreeNode *rootTreeNode_;
  KDocument *representedDocument_;
}

@property(retain) KDocument *representedDocument;

- (void)setRootTreeNodeWithASTNode:(kod::ASTNodePtr)astNode;

@end

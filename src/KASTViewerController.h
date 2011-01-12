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

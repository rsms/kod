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

// Represents a node in the file tree

@interface KFileTreeNodeData : NSObject {
@private
  NSString *path_;
  NSString *name_;
  NSImage *image_;
  BOOL expandable_;
  BOOL selectable_;
  BOOL container_;
}

@property(readwrite, retain) NSString *path;
@property(readwrite, retain) NSString *name;
@property(readwrite, retain) NSImage *image;
@property(readwrite, getter=isExpandable) BOOL expandable;
@property(readwrite, getter=isSelectable) BOOL selectable;
@property(readwrite, getter=isContainer) BOOL container;

- (id)initWithPath:(NSString *)path;
+ (KFileTreeNodeData*)fileTreeNodeDataWithPath:(NSString *)path;

- (NSComparisonResult)compare:(id)other;

@end



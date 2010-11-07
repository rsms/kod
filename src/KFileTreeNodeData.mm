#import "KFileTreeNodeData.h"

@implementation KFileTreeNodeData

@synthesize path = path_,
            name = name_,
            image = image_,
            expandable = expandable_,
            selectable = selectable_,
            container = container_;

- (id)init {
  self = [super init];
  self.name = @"Untitled";
  self.expandable = YES;
  self.selectable = YES;
  self.container = YES;
  return self;
}

- (id)initWithPath:(NSString *)path {
  self = [self init];
  self.path = path;
  self.name = [path lastPathComponent];
  return self;
}

- (void)dealloc {
  [path_ release];
  [name_ release];
  [image_ release];
  [super dealloc];
}

+ (KFileTreeNodeData*)fileTreeNodeDataWithPath:(NSString *)path {
  return [[[self alloc] initWithPath:path] autorelease];
}

- (NSComparisonResult)compare:(id)anOther {
  // We want the data to be sorted by name
  if ([anOther isKindOfClass:[KFileTreeNodeData class]]) {
    KFileTreeNodeData *other = (KFileTreeNodeData *)anOther;
    return [name_ compare:other.name];
  } else {
    return NSOrderedAscending;
  }
}

- (NSString *)description {
  return [NSString stringWithFormat:
      @"%@ - '%@' expandable: %d, selectable: %d, container: %d",
      [super description], self.name, self.expandable, self.selectable,
      self.container];
}

@end

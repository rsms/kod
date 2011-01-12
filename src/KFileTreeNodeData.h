// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

// Represents a node in the file tree

@interface KFileTreeNodeData : NSObject {
@private
  NSURL *url_;
  NSString *name_;
  NSImage *image_;
  BOOL expandable_;
  BOOL selectable_;
  BOOL container_;
}

@property(readwrite, retain) NSURL *url;
@property(readwrite, retain) NSString *name;
@property(readwrite, retain) NSImage *image;
@property(readwrite, getter=isExpandable) BOOL expandable;
@property(readwrite, getter=isSelectable) BOOL selectable;
@property(readwrite, getter=isContainer) BOOL container;

- (id)initWithPath:(NSString *)path;
+ (KFileTreeNodeData*)fileTreeNodeDataWithPath:(NSString *)path;

- (NSComparisonResult)compare:(id)other;

@end



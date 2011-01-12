// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "KTextFieldDecoration.h"

@interface KModeTextFieldDecoration : KTextFieldDecoration {
  NSImage *icon_;
  NSString *name_;
}
@property(retain) NSString *name;

- (id)initWithName:(NSString*)name;

@end

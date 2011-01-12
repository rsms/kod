// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.


#import "HSpinLock.h"

@interface KTextStorage : NSTextStorage {
  NSMutableArray *batchQueue_;
  HSpinLock batchQueueLock_;
}

- (void)queueAttributes:(NSDictionary*)attrs range:(NSRange)range;
- (void)flushQueuedAttributes;

@end

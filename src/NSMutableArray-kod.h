// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

@interface NSMutableArray (Kod)

// Reverse objects in range in-place (based on exchangeObjectAtIndex:...)
- (void)reverseObjectsInRange:(NSRange)range;

@end

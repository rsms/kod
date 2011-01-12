// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

@interface NSString (data)

- (NSMutableData*)mutableDataUsingEncoding:(NSStringEncoding)encoding;

- (NSMutableData*)mutableDataUsingEncoding:(NSStringEncoding)encoding
                                     range:(NSRange)range;

@end

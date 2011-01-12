// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

@interface NSData (Kod)

// Returns an autoreleased string which will become invalid as soon as this data
// is deallocated. |range| is in bytes.
- (NSString*)weakStringWithEncoding:(NSStringEncoding)encoding
                              range:(NSRange)range;

- (NSString*)weakStringWithEncoding:(NSStringEncoding)encoding;

// If outEncoding is not nil, a successful encoding will be assigned (or zero)
- (NSString*)weakStringByGuessingEncoding:(NSStringEncoding*)outEncoding;

- (NSStringEncoding)guessEncodingWithPeekByteLimit:(NSUInteger)peekByteLimit
                                        headOffset:(NSUInteger*)outHeadOffset;

@end

// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

@interface NSString (ranges)

- (NSRange)rangeOfCharactersFromSet:(NSCharacterSet*)charset
                            options:(NSStringCompareOptions)opts
                              range:(NSRange)range;

- (NSRange)rangeOfCharactersFromSet:(NSCharacterSet*)characterSet
                      afterLocation:(NSUInteger)startLocation
                          substring:(NSString**)outString;

- (NSRange)rangeOfWhitespaceStringAtBeginningOfLineForRange:(NSRange)range
                                                substring:(NSString**)outString;

- (NSRange)rangeOfWhitespaceStringAtBeginningOfLineForRange:(NSRange)range;

- (NSUInteger)lineStartForRange:(NSRange)diveInRange;

- (unichar*)copyOfCharactersInRange:(NSRange)range;

+ (void)kodEnumerateLinesOfCharacters:(const unichar*)characters
                             ofLength:(NSUInteger)characterCount
                            withBlock:(void(^)(NSRange lineRange))block;

- (BOOL)hasPrefix:(NSString*)prefix options:(NSStringCompareOptions)options;

@end

// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

// dealing with NSString and C++ std library
#ifdef __cplusplus
#import <string>

@interface NSString (cpp)
- (NSUInteger)populateStdString:(std::string&)str
                  usingEncoding:(NSStringEncoding)encoding
                          range:(NSRange)range;
@end

#endif // __cplusplus

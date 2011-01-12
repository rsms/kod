// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "common.h"
#import <srchilite/regexrulefactory.h>
#import <map>

class KLangSymbol {
 public:
  static const std::string &symbolize(const std::string &name,
                                      NSString const **symbol = NULL);
  static NSString const *symbolForString(const std::string &name);
};

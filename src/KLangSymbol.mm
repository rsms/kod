// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#import "KLangSymbol.h"

typedef std::map<std::string, NSString const*> KLangSymbolMap;
static KLangSymbolMap gNames;


const std::string &KLangSymbol::symbolize(const std::string &name,
                                          NSString const ** symbol) {
  // TODO: atomicity
  KLangSymbolMap::iterator it = gNames.find(name);
  if (it == gNames.end()) {
    // new symbol
    NSString *sym =
        [[NSString alloc] initWithBytesNoCopy:(void*)name.data()
                                       length:name.size()
                                     encoding:NSISOLatin1StringEncoding
                                 freeWhenDone:NO];
    NSString const * internedSymbol = [sym internedString];
    if (internedSymbol != sym)
      [sym release];
    gNames.insert(std::pair<std::string, NSString*>(name, internedSymbol));
    //DLOG("REGISTER ('%s'@%p, '%@')", name.c_str(), name.data(),internedSymbol);
    if (symbol) *symbol = internedSymbol;
    return name;
  } else {
    //DLOG("FOUND '%s'@%p", name.c_str(), name.data());
    if (symbol) *symbol = it->second;
    return it->first;
  }
}


NSString const *KLangSymbol::symbolForString(const std::string &name) {
  KLangSymbolMap::iterator it = gNames.find(name);
  if (it == gNames.end()) {
    NSString const *symbol = nil;
    symbolize(name, &symbol);
    return symbol;
  } else {
    return it->second;
  }
}

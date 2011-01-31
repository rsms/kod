// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#ifndef KOD_GRAMMAR_HH_
#define KOD_GRAMMAR_HH_

#include <gazelle/Grammar.hh>
#include <tr1/memory>

namespace kod {

class Grammar : public gazelle::Grammar {
};

typedef std::tr1::shared_ptr<Grammar> GrammarPtr;

};  // namespace kod
#endif  // KOD_GRAMMAR_HH_

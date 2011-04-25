// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

#ifndef KOD_GRAMMAR_HH_
#define KOD_GRAMMAR_HH_

#include <gazelle/Grammar.hh>
#include <tr1/memory>

#import <CSS/CSS.h>

namespace kod {

class Grammar : public gazelle::Grammar {
 public:
  explicit Grammar(const char *identifier=NULL, const char *name=NULL)
      : gazelle::Grammar(name) {
    identifier_ = NULL;
    if (identifier)
      lwc_intern_string(identifier, strlen(identifier), &identifier_);
  }

  virtual ~Grammar() {
    if (identifier_) {
      lwc_string_unref(identifier_);
      identifier_ = NULL;
    }
  }

  lwc_string *identifier() { return identifier_; }

 protected:
  lwc_string *identifier_;
};

typedef std::tr1::shared_ptr<Grammar> GrammarPtr;

};  // namespace kod
#endif  // KOD_GRAMMAR_HH_

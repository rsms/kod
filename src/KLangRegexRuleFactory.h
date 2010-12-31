#import "common.h"
#import <srchilite/regexrulefactory.h>
#import <map>
#import "KLangSymbol.h"

/**
 * Simply interns all element names.
 */
class KLangRegexRuleFactory : public srchilite::RegexRuleFactory {
public:
  KLangRegexRuleFactory() {}
  virtual ~KLangRegexRuleFactory() {}


  inline srchilite::HighlightRule *createSimpleRule(const std::string &name,
                                             const std::string &s) {
    //DLOG("createSimpleRule ('%s', '%s')", name.c_str(), s.c_str());
    return RegexRuleFactory::createSimpleRule(KLangSymbol::symbolize(name), s);
  }

  inline srchilite::HighlightRule *
      createWordListRule(const std::string &name,
                         const srchilite::WordList &list,
                         bool caseSensitive = true) {
    //DLOG("createWordListRule ('%s')", name.c_str());
    return RegexRuleFactory::createWordListRule(KLangSymbol::symbolize(name),
                                                list, caseSensitive);
  }

  inline srchilite::HighlightRule *
      createListRule(const std::string &name,
                     const srchilite::WordList &list,
                     bool caseSensitive = true) {
    //DLOG("createListRule %s", name.c_str());
    return RegexRuleFactory::createListRule(KLangSymbol::symbolize(name), list,
                                            caseSensitive);
  }

  srchilite::HighlightRule *
      createCompoundRule(const srchilite::ElemNameList &names,
                         const std::string &rep) {
    srchilite::ElemNameList::const_iterator it = names.begin();
    for ( ; it != names.end(); it++) {
      //DLOG("[1] %s @ %p", (*it).c_str(), (*it).data());
      KLangSymbol::symbolize(*it);
    }
    return RegexRuleFactory::createCompoundRule(names, rep);
  }
};
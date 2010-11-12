#import "common.h"
#import <srchilite/regexrulefactory.h>
#import <map>

class KLangSymbol {
 public:
  static const std::string &symbolize(const std::string &name,
                                      NSString const **symbol = NULL);
  static NSString const *symbolForString(const std::string &name);
};

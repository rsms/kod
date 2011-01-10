#import "common.h"
#import <srchilite/regexrulefactory.h>
#import <map>
#import <string>

class KLangSymbol {
 public:
  static const std::string &symbolize(const std::string &name,
                                      NSString **symbol = NULL);
  static NSString *symbolForString(const std::string &name);
};

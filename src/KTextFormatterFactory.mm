#import "KTextFormatterFactory.h"
#import <ChromiumTabs/common.h>

//QtColorMap TextFormatterFactory::colorMap;

KTextFormatterFactory::KTextFormatterFactory() {
}

KTextFormatterFactory::~KTextFormatterFactory() {
}

bool KTextFormatterFactory::hasFormatter(const std::string &key) const {
  return textFormatterMap_.find(key) != textFormatterMap_.end();
}

KStyleElementPtr
    KTextFormatterFactory::getFormatter(const std::string &key) const {
  KStyleElementMap::const_iterator it = textFormatterMap_.find(key);
  if (it != textFormatterMap_.end()) {
    return it->second;
  } else {
    return KStyleElementPtr();
  }
}

void KTextFormatterFactory::addFormatter(const std::string &key,
                                         KStyleElementPtr formatter) {
  textFormatterMap_[key] = formatter;
}


bool KTextFormatterFactory::createFormatter(const std::string &key,
                                            const std::string &color,
                                            const std::string &bgcolor,
                                  srchilite::StyleConstantsPtr styleconstants) {
  if (hasFormatter(key))
    return false;
  
  //DLOG("Creating KStyleElement '%s'", key.c_str());
  KStyleElement *formatter = new KStyleElement(key);
  addFormatter(key, KStyleElementPtr(formatter));
  
  formatter->setStyle(styleconstants);
  if (color.size())
    formatter->setForegroundColor(color);
  if (bgcolor.size())
    formatter->setBackgroundColor(bgcolor);
  return true;
}

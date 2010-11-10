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

KTextFormatterPtr
    KTextFormatterFactory::getFormatter(const std::string &key) const {
  KTextFormatterMap::const_iterator it = textFormatterMap_.find(key);
  if (it != textFormatterMap_.end()) {
    return it->second;
  } else {
    return KTextFormatterPtr();
  }
}

void KTextFormatterFactory::addFormatter(const std::string &key,
                                         KTextFormatterPtr formatter) {
  textFormatterMap_[key] = formatter;
}


bool KTextFormatterFactory::createFormatter(const std::string &key,
                                            const std::string &color,
                                            const std::string &bgcolor,
                                  srchilite::StyleConstantsPtr styleconstants) {
  if (hasFormatter(key))
    return false;
  
  DLOG("Creating KTextFormatter '%s'", key.c_str());
  KTextFormatter *formatter = new KTextFormatter(key);
  addFormatter(key, KTextFormatterPtr(formatter));
  
  formatter->setStyle(styleconstants);
  if (color.size())
    formatter->setForegroundColor(color);
  if (bgcolor.size())
    formatter->setBackgroundColor(bgcolor);
  return true;
}

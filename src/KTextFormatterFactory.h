#import <map>
#import <srchilite/formatterfactory.h>
#import "KTextFormatter.h"

typedef std::map<std::string, KTextFormatterPtr> KTextFormatterMap;

/**
 * Specialization of FormatterFactory to create TextFormatter objects
 * to format text in a TextEdit.
 */
class KTextFormatterFactory: public srchilite::FormatterFactory {
protected:
  KTextFormatterMap textFormatterMap_;

  /// whether to default font to monospace (default true)
  bool defaultToMonospace;

public:
  /// the color map for source-highlight colors into RGB #RRGGBB values
  //static QtColorMap colorMap;

  KTextFormatterFactory();
  virtual ~KTextFormatterFactory();

  /**
   * Checks whether a formatter for the given key is already present.  If not found,
   * then it returns an empty TextFormatterPtr
   * @param key
   * @return whether a formatter for the given key is already present
   */
  bool hasFormatter(const std::string &key) const;

  /**
   * Returns the formatter for the given key.
   * @param key
   * @return the formatter for the given key is already present
   */
  KTextFormatterPtr getFormatter(const std::string &key) const;

  /**
   * Adds the formatter for the given key.
   * @param key
   * @param formatter
   */
  void addFormatter(const std::string &key, KTextFormatterPtr formatter);

  /**
   * @return the KTextFormatterMap
   */
  const KTextFormatterMap &getTextFormatterMap() const {
    return textFormatterMap_;
  }
  
  /**
   * Creates a formatter for the specific language element (identified by
   * key) with the passed style parameters
   *
   * @param key
   * @param color
   * @param bgcolor
   * @param styleconstants
   * @return false if a formatter for the specific key is already present
   */
  virtual bool createFormatter(const std::string &key,
                               const std::string &color,
                               const std::string &bgcolor,
                               srchilite::StyleConstantsPtr styleconstants);
};

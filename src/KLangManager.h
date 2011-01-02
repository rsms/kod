#import <srchilite/highlightstate.h>

namespace srchilite {
class LangElems;
}

class KLangManager {
 public:
  /// Build a highlight sate for language definition file
  static srchilite::HighlightStatePtr buildHighlightState(const char *dirname,
                                                          const char *basename);

  /// Returns the language elements of the specified language definition file.
  static srchilite::LangElems *readLangElems(const char *dirname,
                                             const char *basename);

  ///
  //static NSString *langIdentifierForFilename(NSString *filename);
};

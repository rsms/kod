#import <Cocoa/Cocoa.h>

#include <srchilite/highlightstate.h>
#include <srchilite/formattermanager.h>
#include <srchilite/sourcehighlighter.h>
#include <srchilite/formatterparams.h>
#include <srchilite/langdefmanager.h>
#include <srchilite/langmap.h>
#include <srchilite/instances.h>

@interface SyntaxHighlighter : NSObject {
  /// current definition file or nil
  NSString *definitionFile_;
  
  /// the GNU Source-highlighter used for the actual highlighting
  srchilite::SourceHighlighter *sourceHighlighter_;
  
  /**
   * this is crucial to get the starting position of the string to highlight
   * within the whole line
   */
  srchilite::FormatterParams formatterParams_;

  /// table of formatters
  srchilite::FormatterManager *formatterManager_;
}

/**
 * Returns the the lang def file name by using the file name for detecting
 * the syntax of the file (e.g., <em>foo.cpp</em> brings to <em>cpp.lang</em>,
 * <em>ChangeLog</em> brings to <em>changelog.lang</em>).
 *
 * @param filename
 * @return the lang def file name or the empty string if no mapping exists
 */
+ (NSString*)definitionFileForFilename:(NSString*)filename;

/**
 * Given a language definition file name, initializes the Source-highlight's
 * highlighter.
 * @param file the lang file of Source-highlight
 * @throws srchilite::ParserException
 */
- (id)initWithDefinitionFile:(NSString*)file;

/// Setup this SyntaxHighlighter with |file|
- (void)loadDefinitionFile:(NSString*)file;

@end

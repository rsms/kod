#import <Cocoa/Cocoa.h>
#import "KHighlightStateData.h"
#import "KTextFormatter.h"
#import "KTextFormatterFactory.h"

#import <srchilite/highlightstate.h>
#import <srchilite/formattermanager.h>
#import <srchilite/sourcehighlighter.h>
#import <srchilite/formatterparams.h>
#import <srchilite/langdefmanager.h>
#import <srchilite/langmap.h>
#import <srchilite/instances.h>

@interface KSyntaxHighlighter : NSObject {
  /// current definition and style files (or nil)
  NSString *definitionFile_;
  NSString *styleFile_;
  
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

@property(retain, nonatomic) NSString *styleFile;

/**
 * Returns the the lang def file name by using the file name for detecting
 * the syntax of the file (e.g., <em>foo.cpp</em> brings to <em>cpp.lang</em>,
 * <em>ChangeLog</em> brings to <em>changelog.lang</em>).
 *
 * @param filename
 * @return the lang def file name or the empty string if no mapping exists
 */
+ (NSString*)definitionFileForFilename:(NSString*)filename;

/// Canonical rep of the content of |file|
+ (NSString*)canonicalContentOfDefinitionFile:(NSString*)file;

/// Highlight state for definition |file|
+ (srchilite::HighlightStatePtr)highlightStateForDefinitionFile:(NSString*)file;

/**
 * Given a language definition file name, initializes the Source-highlight's
 * highlighter.
 * @param file the lang file of Source-highlight
 * @throws srchilite::ParserException
 */
- (id)initWithDefinitionsFromFile:(NSString*)file
                    styleFromFile:(NSString*)styleFile;

/// Setup with definition |file|
- (void)loadDefinitionsFromFile:(NSString*)file;

/// Load style from file (causes |reloadFormatting|)
- (void)loadStyleFromFile:(NSString*)file;

/// Optimized method for loading both language definition and style
- (void)loadDefinitionsFromFile:(NSString*)definitionFile
                  styleFromFile:(NSString*)styleFile;

#pragma mark -
#pragma mark Formatting

/**
 * Highlights the passed line.
 *
 * This method assumes that all the fields are already initialized (e.g.,
 * the FormatterManager).
 *
 * The passed KHighlightStateData is used to configure the SourceHighlighter
 * with info like the current highlighting state and the state stack.
 * If it is null, we simply ignore it.
 *
 * This method can modify the bassed pointer and even make it NULL
 * (after deleting it).
 *
 * @param line
 * @param stateData the highlight state data to use
 * @return in case after highlighting the stack changed we return either the original
 * stateData (after updating) or a new KHighlightStateData (again with the updated
 * information)
 */
- (void)highlightLine:(NSString*)line stateData:(KHighlightStateData *&)state;

@end

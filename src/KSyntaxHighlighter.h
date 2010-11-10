#import <Cocoa/Cocoa.h>
#import "KTextFormatter.h"
#import "KTextFormatterFactory.h"
#import "KHighlightStateData.h"
#import "KHighlightEventListener.h"

#import <srchilite/highlightstate.h>
#import <srchilite/formattermanager.h>
#import <srchilite/sourcehighlighter.h>
#import <srchilite/formatterparams.h>
#import <srchilite/langdefmanager.h>
#import <srchilite/langmap.h>
#import <srchilite/instances.h>

@class KHighlightState;

@interface KSyntaxHighlighter : NSObject <KHighlightEventListener> {
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
  
  // Parser state. FIXME reentrant
  NSUInteger currentTextStorageOffset_;
  NSTextStorage *currentTextStorage_;
  __weak const std::string *currentUTF8String_;
  __weak KHighlightState *currentState_;
  __weak KHighlightState *lastFormattedState_; // temporal per format call
  NSRange lastFormattedRange_;
  int tempStackDepthDelta_;
  
  // Search paths
  NSMutableArray *definitionFileSearchPath_;
  NSMutableArray *styleFileSearchPath_;
}

@property(retain, nonatomic) NSString *styleFile;
@property(readonly, nonatomic) NSTextStorage *currentTextStorage;
@property(readonly, nonatomic) NSMutableArray *definitionFileSearchPath;
@property(readonly, nonatomic) NSMutableArray *styleFileSearchPath;

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
 * Update colors (call this after calling loadStyleFromFile: on an already
 * managed NSTextStorage.
 */
- (void)recolorTextStorage:(NSTextStorage*)textStorage;

/**
 * Returns NSNotFound if the highlight state is stable, otherwise the position
 * of the last character highlighted is returned to indicate what should be
 * re-evaluated.
 */
- (NSRange)highlightTextStorage:(NSTextStorage*)textStorage
                        inRange:(NSRange)range
                     deltaRange:(NSRange)deltaRange;

/// Convenience method to highlight a complete NSTextStorage
- (void)highlightTextStorage:(NSTextStorage*)textStorage;

/**
 * This function is applied to the syntax highlighter's current text block
 * (i.e. the text that is passed to the highlightBlock() method).
 *
 * The specified format is applied to the text from the start position
 * for a length of count characters
 * (if count is 0, nothing is done).
 * The formatting properties set in format are merged at display
 * time with the formatting information stored directly in the document,
 * for example as previously set with QTextCursor's functions.
 *
 * Note that this helper function will be called by the corresponding
 * TextFormatter, from Source-highglight library code, and relies on
 * the corresponding protected method of QSyntaxHighlighter: setFormat).
 */
- (void)setFormat:(KTextFormatter*)format inRange:(NSRange)range;

@end

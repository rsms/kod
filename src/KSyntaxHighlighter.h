#import "KStyleElement.h"
#import "KHighlightStateData.h"
#import "KHighlightEventListener.h"
#import "KSourceHighlighter.h"

#import <srchilite/highlightstate.h>
#import <srchilite/formattermanager.h>
#import <srchilite/formatterparams.h>
#import <srchilite/langdefmanager.h>
#import <srchilite/langmap.h>
#import <srchilite/instances.h>
#import <dispatch/dispatch.h>

@class KHighlightState;
@class KStyle;

extern NSString * const KHighlightStateAttribute;

@interface KSyntaxHighlighter : NSObject <KHighlightEventListener> {
  /// current definition and style files (or nil)
  NSString *definitionFile_;
  
  /// the GNU Source-highlighter used for the actual highlighting
  KSourceHighlighter *sourceHighlighter_;
  
  /// initial state
  srchilite::FormatterParams formatterParams_;

  /// table of formatters
  srchilite::FormatterManager *formatterManager_;
  
  /// Temporal state
  // the following variables MUST NOT be modified from the outside while the
  // highlighter is inside call to |highlightMAString:inRange:deltaRange:|
  dispatch_semaphore_t semaphore_; // dsema's only call to kernel on contention
  NSUInteger currentMAStringOffset_;
  NSMutableAttributedString *currentMAString_;
  __weak const std::string *currentUTF8String_;
  BOOL currentUTF8StringIsMultibyte_;
  __weak KHighlightState *currentState_;
  __weak KHighlightState *lastFormattedState_; // temporal per format call
  __weak KStyle *currentStyle_;
  NSRange lastFormattedRange_;
  int tempStackDepthDelta_;
}

@property(readonly, nonatomic) NSMutableAttributedString *currentMAString;

/**
 * Returns the the lang def file name by using the file name for detecting
 * the syntax of the file (e.g., <em>foo.cpp</em> brings to <em>cpp.lang</em>,
 * <em>ChangeLog</em> brings to <em>changelog.lang</em>).
 *
 * @param filename
 * @return the lang def file name or the empty string if no mapping exists
 */
+ (NSString*)languageFileForFilename:(NSString*)filename;

/// Resolve path for |file|, passing |error|.
+ (NSString *)pathForLanguageFile:(NSString*)file error:(NSError**)error;

/// Search paths
+ (NSMutableArray *)languageFileSearchPath;

/// Canonical rep of the content of |file|
+ (NSString*)canonicalContentOfLanguageFile:(NSString*)file;

/// Highlight state for language |file|
+ (srchilite::HighlightStatePtr)highlightStateForLanguageFile:(NSString*)file;

/// Shared highlighter for language |file|
+ (KSyntaxHighlighter*)highlighterForLanguage:(NSString*)language;

/**
 * Given a language definition file name, initializes the Source-highlight's
 * highlighter.
 * @param file the lang file of Source-highlight
 * @throws srchilite::ParserException
 */
- (id)initWithLanguageFile:(NSString*)langFile;

/// Setup with definition |file|
- (void)loadLanguageFile:(NSString*)file;

#pragma mark -
#pragma mark Formatting

/**
 * Returns NSNotFound if the highlight state is stable, otherwise the position
 * of the last character highlighted is returned, indicating a new range which
 * should be (re-)evaluated.
 */
- (NSRange)highlightMAString:(NSMutableAttributedString*)mastr
                     inRange:(NSRange)range
                  deltaRange:(NSRange)deltaRange
                   withStyle:(KStyle*)style;

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
//- (void)setFormat:(KStyleElement*)format inRange:(NSRange)range;
- (void)setStyleForElementOfType:(NSString const*)elem
                     inUTF8Range:(NSRange)range;

@end

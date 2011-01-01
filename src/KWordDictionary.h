#import "HSpinLock.h"

/*!
 * Keeps track of words and provides support for word completion suggestions.
 *
 * All functionality is thread-safe unless otherwise noted.
 *
 * Notes on fast enumeration:
 *
 * A KWordDictionary instance can be operated on using fast enumeration, but it
 * is currently NOT thread safe. Prefer to use the |words| property instead,
 * which returns a snapshot of the words in an atomic manner.
 */
@interface KWordDictionary : NSObject <NSFastEnumeration> {
  HSpinLock wordsSpinLock_;
  NSMutableDictionary *words_;
  NSUInteger wordMaxFrequency_; // unclamped
  NSCharacterSet *wordSeparatorCharacterSet_;
  NSUInteger proximitySearchDistance_;
}

// Default word separator characters
+ (NSCharacterSet *)defaultWordSeparatorCharacterSet;

// Frequency counts of all words (e.g. used for autocomplete)
@property(readonly) NSDictionary *wordFrequencies;

// List of all unique words
@property(readonly) NSArray *words;

// Characters treated as word separators
@property(retain) NSCharacterSet *wordSeparatorCharacterSet;

// Amount of string for autocomplete to search when looking for nearby
// matching words
@property(assign) NSUInteger proximitySearchDistance;

// If true, words which was known but disappeared are forgotten.
// If false, a word which appeared at one point in time but later disappeared
// (e.g. was deleted from a document) will still be remebered with a zero
// frequency. Defaults to false.
//@property(assign) BOOL forgetsUnusedWords;


// Initializes a new object with default word separator characters
- (id)init;

// Initializes a new object with explicit word separator characters
- (id)initWithWordSeparatorCharacterSet:(NSCharacterSet*)wordSeparatorCS;


// Scan and register all words in |string|
- (void)scanString:(NSString*)string;

// Re-scan updated text. First all words already accounted for range will have
// their frequency decremented by one, then this method invokes scanString:
// which will register any new words and re-establish frequency count for
// unchanged words.
// Note that this is _not_ an atomic operation (although it's thread safe) since
// there's a race condition to scanString:. However, this should never have a
// practical effect.
- (void)rescanUpdatedText:(NSString*)text
                 forRange:(NSRange)range
    withReplacementString:(NSString*)replacementString;

// Forget all registered words and reset the receiver to a "blank" state
- (void)reset;


// Return an ordered list of maximum |countLimit| word completions for |prefix|
// at |position| in |text|.
- (NSArray*)completionsForPrefix:(NSString*)prefix
                      atPosition:(NSUInteger)position
                          inText:(NSString*)text
                      countLimit:(NSUInteger)countLimit;

// Searches string within proximitySearchDistance_ for occurrences
// of matching keywords and puts the closest ones at the top. Keywords that do
// not appear closer than 1024 characters to the cursor are unsorted and are
// listed after the sorted keywords.
//
// Putting the sorting in a separate method from finding the completions will
// make it simpler to test different sorting strategies or allow extensions to
// provide them.
- (NSArray*)sortedCompletions:(NSArray*)completions
                    forPrefix:(NSString*)prefix
                   atPosition:(NSUInteger)position
                       inText:(NSString*)text;

@end

#import "KWordDictionary.h"
#import "common.h"

// Characters which are not considered to be part of a "word"
static NSCharacterSet *gDefaultWordSeparatorCharacterSet = nil;


@implementation KWordDictionary

@synthesize wordFrequencies = words_,
            wordSeparatorCharacterSet = wordSeparatorCharacterSet_,
            proximitySearchDistance = proximitySearchDistance_;


+ (NSCharacterSet *)defaultWordSeparatorCharacterSet {
  if (!gDefaultWordSeparatorCharacterSet) {
    // kAutocompleteIrrelevantCharacterSet -- Characters that should be ignored by
    // the autocomplete word finder
    NSMutableCharacterSet *cs =
        [[[NSCharacterSet alphanumericCharacterSet] invertedSet] mutableCopy];

    // remove some characters which should be considered part of sequences in
    // most computer code
    [cs removeCharactersInString:@"_"];

    // CAS to avoid smashing memory
    h_casid(&gDefaultWordSeparatorCharacterSet, cs);

    // release temporary ref
    [cs release];
  }
  return gDefaultWordSeparatorCharacterSet;
}


- (id)initWithWordSeparatorCharacterSet:(NSCharacterSet*)wordSeparatorCS {
  if (!(self = [super init])) return nil;

  // separator charset
  if (!wordSeparatorCS)
    wordSeparatorCS = [isa defaultWordSeparatorCharacterSet];
  wordSeparatorCharacterSet_ = [wordSeparatorCS retain];

  // word dictionary
  words_ = [[NSMutableDictionary alloc] initWithCapacity:(4096/sizeof(void*))];

  // default proximity search distance
  proximitySearchDistance_ = 1024;

  return self;
}


- (id)init {
  return [self initWithWordSeparatorCharacterSet:nil];
}


- (void)dealloc {
  [wordSeparatorCharacterSet_ release];
  [words_ release];
  [super dealloc];
}


#pragma mark -
#pragma mark Properties


- (NSArray*)words {
  HSpinLock::Scope slscope(wordsSpinLock_);
  return [words_ allKeys];
}


#pragma mark -
#pragma mark NSFastEnumeration


- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(id*)stackbuf
                                    count:(NSUInteger)len {
  return [words_ countByEnumeratingWithState:state
                                     objects:stackbuf
                                       count:len];
}


#pragma mark -
#pragma mark Word scanning


- (void)scanString:(NSString*)string {
  NSCharacterSet *cs = self.wordSeparatorCharacterSet;
  HSpinLock::Scope slscope(wordsSpinLock_);

  // for each word in string...
  NSArray *words = [string componentsSeparatedByCharactersInSet:cs];
  for (NSString *word in words) {
    if (word.length == 0) continue;
    NSNumber *occurrences = [words_ valueForKey:word];

    if (occurrences) {
      NSUInteger freq = [occurrences unsignedIntegerValue] + 1;
      occurrences = [NSNumber numberWithUnsignedInteger:freq];
      if (freq > wordMaxFrequency_)
        wordMaxFrequency_ = freq;
    } else {
      occurrences = [NSNumber numberWithUnsignedInteger:1];
      if (wordMaxFrequency_ == 0)
        wordMaxFrequency_ = 1;
    }
    [words_ setValue:occurrences forKey:word];
  }
}


// Update the autocomplete dictionary for the part of the text that changed
- (void)rescanUpdatedText:(NSString*)text
                 forRange:(NSRange)range
    withReplacementString:(NSString*)replacementString {
  // Copy the range so we can change it without fear of side effects
  NSRange newRange = range;
  NSCharacterSet *irrelevantChars = self.wordSeparatorCharacterSet;

  // Expand range to "the left", to start of word boundary
  NSRange searchRange = NSMakeRange(0, range.location);
  NSRange r = [text rangeOfCharacterFromSet:irrelevantChars
                                    options:NSLiteralSearch|NSBackwardsSearch
                                      range:searchRange];
  NSUInteger leftIndex = (r.location == NSNotFound) ? 0 : r.location+1;
  newRange.length += newRange.location - leftIndex;
  newRange.location = leftIndex;

  // Scan forward and decrement the frequency counts until we are past the edit
  // point
  NSScanner *scanner = [NSScanner scannerWithString:text];
  [scanner setCharactersToBeSkipped:irrelevantChars];
  [scanner setScanLocation:newRange.location];

  HSpinLockSync(wordsSpinLock_) {
    NSString *word = nil;
    while (![scanner isAtEnd] &&
           [scanner scanLocation] < range.location + range.length) {
      if ([scanner scanUpToCharactersFromSet:irrelevantChars
                                  intoString:&word]) {
        NSNumber *n = [words_ objectForKey:word];
        if (!n) continue;

        NSUInteger newFrequency = [n unsignedIntegerValue];
        if (newFrequency > 0) --newFrequency;

        if (newFrequency > 0) {
          [words_ setValue:[NSNumber numberWithUnsignedInteger:newFrequency]
                    forKey:word];
        } else {
          [words_ removeObjectForKey:word];
        }
      }
    }
  }

  // Construct the new substring and scan it for autocomplete words
  NSRange preRange = NSMakeRange(newRange.location,
                                 range.location-newRange.location);
  NSString *preString = [text substringWithRange:preRange];

  NSRange postRange;
  if ([scanner scanLocation] > (range.location + range.length)) {
    NSUInteger distFromRangeEndToScanLocation =
        [scanner scanLocation] - (range.location + range.length);
    postRange = NSMakeRange(range.location + range.length,
                            distFromRangeEndToScanLocation);
  } else {
    postRange = NSMakeRange(range.location + range.length, 0);
  }
  NSString *postString = [text substringWithRange:postRange];
  NSString *newString = [NSString stringWithFormat:@"%@%@%@",
                         preString, replacementString, postString];
  [self scanString:newString];
}


- (void)reset {
  HSpinLock::Scope slscope(wordsSpinLock_);
  h_casid(&words_,
          [NSMutableDictionary dictionaryWithCapacity:(4096/sizeof(void*))]);
}


#pragma mark -
#pragma mark Auto-completion


- (NSArray*)sortedCompletions:(NSArray*)completions
                    forPrefix:(NSString*)prefix
                   atPosition:(NSUInteger)position
                       inText:(NSString*)text {
  // word -> smallest number of characters between cursor and any occurrence of
  // this keyword Magic number guess is
  //
  //    2048 (size of character search space)
  //    / 8 (average word size + arbitrary whitespace guess)
  //
  NSMutableDictionary *proximities =
      [NSMutableDictionary dictionaryWithCapacity:256];

  // Scanner starts at start of document or proximitySearchDistance_ before
  // position, whichever is closes to position
  NSScanner *scanner = [NSScanner scannerWithString:text];
  NSCharacterSet *irrelevantChars = self.wordSeparatorCharacterSet;
  NSUInteger startLocation = (NSUInteger)
      MAX((NSInteger)position - (NSInteger)proximitySearchDistance_, 0);
  NSUInteger endLocation = position + proximitySearchDistance_;
  [scanner setCharactersToBeSkipped:irrelevantChars];
  [scanner setScanLocation:startLocation];
  NSUInteger maxLocalDistance = 0;

  // Scan words until end of |text| or |endLocation|
  NSString *word = nil;
  while ( [scanner scanLocation] < endLocation && ![scanner isAtEnd] ) {
    if (![scanner scanUpToCharactersFromSet:irrelevantChars intoString:&word])
      continue;

    // Consider words which include the prefix but is not an exact match
    if ([word hasPrefix:prefix options:NSCaseInsensitiveSearch] &&
        ![word isEqualToString:prefix]) {
      // Compute a distance score (distance between beginning of this word and
      // the cursor)
      NSInteger score = (NSInteger)[scanner scanLocation] - (NSInteger)position;
      if (score < 0) score = -score;
      NSUInteger distance = (NSUInteger)score;

      // Save score if no score stored or if old score was greater
      NSNumber *oldDistance = [proximities objectForKey:word];
      if (oldDistance == nil || [oldDistance unsignedIntegerValue] > distance) {
        NSNumber *n = [NSNumber numberWithUnsignedInteger:distance];
        [proximities setObject:n forKey:word];
        if (distance > maxLocalDistance)
          maxLocalDistance = distance;
      }
    }
  }

  // Return version sorted by score given earlier (or max distance + 1 if word
  // was not in the search space)
  HSpinLock::Scope slscope(wordsSpinLock_);

  // this constants control how much frequency should be praised when
  // calculating the score for a word
  static const float frequencyWeight = 0.5;

  // this constants control how much distance should be punished when
  // calculating the score for a word
  static const float distanceWeight = 0.5;

  return [completions sortedArrayUsingComparator:^(id word1, id word2) {
    NSUInteger freq1 = [[words_ objectForKey:word1] unsignedIntegerValue];
    NSUInteger freq2 = [[words_ objectForKey:word2] unsignedIntegerValue];
    float score1 = ((float)freq1 / wordMaxFrequency_) * frequencyWeight;
    float score2 = ((float)freq2 / wordMaxFrequency_) * frequencyWeight;

    NSNumber *n = [proximities objectForKey:word1];
    NSUInteger distance = n ? [n unsignedIntegerValue] : maxLocalDistance;
    score1 += (1.0 - ((float)distance / maxLocalDistance)) * distanceWeight;

    n = [proximities objectForKey:word2];
    distance = n ? [n unsignedIntegerValue] : maxLocalDistance;
    score2 += (1.0 - ((float)distance / maxLocalDistance)) * distanceWeight;

    if (score1 > score2) return (NSComparisonResult)NSOrderedAscending;
    else if (score1 < score2) return (NSComparisonResult)NSOrderedDescending;
    else return (NSComparisonResult)NSOrderedSame;
  }];
}


- (NSArray*)completionsForPrefix:(NSString*)prefix
                      atPosition:(NSUInteger)position
                          inText:(NSString*)text
                      countLimit:(NSUInteger)countLimit {
  // zero prefix means no no
  if (prefix.length == 0)
    return nil;

  // countdown to break
  __block NSUInteger countdown = countLimit;

  NSMutableArray *completions;

  HSpinLockSync(wordsSpinLock_) {
    // Initial guess for number of completions:
    // 16^(length of prefix), i.e. 1/16th the set for each letter
    NSUInteger capacity = [words_ count]/pow(16.0, (double)[prefix length]);
    completions = [NSMutableArray arrayWithCapacity:capacity];

    // Insert all matches into an array
    [words_ enumerateKeysAndObjectsUsingBlock:^(id word, id freq, BOOL *stop){
      // add words which are longer than the prefix and contains the prefix
      if ([word length] > prefix.length &&
          [word hasPrefix:prefix options:NSCaseInsensitiveSearch]) {
        // add word to list of suggestions
        [completions addObject:word];

        // stop we reached countLimit
        if (--countdown == 0)
          *stop = YES;
      }
    }];
  }

  // Sort and return
  return [self sortedCompletions:completions
                       forPrefix:prefix
                      atPosition:position
                          inText:text];
}


@end

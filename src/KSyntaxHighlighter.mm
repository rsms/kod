#import "KSyntaxHighlighter.h"
#import "KHighlightState.h"
#import "KStyleElement.h"
#import "KStyle.h"
#import "KLangRegexRuleFactory.h"

#import <srchilite/langelems.h>
#import <srchilite/stylefileparser.h>
#import <srchilite/parserexception.h>
#import <srchilite/ioexception.h>
#import <srchilite/settings.h>
#import <libkern/OSAtomic.h>

#import "common.h"

// xxx temp debug
#define DLOG_state_enabled 0

// enable logging of state (only effective in debug mode)
#ifndef DLOG_state_enabled
  #define DLOG_state_enabled 1
#endif
#if DLOG_state_enabled
  #define DLOG_state DLOG
#else
  #define DLOG_state(...) ((void)0)
#endif


@implementation KSyntaxHighlighter

@synthesize currentMAString = currentMAString_;


static NSMutableArray *gLanguageFileSearchPath_;
static NSMutableDictionary *gSharedInstances_;
static OSSpinLock gSharedInstancesSpinLock_ = OS_SPINLOCK_INIT;
static srchilite::LangDefManager *gLangDefManager_ = NULL;

NSString * const KHighlightStateAttribute = @"KHighlightState";

+ (void)load {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  
  // TODO: replace style with KStyle stuff
  NSBundle *mainBundle = [NSBundle mainBundle];
  NSString *builtinLangDir = nil;
  if (mainBundle) {
    builtinLangDir =
        [[mainBundle resourcePath] stringByAppendingPathComponent:@"lang"];
    srchilite::Settings::setGlobalDataDir([builtinLangDir UTF8String]);
  }
  gLanguageFileSearchPath_ =
      [[NSMutableArray alloc] initWithObjects:builtinLangDir, nil];
  
  // language-name => KSyntaxHighlighter
  gSharedInstances_ = [NSMutableDictionary new];
  
  // Language manager
  gLangDefManager_ = new srchilite::LangDefManager(new KLangRegexRuleFactory);
  [pool drain];
}


+ (NSMutableArray *)languageFileSearchPath { return gLanguageFileSearchPath_; }


+ (srchilite::LangMap*)definitionMap {
  // make sure the lang map is loaded before returning it
  srchilite::Instances::getLangMap()->open();
  return srchilite::Instances::getLangMap();
}


// guess language file based on filename
+ (NSString*)languageFileForFilename:(NSString*)filename {
  srchilite::LangMap* langMap = [self definitionMap];
  const char *pch =
      langMap->getMappedFileNameFromFileName([filename UTF8String]).c_str();
  if (pch) {
    return [NSString stringWithUTF8String:pch];
  }
  return nil;
}


+ (NSString *)_pathForResourceFile:(NSString*)file
                            ofType:(NSString*)type
                     inSearchPaths:(NSArray*)searchPaths
                             error:(NSError**)error {
  if (file && file.length) {
    if ([file isAbsolutePath]) {
      return file;
    } else if ([searchPaths count] > 0) { 
      if (type && type.length && ![[file pathExtension] isEqualToString:type]) {
        file = [file stringByAppendingPathExtension:type];
      }
      NSFileManager *fm = [NSFileManager defaultManager];
      for (NSString *path in searchPaths) {
        path = [path stringByAppendingPathComponent:file];
        if ([fm fileExistsAtPath:path])
          return path;
      }
    }
  }
  if (error)
    *error = [NSError kodErrorWithFormat:@"File not found: \"%@\"", file];
  return nil;
}


+ (NSString *)pathForLanguageFile:(NSString*)file error:(NSError**)error {
  return [self _pathForResourceFile:file
                             ofType:@"lang"
                      inSearchPaths:gLanguageFileSearchPath_
                              error:error];
}


/*+ (NSString *)pathForStyleFile:(NSString*)file error:(NSError**)error {
  return [self _pathForResourceFile:file
                             ofType:@"css"
                      inSearchPaths:gStyleFileSearchPath_
                              error:error];
}*/


+ (NSString*)canonicalContentOfLanguageFile:(NSString*)file {
  if (![file isAbsolutePath]) {
    file = [self pathForLanguageFile:file error:nil];
    if (!file) return nil;
  }
  NSString *dirname = [file stringByDeletingLastPathComponent];
  file = [file lastPathComponent];
  srchilite::LangElems *langElems =
      gLangDefManager_->getLangElems([dirname UTF8String], [file UTF8String]);
  if (langElems) {
    return [NSString stringWithUTF8String:langElems->toString().c_str()];
  }
  return nil;
}


+ (srchilite::HighlightStatePtr)highlightStateForLanguageFile:(NSString*)file{
  if ([file isAbsolutePath]) {
    NSString *dirname = [file stringByDeletingLastPathComponent];
    file = [file lastPathComponent];
    DLOG("loading lang from %@/%@", dirname, file);
    return gLangDefManager_->getHighlightState([dirname UTF8String],
                                             [file UTF8String]);
  } else {
    DLOG("loading lang from %@", file);
    return gLangDefManager_->getHighlightState([file UTF8String]);
  }
}


/*+ (const KStyleElementMap &)textFormatterMapForFormatterFactory:
    (KTextFormatterFactory &)formatterFactory
    styleFile:(NSString *)styleFile {

  if (formatterFactory.getTextFormatterMap().size()) {
    return formatterFactory.getTextFormatterMap();
  }
  
  std::string bgcolor = "";
  
  if (styleFile) {
    DLOG("loading style from %@", styleFile);
    std::string styleFileStdStr = [styleFile UTF8String];
    try {
      if (srchilite::get_file_extension(styleFileStdStr) == "css") {
        srchilite::StyleFileParser::parseCssStyleFile(styleFileStdStr,
                                                      &formatterFactory,
                                                      bgcolor);
      } else {
        srchilite::StyleFileParser::parseStyleFile(styleFileStdStr,
                                                   &formatterFactory, bgcolor);
      }
    } catch (srchilite::ParserException *e) {
      WLOG("style parse error: %s -- %s (%s:%u)", e->message.c_str(),
           e->additional.c_str(), e->filename.c_str(), e->line);
      throw e;
    }
  }
  
  if (bgcolor != "") {
    DLOG("TODO: bgcolor = %s", bgcolor.c_str());
    // TODO: clean up this mess and move all style things to a separate class
    // with proper caching of {style_id => KStyleElementMap}
  }
  // Idea: We should fetch the "normal" formatter and:
  // 1. if bgcolor is set but no fgcolor, deduce a good fgcolor based on bgcolor
  // 2. if fgcolor is set but no ... (vice versa)
  // 3. use default colors

  return formatterFactory.getTextFormatterMap();
}*/


+ (KSyntaxHighlighter*)highlighterForLanguage:(NSString*)language {
  KSyntaxHighlighter *highlighter;
  OSSpinLockLock(&gSharedInstancesSpinLock_);
  try {
    highlighter = [gSharedInstances_ objectForKey:language];
    if (highlighter) DLOG("gSharedInstances_ HIT %@", language);
    if (!highlighter) { DLOG("gSharedInstances_ MISS %@", language);
      language = [language internedString];
      highlighter = [[self alloc] initWithLanguageFile:language];
      [gSharedInstances_ setObject:highlighter forKey:language];
      [highlighter release];
    }
    OSSpinLockUnlock(&gSharedInstancesSpinLock_);
  } catch (const std::exception &e) {
    OSSpinLockUnlock(&gSharedInstancesSpinLock_);
    throw e;
  }
  return highlighter;
}


- (id)init {
  self = [super init];
  semaphore_ = dispatch_semaphore_create(1); // 1=unlocked, 0=locked
  return self;
}


- (id)initWithLanguageFile:(NSString*)langFile {
  if ((self = [self init])) {
    [self loadLanguageFile:langFile];
  }
  return self;
}


- (void)dealloc {
  if (formatterManager_)
    delete formatterManager_;
  if (sourceHighlighter_)
    delete sourceHighlighter_;
  [super dealloc];
}


- (void)loadLanguageFile:(NSString*)file {
  NSError *error = nil;
  srchilite::HighlightStatePtr mainState;
  
  // try to load language file
  file = [isa pathForLanguageFile:file error:&error];
  if (!error) {
    try {
      mainState = [isa highlightStateForLanguageFile:file];
    } catch (const srchilite::ParserException &e) {
      DLOG("ParserException when loading lang file \"%@\": %s", file, e.what());
      error = [NSError kodErrorWithFormat:
               @"Error when loading language file \"%@\": %s", file, e.what()];
    }
  }
  
  // handle error
  if (error) {
    if (!sourceHighlighter_) {
      // make sure sourceHighlighter_ is valid
      mainState.reset(new srchilite::HighlightState());
      sourceHighlighter_ = new KSourceHighlighter(mainState);
    }
    [NSApp presentError:error]; // FIXME pass by reference or something
    return;
  }
  
  if (sourceHighlighter_)
    delete sourceHighlighter_;
  sourceHighlighter_ = new KSourceHighlighter(mainState);
  sourceHighlighter_->setFormatterParams(&formatterParams_);

  definitionFile_ = [file retain];
}


#pragma mark -
#pragma mark Formatting


- (NSRange)highlightMAString:(NSMutableAttributedString*)mastr
                     inRange:(NSRange)range
                  deltaRange:(NSRange)deltaRange
                   withStyle:(KStyle*)style {
  // assure mutual exclusive access to this highlighter
  dispatch_semaphore_wait(semaphore_, DISPATCH_TIME_FOREVER);

  #if !NDEBUG
  fprintf(stderr,
      "------------------ highlight:inRange:deltaRange: ------------------\n");
  #endif
  assert(currentMAString_ == nil);
  currentStyle_ = style; // weak, so no need to retain/release/clear
  //assert(currentStyle_);
  currentMAString_ = [mastr retain];
  NSString *text = [mastr string];
  NSUInteger documentLength = [text length];
  
  // Adjust range
  if (range.location == NSNotFound) {
    // highlight all lines
    range = NSMakeRange(0, documentLength);
  } else {
    // highlight minimal part
    DLOG_state("range: %@  \"%@\"", NSStringFromRange(range),
         [text substringWithRange:range]);
  }
  
  // get previous state
  NSRange effectiveRange = range;
  BOOL didBreakState = NO;
  BOOL isCompleteDocument = range.location == NSNotFound;
  BOOL wasCausedByDeleteEvent = deltaRange.length == 0;
  BOOL isBeginningOfDocument = range.location == 0;
  BOOL isZeroPointOfDocument = isBeginningOfDocument && wasCausedByDeleteEvent;
  BOOL shouldTryToRestoreState = YES;
  if (isBeginningOfDocument && range.length == documentLength) {
    isCompleteDocument = YES;
  }
  
  if (isCompleteDocument) {
    shouldTryToRestoreState = NO;
  } else if (isBeginningOfDocument && !wasCausedByDeleteEvent) {
    shouldTryToRestoreState = NO;
  }
  
  #if DLOG_state_enabled
  DLOG_EXPR(isCompleteDocument);
  DLOG_EXPR(wasCausedByDeleteEvent);
  DLOG_EXPR(isBeginningOfDocument);
  DLOG_EXPR(isZeroPointOfDocument);
  DLOG_EXPR(shouldTryToRestoreState);
  #endif
  
  assert(currentState_ == nil);
  if (shouldTryToRestoreState) {
    //DLOG("finding previous state");
    NSUInteger previousIndex = 0;
    if (range.location != 0 && range.location != NSNotFound)
      previousIndex = range.location - 1;
    
    // get stored state
    int tries = wasCausedByDeleteEvent ? 2 : 1;
    while (tries--) {
      currentState_ = [currentMAString_ attribute:KHighlightStateAttribute
                                          atIndex:previousIndex
                                   effectiveRange:&effectiveRange];
      if (currentState_) {
        //stateData = new KHighlightStateData(*(currentState_->data));
        //[currentState_ replaceData:stateData];
        assert(currentState_->data != NULL);
        srchilite::HighlightStatePtr cs = currentState_->data->currentState;
        DLOG_state("found previous state: %d at index %u",
             currentState_->data->currentState->getId(),
             previousIndex);
        if (tries == 0 && deltaRange.length == 0)
          didBreakState = YES;
        break;
      } else {
        DLOG_state("no previous state");
        if ([currentMAString_ length]-range.location > 1) {
          previousIndex = range.location+1;
        } else {
          break;
        }

      }
    }
  }
  
  DLOG_state("didBreakState = %s", didBreakState?"YES":"NO");
  
  // restore state
  //int stateIdAtStart = 0;
  if (currentState_) {
    [currentState_ retain]; // our ref, released just before we return
    // we need to make a copy of the state stack here, since sourceHighlighter_
    // will "steal" it and possibly free the object.
    srchilite::HighlightStateStack *stateStack =
      new srchilite::HighlightStateStack(*(currentState_->data->stateStack));
    sourceHighlighter_->setCurrentState(currentState_->data->currentState);
    sourceHighlighter_->setStateStack(srchilite::HighlightStateStackPtr(stateStack));
    //stateIdAtStart = currentState_->data->currentState->getId();
  } else {
    // we must make sure to reset the highlighter to the initial state
    sourceHighlighter_->setCurrentState(sourceHighlighter_->getMainState());
    sourceHighlighter_->clearStateStack();
    //stateIdAtStart = sourceHighlighter_->getMainState()->getId();
  }
  
  // clear state (trick since we will never act on linebreaks, but they are
  // important)
  [currentMAString_ removeAttribute:KHighlightStateAttribute
                              range:range];
  
  currentMAStringOffset_ = range.location;
  tempStackDepthDelta_ = 0;
  
  // for each line ...
  [text enumerateSubstringsInRange:range
                           options:NSStringEnumerationByLines
                                  |NSStringEnumerationSubstringNotRequired
                           usingBlock:^(NSString *_, NSRange substringRange,
                                        NSRange enclosingRange, BOOL *stop) {
    //DLOG("substringRange: %@", NSStringFromRange(substringRange));
    //std::string str([[text substringWithRange:enclosingRange] UTF8String]);
    //currentUTF8StringIsMultibyte_ = (str.size() != enclosingRange.length);
    std::string str;
    NSUInteger size = [text populateStdString:str
                                usingEncoding:NSUTF8StringEncoding
                                        range:enclosingRange];
    currentUTF8StringIsMultibyte_ = (size != enclosingRange.length);

    currentUTF8String_ = &str;
    //fprintf(stderr, "** \"%s\"\n", str.c_str());
    sourceHighlighter_->highlightParagraph(str);
    currentMAStringOffset_ += enclosingRange.length;
  }];
  
  currentUTF8String_ = nil;
  
  [currentState_ release];
  currentState_ = nil;

  [currentMAString_ release];
  currentMAString_ = nil;
  
  BOOL stateStackIsEmpty = sourceHighlighter_->getStateStack()->empty();
  
  // we are now done accessing non-thread safe stuff -- release our lock
  dispatch_semaphore_signal(semaphore_);
  
  //DLOG("tempStackDepthDelta_: %d", tempStackDepthDelta_);
  if (didBreakState) {
    DLOG_state("highlightMAString returned with open state (0)");
    NSRange nextRange = NSUnionRange(range, effectiveRange);
    //DLOG("nextRange: %@", NSStringFromRange(nextRange));
    return nextRange;
  } else if (tempStackDepthDelta_ != 0) {
    DLOG_state("highlightMAString returned with open state (1)");
  
    // if effectiveRange extends beyond our editing point, include the
    // remainder.
    // Use-case: multiline C-comment
    //   /* foo
    //   bar
    //   baz */
    // Now, imagine we insert "*/" after "bar":
    //   /* foo
    //   bar */
    //   baz */
    // We need to extend our range to include "baz */"
    //
    // TODO: optimize this by recording state change and only returning
    //       |end| if the state changed.
    //
    NSRange nextRange;
    NSUInteger end1 = range.location + range.length;
    NSUInteger end2 = effectiveRange.location + effectiveRange.length;
    
    nextRange.location = end1;
    if (end2 > end1) {
      nextRange.length = end2 - end1;
    } else {
      nextRange.length = 0;
    }
    
    DLOG_state("range: %@, effectiveRange: %@, nextRange: %@",
         NSStringFromRange(range),
         NSStringFromRange(effectiveRange), NSStringFromRange(nextRange));
    return nextRange;
  } else if (!stateStackIsEmpty) {
    if (deltaRange.length == 0) {
      DLOG_state("highlightMAString returned with open state (2)");
      // we are dealing with a DELETE edit which possibly caused dirty content
      // below the edited point.
      return NSMakeRange(range.location + range.length, 0);
    } else {
      DLOG_state("highlightMAString returned with open state (3)");
      return NSMakeRange(range.location + range.length, 0);
    }
  }
  return NSMakeRange(NSNotFound, 0);
}


static void _debugDumpHighlightEvent(const srchilite::HighlightEvent &event) {
  const char *name = "?";
  switch (event.type) {
    case srchilite::HighlightEvent::FORMAT:
      name = "FORMAT"; break;
    case srchilite::HighlightEvent::FORMATDEFAULT:
      name = "FORMATDEFAULT"; break;
    case srchilite::HighlightEvent::ENTERSTATE:
      name = "ENTERSTATE"; break;
    case srchilite::HighlightEvent::EXITSTATE:
      name = "EXITSTATE"; break;
  }
  
  const srchilite::HighlightRule *rule = event.token.rule;
  
  DLOG("hlevent %s:"
       "\n  prefix: %s"
       "\n  prefixOnlySpaces: %s"
       "\n  suffix: %s"
       "\n  matchedSize: %u"
       "\n  rule: %s"
       "\n  ruleinfo: %s"
       ,
       name,
       event.token.prefix.c_str(),
       event.token.prefixOnlySpaces ? "YES":"NO",
       event.token.suffix.c_str(),
       event.token.matchedSize,
       rule ? rule->toString().c_str() : "(null)",
       rule ? rule->getAdditionalInfo().c_str() : "(null)"
       );

  if (event.type == srchilite::HighlightEvent::FORMAT) {
    for (srchilite::MatchedElements::const_iterator it =
         event.token.matched.begin(); it != event.token.matched.end(); ++it) {
      // first = the element name, second = the actual program string
      fprintf(stderr, "  >>format \"%s\" as %s\n",
              it->second.c_str(), it->first.c_str());
    }
  }
}


- (void)_updateCurrentState:(BOOL)didExit {
  assert(!sourceHighlighter_->getStateStack()->empty());
  // typedef std::stack<HighlightStatePtr> HighlightStateStack;
  KHighlightStateData *stateData = new KHighlightStateData();
  
  srchilite::HighlightStateStack *stateStack =
      new srchilite::HighlightStateStack(*(sourceHighlighter_->getStateStack()));
  stateData->stateStack = srchilite::HighlightStateStackPtr(stateStack);
  
  if (didExit) {
    // if the state was just exited, current state is now the last one on the
    // stack.
    // Note: We never get here unless the stack is non-empty, so this is safe.
    // As we already made a copy of the stack, no need to make another copy
    stateData->currentState = stateData->stateStack->top();
  } else {
    srchilite::HighlightState *currentState =
        new srchilite::HighlightState(*(sourceHighlighter_->getCurrentState()));
    stateData->currentState = srchilite::HighlightStatePtr(currentState);
  }
  
  objc_exch(&currentState_,
            [[KHighlightState alloc] initWithData:(NSData*)stateData]);
}

-(void)_applyCurrentStateToLastFormattedRange {
  if (currentState_) {
    if (currentState_ != lastFormattedState_) {
      DLOG_state("set state #%d %@ \"%@\"",
           currentState_->data->currentState->getId(),
           NSStringFromRange(lastFormattedRange_),
           [[currentMAString_ string] substringWithRange:lastFormattedRange_]);
      NSRange range = lastFormattedRange_;
      if (range.location == 0 && range.length > 0) {
        range.location++;
        range.length--;
      }
      if (range.length) {
        [currentMAString_ addAttribute:KHighlightStateAttribute
                                 value:currentState_
                                 range:lastFormattedRange_];
      }
      lastFormattedState_ = currentState_;
    }
  } else {
    DLOG_state("clear state %@ \"%@\"",
         NSStringFromRange(lastFormattedRange_),
         [[currentMAString_ string] substringWithRange:lastFormattedRange_]);
    [currentMAString_ removeAttribute:KHighlightStateAttribute
                                range:lastFormattedRange_];
  }
}

- (void)handleHighlightEvent:(const srchilite::HighlightEvent &)event {
  //_debugDumpHighlightEvent(event);
  switch (event.type) {
    case srchilite::HighlightEvent::ENTERSTATE: {
      // DID enter state
      DLOG_state("STATE+");
      tempStackDepthDelta_++;
      [self _updateCurrentState:NO];
      // never set state on first char of state opening
      if (lastFormattedRange_.length > 0) {
        lastFormattedRange_.location++;
        lastFormattedRange_.length--;
      }
      [self _applyCurrentStateToLastFormattedRange];
      break;
    }
    case srchilite::HighlightEvent::EXITSTATE: {
      // DID exit state
      DLOG_state("STATE-");
      tempStackDepthDelta_--;
      // Clear currentState_?
      if (sourceHighlighter_->getStateStack()->empty()) {
        if (currentState_) {
          [currentState_ release];
          currentState_ = nil;
        }
      } else {
        [self _updateCurrentState:YES];
      }
      // The token we just formatted was the last part of the state
      if (lastFormattedRange_.length != 0) {
        // never set state on the last char of a block since it will "taint"
        // any preceeding text. Clear state on the last char.
        NSRange range =
            NSMakeRange(lastFormattedRange_.location +
                        lastFormattedRange_.length-1, 1);
        [currentMAString_ removeAttribute:KHighlightStateAttribute range:range];
        DLOG_state("clear state %@ \"%@\"",
             NSStringFromRange(range),
             [[currentMAString_ string] substringWithRange:range]);
      }
      break;
    }
    default: if (currentState_) {
      DLOG_state("STATE=");
      [self _applyCurrentStateToLastFormattedRange];
      break;
    }
  }
  
}


- (void)setStyleForElementOfType:(NSString const*)typeSymbol
                     inUTF8Range:(NSRange)range {
  if (!currentMAString_) return;

  // convert range if needed
  if (currentUTF8StringIsMultibyte_) {
    range = [NSString UTF16RangeFromUTF8Range:range
                                 inUTF8String:currentUTF8String_->data()
                                     ofLength:currentUTF8String_->size()];
  }

  // Apply current stateful offset
  range.location += currentMAStringOffset_;
  
  // Set local-temporal state (used by handleHighlightEvent:)
  lastFormattedRange_ = range;
  lastFormattedState_ = nil;
  
  [currentStyle_ applyStyle:typeSymbol
                 toMAString:currentMAString_
                    inRange:range
              byReplacement:YES]; // replacing is faster than adding
}


/*- (void)setFormat:(KStyleElement*)format inRange:(NSRange)range {
  if (!currentMAString_) return;
  NSDictionary *attrs = format->textAttributes();

  if (currentUTF8StringIsMultibyte_) {
    // currentUTF8String_ contains non-ascii chars, so we need to convert range
    range = [NSString UTF16RangeFromUTF8Range:range
                                 inUTF8String:currentUTF8String_->data()
                                     ofLength:currentUTF8String_->size()];
  }

  range.location += currentMAStringOffset_;
  lastFormattedRange_ = range;
  lastFormattedState_ = nil; // temporal
  //DLOG_RANGE(range, currentMAString_.string);
  DLOG_state("format [%@] %@ '%@'", format->symbol(),
             NSStringFromRange(range),
             [currentMAString_.string substringWithRange:range]);
  [currentMAString_ setAttributes:attrs range:range];
}*/

@end

#import "KSyntaxHighlighter.h"
#import "KHighlightState.h"
#import "KTextFormatter.h"
#import "NSString-utf8-range-conv.h"
#import "NSError+KAdditions.h"

#import <srchilite/langelems.h>
#import <srchilite/stylefileparser.h>
#import <srchilite/parserexception.h>
#import <srchilite/ioexception.h>
#import <srchilite/settings.h>
#import <ChromiumTabs/common.h>


@interface NSString (cpp)
- (NSUInteger)populateStdString:(std::string*)str
                  usingEncoding:(NSStringEncoding)encoding
                          range:(NSRange)range;
@end
@implementation NSString (cpp)

- (NSUInteger)populateStdString:(std::string*)str
                  usingEncoding:(NSStringEncoding)encoding
                          range:(NSRange)range {
  *str = std::string(range.length, '0');
  char *pch = (char*)str->data();
  NSUInteger usedBufferCount = 0;
  [self getBytes:pch
       maxLength:range.length
      usedLength:&usedBufferCount
        encoding:encoding
         options:0
           range:range
  remainingRange:NULL];
  return usedBufferCount;
}

@end



@implementation KSyntaxHighlighter

@synthesize styleFile = styleFile_,
            currentTextStorage = currentTextStorage_;


static NSMutableArray *gLanguageFileSearchPath_;
static NSMutableArray *gStyleFileSearchPath_;


+ (void)load {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSBundle *mainBundle = [NSBundle mainBundle];
  NSString *builtinLangDir = nil, *builtinStyleDir = nil;
  if (mainBundle) {
    builtinLangDir =
        [[mainBundle resourcePath] stringByAppendingPathComponent:@"lang"];
    builtinStyleDir =
        [[mainBundle resourcePath] stringByAppendingPathComponent:@"style"];
    srchilite::Settings::setGlobalDataDir([builtinLangDir UTF8String]);
  }
  gLanguageFileSearchPath_ =
      [[NSMutableArray alloc] initWithObjects:builtinLangDir, nil];
  gStyleFileSearchPath_ =
      [[NSMutableArray alloc] initWithObjects:builtinStyleDir, nil];
  [pool drain];
}


+ (NSMutableArray *)languageFileSearchPath { return gLanguageFileSearchPath_; }
+ (NSMutableArray *)styleFileSearchPath { return gStyleFileSearchPath_; }


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


+ (NSString *)pathForStyleFile:(NSString*)file error:(NSError**)error {
  return [self _pathForResourceFile:file
                             ofType:@"css"
                      inSearchPaths:gStyleFileSearchPath_
                              error:error];
}



+ (NSString*)canonicalContentOfDefinitionFile:(NSString*)file {
  srchilite::LangDefManager *langDefManager =
      srchilite::Instances::getLangDefManager();
  const std::string path = "/opt/local/share/source-highlight";
  srchilite::LangElems *langElems =
      langDefManager->getLangElems(path, [file UTF8String]);
  if (langElems) {
    return [NSString stringWithUTF8String:langElems->toString().c_str()];
  }
  return nil;
}


+ (srchilite::HighlightStatePtr)highlightStateForDefinitionFile:(NSString*)file{
  srchilite::LangDefManager *langDefManager =
      srchilite::Instances::getLangDefManager();
  if ([file isAbsolutePath]) {
    NSString *dirname = [file stringByDeletingLastPathComponent];
    file = [file lastPathComponent];
    DLOG("loading lang from %@/%@", dirname, file);
    return langDefManager->getHighlightState([dirname UTF8String],
                                             [file UTF8String]);
  } else {
    DLOG("loading lang from %@", file);
    return langDefManager->getHighlightState([file UTF8String]);
  }
}


+ (const KTextFormatterMap &)textFormatterMapForFormatterFactory:
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
    // with proper caching of {style_id => KTextFormatterMap}
  }
  // Idea: We should fetch the "normal" formatter and:
  // 1. if bgcolor is set but no fgcolor, deduce a good fgcolor based on bgcolor
  // 2. if fgcolor is set but no ... (vice versa)
  // 3. use default colors

  return formatterFactory.getTextFormatterMap();
}


- (id)init {
  self = [super init];
  return self;
}


- (id)initWithLanguageFile:(NSString*)langFile styleFile:(NSString*)styleFile {
  if ((self = [self init])) {
    [self loadLanguageFile:langFile styleFile:styleFile];
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


/**
 * Creates formatters (and use them to initialize the formatter manager),
 * by using the passed TextFormatterMap. This can be called only after
 * the highlighter was initialized through init().
 * @param formatterMap
 */
- (void)setFormatters:(const KTextFormatterMap &)formatterMap {
  // For each element set this QSyntaxHighlighter
  // pointer (the formatters will call setFormat on such pointer).
  for (KTextFormatterMap::const_iterator it = formatterMap.begin();
       it != formatterMap.end(); ++it) {
    KTextFormatter *formatter = it->second.get();
    formatter->setSyntaxHighlighter(self);
    formatterManager_->addFormatter(it->first, it->second);
    if (it->first == "normal")
      formatterManager_->setDefaultFormatter(it->second);
  }
}


- (void)reloadStyle {
  DLOG("reloading FormatterManager");
  if (formatterManager_) {
    if (sourceHighlighter_ &&
        sourceHighlighter_->getFormatterManager() == formatterManager_) {
      sourceHighlighter_->setFormatterManager(NULL);
    }
    delete formatterManager_;
  }
  KTextFormatter *defaultFormatter = new KTextFormatter("normal");
  defaultFormatter->setSyntaxHighlighter(self);
  formatterManager_ =
      new srchilite::FormatterManager(KTextFormatterPtr(defaultFormatter));
  KTextFormatterFactory f;
  //f.setDefaultToMonospace(isDefaultToMonospace());
  
  NSError *error = nil;
  NSString *file = [isa pathForStyleFile:styleFile_ error:&error];
  if (error) {
    [NSApp presentError:error];
  } else {
    if (file)
      self.styleFile = file;
    [self setFormatters:
        [isa textFormatterMapForFormatterFactory:f styleFile:styleFile_]];
  }
  
  if (sourceHighlighter_)
    sourceHighlighter_->setFormatterManager(formatterManager_);
}


- (void)loadStyleFile:(NSString*)file {
  self.styleFile = file;
  [self reloadStyle];
}


- (void)loadLanguageFile:(NSString*)langFile styleFile:(NSString*)styleFile {
  self.styleFile = styleFile;
  [self loadLanguageFile:langFile];  // implies reloadStyle
}


- (void)loadLanguageFile:(NSString*)file {
  NSError *error = nil;
  srchilite::HighlightStatePtr mainState;
  
  // try to load language file
  file = [isa pathForLanguageFile:file error:&error];
  if (!error) {
    try {
      mainState = [isa highlightStateForDefinitionFile:file];
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
      sourceHighlighter_ = new srchilite::SourceHighlighter(mainState);
    }
    [NSApp presentError:error]; // FIXME pass by reference or something
    return;
  }
  
  if (sourceHighlighter_)
    delete sourceHighlighter_;
  sourceHighlighter_ = new srchilite::SourceHighlighter(mainState);
  sourceHighlighter_->setFormatterParams(&formatterParams_);
  sourceHighlighter_->setOptimize(false);
  sourceHighlighter_->addListener(new KHighlightEventListenerProxy(self));
  
  // reload FormatterManager
  if (!formatterManager_)
    [self reloadStyle];

  definitionFile_ = [file retain];
}


#pragma mark -
#pragma mark Formatting


- (void)recolorTextStorage:(NSTextStorage*)textStorage {
  NSRange textRange = NSMakeRange(0, textStorage.length);
  NSAttributedStringEnumerationOptions opts = 0;
  //opts = NSAttributedStringEnumerationLongestEffectiveRangeNotRequired;
  [textStorage enumerateAttribute:KTextFormatter::ClassAttributeName
                          inRange:textRange
                          options:opts
                       usingBlock:^(id value, NSRange range, BOOL *stop) {
    std::string elem;
    [value populateStdString:&elem
               usingEncoding:NSUTF8StringEncoding
                       range:NSMakeRange(0, [value length])];
    
    // clear any formatter attributes
    KTextFormatter::clearAttributes(textStorage, range);
    // find current formatter for |elem|
    KTextFormatter* formatter = dynamic_cast<KTextFormatter*>(
        formatterManager_->getFormatter(elem).get());
    // apply the formatters' style to |range|
    if (formatter) {
      formatter->applyAttributes(textStorage, range);
    }
    //DLOG("%s %@", elem.c_str(), NSStringFromRange(range));
  }];
}


- (void)highlightTextStorage:(NSTextStorage*)textStorage {
  static NSRange r = (NSRange){NSNotFound, 0};
  [self highlightTextStorage:textStorage inRange:r deltaRange:r];
}


- (NSRange)highlightTextStorage:(NSTextStorage*)textStorage
                        inRange:(NSRange)range
                     deltaRange:(NSRange)deltaRange {
  #if !NDEBUG
  fprintf(stderr,
      "----------------------- highlightTextStorage -----------------------\n");
  #endif
  assert(currentTextStorage_ == nil);
  currentTextStorage_ = [textStorage retain];
  NSString *text = [textStorage string];
  NSUInteger documentLength = [text length];
  
  // Adjust range
  if (range.location == NSNotFound) {
    // highlight all lines
    range = NSMakeRange(0, documentLength);
  } else {
    // highlight minimal part
    DLOG("range: %@  \"%@\"", NSStringFromRange(range),
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
  
  DLOG_EXPR(isCompleteDocument);
  DLOG_EXPR(wasCausedByDeleteEvent);
  DLOG_EXPR(isBeginningOfDocument);
  DLOG_EXPR(isZeroPointOfDocument);
  DLOG_EXPR(shouldTryToRestoreState);
  
  assert(currentState_ == nil);
  if (shouldTryToRestoreState) {
    //DLOG("finding previous state");
    NSUInteger previousIndex = 0;
    if (range.location != 0 && range.location != NSNotFound)
      previousIndex = range.location - 1;
    
    // get stored state
    int tries = wasCausedByDeleteEvent ? 2 : 1;
    while (tries--) {
      currentState_ = [currentTextStorage_ attribute:@"KHighlightState"
                                             atIndex:previousIndex
                                      effectiveRange:&effectiveRange];
      if (currentState_) {
        //stateData = new KHighlightStateData(*(currentState_->data));
        //[currentState_ replaceData:stateData];
        assert(currentState_->data != NULL);
        srchilite::HighlightStatePtr cs = currentState_->data->currentState;
        DLOG("found previous state: %d at index %u",
             currentState_->data->currentState->getId(),
             previousIndex);
        if (tries == 0 && deltaRange.length == 0)
          didBreakState = YES;
        break;
      } else {
        DLOG("no previous state");
        if ([currentTextStorage_ length]-range.location > 1) {
          previousIndex = range.location+1;
        } else {
          break;
        }

      }
    }
  }
  
  DLOG("didBreakState = %s", didBreakState?"YES":"NO");
  
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
  [currentTextStorage_ removeAttribute:@"KHighlightState"
                                 range:range];
  
  currentTextStorageOffset_ = range.location;
  tempStackDepthDelta_ = 0;
  
  // for each line ...
  [text enumerateSubstringsInRange:range
                           options:NSStringEnumerationByLines
                                  |NSStringEnumerationSubstringNotRequired
                           usingBlock:^(NSString *_, NSRange substringRange,
                                        NSRange enclosingRange, BOOL *stop) {
    //DLOG("substringRange: %@", NSStringFromRange(substringRange));
    std::string str;
    [text populateStdString:&str
              usingEncoding:NSUTF8StringEncoding
                      range:enclosingRange];
    currentUTF8String_ = &str;
    //fprintf(stderr, "** \"%s\"\n", str.c_str());
    sourceHighlighter_->highlightParagraph(str);
    currentTextStorageOffset_ += enclosingRange.length;
  }];
  
  currentUTF8String_ = nil;
  
  [currentState_ release];
  currentState_ = nil;

  [currentTextStorage_ release];
  currentTextStorage_ = nil;
  
  //DLOG("tempStackDepthDelta_: %d", tempStackDepthDelta_);
  BOOL stateStackIsEmpty = sourceHighlighter_->getStateStack()->empty();
  if (didBreakState) {
    DLOG("highlightTextStorage returned with lingering state (0)");
    NSRange nextRange = NSUnionRange(range, effectiveRange);
    
    DLOG("nextRange: %@", NSStringFromRange(nextRange));
    return nextRange;
  } else if (tempStackDepthDelta_ != 0) {
    DLOG("highlightTextStorage returned with lingering state (1)");
  
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
    
    DLOG("range: %@, effectiveRange: %@, nextRange: %@",
         NSStringFromRange(range),
         NSStringFromRange(effectiveRange), NSStringFromRange(nextRange));
    return nextRange;
  } else if (!stateStackIsEmpty) {
    if (deltaRange.length == 0) {
      DLOG("highlightTextStorage returned with lingering state (2)");
      // we are dealing with a DELETE edit which possibly caused dirty content
      // below the edited point.
      return NSMakeRange(range.location + range.length, 0);
    } else {
      DLOG("highlightTextStorage returned with lingering state (3)");
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
      DLOG("set state #%d %@ \"%@\"",
           currentState_->data->currentState->getId(),
           NSStringFromRange(lastFormattedRange_),
           [[currentTextStorage_ string] substringWithRange:lastFormattedRange_]);
      NSRange range = lastFormattedRange_;
      if (range.location == 0 && range.length > 0) {
        range.location++;
        range.length--;
      }
      if (range.length) {
        [currentTextStorage_ addAttribute:@"KHighlightState"
                                    value:currentState_
                                    range:lastFormattedRange_];
      }
      lastFormattedState_ = currentState_;
    }
  } else {
    DLOG("clear state %@ \"%@\"",
         NSStringFromRange(lastFormattedRange_),
         [[currentTextStorage_ string] substringWithRange:lastFormattedRange_]);
    [currentTextStorage_ removeAttribute:@"KHighlightState"
                                   range:lastFormattedRange_];
  }
}

- (void)handleHighlightEvent:(const srchilite::HighlightEvent &)event {
  //_debugDumpHighlightEvent(event);
  switch (event.type) {
    case srchilite::HighlightEvent::ENTERSTATE: {
      // DID enter state
      DLOG("STATE+");
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
      DLOG("STATE-");
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
        [currentTextStorage_ removeAttribute:@"KHighlightState" range:range];
        DLOG("clear state %@ \"%@\"",
             NSStringFromRange(range),
             [[currentTextStorage_ string] substringWithRange:range]);
      }
      break;
    }
    default: if (currentState_) {
      DLOG("STATE=");
      [self _applyCurrentStateToLastFormattedRange];
      break;
    }
  }
  
}


- (void)setFormat:(KTextFormatter*)format inRange:(NSRange)range {
  if (!currentTextStorage_) return;
  NSDictionary *attrs = format->textAttributes();
  
  NSRange utf8Range = range;
  range = [NSString UTF16RangeFromUTF8Range:range
                               inUTF8String:currentUTF8String_->data()
                                   ofLength:currentUTF8String_->size()];
  range.location += currentTextStorageOffset_;
  lastFormattedRange_ = range;
  lastFormattedState_ = nil; // temporal
  #if 0
  DLOG("setFormat:%s inRange:%@ (\"%@\") <-- %@",
       format->getElem().c_str(), NSStringFromRange(range),
       [[currentTextStorage_ string] substringWithRange:range],
       attrs);
  #endif
  [currentTextStorage_ setAttributes:attrs range:range];
}

@end

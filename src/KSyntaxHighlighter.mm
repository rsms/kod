#import "KSyntaxHighlighter.h"
#import "KHighlightState.h"
#import "KTextFormatter.h"
#import "NSString-utf8-range-conv.h"

#import <srchilite/langelems.h>
#import <srchilite/stylefileparser.h>
#import <srchilite/parserexception.h>
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


+ (srchilite::LangMap*)definitionMap {
  // make sure the lang map is loaded before returning it
  srchilite::Instances::getLangMap()->open();
  return srchilite::Instances::getLangMap();
}


+ (NSString*)definitionFileForFilename:(NSString*)filename {
  srchilite::LangMap* langMap = [self definitionMap];
  const char *pch =
      langMap->getMappedFileNameFromFileName([filename UTF8String]).c_str();
  if (pch) {
    return [NSString stringWithUTF8String:pch];
  }
  return nil;
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
  const std::string path = "/opt/local/share/source-highlight";
  return langDefManager->getHighlightState(path, [file UTF8String]);
}


+ (const KTextFormatterMap &)textFormatterMapForFormatterFactory:
    (KTextFormatterFactory &)formatterFactory
    styleFile:(NSString *)styleFile {

  if (formatterFactory.getTextFormatterMap().size()) {
    return formatterFactory.getTextFormatterMap();
  }
  
  std::string bgcolor;
  
  if (styleFile) {
    NSLog(@"loading style from %@", styleFile);
    std::string styleFileStdStr = [styleFile UTF8String];
    try {
      if (srchilite::get_file_extension(styleFileStdStr) == "css") {
        srchilite::StyleFileParser::parseCssStyleFile(styleFileStdStr,
                                                      &formatterFactory, bgcolor);
      } else {
        srchilite::StyleFileParser::parseStyleFile(styleFileStdStr,
                                                   &formatterFactory, bgcolor);
      }
    } catch (srchilite::ParserException *e) {
      NSLog(@"style parse error: %s -- %s (%s:%u)", e->message.c_str(),
            e->additional.c_str(), e->filename.c_str(), e->line);
      throw e;
    }
  }
  
  // make sure we default background to a standard color
  if (bgcolor == "")
    bgcolor = "white";
  
  // we need to transform the color string
  // since it might be in source-highlight format and not html one
  //backgroundColor_ = TextFormatterFactory::colorMap.getColor(bgcolor).c_str()); TODO
  
  return formatterFactory.getTextFormatterMap();
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


- (id)initWithDefinitionsFromFile:(NSString*)file
                    styleFromFile:(NSString*)styleFile {
  if ((self = [super init])) {
    [self loadDefinitionsFromFile:file styleFromFile:styleFile];
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


- (void)reloadFormatting {  // internal
  NSLog(@"reloading FormatterManager");
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
  [self setFormatters:
      [isa textFormatterMapForFormatterFactory:f styleFile:styleFile_]];
  if (sourceHighlighter_)
    sourceHighlighter_->setFormatterManager(formatterManager_);
}


- (void)loadDefinitionsFromFile:(NSString*)definitionFile
                  styleFromFile:(NSString*)styleFile {
  self.styleFile = styleFile;
  [self loadDefinitionsFromFile:definitionFile];  // implies reloadFormatting
}


- (void)loadDefinitionsFromFile:(NSString*)file {
  // delete any previous highlighter
  if (sourceHighlighter_)
    delete sourceHighlighter_;
  srchilite::HighlightStatePtr mainState =
      [isa highlightStateForDefinitionFile:file];
  sourceHighlighter_ = new srchilite::SourceHighlighter(mainState);
  sourceHighlighter_->setFormatterParams(&formatterParams_);
  sourceHighlighter_->setOptimize(false);
  sourceHighlighter_->addListener(new KHighlightEventListenerProxy(self));
  
  // reload FormatterManager
  if (!formatterManager_)
    [self reloadFormatting];

  definitionFile_ = [file retain];
}


- (void)loadStyleFromFile:(NSString*)file {
  self.styleFile = file;
  [self reloadFormatting];
}


#pragma mark -
#pragma mark Formatting


/*- (void)_highlightLine:(const std::string &)line
             stateData:(KHighlightStateData *&)state {
  if (state) {
    sourceHighlighter_->setCurrentState(state->currentState);
    sourceHighlighter_->setStateStack(state->stateStack);
  } else {
    // we must make sure to reset the highlighter to the initial state
    sourceHighlighter_->setCurrentState(sourceHighlighter_->getMainState());
    sourceHighlighter_->clearStateStack();
  }

  // this does all the highlighting
  currentUTF8String_ = &line;
  sourceHighlighter_->highlightParagraph(line);
  currentUTF8String_ = nil;

  // if we're not in the main initial state...
  if (!sourceHighlighter_->getStateStack()->empty()) {
    // communicate this information to parent
    if (!state)
      state = new KHighlightStateData();
    state->currentState = sourceHighlighter_->getCurrentState();
    state->stateStack = sourceHighlighter_->getStateStack();
  } else {
    // simply update the previous user data information
    if (state) {
      delete state;
      state = NULL;
    }
  }
}*/


- (void)highlightTextStorage:(NSTextStorage*)textStorage {
  static NSRange r = (NSRange){NSNotFound, 0};
  [self highlightTextStorage:textStorage inRange:r];
}


- (void)highlightTextStorage:(NSTextStorage*)textStorage
                     inRange:(NSRange)range {
  fprintf(stderr,
      "----------------------- highlightTextStorage -----------------------\n");
  assert(currentTextStorage_ == nil);
  currentTextStorage_ = [textStorage retain];
  NSString *text = [textStorage string];
  NSRange	originalRange = range;
  
  // Adjust range
  if (range.location == NSNotFound) {
    // highlight all lines
    range = NSMakeRange(0, [text length]);
  } else {
    // highlight minimal part
    if (range.length != 1 || [text characterAtIndex:range.location] != '\n') {
      // unless newline
      //range = [text lineRangeForRange:range];
      range = [text paragraphRangeForRange:range];
    }
    DLOG("range: %@", NSStringFromRange(range));
  }
  
  // get previous state
  assert(currentState_ == nil);
  if (range.location != NSNotFound && range.location != 0) {
    DLOG("finding previous state");
    NSRange effectiveRange;
    NSUInteger previousIndex = range.location-1;
    //NSDictionary *attrs = [currentTextStorage_ attributesAtIndex:previousIndex
    //                                              effectiveRange:&effectiveRange];
    //DLOG("attributesAtIndex:%u effectiveRange:%@ => %@",
    //     range.location, NSStringFromRange(effectiveRange), attrs);
    //range = NSUnionRange(effectiveRange, range);
    
    // get stored state
    //state = [attrs objectForKey:@"KHighlightState"];
    currentState_ = [currentTextStorage_ attribute:@"KHighlightState"
                                           atIndex:previousIndex
                                    effectiveRange:NULL];
    if (currentState_) {
      //stateData = new KHighlightStateData(*(currentState_->data));
      //[currentState_ replaceData:stateData];
      assert(currentState_->data != NULL);
      srchilite::HighlightStatePtr cs = currentState_->data->currentState;
      DLOG("found previous state: %d",
           currentState_->data->currentState->getId());
    } else {
      DLOG("no previous state");
    }
  }
  
  // restore state
  if (currentState_) {
    [currentState_ retain]; // our ref, released just before we return
    
    srchilite::HighlightStateStack *stateStack =
      new srchilite::HighlightStateStack(*(currentState_->data->stateStack));
    
    sourceHighlighter_->setCurrentState(currentState_->data->currentState);
    //sourceHighlighter_->setStateStack(currentState_->data->stateStack);
    sourceHighlighter_->setStateStack(srchilite::HighlightStateStackPtr(stateStack));
  } else {
    // we must make sure to reset the highlighter to the initial state
    sourceHighlighter_->setCurrentState(sourceHighlighter_->getMainState());
    sourceHighlighter_->clearStateStack();
  }
  
  currentTextStorageOffset_ = range.location;
  
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
    fprintf(stderr, "** \"%s\"\n", str.c_str());
    sourceHighlighter_->highlightParagraph(str);
    currentTextStorageOffset_ += enclosingRange.length;
  }];
  
  currentUTF8String_ = nil;
  
  [currentState_ release];
  currentState_ = nil;

  [currentTextStorage_ release];
  currentTextStorage_ = nil;
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
    DLOG("set state #%d %@", currentState_->data->currentState->getId(),
         NSStringFromRange(lastFormattedRange_));
    [currentTextStorage_ addAttribute:@"KHighlightState"
                                value:currentState_
                                range:lastFormattedRange_];
  } else {
    DLOG("clear state %@", NSStringFromRange(lastFormattedRange_));
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
      [self _updateCurrentState:NO];
      [self _applyCurrentStateToLastFormattedRange];
      break;
    }
    case srchilite::HighlightEvent::EXITSTATE: {
      // DID exit state
      DLOG("STATE-");
      // The token we just formatted was the last part of the state
      [self _applyCurrentStateToLastFormattedRange];
      // Clear currentState_?
      /*if (sourceHighlighter_->getStateStack()->empty()) {
        if (currentState_) {
          DLOG("currentState_ = nil");
          [currentState_ release];
          currentState_ = nil;
        }
      } else {
        //[self _updateCurrentState:YES];
      }*/
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
  
  #if 0
  KHighlightStateData *stateData = new KHighlightStateData();
  stateData->currentState = sourceHighlighter_->getCurrentState();
  stateData->stateStack = sourceHighlighter_->getStateStack();
  KHighlightState *state =
      [[KHighlightState alloc] initWithData:(NSData*)stateData];
  attrs = [NSMutableDictionary dictionaryWithDictionary:attrs];
  [(NSMutableDictionary*)attrs setObject:state forKey:@"KHighlightState"];
  #endif
  
  
  #if 0
  srchilite::HighlightStatePtr currentState =
      sourceHighlighter_->getCurrentState();
  attrs = [NSMutableDictionary dictionaryWithDictionary:attrs];
  NSNumber *stateIdNumber = [NSNumber numberWithInt:currentState->getId()];
  [(NSMutableDictionary*)attrs setObject:stateIdNumber
                                  forKey:@"KHighlightStateId"];
  #endif
  
  
  NSRange utf8Range = range;
  range = [NSString UTF16RangeFromUTF8Range:range
                               inUTF8String:currentUTF8String_->data()
                                   ofLength:currentUTF8String_->size()];
  range.location += currentTextStorageOffset_;
  lastFormattedRange_ = range;
  #if 1
  NSLog(@"setFormat:%s inRange:%@ (\"%@\") <-- %@",
        format->getElem().c_str(), NSStringFromRange(range),
        [[currentTextStorage_ string] substringWithRange:range],
        attrs);
  #endif
  [currentTextStorage_ setAttributes:attrs range:range];
}

@end

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


- (void)_highlightLine:(const std::string &)line
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
}


- (void)highlightLine:(NSString*)line {
  KHighlightStateData *state = NULL;
  [self _highlightLine:[line UTF8String] stateData:state];
  assert(state == NULL); // TODO reentrant block state (stack)
}


- (void)highlightTextStorage:(NSTextStorage*)textStorage {
  static NSRange r = (NSRange){NSNotFound, 0};
  [self highlightTextStorage:textStorage inRange:r];
}


- (void)highlightTextStorage:(NSTextStorage*)textStorage
                     inRange:(NSRange)range {
  assert(currentTextStorage_ == nil);
  currentTextStorage_ = [textStorage retain];
  NSString *text = [textStorage string];
  NSRange	effectiveRange;
  
  if (range.location == NSNotFound) {
    // highlight all lines
    effectiveRange = NSMakeRange(0, [text length]);
  } else {
    // highlight minimal part
    NSString *elem = [currentTextStorage_ attribute:KTextFormatter::ClassAttributeName
                                            atIndex:range.location
                                     effectiveRange:&effectiveRange];
    effectiveRange = NSUnionRange(effectiveRange, range);
    DLOG("effectiveRange: %@, elem: %@",NSStringFromRange(effectiveRange),elem);
  }
  
  currentTextStorageOffset_ = effectiveRange.location;
  __block KHighlightStateData *stateData = NULL;
  
  // get stored state
  KHighlightState *state = nil;
  if (range.location != NSNotFound) {
    
    NSDictionary *attrs = [currentTextStorage_ attributesAtIndex:range.location
                                             effectiveRange:NULL];
    DLOG("attrs{%u, %u} => %@", range.location, range.location, attrs);
    
    state = [currentTextStorage_ attribute:@"KHighlightState"
                                   atIndex:range.location
                            effectiveRange:NULL];
    if (state) {
      assert(state->data != NULL);
      DLOG("prev stateId: %d", state->data->currentState->getId());
      stateData = new KHighlightStateData(*(state->data));
    }
  }
  
  // for each line ...
  [text enumerateSubstringsInRange:effectiveRange
                           options:NSStringEnumerationByLines
                                  |NSStringEnumerationSubstringNotRequired
                           usingBlock:^(NSString *_, NSRange substringRange,
                                        NSRange enclosingRange, BOOL *stop) {
    //DLOG("substringRange: %@", NSStringFromRange(substringRange));
    std::string str;
    [text populateStdString:&str
              usingEncoding:NSUTF8StringEncoding
                      range:enclosingRange];
    //NSLog(@"%s", str.c_str());
    [self _highlightLine:str stateData:stateData];
    //WLOG("TODO reentrant block state (stack)");
    currentTextStorageOffset_ += enclosingRange.length;
  }];
  
  // clear any previous KHighlightState attribute(s)
  [currentTextStorage_ removeAttribute:@"KHighlightState" range:effectiveRange];
  
  int stateId = 0;
  if (stateData) {
    // we changed the highlighting state
    stateId = stateData->currentState->getId();
    if (!state) {
      state = [[KHighlightState alloc] initWithData:(NSData*)stateData];
    } else {
      [state replaceData:stateData];
    }
    // store state
    [currentTextStorage_ addAttribute:@"KHighlightState"
                                value:state
                                range:effectiveRange];

    // this is crucial for QSyntaxHighlighter to know whether other parts
    // of the document must be re-highlighted
    //setCurrentBlockState(stateId);
    DLOG("currentBlockState: %d", stateId);
  }

  [currentTextStorage_ release];
  currentTextStorage_ = nil;
}


- (void)setFormat:(KTextFormatter*)format inRange:(NSRange)range {
  if (currentTextStorage_) {
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
    
    NSRange utf8Range = range;
    range = [NSString UTF16RangeFromUTF8Range:range
                                 inUTF8String:currentUTF8String_->data()
                                     ofLength:currentUTF8String_->size()];
    range.location += currentTextStorageOffset_;
    #if 0
    NSLog(@"setFormat '%@' %@ (%@) <-- %@ ",
          [[currentTextStorage_ string] substringWithRange:range],
          NSStringFromRange(range), NSStringFromRange(utf8Range), attrs);
    #endif
    [currentTextStorage_ setAttributes:attrs range:range];
  }
}

@end

#import "KSyntaxHighlighter.h"
#import "KTextFormatter.h"
#import "NSString-utf8-range-conv.h"

#import <srchilite/langelems.h>
#import <srchilite/stylefileparser.h>
#import <srchilite/parserexception.h>
#import <ChromiumTabs/common.h>


@implementation KSyntaxHighlighter

@synthesize styleFile = styleFile_;


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
    // communicate this information to the QSyntaxHighlighter
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


/*- (void)highlightTextStorage:(NSTextStorage*)textStorage
                     inRange:(NSRange)range {
  assert(currentTextStorage_ == nil);
  currentTextStorage_ = [textStorage retain];
  currentTextStorageOffset_ = range.location;
  KHighlightStateData *state = NULL;
  NSString *text = [[textStorage string] substringWithRange:range];
  const char *utf8str = [text UTF8String];
  const char *ptr = utf8str;
  size_t len = 0;
  //NSLog(@"utf8len: %zd, unilen: %zd", strlen(utf8str), [text length]);
  while (*ptr) {
    while (*(++ptr) && *ptr != '\n') {};
    len = ptr-utf8str;
    std::string line(utf8str, len);
    //NSLog(@"<string(%zd) \"%s\">", len, line.c_str());
    [self _highlightLine:line stateData:state];
    utf8str = ptr+1;
    currentTextStorageOffset_ += len+1;
  }
  assert(state == NULL); // TODO reentrant block state (stack)
  [currentTextStorage_ release];
  currentTextStorage_ = nil;
}*/


- (void)highlightTextStorage:(NSTextStorage*)textStorage
                     inRange:(NSRange)range {
  assert(currentTextStorage_ == nil);
  currentTextStorage_ = [textStorage retain];
  currentTextStorageOffset_ = range.location;
  NSString *text = [[textStorage string] substringWithRange:range];
  [text enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
    KHighlightStateData *state = NULL;
    [self _highlightLine:[line UTF8String] stateData:state];
    WLOG("TODO reentrant block state (stack)");
    currentTextStorageOffset_ += [line length] + 1;
  }];
  [currentTextStorage_ release];
  currentTextStorage_ = nil;
}


- (void)setFormat:(KTextFormatter*)format inRange:(NSRange)range {
  if (currentTextStorage_) {
    NSDictionary *attrs = format->textAttributes();
    //sourceHighlighter_->getStateStack()
    range = [NSString UTF16RangeFromUTF8Range:range
                                 inUTF8String:currentUTF8String_->c_str()
                                     ofLength:currentUTF8String_->size()];
    range.location += currentTextStorageOffset_;
    //NSLog(@"setFormat %@ <-- %@", NSStringFromRange(range), attrs);
    [currentTextStorage_ setAttributes:attrs range:range];
  }
}

@end

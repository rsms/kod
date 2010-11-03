#import "KSyntaxHighlighter.h"
#import "KTextFormatter.h"

#include <srchilite/langelems.h>
#include <srchilite/stylefileparser.h>

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
    if (srchilite::get_file_extension(styleFileStdStr) == "css") {
      srchilite::StyleFileParser::parseCssStyleFile(styleFileStdStr,
                                                    &formatterFactory, bgcolor);
    } else {
      srchilite::StyleFileParser::parseStyleFile(styleFileStdStr,
                                                 &formatterFactory, bgcolor);
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
  }
  // now store the color for the normal font, and set the highlighter for the formatter
  /*Qt4TextFormatter *formatter =
      dynamic_cast<Qt4TextFormatter *> (formatterManager->getFormatter("normal").get());
  if (formatter) {
    setForegroundColor(formatter->getQTextCharFormat().foreground().color().name());
  }*/
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

/**
 * Highlights the passed line.
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
- (void)highlightLine:(NSString*)line
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
  sourceHighlighter_->highlightParagraph([line UTF8String]);

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

@end

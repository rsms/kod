#import "SyntaxHighlighter.h"

@implementation SyntaxHighlighter

- (srchilite::HighlightStatePtr)highlightStateForDefinitionFile:(NSString*)file {
  srchilite::LangDefManager *langDefManager =
      srchilite::Instances::getLangDefManager();
  return langDefManager->getHighlightState([file UTF8String]);
}

- (void)loadDefinitionFile:(NSString*)file {
  // delete the possible previous highlighter
  if (sourceHighlighter_) {
    delete sourceHighlighter_;
    sourceHighlighter_ = NULL;
  }
  srchilite::HighlightStatePtr mainState =
      [self highlightStateForDefinitionFile:file];
  sourceHighlighter_ = new srchilite::SourceHighlighter(mainState);
  //sourceHighlighter_->setFormatterManager(formatterManager);
  //sourceHighlighter_->setFormatterParams(&formatterParams);
  sourceHighlighter_->setOptimize(false);

  definitionFile_ = [file retain];
}

@end

#import "KLangManager.h"
#import "KLangRegexRuleFactory.h"
#import "KConfig.h"

#import <srchilite/fileutil.h>
#import <srchilite/langdefparserfun.h>
#import <srchilite/langelems.h>
#import <srchilite/highlightstatebuilder.h>

using namespace srchilite;


HighlightStatePtr KLangManager::buildHighlightState(const char *dirname,
                                                    const char *basename) {
  HighlightStatePtr highlightState(new HighlightState);
  
  // parse the contents of the langdef file
  LangElems *elems = readLangElems(dirname, basename);
  
  // build the highlight state corresponding to the language definition file
  KLangRegexRuleFactory ruleFactory;
  HighlightStateBuilder builder(&ruleFactory);
  builder.build(elems, highlightState);
  
  delete elems;
  return highlightState;
}


LangElems *KLangManager::readLangElems(const char *dirname,
                                       const char *basename) {
  try {
    return parse_lang_def(dirname, basename);
  } catch (const std::exception &e) {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isdir = NO;
    NSString *path = [NSString stringWithFormat:@"%s/%s", dirname, basename];
    if (![fm fileExistsAtPath:path isDirectory:&isdir]) {
      [NSException raise:KFileNotFoundException format:@"\"%@\"", path];
    } else if (isdir) {
      [NSException raise:KFileNotFoundException
                  format:@"\"%@\" is a directory, not a file", path];
    } else {
      throw e;
    }
  }
}


//static KLangMap g_lang_map;


/*NSDictionary *KLangManager::langMap() {
  NSDictionary *langMap = KConfig.getDict(@"languages");
  NSDictionary *extMap, *nameMap, *firstlineMap;
  if (!langMap) {
    // create langMap
    extMap = [NSMutableDictionary dictionary];
    nameMap = [NSMutableDictionary dictionary];
    firstlineMap = [NSMutableDictionary dictionary];
    
    langMap = [NSDictionary dictionaryWithObjectsAndKeys:nil];
    
    
    KConfig.set(@"languages", langMap);
  }
  return langMap;
}


NSString *KLangManager::langIdentifierForFilename(NSString *filename) {
  assert([[filename pathComponents] count] == 1);
  NSDictionary *langMap = langMap();
  
  //# @matchext html, htm, shtml, xhtml, phtml, php, inc, tmpl, tpl, ctp
  //# #@matchname moc, cpp, C, cc, h, hh, H, hpp
  //# @matchfirstline <!DOCTYPE|<(?i:html)|<\?(?i:php)
  
  //firstLineMatch = '<!DOCTYPE|<(?i:html)|<\?(?i:php)';
	//fileTypes = ( 'html', 'htm', 'shtml', 'xhtml', 'phtml', 'php', 'inc', 'tmpl', 'tpl', 'ctp' );
  
}*/





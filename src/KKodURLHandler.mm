#import "common.h"
#import "KKodURLHandler.h"
#import "KFileURLHandler.h"
#import "KLangMap.h"
#import "kconf.h"
#import "kod_version.h"
#import "KDocumentController.h"


@interface NSURL (kod_uri)
- (NSString*)kodURICommand;
@end
@implementation NSURL (kod_uri)

- (NSString*)kodURICommand {
  return [[self relativeString] substringFromIndex:4]; // "kod:"...
}

@end



@implementation KKodURLHandler


- (id)init {
  if (!(self = [super init])) return nil;

  commandToFileResource_ = [[NSDictionary alloc] initWithObjectsAndKeys:
      @"about.md", @"about",
      @"changelog", @"changelog",
      nil];

  return self;
}


- (BOOL)canReadURL:(NSURL*)url {
  if ([[url scheme] caseInsensitiveCompare:@"kod"] == NSOrderedSame) {
    // supported commands
    NSString *cmd = [[url kodURICommand] lowercaseString];
    return [commandToFileResource_ objectForKey:cmd] != nil;
  }
  return NO;
}


- (void)readURL:(NSURL*)url ofType:(NSString*)typeName inTab:(KDocument*)tab{
  NSString *cmd = [[url kodURICommand] lowercaseString];
  NSString *fileResourceRelPath = [commandToFileResource_ objectForKey:cmd];
  kassert(fileResourceRelPath != nil);

  NSURL *fileURL = kconf_res_url(fileResourceRelPath);
  KDocumentController *documentController = [KDocumentController kodController];
  KFileURLHandler *fileURLHandler =
      (KFileURLHandler*)[documentController urlHandlerForURL:fileURL];
  kassert(fileURLHandler != nil);
  [tab.textView setEditable:NO];

  // guess langId
  tab.langId = [[KLangMap sharedLangMap] langIdForSourceURL:fileURL
                                                    withUTI:nil
                                       consideringFirstLine:nil];

  // delegate reading to the file url handler
  [fileURLHandler readURL:fileURL
                   ofType:nil
                    inTab:tab
          successCallback:^{
    // substitute placeholders
    NSString *str = [tab.textView string];
    str = [str stringByReplacingOccurrencesOfString:@"$VERSION"
                                         withString:@K_VERSION_STR];
    [tab.textView setString:str];

    // set cursor to 0,0 (has the side-effect of hiding it)
    [tab.textView setSelectedRange:NSMakeRange(0, 0)];

    // Clear change count
    [tab updateChangeCount:NSChangeCleared];

    // set the icon to the app icon
    tab.icon = [NSImage imageNamed:@"kod.icns"];
  }];
}


@end

#import "common.h"
#import "KKodURLHandler.h"
#import "KFileURLHandler.h"
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


- (BOOL)canReadURL:(NSURL*)url {
  if ([[url scheme] caseInsensitiveCompare:@"kod"] == NSOrderedSame) {
    // supported commands
    NSString *cmd = [url kodURICommand];
    if ([cmd isEqualToString:@"about"]) {
      return YES;
    }
  }
  return NO;
}


- (void)readURL:(NSURL*)url ofType:(NSString*)typeName inTab:(KTabContents*)tab{
  NSString *cmd = [url kodURICommand];
  kassert([cmd isEqualToString:@"about"]); // only supported command atm

  NSURL *fileURL = kconf_res_url(@"about.md");
  KDocumentController *documentController = [KDocumentController kodController];
  KFileURLHandler *fileURLHandler =
      (KFileURLHandler*)[documentController urlHandlerForURL:fileURL];
  kassert(fileURLHandler != nil);
  [tab.textView setEditable:NO];
  [fileURLHandler readURL:fileURL
                   ofType:@"net.daringfireball.markdown"
                    inTab:tab
          successCallback:^{
    // substitute placeholders
    NSString *str = [tab.textView string];
    str = [str stringByReplacingOccurrencesOfString:@"$VERSION"
                                         withString:@K_VERSION_STR];
    [tab.textView setString:str];
    
    // Clear change count
    [tab updateChangeCount:NSChangeCleared];
  }];
}


@end

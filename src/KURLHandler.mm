#import "common.h"
#import "KURLHandler.h"

@implementation KURLHandler


+ (KURLHandler*)handler {
  return [[self new] autorelease];
}


- (BOOL)canReadURL:(NSURL*)url {
  return NO;
}


- (void)readURL:(NSURL*)url ofType:(NSString*)typeName inTab:(KTabContents*)tab{
  [tab urlHandler:self finishedReadingURL:url data:nil ofType:typeName
            error:[NSError kodErrorWithFormat:
            @"%@ %@ not implemented", self, NSStringFromSelector(_cmd)]
         callback:nil];
}


@end

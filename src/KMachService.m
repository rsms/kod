#import "KMachService.h"
#import "KDocumentController.h"
#import "common.h"

static KMachService *gSharedInstance = nil;

@implementation KMachService


+ (KMachService*)sharedService {
  if (!gSharedInstance) {
    gSharedInstance =
        [[self alloc] initWithMachPortName:K_SHARED_SERVICE_PORT_NAME];
  }
  return gSharedInstance;
}


- (id)initWithMachPortName:(NSString*)portName {
  self = [super init];

  connection_ = [[NSConnection alloc] initWithReceivePort:[NSMachPort port]
                                                 sendPort:nil];
  [connection_ setRootObject:self];
  if (![connection_ registerName:portName]) {
    WLOG("error: failed to initialize mach port %@ for receiving", portName);
    [self release];
    self = nil;
  } else {
    DLOG("%@ opened", self);
  }

  return self;
}


- (BOOL)connection:(NSConnection *)parentConnection
shouldMakeNewConnection:(NSConnection *)newConnnection {
  DLOG_TRACE();
  return YES;
}


- (void)openURLs:(NSArray*)urlStrings {
  NSMutableArray *absoluteURLs =
      [NSMutableArray arrayWithCapacity:[urlStrings count]];
  for (NSString *url in urlStrings) {
    if ([url rangeOfString:@":"].location != NSNotFound) {
      [absoluteURLs addObject:[NSURL URLWithString:url]];
    } else {
      [absoluteURLs addObject:[NSURL fileURLWithPath:url]];
    }
  }
  DLOG("%@ openURLs:%@", self, absoluteURLs);
  KDocumentController *documentController = [KDocumentController kodController];
  kassert(documentController != nil);
  [documentController openDocumentsWithContentsOfURLs:absoluteURLs
                       nonExistingFilesAsNewDocuments:YES
                                             callback:nil];
}


@end

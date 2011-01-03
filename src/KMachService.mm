#import "KMachService.h"
#import "KMachService-NSInvocation.h"
#import "HEventEmitter.h"
#import "HDStream.h"
#import "KDocument.h"
#import "KDocumentController.h"
#import "common.h"

static KMachService *gSharedInstance = nil;

@implementation KMachService


+ (KMachService*)sharedService {
  if (!gSharedInstance) {
    gSharedInstance =
        [[self alloc] initWithMachPortName:@K_SHARED_SERVICE_PORT_NAME];
  }
  return gSharedInstance;
}


- (id)initWithMachPortName:(NSString*)portName {
  self = [super init];

  connection_ = [[NSConnection serviceConnectionWithName:portName
                                              rootObject:self] retain];
  if (!connection_) {
    WLOG("error: failed to initialize mach port %@ for receiving", portName);
    [self release];
    self = nil;
  } else {
    DLOG("%@ opened", self);
  }
  
  fileHandleWaitQueue_ = [NSMutableDictionary new];

  return self;
}


- (void)dealloc {
  [fileHandleWaitQueue_ release];
  [connection_ invalidate];
  [connection_ release];
  [super dealloc];
}


- (BOOL)connection:(NSConnection *)parentConnection
shouldMakeNewConnection:(NSConnection *)newConnnection {
  DLOG_TRACE();
  return YES;
}


- (void)openURLs:(NSArray*)urlStrings callback:(NSInvocation*)callback {
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
                                             callback:^(NSError *err){
    [callback invokeKMachServiceCallbackWithArgument:err];
  }];
}


/*- (void)fileHandleDidReadToEndOfFile:(NSNotification*)notification {
  NSDictionary *info = [notification userInfo];
  NSFileHandle *fileHandle = [notification object];
  [self stopObservingObject:fileHandle];
  NSError *error = [info objectForKey:@"NSFileHandleError"];
  if (!error) {
    NSData *data = [info objectForKey:NSFileHandleNotificationDataItem];
    // ...
  }
}*/


- (void)openNewDocumentWithData:(NSData*)data
                         ofType:(NSString*)typeName
                       callback:(NSInvocation*)callback {
  DLOG("%@ openNewDocumentWithData", self);
  
  KDocumentController *documentController = [KDocumentController kodController];
  kassert(documentController != nil);

  // Create a new blank document
  NSError *error;
  KDocument *document = [documentController openNewDocumentWithData:data
                                                             ofType:typeName
                                               withWindowController:nil
                                                  groupWithSiblings:NO
                                                            display:YES
                                                              error:&error];

  // Handle error
  if (!document) {
    WLOG("failed to open an untitled document: %@", error);
    K_DISPATCH_MAIN_ASYNC({ [documentController presentError:error]; });
  }

  // invoke callback
  if (callback)
    [callback invokeKMachServiceCallbackWithArgument:error];

  /*
  TODO(rsms): Pass the file descriptor by kernel FD delegation using sendmsg.
  This would allow us to read data using async I/O using the below code:

  // Set document as loading
  document.isLoading = YES;
  document.isEditable = NO;

  [self observe:NSFileHandleReadToEndOfFileCompletionNotification
         source:fileHandle
        handler:@selector(fileHandleDidReadToEndOfFile:)];
  if (callbackInvocation) {
    [fileHandleWaitQueue_ setObject:callbackInvocation forKey:fileHandle];
  }
  [fileHandle readToEndOfFileInBackgroundAndNotify];
  */
}


@end

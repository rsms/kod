// Copyright (c) 2010-2011, Rasmus Andersson. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

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
    if (!gSharedInstance) {
      WLOG("error: failed to initialize shared KMachService -- are you"
           " running more than one Kod.app instance?");
    }
  }
  return gSharedInstance;
}


- (id)initWithMachPortName:(NSString*)portName {
  if (!(self = [super init])) return nil;

  connection_ = [[NSConnection serviceConnectionWithName:portName
                                              rootObject:self] retain];
  if (!connection_) {
    [self release];
    return nil;
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


- (void)openURLs:(NSArray*)urlStrings
    openCallback:(NSInvocation*)openCallback
  closeCallbacks:(NSArray*)closeCallbacks {
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
                                             callback:
    ^(NSError *err, NSArray *openedDocs) {
      // register close callbacks
      // TODO: handle program termination -- register for the
      // NSApplicationWillTerminate notification and invoke all close callbacks
      // which remains.
      if (closeCallbacks) {
        NSUInteger i, count = [openedDocs count];
        for (i = 0; i < count; i++) {
          KDocument *doc = [openedDocs objectAtIndex:i];
          kassert([doc isKindOfClass:[KDocument class]]);
          NSInvocation *closeCallback = [closeCallbacks objectAtIndex:i];
          kassert([closeCallback isKindOfClass:[NSInvocation class]]);
          [doc on:@"close" call:^(KDocument *doc){
            [closeCallback invokeKMachServiceCallbackWithArgument:doc.url];
          }];
        }
      }
      // TODO: handle the case when we get closeCallbacks and an error occured
      // when opening files.
      [openCallback invokeKMachServiceCallbackWithArgument:err];
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
                   openCallback:(NSInvocation*)openCallback
                  closeCallback:(NSInvocation*)closeCallback {
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
  } else if (closeCallback) {
    // register close callback
    // TODO: handle program termination -- register for the
    // NSApplicationWillTerminate notification and invoke all close callbacks
    // which remains.
    [document on:@"close" call:^(KDocument *doc){
      [closeCallback invokeKMachServiceCallbackWithArgument:doc.url];
    }];
  }

  // invoke callback
  if (openCallback)
    [openCallback invokeKMachServiceCallbackWithArgument:error];

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

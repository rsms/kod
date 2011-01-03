#import "common.h"
#import "KHTTPURLHandler.h"

@implementation KHTTPURLHandler


- (BOOL)canReadURL:(NSURL*)url {
  return [[url scheme] caseInsensitiveCompare:@"http"] == NSOrderedSame;
}


- (void)readURL:(NSURL*)absoluteURL
         ofType:(NSString*)typeName
          inTab:(KDocument*)tab {
  // set state to "waiting"
  tab.isLoading = YES;
  tab.isWaitingForResponse = YES;

  // set text view to be read-only
  tab.isEditable = NO;

  // set type (might change when we receive a response)
  tab.fileType = typeName;

  __block NSString *textEncodingNameFromResponse = nil;

  HURLConnection *conn = [absoluteURL
    fetchWithOnResponseBlock:^(NSURLResponse *response) {
      NSError *error = nil;
      NSDate *fileModificationDate = nil;

      // change state from waiting to loading
      tab.isWaitingForResponse = NO;

      // handle HTTP response
      if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        // check status
        NSInteger status = [(NSHTTPURLResponse*)response statusCode];
        if (status < 200 || status > 299) {
          error = [NSError kodErrorWithHTTPStatusCode:status];
        }
        // TODO: get fileModificationDate from response headers
      }

      // try to derive UTI and read filename, unless error
      if (!error) {
        // get UTI based on MIME type
        CFStringRef mimeType = (CFStringRef)[response MIMEType];
        if (mimeType) {
          NSString *uti = (NSString*)
              UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType,
                                                    mimeType, NULL);
          if (uti)
            tab.fileType = uti;
        }

        // get text encoding
        textEncodingNameFromResponse = [response textEncodingName];
      }

      // update URL, if needed (might have been redirected)
      tab.fileURL = response.URL;

      // set suggested title
      tab.title = response.suggestedFilename;

      // set modification date
      tab.fileModificationDate = fileModificationDate ? fileModificationDate
                                                      : [NSDate date];

      return error;
    }
    onCompleteBlock:^(NSError *err, NSData *data) {
      // Read data unless an error occured while reading URL
      if (err) {
        tab.isLoading = NO;
        tab.isCrashed = YES; // FIXME
        data = nil;
      } else {
        // if we got a charset, try to convert it into a NSStringEncoding symbol
        if (textEncodingNameFromResponse) {
          tab.textEncoding = CFStringConvertEncodingToNSStringEncoding(
              CFStringConvertIANACharSetNameToEncoding(
                  (CFStringRef)textEncodingNameFromResponse));
        }
      }

      // finalize
      [tab urlHandler:self
   finishedReadingURL:absoluteURL
                 data:data
               ofType:typeName
                error:err
             callback:^(NSError *err) {
        if (!err) {
          // done -- enable editing
          tab.isEditable = YES;
        }
      }];
    }
    startImmediately:NO];

  kassert(conn);

  // we want the blocks to be invoked on the main thread, thank you
  [conn scheduleInRunLoop:[NSRunLoop mainRunLoop]
                  forMode:NSDefaultRunLoopMode];
  [conn start];

  // TODO: keep a reference to the connection so we can cancel it if the tab is
  // prematurely closed.
}



@end

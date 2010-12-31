#import "common.h"
#import "KCrashReportCollector.h"

@implementation KCrashReportCollector


+ (KCrashReportCollector*)crashReportCollector {
  return [[self new] autorelease];
}


- (id)init {
  if (!(self = [super init])) return nil;
  processedFileSuffix_ = @"-processed";
  return self;
}


- (NSArray*)URLsForUnprocessedCrashReports {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *crashReporterLogdir =
      [@"~/Library/Logs/CrashReporter/" stringByExpandingTildeInPath];
  NSError *error;
  NSArray *metaKeys = [NSArray arrayWithObject:NSURLContentModificationDateKey];
  NSURL *dirurl = [NSURL fileURLWithPath:crashReporterLogdir isDirectory:YES];
  NSArray *urls = [fm contentsOfDirectoryAtURL:dirurl
                    includingPropertiesForKeys:metaKeys
                                  options:NSDirectoryEnumerationSkipsHiddenFiles
                                         error:&error];
  NSString *filenamePrefix = @"Kod_";
  NSMutableArray *urls2 = [NSMutableArray array];
  for (NSURL *url in urls) {
    NSString *filename =
        [[url lastPathComponent] stringByDeletingPathExtension];
    if ([filename hasPrefix:filenamePrefix] &&
        ![filename hasSuffix:processedFileSuffix_]){
      [urls2 addObject:url];
    }
  }
  return urls2;
}


- (NSURL*)markCrashReportsAsProcessedForURLs:(NSArray*)urls {
  NSDate *latestDate = [NSDate distantPast];
  NSURL *latestURL = nil;
  NSFileManager *fm = [NSFileManager defaultManager];
  NSDate *mtime = nil;
  NSError *error;
  for (NSURL *url in urls) {
    if ([url getResourceValue:&mtime
                       forKey:NSURLContentModificationDateKey
                        error:nil]) {
      // move file
      NSString *path = [url path];
      NSString *pathExt = [url pathExtension];
      path = [NSString stringWithFormat:@"%@%@.%@",
          [path stringByDeletingPathExtension], processedFileSuffix_, pathExt];
      NSURL *dstURL = [NSURL fileURLWithPath:path isDirectory:NO];
      DLOG("[crash reporter] marking %@ as processed", url);
      if ([fm moveItemAtURL:url toURL:dstURL error:&error] && mtime &&
          [mtime laterDate:latestDate]) {
        latestURL = dstURL;
        latestDate = mtime;
      }
    }
  }
  return latestURL;
}


- (void)submitCrashReportAtURL:(NSURL*)reportURL
                      callback:(void(^)(NSError*))callback {
  NSError *error = nil;
  NSData *data = [NSData dataWithContentsOfURL:reportURL
                                       options:NSDataReadingUncached
                                         error:&error];
  if (!data) {
    if (callback)
      callback(error);
    return;
  }
  NSURL *url =
      [NSURL URLWithString:@"http://kodapp.com/crashreport/recv.php"];
  NSMutableURLRequest *req =
      [NSMutableURLRequest requestWithURL:url cachePolicy:
       NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:60.0];
  [req setHTTPMethod:@"POST"];
  [req setAllHTTPHeaderFields:[NSDictionary
      dictionaryWithObject:@"application/octet-stream"
                    forKey:@"Content-Type"]];
  [req setHTTPBody:data];
  [self retain]; // during submission
  [HURLConnection connectionWithRequest:req
                               onResponseBlock:^(NSURLResponse *response) {
    // check response status
    NSError *error = nil;
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
      NSInteger status = [(NSHTTPURLResponse*)response statusCode];
      if (status < 200 || status > 299) {
        error = [NSError kodErrorWithHTTPStatusCode:status];
      }
    }
    return error;
  }
  onDataBlock:nil onCompleteBlock:
  ^(NSError *err, NSData *rspData){
    if (!err) {
      DLOG("submitted crash report OK. Response: '%@'",
           [rspData weakStringWithEncoding:NSUTF8StringEncoding]);
    }
    if (callback)
      callback(err);
    [self release];
    // Note: the connection object releases itself after the onComplete handler
    // returns.
  } startImmediately:YES];
}


- (void)askUserToSubmitAnyUnprocessedCrashReport {
  NSArray *unprocessedReportURLs = [self URLsForUnprocessedCrashReports];
  NSURL *latestUnprocessedReportURL =
      [self markCrashReportsAsProcessedForURLs:unprocessedReportURLs];
  if (!latestUnprocessedReportURL)
    return;
  // Ask if the user thinks it is ok to send the log to us.
  NSAlert *alertModal = [NSAlert alertWithMessageText:@"Crash report found"
                                        defaultButton:@"Submit report"
                                      alternateButton:@"Forget"
                                          otherButton:nil
                            informativeTextWithFormat:
      @"Oops. Looks like Kod crashed earlier. Would you please like to send"
       "us the crash report so Kod can be improved?"];
  //[alertBox setIcon:[NSImage imageNamed:@"crash-reporter.png"]];

  if ([alertModal runModal] == NSCancelButton)
    return;
  NSError *error = nil;
  [self submitCrashReportAtURL:latestUnprocessedReportURL
                      callback:^(NSError *err) {
    if (err) {
      WLOG("failed to send crash report (%@) -- report resides on disk at %@",
           err, latestUnprocessedReportURL);
    }
  }];
}


@end

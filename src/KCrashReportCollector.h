@interface KCrashReportCollector : NSObject {
  NSString *processedFileSuffix_;
}
+ (KCrashReportCollector*)crashReportCollector;
- (NSArray*)URLsForUnprocessedCrashReports;
- (NSURL*)markCrashReportsAsProcessedForURLs:(NSArray*)urls;
- (void)submitCrashReportAtURL:(NSURL*)reportURL
                      callback:(void(^)(NSError*))callback;
- (void)askUserToSubmitAnyUnprocessedCrashReport;

@end

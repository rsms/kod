#import "HDProcess.h"

@interface KNodeProcess : NSObject {
  HDProcess *process_;
  HDStream *channel_;
  BOOL channelHasConfirmedHandshake_;
}

+ (id)sharedProcess;
- (void)start;

@end

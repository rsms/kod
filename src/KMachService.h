#import "KMachServiceProtocol.h"

@interface KMachService : NSObject <KMachServiceProtocol,
                                    NSConnectionDelegate> {
  NSConnection *connection_;
  NSMutableDictionary *fileHandleWaitQueue_;
}

+ (KMachService*)sharedService;
- (id)initWithMachPortName:(NSString*)portName;

@end

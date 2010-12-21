#import "KMachServiceProtocol.h"

@interface KMachService : NSObject <KMachServiceProtocol,
                                    NSConnectionDelegate> {
  NSConnection *connection_;
}

+ (KMachService*)sharedService;
- (id)initWithMachPortName:(NSString*)portName;

@end

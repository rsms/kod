#import <QuartzCore/QuartzCore.h>

@interface NSImage (kod)

+ (NSImage*)imageWithCIImage:(CIImage*)ciImage;

- (NSImage*)imageByApplyingCIFilterNamed:(NSString*)ciFilterName;

- (NSImage*)imageByApplyingCIFilterNamed:(NSString*)ciFilterName
                        filterParameters:(NSDictionary*)filterParameters;

- (CIImage*)ciImage;

@end

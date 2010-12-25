#import <QuartzCore/QuartzCore.h>

@interface CIImage (kod)

- (CIImage*)flippedImage;

- (CIImage*)imageByApplyingFilterNamed:(NSString*)filterName;

- (CIImage*)imageByApplyingFilterNamed:(NSString*)filterName
                            parameters:(NSDictionary*)parameters;

@end
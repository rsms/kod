#import "CIImage-kod.h"

@implementation CIImage (kod)

- (CIImage*)flippedImage {
  CGAffineTransform transform =
      CGAffineTransformMakeTranslation(0.0, [self extent].size.height);
  transform = CGAffineTransformScale(transform, 1.0, -1.0);
  return [self imageByApplyingTransform:transform];
}

- (CIImage*)imageByApplyingFilterNamed:(NSString*)filterName
                            parameters:(NSDictionary*)parameters {
  CIFilter* filter = [CIFilter filterWithName:filterName];
  [filter setDefaults];
  [filter setValue:self forKey:@"inputImage"];
  if (parameters) {
    [parameters enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop){
      [filter setValue:obj forKey:key];
    }];
  }
  return [filter valueForKey:@"outputImage"];
}

- (CIImage*)imageByApplyingFilterNamed:(NSString*)filterName {
  return [self imageByApplyingFilterNamed:filterName parameters:nil];
}

@end
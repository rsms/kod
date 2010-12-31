#import "NSImage-kod.h"
#import "CIImage-kod.h"

@implementation NSImage (kod)

+ (NSImage*)imageWithCIImage:(CIImage*)ciImage {
  CGRect ciImageExtent = [ciImage extent];
  NSImage *image = [[[NSImage alloc] initWithSize:
      NSSizeFromCGSize(ciImageExtent.size)] autorelease];
  [image lockFocus];
  CIContext *ciContext = [[NSGraphicsContext currentContext] CIContext];
  [ciContext drawImage:ciImage
               atPoint:CGPointMake(0, 0)
              fromRect:ciImageExtent];
  [image unlockFocus];
  return image;
  /*
  According to an old article
  <http://inessential.com/2007/03/07/workaround_for_ciimage_to_nsimage_memory>
  the above code might leak and the below code doesn't. But that was in an older
  version of OS X. Might still be a good idea to investigate this.

  NSImage *image = [[[NSImage alloc] initWithSize:
                     NSMakeSize([ciImage extent].size.width,
                                [ciImage extent].size.height)]
                    autorelease];
  [image lockFocus];
  CGContextRef contextRef = [[NSGraphicsContext currentContext] graphicsPort];
  NSDictionary *options = [NSDictionary dictionaryWithObject:
      [NSNumber numberWithBool:YES] forKey:kCIContextUseSoftwareRenderer];
  CIContext *ciContext =
  [CIContext contextWithCGContext:contextRef
                          options:options];
  [ciContext drawImage:ciImage
               atPoint:CGPointMake(0, 0) fromRect:[ciImage extent]];
  // Note: Does not leak when using the software renderer. See
  [image unlockFocus];
  return image;*/
}


- (NSImage*)imageByApplyingCIFilterNamed:(NSString*)ciFilterName
                        filterParameters:(NSDictionary*)filterParameters {
  CIImage* ciImage = [self ciImage];
  //if ([image isFlipped])
  //  ciImage = [ciImage flippedImage];
  ciImage = [ciImage imageByApplyingFilterNamed:ciFilterName
                                     parameters:filterParameters];
  return [NSImage imageWithCIImage:ciImage];
}


- (NSImage*)imageByApplyingCIFilterNamed:(NSString*)ciFilterName {
  return [self imageByApplyingCIFilterNamed:ciFilterName
                           filterParameters:nil];
}


- (CIImage*)ciImage {
  return [[[CIImage alloc] initWithData:[self TIFFRepresentation]] autorelease];
}

@end

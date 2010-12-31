#import "NSColor-web.h"
#import <libkern/OSAtomic.h>
#import <stdint.h>

static uint32_t _strtouint32(const char *pch, int radix) {
  char *endptr = NULL;
  long val = strtol(pch, &endptr, radix);
  if (!endptr || val < 0) return 0;
  else if (val > 0xffffffffL) return 0xffffffff;
  return (uint32_t)val;
}

static uint8_t _strtouint8(const char *pch, int radix) {
  char *endptr = NULL;
  long val = strtol(pch, &endptr, radix);
  if (!endptr || val < 0) return 0;
  else if (val > 0xff) return 0xff;
  return (uint8_t)val;
}

static float _strtopfloat(const char *pch) {
  char *endptr = NULL;
  float val = strtof(pch, &endptr);
  if (!endptr || val < 0.0f) return 0.0f;
  else if (val > 1.0f) return 1.0f;
  return val;
}

@implementation NSColorSpace (Kod)

static NSColorSpace *gLabColorSpace_ = nil;
static OSSpinLock gLabColorSpaceSpinLock_ = OS_SPINLOCK_INIT;

+ (NSColorSpace *)genericLabColorSpace {
  OSSpinLockLock(&gLabColorSpaceSpinLock_);
  if (!gLabColorSpace_) {
    // Observer= 2°, Illuminant= D65
    // TODO(alcor): these should come from ColorSync
    CGFloat whitePoint[3] = {0.95047, 1.0, 1.08883};
    CGFloat blackPoint[3] = {0, 0, 0};
    CGFloat range[4] = {-127, 127, -127, 127};
    CGColorSpaceRef cs = CGColorSpaceCreateLab(whitePoint, blackPoint, range);
    if (cs) {
      gLabColorSpace_ = [[NSColorSpace alloc] initWithCGColorSpace:cs];
      CGColorSpaceRelease(cs);
    }
  }
  OSSpinLockUnlock(&gLabColorSpaceSpinLock_);
  return gLabColorSpace_;
}
@end

@implementation NSColor (web)

static const CGFloat kLuminanceDarkCutoff_ = 0.6;


+ (NSColor*)colorWithSRGBHexString:(NSString*)str {
  NSColor *color = nil;
  if (!str) return nil;
  NSUInteger len = str.length;
  if (len > 8) return nil;
  const char *pch = [str cStringUsingEncoding:NSASCIIStringEncoding];
  CGFloat rgba[4];
  switch (len) {
    case 8: { // RRGGBBAA
      uint32_t u = _strtouint32(pch, 16);
      rgba[0] = (CGFloat)(u >> 24) / 255.0;
      rgba[1] = (CGFloat)(u >> 16 & 0xff) / 255.0;
      rgba[2] = (CGFloat)(u >> 8 & 0xff) / 255.0;
      rgba[3] = (CGFloat)(u & 0xff) / 255.0;
      break;
    }
    case 6: { // RRGGBB
      uint32_t u = _strtouint32(pch, 16) << 8 | 0xff;
      assert(u <= 0xffffff);
      rgba[0] = (CGFloat)(u >> 16) / 255.0;
      rgba[1] = (CGFloat)(u >> 8 & 0xff) / 255.0;
      rgba[2] = (CGFloat)(u & 0xff) / 255.0;
      rgba[3] = 1.0;
      break;
    }
    case 4: { // RGBA
      uint32_t u = _strtouint32(pch, 16);
      assert(u <= 0xffff);
      uint8_t c = (u & 0xf000) >> 12;
      rgba[0] = (CGFloat)(c << 4 | c) / 255.0;
      c = (u & 0xf00) >> 8;
      rgba[1] = (CGFloat)(c << 4 | c) / 255.0;
      c = (u & 0xf0) >> 4;
      rgba[2] = (CGFloat)(c << 4 | c) / 255.0;
      c = u & 0xf;
      rgba[3] = (CGFloat)(c << 4 | c) / 255.0;
      break;
    }
    case 3: { // RGB
      uint32_t u = _strtouint32(pch, 16);
      assert(u <= 0xfff);
      uint8_t c = (u & 0xf00) >> 8;
      rgba[0] = (CGFloat)(c << 4 | c) / 255.0;
      c = (u & 0xf0) >> 4;
      rgba[1] = (CGFloat)(c << 4 | c) / 255.0;
      c = u & 0xf;
      rgba[2] = (CGFloat)(c << 4 | c) / 255.0;
      rgba[3] = 1.0;
      break;
    }
    default:
      return nil;
  }
  return [NSColor colorWithColorSpace:[NSColorSpace sRGBColorSpace]
                           components:rgba
                                count:4];
}


+ (NSColor*)randomColorWithSaturation:(CGFloat)saturation
                           brightness:(CGFloat)brightness
                                alpha:(CGFloat)alpha {
  srand(time(NULL));
  CGFloat hue = (CGFloat)rand() / RAND_MAX;
  return [NSColor colorWithCalibratedHue:hue saturation:0.5 brightness:0.9 alpha:1.0];
}


typedef union rgbauint32 {
  struct { uint8_t r; uint8_t g; uint8_t b; uint8_t a; } rgba;
  uint32_t uintValue;
} rgbauint32_t;


static uint32_t _touint32(NSColor *color) {
  CGFloat r = 0.0, g = 0.0, b = 0.0, a = 0.0;
  [color getRed:&r green:&g blue:&b alpha:&a];
  rgbauint32_t u;
  u.rgba.r = (uint32_t)(r * 255.0);
  u.rgba.g = (uint32_t)(g * 255.0);
  u.rgba.b = (uint32_t)(b * 255.0);
  u.rgba.a = (uint32_t)(a * 255.0);
  return u.uintValue;
}


- (uint32_t)sRGBUInt32Value {
  NSColor *color = [self colorUsingSRGBColorSpace];
  if (!color) return 0;
  return _touint32(color);
}


- (NSString*)sRGBhexString {
  NSColor *color = [self colorUsingSRGBColorSpace];
  if (!color) return nil;
  return [NSString stringWithFormat:@"%x",
         CFSwapInt32HostToBig(_touint32(color))];
}


- (NSColor*)colorUsingSRGBColorSpace {
  NSColorSpace *sRGBColorSpace = [NSColorSpace sRGBColorSpace];
  if (![[self colorSpace] isEqual:sRGBColorSpace]) {
    return [self colorUsingColorSpace:sRGBColorSpace];
  }
  return self;
}


- (NSColor*)labColor {
  return [self colorUsingColorSpace:[NSColorSpace genericLabColorSpace]];
}


- (CGFloat)luminance {
  CGFloat lab[4];
  lab[0] = 0.0;
  [[self labColor] getComponents:lab];
  return lab[0] / 100.0;
}


- (BOOL)isDarkColor {
  return [self luminance] < kLuminanceDarkCutoff_;
}


- (NSColor*)legibleTextColor {
  return [self isDarkColor] ? [NSColor whiteColor] : [NSColor blackColor];
}


@end

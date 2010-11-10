#import "NSColor-web.h"

static uint32_t _strtouint32(const char *pch, int radix) {
  char *endptr = NULL;
  long val = strtol(pch, &endptr, radix);
  if (!endptr || val < 0) return 0;
  else if (val > 0xffffff) return 0xffffff;
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

@implementation NSColor (web)

static NSDictionary *map_ = nil;

+ (void)load {
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  map_ = [[NSDictionary alloc] initWithObjectsAndKeys:
    [NSColor colorWithCalibratedRed:0.9411764705882353 green:0.9725490196078431 blue:1 alpha:1.0], @"aliceblue",
    [NSColor colorWithCalibratedRed:0.9803921568627451 green:0.9215686274509803 blue:0.8431372549019608 alpha:1.0], @"antiquewhite",
    [NSColor colorWithCalibratedRed:0 green:1 blue:1 alpha:1.0], @"aqua",
    [NSColor colorWithCalibratedRed:0.4980392156862745 green:1 blue:0.8313725490196079 alpha:1.0], @"aquamarine",
    [NSColor colorWithCalibratedRed:0.9411764705882353 green:1 blue:1 alpha:1.0], @"azure",
    [NSColor colorWithCalibratedRed:0.9607843137254902 green:0.9607843137254902 blue:0.8627450980392157 alpha:1.0], @"beige",
    [NSColor colorWithCalibratedRed:1 green:0.8941176470588236 blue:0.7686274509803922 alpha:1.0], @"bisque",
    [NSColor colorWithCalibratedRed:0 green:0 blue:0 alpha:1.0], @"black",
    [NSColor colorWithCalibratedRed:1 green:0.9215686274509803 blue:0.803921568627451 alpha:1.0], @"blanchedalmond",
    [NSColor colorWithCalibratedRed:0 green:0 blue:1 alpha:1.0], @"blue",
    [NSColor colorWithCalibratedRed:0.5411764705882353 green:0.16862745098039217 blue:0.8862745098039215 alpha:1.0], @"blueviolet",
    [NSColor colorWithCalibratedRed:0.6470588235294118 green:0.16470588235294117 blue:0.16470588235294117 alpha:1.0], @"brown",
    [NSColor colorWithCalibratedRed:0.8705882352941177 green:0.7215686274509804 blue:0.5294117647058824 alpha:1.0], @"burlywood",
    [NSColor colorWithCalibratedRed:0.37254901960784315 green:0.6196078431372549 blue:0.6274509803921569 alpha:1.0], @"cadetblue",
    [NSColor colorWithCalibratedRed:0.4980392156862745 green:1 blue:0 alpha:1.0], @"chartreuse",
    [NSColor colorWithCalibratedRed:0.8235294117647058 green:0.4117647058823529 blue:0.11764705882352941 alpha:1.0], @"chocolate",
    [NSColor colorWithCalibratedRed:1 green:0.4980392156862745 blue:0.3137254901960784 alpha:1.0], @"coral",
    [NSColor colorWithCalibratedRed:0.39215686274509803 green:0.5843137254901961 blue:0.9294117647058824 alpha:1.0], @"cornflowerblue",
    [NSColor colorWithCalibratedRed:1 green:0.9725490196078431 blue:0.8627450980392157 alpha:1.0], @"cornsilk",
    [NSColor colorWithCalibratedRed:0.8627450980392157 green:0.0784313725490196 blue:0.23529411764705882 alpha:1.0], @"crimson",
    [NSColor colorWithCalibratedRed:0 green:1 blue:1 alpha:1.0], @"cyan",
    [NSColor colorWithCalibratedRed:0 green:0 blue:0.5450980392156862 alpha:1.0], @"darkblue",
    [NSColor colorWithCalibratedRed:0 green:0.5450980392156862 blue:0.5450980392156862 alpha:1.0], @"darkcyan",
    [NSColor colorWithCalibratedRed:0.7215686274509804 green:0.5254901960784314 blue:0.043137254901960784 alpha:1.0], @"darkgoldenrod",
    [NSColor colorWithCalibratedRed:0.6627450980392157 green:0.6627450980392157 blue:0.6627450980392157 alpha:1.0], @"darkgray",
    [NSColor colorWithCalibratedRed:0 green:0.39215686274509803 blue:0 alpha:1.0], @"darkgreen",
    [NSColor colorWithCalibratedRed:0.7411764705882353 green:0.7176470588235294 blue:0.4196078431372549 alpha:1.0], @"darkkhaki",
    [NSColor colorWithCalibratedRed:0.5450980392156862 green:0 blue:0.5450980392156862 alpha:1.0], @"darkmagenta",
    [NSColor colorWithCalibratedRed:0.3333333333333333 green:0.4196078431372549 blue:0.1843137254901961 alpha:1.0], @"darkolivegreen",
    [NSColor colorWithCalibratedRed:1 green:0.5490196078431373 blue:0 alpha:1.0], @"darkorange",
    [NSColor colorWithCalibratedRed:0.6 green:0.19607843137254902 blue:0.8 alpha:1.0], @"darkorchid",
    [NSColor colorWithCalibratedRed:0.5450980392156862 green:0 blue:0 alpha:1.0], @"darkred",
    [NSColor colorWithCalibratedRed:0.9137254901960784 green:0.5882352941176471 blue:0.47843137254901963 alpha:1.0], @"darksalmon",
    [NSColor colorWithCalibratedRed:0.5607843137254902 green:0.7372549019607844 blue:0.5607843137254902 alpha:1.0], @"darkseagreen",
    [NSColor colorWithCalibratedRed:0.2823529411764706 green:0.23921568627450981 blue:0.5450980392156862 alpha:1.0], @"darkslateblue",
    [NSColor colorWithCalibratedRed:0.1843137254901961 green:0.30980392156862746 blue:0.30980392156862746 alpha:1.0], @"darkslategray",
    [NSColor colorWithCalibratedRed:0 green:0.807843137254902 blue:0.8196078431372549 alpha:1.0], @"darkturquoise",
    [NSColor colorWithCalibratedRed:0.5803921568627451 green:0 blue:0.8274509803921568 alpha:1.0], @"darkviolet",
    [NSColor colorWithCalibratedRed:1 green:0.0784313725490196 blue:0.5764705882352941 alpha:1.0], @"deeppink",
    [NSColor colorWithCalibratedRed:0 green:0.7490196078431373 blue:1 alpha:1.0], @"deep skyblue",
    [NSColor colorWithCalibratedRed:0.4117647058823529 green:0.4117647058823529 blue:0.4117647058823529 alpha:1.0], @"dimgray",
    [NSColor colorWithCalibratedRed:0.11764705882352941 green:0.5647058823529412 blue:1 alpha:1.0], @"dodgerblue",
    [NSColor colorWithCalibratedRed:0.6980392156862745 green:0.13333333333333333 blue:0.13333333333333333 alpha:1.0], @"firebrick",
    [NSColor colorWithCalibratedRed:1 green:0.9803921568627451 blue:0.9411764705882353 alpha:1.0], @"floralwhite",
    [NSColor colorWithCalibratedRed:0.13333333333333333 green:0.5450980392156862 blue:0.13333333333333333 alpha:1.0], @"forestgreen",
    [NSColor colorWithCalibratedRed:0.8627450980392157 green:0.8627450980392157 blue:0.8627450980392157 alpha:1.0], @"gainsboro",
    [NSColor colorWithCalibratedRed:0.9725490196078431 green:0.9725490196078431 blue:1 alpha:1.0], @"ghostwhite",
    [NSColor colorWithCalibratedRed:1 green:0.8431372549019608 blue:0 alpha:1.0], @"gold",
    [NSColor colorWithCalibratedRed:0.8549019607843137 green:0.6470588235294118 blue:0.12549019607843137 alpha:1.0], @"goldenrod",
    [NSColor colorWithCalibratedRed:0.5019607843137255 green:0.5019607843137255 blue:0.5019607843137255 alpha:1.0], @"gray",
    [NSColor colorWithCalibratedRed:0 green:0.5019607843137255 blue:0 alpha:1.0], @"green",
    [NSColor colorWithCalibratedRed:0.6784313725490196 green:1 blue:0.1843137254901961 alpha:1.0], @"greenyellow",
    [NSColor colorWithCalibratedRed:0.9411764705882353 green:1 blue:0.9411764705882353 alpha:1.0], @"honeydew",
    [NSColor colorWithCalibratedRed:1 green:0.4117647058823529 blue:0.7058823529411765 alpha:1.0], @"hotpink",
    [NSColor colorWithCalibratedRed:0.803921568627451 green:0.3607843137254902 blue:0.3607843137254902 alpha:1.0], @"indianred",
    [NSColor colorWithCalibratedRed:0.29411764705882354 green:0 blue:0.5098039215686274 alpha:1.0], @"indigo",
    [NSColor colorWithCalibratedRed:1 green:1 blue:0.9411764705882353 alpha:1.0], @"ivory",
    [NSColor colorWithCalibratedRed:0.9411764705882353 green:0.9019607843137255 blue:0.5490196078431373 alpha:1.0], @"khaki",
    [NSColor colorWithCalibratedRed:0.9019607843137255 green:0.9019607843137255 blue:0.9803921568627451 alpha:1.0], @"lavender",
    [NSColor colorWithCalibratedRed:1 green:0.9411764705882353 blue:0.9607843137254902 alpha:1.0], @"lavenderblush",
    [NSColor colorWithCalibratedRed:0.48627450980392156 green:0.9882352941176471 blue:0 alpha:1.0], @"lawngreen",
    [NSColor colorWithCalibratedRed:1 green:0.9803921568627451 blue:0.803921568627451 alpha:1.0], @"lemonchiffon",
    [NSColor colorWithCalibratedRed:0.6784313725490196 green:0.8470588235294118 blue:0.9019607843137255 alpha:1.0], @"lightblue",
    [NSColor colorWithCalibratedRed:0.9411764705882353 green:0.5019607843137255 blue:0.5019607843137255 alpha:1.0], @"lightcoral",
    [NSColor colorWithCalibratedRed:0.8784313725490196 green:1 blue:1 alpha:1.0], @"lightcyan",
    [NSColor colorWithCalibratedRed:0.9803921568627451 green:0.9803921568627451 blue:0.8235294117647058 alpha:1.0], @"lightgoldenrodyellow",
    [NSColor colorWithCalibratedRed:0.8274509803921568 green:0.8274509803921568 blue:0.8274509803921568 alpha:1.0], @"lightgray",
    [NSColor colorWithCalibratedRed:0.5647058823529412 green:0.9333333333333333 blue:0.5647058823529412 alpha:1.0], @"lightgreen",
    [NSColor colorWithCalibratedRed:1 green:0.7137254901960784 blue:0.7568627450980392 alpha:1.0], @"lightpink",
    [NSColor colorWithCalibratedRed:1 green:0.6274509803921569 blue:0.47843137254901963 alpha:1.0], @"lightsalmon",
    [NSColor colorWithCalibratedRed:0.12549019607843137 green:0.6980392156862745 blue:0.6666666666666666 alpha:1.0], @"lightseagreen",
    [NSColor colorWithCalibratedRed:0.5294117647058824 green:0.807843137254902 blue:0.9803921568627451 alpha:1.0], @"lightskyblue",
    [NSColor colorWithCalibratedRed:0.5176470588235295 green:0.4392156862745098 blue:1 alpha:1.0], @"lightslateblue",
    [NSColor colorWithCalibratedRed:0.4666666666666667 green:0.5333333333333333 blue:0.6 alpha:1.0], @"lightslategray",
    [NSColor colorWithCalibratedRed:0.6901960784313725 green:0.7686274509803922 blue:0.8705882352941177 alpha:1.0], @"lightsteelblue",
    [NSColor colorWithCalibratedRed:1 green:1 blue:0.8784313725490196 alpha:1.0], @"lightyellow",
    [NSColor colorWithCalibratedRed:0 green:1 blue:0 alpha:1.0], @"lime",
    [NSColor colorWithCalibratedRed:0.19607843137254902 green:0.803921568627451 blue:0.19607843137254902 alpha:1.0], @"limegreen",
    [NSColor colorWithCalibratedRed:0.9803921568627451 green:0.9411764705882353 blue:0.9019607843137255 alpha:1.0], @"linen",
    [NSColor colorWithCalibratedRed:1 green:0 blue:1 alpha:1.0], @"magenta",
    [NSColor colorWithCalibratedRed:0.5019607843137255 green:0 blue:0 alpha:1.0], @"maroon",
    [NSColor colorWithCalibratedRed:0.4 green:0.803921568627451 blue:0.6666666666666666 alpha:1.0], @"mediumaquamarine",
    [NSColor colorWithCalibratedRed:0 green:0 blue:0.803921568627451 alpha:1.0], @"mediumblue",
    [NSColor colorWithCalibratedRed:0.7294117647058823 green:0.3333333333333333 blue:0.8274509803921568 alpha:1.0], @"mediumorchid",
    [NSColor colorWithCalibratedRed:0.5764705882352941 green:0.4392156862745098 blue:0.8470588235294118 alpha:1.0], @"mediumpurple",
    [NSColor colorWithCalibratedRed:0.23529411764705882 green:0.7019607843137254 blue:0.44313725490196076 alpha:1.0], @"mediumseagreen",
    [NSColor colorWithCalibratedRed:0.4823529411764706 green:0.40784313725490196 blue:0.9333333333333333 alpha:1.0], @"mediumslateblue",
    [NSColor colorWithCalibratedRed:0 green:0.9803921568627451 blue:0.6039215686274509 alpha:1.0], @"medium springgreen",
    [NSColor colorWithCalibratedRed:0.2823529411764706 green:0.8196078431372549 blue:0.8 alpha:1.0], @"mediumturquoise",
    [NSColor colorWithCalibratedRed:0.7803921568627451 green:0.08235294117647059 blue:0.5215686274509804 alpha:1.0], @"mediumvioletred",
    [NSColor colorWithCalibratedRed:0.09803921568627451 green:0.09803921568627451 blue:0.4392156862745098 alpha:1.0], @"midnightblue",
    [NSColor colorWithCalibratedRed:0.9607843137254902 green:1 blue:0.9803921568627451 alpha:1.0], @"mintcream",
    [NSColor colorWithCalibratedRed:1 green:0.8941176470588236 blue:0.8823529411764706 alpha:1.0], @"mistyrose",
    [NSColor colorWithCalibratedRed:1 green:0.8941176470588236 blue:0.7098039215686275 alpha:1.0], @"moccasin",
    [NSColor colorWithCalibratedRed:1 green:0.8705882352941177 blue:0.6784313725490196 alpha:1.0], @"navajowhite",
    [NSColor colorWithCalibratedRed:0 green:0 blue:0.5019607843137255 alpha:1.0], @"navy",
    [NSColor colorWithCalibratedRed:0.9921568627450981 green:0.9607843137254902 blue:0.9019607843137255 alpha:1.0], @"oldlace",
    [NSColor colorWithCalibratedRed:0.5019607843137255 green:0.5019607843137255 blue:0 alpha:1.0], @"olive",
    [NSColor colorWithCalibratedRed:0.4196078431372549 green:0.5568627450980392 blue:0.13725490196078433 alpha:1.0], @"olivedrab",
    [NSColor colorWithCalibratedRed:1 green:0.6470588235294118 blue:0 alpha:1.0], @"orange",
    [NSColor colorWithCalibratedRed:1 green:0.27058823529411763 blue:0 alpha:1.0], @"orangered",
    [NSColor colorWithCalibratedRed:0.8549019607843137 green:0.4392156862745098 blue:0.8392156862745098 alpha:1.0], @"orchid",
    [NSColor colorWithCalibratedRed:0.9333333333333333 green:0.9098039215686274 blue:0.6666666666666666 alpha:1.0], @"pale goldenrod",
    [NSColor colorWithCalibratedRed:0.596078431372549 green:0.984313725490196 blue:0.596078431372549 alpha:1.0], @"palegreen",
    [NSColor colorWithCalibratedRed:0.6862745098039216 green:0.9333333333333333 blue:0.9333333333333333 alpha:1.0], @"paleturquoise",
    [NSColor colorWithCalibratedRed:0.8470588235294118 green:0.4392156862745098 blue:0.5764705882352941 alpha:1.0], @"palevioletred",
    [NSColor colorWithCalibratedRed:1 green:0.9372549019607843 blue:0.8352941176470589 alpha:1.0], @"papayawhip",
    [NSColor colorWithCalibratedRed:1 green:0.8549019607843137 blue:0.7254901960784313 alpha:1.0], @"peachpuff",
    [NSColor colorWithCalibratedRed:0.803921568627451 green:0.5215686274509804 blue:0.24705882352941178 alpha:1.0], @"peru",
    [NSColor colorWithCalibratedRed:1 green:0.7529411764705882 blue:0.796078431372549 alpha:1.0], @"pink",
    [NSColor colorWithCalibratedRed:0.8666666666666667 green:0.6274509803921569 blue:0.8666666666666667 alpha:1.0], @"plum",
    [NSColor colorWithCalibratedRed:0.6901960784313725 green:0.8784313725490196 blue:0.9019607843137255 alpha:1.0], @"powderblue",
    [NSColor colorWithCalibratedRed:0.5019607843137255 green:0 blue:0.5019607843137255 alpha:1.0], @"purple",
    [NSColor colorWithCalibratedRed:1 green:0 blue:0 alpha:1.0], @"red",
    [NSColor colorWithCalibratedRed:0.7372549019607844 green:0.5607843137254902 blue:0.5607843137254902 alpha:1.0], @"rosybrown",
    [NSColor colorWithCalibratedRed:0.2549019607843137 green:0.4117647058823529 blue:0.8823529411764706 alpha:1.0], @"royalblue",
    [NSColor colorWithCalibratedRed:0.5450980392156862 green:0.27058823529411763 blue:0.07450980392156863 alpha:1.0], @"saddlebrown",
    [NSColor colorWithCalibratedRed:0.9803921568627451 green:0.5019607843137255 blue:0.4470588235294118 alpha:1.0], @"salmon",
    [NSColor colorWithCalibratedRed:0.9568627450980393 green:0.6431372549019608 blue:0.3764705882352941 alpha:1.0], @"sandybrown",
    [NSColor colorWithCalibratedRed:0.1803921568627451 green:0.5450980392156862 blue:0.3411764705882353 alpha:1.0], @"seagreen",
    [NSColor colorWithCalibratedRed:1 green:0.9607843137254902 blue:0.9333333333333333 alpha:1.0], @"seashell",
    [NSColor colorWithCalibratedRed:0.6274509803921569 green:0.3215686274509804 blue:0.17647058823529413 alpha:1.0], @"sienna",
    [NSColor colorWithCalibratedRed:0.7529411764705882 green:0.7529411764705882 blue:0.7529411764705882 alpha:1.0], @"silver",
    [NSColor colorWithCalibratedRed:0.5294117647058824 green:0.807843137254902 blue:0.9215686274509803 alpha:1.0], @"skyblue",
    [NSColor colorWithCalibratedRed:0.41568627450980394 green:0.35294117647058826 blue:0.803921568627451 alpha:1.0], @"slateblue",
    [NSColor colorWithCalibratedRed:0.4392156862745098 green:0.5019607843137255 blue:0.5647058823529412 alpha:1.0], @"slategray",
    [NSColor colorWithCalibratedRed:1 green:0.9803921568627451 blue:0.9803921568627451 alpha:1.0], @"snow",
    [NSColor colorWithCalibratedRed:0 green:1 blue:0.4980392156862745 alpha:1.0], @"springgreen",
    [NSColor colorWithCalibratedRed:0.27450980392156865 green:0.5098039215686274 blue:0.7058823529411765 alpha:1.0], @"steelblue",
    [NSColor colorWithCalibratedRed:0.8235294117647058 green:0.7058823529411765 blue:0.5490196078431373 alpha:1.0], @"tan",
    [NSColor colorWithCalibratedRed:0 green:0.5019607843137255 blue:0.5019607843137255 alpha:1.0], @"teal",
    [NSColor colorWithCalibratedRed:0.8470588235294118 green:0.7490196078431373 blue:0.8470588235294118 alpha:1.0], @"thistle",
    [NSColor colorWithCalibratedRed:1 green:0.38823529411764707 blue:0.2784313725490196 alpha:1.0], @"tomato",
    [NSColor colorWithCalibratedRed:0.25098039215686274 green:0.8784313725490196 blue:0.8156862745098039 alpha:1.0], @"turquoise",
    [NSColor colorWithCalibratedRed:0.9333333333333333 green:0.5098039215686274 blue:0.9333333333333333 alpha:1.0], @"violet",
    [NSColor colorWithCalibratedRed:0.8156862745098039 green:0.12549019607843137 blue:0.5647058823529412 alpha:1.0], @"violetred",
    [NSColor colorWithCalibratedRed:0.9607843137254902 green:0.8705882352941177 blue:0.7019607843137254 alpha:1.0], @"wheat",
    [NSColor colorWithCalibratedRed:1 green:1 blue:1 alpha:1.0], @"white",
    [NSColor colorWithCalibratedRed:0.9607843137254902 green:0.9607843137254902 blue:0.9607843137254902 alpha:1.0], @"whitesmoke",
    [NSColor colorWithCalibratedRed:1 green:1 blue:0 alpha:1.0], @"yellow",
    [NSColor colorWithCalibratedRed:0.6039215686274509 green:0.803921568627451 blue:0.19607843137254902 alpha:1.0], @"yellowgreen",
    nil];
  [pool drain];
}

+ (NSColor*)colorWithCssDefinition:(NSString*)name {
  float r = .0f, g = .0f, b = .0f, a = 1.f;
  if ([name characterAtIndex:0] == '#') {
    //NSLog(@"branch: #...");
    // branch: #%x
    name = [name substringFromIndex:1];
    uint32_t rgb = 0;
    if ([name length] == 8) {
      // branch: #rrggbbaa (special extension for e.g. srchilight)
      rgb = _strtouint32([[name substringToIndex:6] UTF8String], 16);
      a = _strtouint8([[name substringFromIndex:6] UTF8String], 16)/255.0;
    } else if ([name length] == 6) {
      // branch: #rrggbb
      rgb = _strtouint32([name UTF8String], 16);
    } else if ([name length] == 3) {
      // branch: #rgb
      const char *utf8str = [name UTF8String];
      char pch[7];
      pch[0] = pch[1] = utf8str[0];
      pch[2] = pch[3] = utf8str[1];
      pch[4] = pch[5] = utf8str[2];
      pch[6] = 0;
      rgb = _strtouint32(pch, 16);
    } else {
      // invalid
      return nil;
    }
    r = ((rgb>>16)&0xFF)/255.0;
    g = ((rgb>>8)&0xFF)/255.0;
    b = (rgb&0xFF)/255.0;
  } else if ([name hasPrefix:@"rgb"] && [name length] > 9) {
    name = [name stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSString *s;
    if ([name characterAtIndex:3] == 'a') {
      // branch: rgba(r[0-255],g[0-255],b[0-255],a[0-1])
      s = [name substringWithRange:NSMakeRange(5, [name length]-6)];
    } else {
      // branch: rgb(r[0-255],g[0-255],b[0-255])
      s = [name substringWithRange:NSMakeRange(4, [name length]-5)];
    }
    NSArray *rgba = [s componentsSeparatedByString:@","];
    if ([rgba count] >= 3) {
      r = _strtouint8([[rgba objectAtIndex:0] UTF8String], 10)/255.0;
      g = _strtouint8([[rgba objectAtIndex:1] UTF8String], 10)/255.0;
      b = _strtouint8([[rgba objectAtIndex:2] UTF8String], 10)/255.0;
      if ([rgba count] > 3)
        a = _strtopfloat([[rgba objectAtIndex:3] UTF8String]);
    } else {
      // invalid
      return nil;
    }
  } else {
    // branch: name
    name = [[name lowercaseString] stringByReplacingOccurrencesOfString:@" "
                                                             withString:@""];
    return [map_ objectForKey:name];
  }
  return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:a];
}


@end
